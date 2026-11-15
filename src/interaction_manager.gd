class_name AizuInteractionManager extends Node

signal target_changed(zone: AizuInteractionZone)
signal nearby_changed(zones: Array[AizuInteractionZone])
signal lock_changed(is_locked: bool)
## A grabbable was grabbed.
signal grabbed(grabbable: AizuGrabbable)
## The held grabbable was let go, dropped or thrown.
signal released(grabbable: AizuGrabbable)
## The held grabbable was thrown, right after [signal released].
signal thrown(grabbable: AizuGrabbable)
## What is held changed: the grabbable, or null when nothing is held.
signal held_changed(grabbable: AizuGrabbable)

## Reported as 'by' when a zone is triggered. Usually the player.
@export var interactor: Node
## Detectors to suspend while the manager is locked, so that the UI hides too.
@export var detectors: Array[AizuInteractionDetector]

@export_group("Grab")
## Where the held body is carried to, and the direction it is thrown along (its
## -Z axis). Usually a Marker3D in front of the camera.
@export var grab_point: Marker3D
## Input that throws the held body. Dropping uses the input that grabbed it.
@export var throw_trigger: AizuInteractionTrigger
## Impulse of a throw, multiplied by the throw_force_multiplier of the grabbable.
## An impulse depends on the mass: a body of 1 kg leaves at this speed in m/s.
@export_range(0.0, 1000.0, 0.1, "or_greater") var base_throw_force: float = 8.0
## How hard the held body is pulled to the grab point, in 1/s: the speed is the
## distance times this.
@export_range(0.0, 100.0, 0.1, "or_greater") var grab_stiffness: float = 20.0
## Speed limit of the pull, in m/s. The body also turns to the grab point's
## orientation, limited by the same number of radians per second.
@export_range(0.0, 100.0, 0.1, "or_greater") var max_grab_speed: float = 12.0
## Prompt rows shown while something is held. [code]{interaction_key}[/code]
## stands for the input, and the text goes through tr() like any prompt.
@export var drop_text: String = "{interaction_key} Drop"
@export var throw_text: String = "{interaction_key} Throw"

var current_target: AizuInteractionZone
## The grabbable being carried, or null.
var held: AizuGrabbable
var nearby_zones: Array[AizuInteractionZone] = []

# detector -> { zone: true }
var _detector_candidates: Dictionary = {}
var _locks: Dictionary[StringName, bool] = {}
var _drop_action: AizuInteractionAction = AizuInteractionAction.new()
var _throw_action: AizuInteractionAction = AizuInteractionAction.new()
# Body state to restore on release.
var _saved_gravity_scale: float
var _saved_can_sleep: bool
# Orientation of the body relative to the grab point, kept from the grab.
var _grab_local_basis: Basis
var _held_exception: PhysicsBody3D

const _HOST_LOCK := &"host"


func _ready() -> void:
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)
	AizuInteractionDetectorBus.zone_locked.connect(_on_zone_locked)
	AizuInteractionDetectorBus.grab_requested.connect(_on_grab_requested)
	_drop_action.id = &"drop"
	_throw_action.id = &"throw"
	set_physics_process(false)


## Locks the interaction for a reason (menu, cutscene, dialogue...). Several
## reasons can be active at once: interaction comes back when all are released.
func set_lock(reason: StringName, on: bool) -> void:
	var was_locked := is_locked()
	if on:
		_locks[reason] = true
	else:
		_locks.erase(reason)
	if is_locked() == was_locked:
		return
	if is_locked():
		drop()
	_sync_detectors()
	lock_changed.emit(is_locked())


## Shortcut with a single reason, handy to connect to the lock signal of
## whatever controls the player.
func set_locked(on: bool) -> void:
	set_lock(_HOST_LOCK, on)


func is_locked() -> bool:
	return not _locks.is_empty()


func is_holding() -> bool:
	return held != null


