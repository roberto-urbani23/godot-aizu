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

## The body that gets carried. Frozen bodies cannot be grabbed.
@export var body: RigidBody3D
## The zone that offers the grab. Usually a child of the body, so it follows it.
@export var zone: AizuInteractionZone
## Id of the action of the zone that grabs. The primary action is "primary".
@export var grab_action_id: StringName = AizuInteractionZone.PRIMARY_ACTION_ID
## Optional. The point of the body that is carried to the grab point, for example
## the tail of a fish. Without it the body is carried by its center of mass.
@export var grab_handle: Marker3D
## Multiplies the base throw force of the manager. 1 changes nothing: raise it
## for heavy bodies, lower it for light ones.
@export_range(0.0, 100.0, 0.01, "or_greater") var throw_force_multiplier: float = 1.0

## True while a manager is carrying the body. Set by the manager.
var is_grabbed: bool = false


func _ready() -> void:
	if body == null or zone == null:
		push_warning("AizuGrabbable '%s' needs both body and zone." % name)
		return
	zone.action_triggered.connect(_on_action_triggered)


## The action of the zone that grabs, or null if the zone has none with that id.
func get_grab_action() -> AizuInteractionAction:
	if zone == null:
		return null
	for action in zone.get_actions():
		if action.id == grab_action_id:
			return action
	return null


func _on_action_triggered(action: AizuInteractionAction, by: Node) -> void:
	if action.id == grab_action_id and not is_grabbed:
		AizuInteractionDetectorBus.grab_requested.emit(self, by)
