class_name AizuGrabbable extends Node
## Makes a rigid body grabbable: the player can carry it around and throw it.
## Put it next to the body, wire the exports, and give the zone an action whose
## id is [member grab_action_id] (the primary action by default).
##
## While the body is grabbed its zone stays locked, so keep other code from
## unlocking it.

## Fires when the body is grabbed.
signal grabbed
## Fires when the body is let go, dropped or thrown.
signal released
## Fires when the body is thrown, right after [signal released].
signal thrown
## Fires when the body is used on a receiver. The script of the grabbable's own
## object decides what happens to it: the receiver never touches it. A key frees
## itself here, a knife does nothing and stays in the hands.
signal used_on(receiver: AizuItemReceiver, use: AizuItemUse)

## The body that gets carried. Frozen bodies cannot be grabbed.
@export var body: RigidBody3D
## The zone that offers the grab. Usually a child of the body, so it follows it.
@export var zone: AizuInteractionZone
## Id of the action of the zone that grabs. The primary action is "primary".
@export var grab_action_id: StringName = AizuInteractionZone.PRIMARY_ACTION_ID
## What this grabbable is for the receivers it can be used on. The kinds a
## receiver accepts are matched against these.
@export var kinds: Array[AizuItemKind]
## Optional. The point of the body that is carried to the grab point, for example
## the tail of a fish. Without it the body is carried by its center of mass.
@export var grab_handle: Marker3D
## Turns on continuous collision detection on the body from the grab until it
## comes to rest after being let go. A small or thin body (a knife, a key) thrown
## fast would otherwise go through the floor.
@export var continuous_collision: bool = true
## Multiplies the base throw force of the manager. 1 changes nothing: raise it
## for heavy bodies, lower it for light ones.
@export_range(0.0, 100.0, 0.01, "or_greater") var throw_force_multiplier: float = 1.0

## True while a manager is carrying the body. Set by the manager.
var is_grabbed: bool = false

var _saved_continuous_cd: bool = false
var _cd_restore_pending: bool = false


func _ready() -> void:
	if body == null or zone == null:
		push_warning("AizuGrabbable '%s' needs both body and zone." % name)
		return
	zone.action_triggered.connect(_on_action_triggered)


## The action of the zone that grabs, or null if the zone has none with that id.
func get_grab_action() -> AizuInteractionAction:
	if zone == null:
		return null
	for action in zone.get_own_actions():
		if action.id == grab_action_id:
			return action
	return null


## Turns on continuous collision detection on the body, if
## [member continuous_collision] is set. Called by the manager at the grab.
func protect_collision() -> void:
	if not continuous_collision or not is_instance_valid(body):
		return
	if _cd_restore_pending:
		# Grabbed again before the last throw came to rest: the saved value is
		# still the original one.
		body.sleeping_state_changed.disconnect(_on_sleeping_state_changed)
		_cd_restore_pending = false
	else:
		_saved_continuous_cd = body.continuous_cd
	body.continuous_cd = true


## Puts continuous collision detection back as it was when the body rests.
## Called by the manager when the body is let go.
func restore_collision_when_at_rest() -> void:
	if not continuous_collision or not is_instance_valid(body) or _cd_restore_pending:
		return
	_cd_restore_pending = true
	body.sleeping_state_changed.connect(_on_sleeping_state_changed)


func _on_sleeping_state_changed() -> void:
	if not body.sleeping:
		return
	body.continuous_cd = _saved_continuous_cd
	body.sleeping_state_changed.disconnect(_on_sleeping_state_changed)
	_cd_restore_pending = false


func _on_action_triggered(action: AizuInteractionAction, by: Node) -> void:
	if action.id == grab_action_id and not is_grabbed:
		AizuInteractionDetectorBus.grab_requested.emit(self, by)