## Grabs a grabbable. Fails, returning false, when something is already held,
## the manager is locked, there is no grab point or the body is frozen.
func grab(grabbable: AizuGrabbable) -> bool:
	if held != null or is_locked() or not is_instance_valid(grabbable):
		return false
	var body := grabbable.body
	if not is_instance_valid(body) or not body.is_inside_tree() or body.freeze:
		return false
	if grab_point == null:
		push_warning("AizuInteractionManager needs a grab_point to grab.")
		return false

	held = grabbable
	grabbable.is_grabbed = true
	_saved_gravity_scale = body.gravity_scale
	_saved_can_sleep = body.can_sleep
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.sleeping = false
	grabbable.protect_collision()
	_held_exception = interactor as PhysicsBody3D
	if _held_exception:
		body.add_collision_exception_with(_held_exception)
	_grab_local_basis = (
		grab_point.global_basis.orthonormalized().inverse() * body.global_basis.orthonormalized()
	)
	body.tree_exiting.connect(drop, CONNECT_ONE_SHOT)
	# The zone of the body is locked so it is not targeted while carried. The
	# detectors then report again, and only the zones with a use for what is held
	# are of use now.
	grabbable.zone.lock()
	AizuInteractionDetectorBus.set_held(grabbable.kinds)
	# The body in front of the camera, and its zone, must not hide what the player
	# aims at: a cast stops at the first thing it touches.
	for detector in detectors:
		if detector:
			detector.ignore_body(body)
			detector.ignore_body(grabbable.zone)
	_refresh_detectors()
	set_physics_process(true)
	grabbable.grabbed.emit()
	grabbed.emit(grabbable)
	held_changed.emit(grabbable)
	return true


## Lets the held body go. It keeps the velocity it had.
func drop() -> void:
	_release(false)


## Lets the held body go with an impulse along the -Z axis of the grab point.
func throw() -> void:
	_release(true)


## Rows to show while something is held: the item uses of the targeted zone,
## then drop and throw. Each one only when it has an input. Drop and throw give
## way to a use that shares their input.
func get_held_actions() -> Array[AizuInteractionAction]:
	var rows: Array[AizuInteractionAction] = []
	if held == null:
		return rows
	for action in _get_target_uses():
		if not action.text.is_empty():
			rows.append(action)
	var grab_action := held.get_grab_action()
	if grab_action:
		_drop_action.trigger = grab_action.trigger
		_drop_action.text = drop_text
		if _drop_action.can_trigger() and not _conflicts_with_uses(_drop_action.trigger):
			rows.append(_drop_action)
	_throw_action.trigger = throw_trigger
	_throw_action.text = throw_text
	if _throw_action.can_trigger() and not _conflicts_with_uses(_throw_action.trigger):
		rows.append(_throw_action)
	return rows


func _release(with_throw: bool) -> void:
	if held == null:
		return
	var grabbable := held
	held = null
	set_physics_process(false)

	var body := grabbable.body
	grabbable.is_grabbed = false
	if is_instance_valid(body):
		if body.tree_exiting.is_connected(drop):
			body.tree_exiting.disconnect(drop)
		body.gravity_scale = _saved_gravity_scale
		body.can_sleep = _saved_can_sleep
		if is_instance_valid(_held_exception):
			body.remove_collision_exception_with(_held_exception)
		body.sleeping = false
		grabbable.restore_collision_when_at_rest()
		if with_throw and body.is_inside_tree() and grab_point:
			var direction := -grab_point.global_basis.z
			body.apply_central_impulse(
				direction * base_throw_force * grabbable.throw_force_multiplier
			)
	_held_exception = null
	if is_instance_valid(grabbable.zone):
		grabbable.zone.unlock()
	AizuInteractionDetectorBus.clear_held()
	for detector in detectors:
		if detector:
			if is_instance_valid(body):
				detector.unignore_body(body)
			if is_instance_valid(grabbable.zone):
				detector.unignore_body(grabbable.zone)
	_refresh_detectors()

	grabbable.released.emit()
	released.emit(grabbable)
	if with_throw:
		grabbable.thrown.emit()
		thrown.emit(grabbable)
	held_changed.emit(null)


# The center of mass of the body, in world space. It is the point a body is
# carried by, not its origin: the origin can be anywhere (a fish whose mesh sits
# above its pivot), and carrying it would put the body in a different spot for
# every orientation it was grabbed in.
func _get_body_center(body: RigidBody3D) -> Vector3:
	var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state == null:
		return body.global_position
	return body.global_position + state.center_of_mass


# The point of the body that goes to the grab point: the grab handle of the
# grabbable if it has one, the center of mass otherwise.
func _get_carried_point(grabbable: AizuGrabbable) -> Vector3:
	if is_instance_valid(grabbable.grab_handle) and grabbable.grab_handle.is_inside_tree():
		return grabbable.grab_handle.global_position
	return _get_body_center(grabbable.body)


# Detectors rest while locked.
func _sync_detectors() -> void:
	var suspended := is_locked()
	for detector in detectors:
		if detector:
			detector.set_suspended(suspended)


# Makes the detectors report their zones again, to judge them against what is
# held now. A locked manager has them suspended already.
func _refresh_detectors() -> void:
	if is_locked():
		return
	for detector in detectors:
		if detector:
			detector.set_suspended(true)
			detector.set_suspended(false)


func _on_grab_requested(grabbable: AizuGrabbable, by: Node) -> void:
	if by == interactor:
		grab(grabbable)


