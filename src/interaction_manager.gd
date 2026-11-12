class_name AizuInteractionManager extends Node

signal target_changed(zone: AizuInteractionZone)
signal nearby_changed(zones: Array[AizuInteractionZone])
signal lock_changed(is_locked: bool)

## Reported as 'by' when a zone is triggered. Usually the player.
@export var interactor: Node
## Detectors to suspend while the manager is locked, so that the UI hides too.
@export var detectors: Array[AizuInteractionDetector]

var current_target: AizuInteractionZone
var nearby_zones: Array[AizuInteractionZone] = []

# detector -> { zone: true }
var _detector_candidates: Dictionary = {}
var _locks: Dictionary[StringName, bool] = {}

const _HOST_LOCK := &"host"


func _ready() -> void:
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)
	AizuInteractionDetectorBus.zone_locked.connect(_on_zone_locked)


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
	for detector in detectors:
		if detector:
			detector.set_suspended(is_locked())
	lock_changed.emit(is_locked())


## Shortcut with a single reason, handy to connect to a signal such as
## ModularFpc.lock_changed.
func set_locked(on: bool) -> void:
	set_lock(_HOST_LOCK, on)


func is_locked() -> bool:
	return not _locks.is_empty()


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
	if is_locked() or not is_instance_valid(current_target):
		return
	if not current_target.can_be_triggered():
		return

	# The first action whose input matches wins, the primary one first.
	for action in current_target.get_actions():
		if action.can_trigger() and action.trigger.is_triggered(event):
			current_target.trigger_action(action, interactor)
			get_viewport().set_input_as_handled()
			return
