class_name AizuItemReceiver extends Node
## Lets grabbables be used on an object: a knife on a piece of meat, a key on a
## door. Give it the zones of the object and the item uses it accepts.
##
## With nothing held the zones behave as usual. While the player holds a
## grabbable, a zone is active only if one of its receivers has an enabled item
## use for one of the kinds held. The zone then shows the prompts of those uses
## instead of its own actions.
##
## Connect to [signal used] from the script of the object. The held grabbable
## gets [signal AizuGrabbable.used_on], so its own script can decide what
## happens to it. Neither side knows the other. If nobody reacts, the grabbable
## stays in the hands.

## Fires when the player uses a held grabbable on this receiver.
signal used(use: AizuItemUse, grabbable: AizuGrabbable, by: Node)

## Zones of the object that offer the uses, for example both sides of a door.
@export var zones: Array[AizuInteractionZone]
## The kinds accepted, each with its input and text.
@export var uses: Array[AizuItemUse]:
	set(value):
		for use in uses:
			if use and use.changed.is_connected(_on_use_changed):
				use.changed.disconnect(_on_use_changed)
		uses = value
		for use in uses:
			if use:
				use.changed.connect(_on_use_changed)
		_on_use_changed()


func _ready() -> void:
	for zone in zones:
		if zone:
			zone.register_receiver(self)


func _exit_tree() -> void:
	for zone in zones:
		if is_instance_valid(zone):
			zone.unregister_receiver(self)


## The uses that accept one of [param kinds] and are enabled.
func get_uses_for(kinds: Array[AizuItemKind]) -> Array[AizuItemUse]:
	var found: Array[AizuItemUse] = []
	for use in uses:
		if use and use.kind and use.can_trigger() and kinds.has(use.kind):
			found.append(use)
	return found


## Uses the held grabbable. Called by the manager.
func use(item_use: AizuItemUse, grabbable: AizuGrabbable, by: Node) -> void:
	used.emit(item_use, grabbable, by)
	grabbable.used_on.emit(self, item_use)


func _on_use_changed() -> void:
	for zone in zones:
		if is_instance_valid(zone):
			zone.refresh_prompt_and_availability()