func _physics_process(_delta: float) -> void:
	if held == null or not is_instance_valid(held.body) or grab_point == null:
		return
	var body := held.body
	var point := _get_carried_point(held)
	var to_point := grab_point.global_position - point
	var point_velocity := (to_point * grab_stiffness).limit_length(max_grab_speed)

	# Turn by the shortest rotation to the orientation the body had at the grab,
	# relative to the grab point.
	var target := (
		(grab_point.global_basis.orthonormalized() * _grab_local_basis).get_rotation_quaternion()
	)
	var delta_rotation := target * body.global_basis.orthonormalized().get_rotation_quaternion().inverse()
	if delta_rotation.w < 0.0:
		delta_rotation = -delta_rotation
	var angle := delta_rotation.get_angle()
	var axis := delta_rotation.get_axis() if angle > 0.0001 else Vector3.ZERO
	body.angular_velocity = (axis * angle * grab_stiffness).limit_length(max_grab_speed)

	# The turn is around the center of mass: it also moves a carried point that is
	# not there, so the velocity of the body makes up for it.
	var arm := point - _get_body_center(body)
	body.linear_velocity = point_velocity - body.angular_velocity.cross(arm)


func _on_zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if not is_instance_valid(detector) or not is_instance_valid(zone):
		return
	if not _detector_candidates.has(detector):
		_detector_candidates[detector] = {}
	_detector_candidates[detector][zone] = true
	_update_nearby()
	_update_target()


func _on_zone_lost(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if not _detector_candidates.has(detector):
		return
	_detector_candidates[detector].erase(zone)
	if _detector_candidates[detector].is_empty():
		_detector_candidates.erase(detector)
	_update_nearby()
	_update_target()


func _update_nearby() -> void:
	var new_nearby: Array[AizuInteractionZone] = []
	for detector in _detector_candidates:
		for zone in _detector_candidates[detector]:
			if is_instance_valid(zone) and zone.can_be_detected() and not new_nearby.has(zone):
				new_nearby.append(zone)
	if new_nearby != nearby_zones:
		nearby_zones = new_nearby
		nearby_changed.emit(nearby_zones)


func _update_target() -> void:
	var new_target: AizuInteractionZone
	var highest_priority: int = -2147483648
	for detector in _detector_candidates:
		if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
			continue
		for zone in _detector_candidates[detector]:
			if not is_instance_valid(zone):
				continue
			if detector.priority > highest_priority:
				highest_priority = detector.priority
				new_target = zone
	if new_target == current_target:
		return
	current_target = new_target
	target_changed.emit(current_target)


func _on_zone_locked(zone: AizuInteractionZone) -> void:
	var to_emit: Array = []
	for detector in _detector_candidates:
		if _detector_candidates[detector].has(zone):
			to_emit.append(detector)
			_detector_candidates[detector].erase(zone)
	_update_nearby()
	_update_target()
	for detector in to_emit:
		AizuInteractionDetectorBus.zone_lost.emit(detector, zone)


func _unhandled_input(event: InputEvent) -> void:
	if is_locked():
		return
	if held != null:
		_handle_held_input(event)
		return
	if not is_instance_valid(current_target):
		return
	if not current_target.can_be_triggered():
		return

	# The first action whose input matches wins, the primary one first.
	for action in current_target.get_actions():
		if action.can_trigger() and action.trigger.is_triggered(event):
			current_target.trigger_action(action, interactor)
			get_viewport().set_input_as_handled()
			return


func _handle_held_input(event: InputEvent) -> void:
	# A use on the zone being aimed at wins over drop and throw.
	for use in _get_target_uses():
		if use.trigger.is_triggered(event):
			var receiver := current_target.find_receiver(use as AizuItemUse)
			if receiver:
				receiver.use(use as AizuItemUse, held, interactor)
				get_viewport().set_input_as_handled()
				return
	if throw_trigger and throw_trigger.is_triggered(event):
		throw()
		get_viewport().set_input_as_handled()
		return
	var grab_action := held.get_grab_action()
	if grab_action and grab_action.can_trigger() and grab_action.trigger.is_triggered(event):
		drop()
		get_viewport().set_input_as_handled()


# The enabled item uses of the zone being aimed at, for what is held.
func _get_target_uses() -> Array[AizuInteractionAction]:
	var uses: Array[AizuInteractionAction] = []
	if held == null or not is_instance_valid(current_target):
		return uses
	if not current_target.can_be_triggered():
		return uses
	for action in current_target.get_actions():
		if action.can_trigger():
			uses.append(action)
	return uses


func _conflicts_with_uses(trigger: AizuInteractionTrigger) -> bool:
	for use in _get_target_uses():
		if use.trigger.conflicts_with(trigger):
			return true
	return false
