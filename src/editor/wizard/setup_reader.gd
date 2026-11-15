@tool
extends RefCounted
## Fills the model with what the object already has, so the wizard opens as an editor of
## the nodes that are in the scene. It reads through get(): the scripts of the addon do
## not run in the editor.

const _Model := preload("res://addons/godot-aizu/src/editor/wizard/setup_model.gd")


func fill(model: RefCounted, scan: RefCounted) -> void:
	model.is_edit = scan.zone != null or scan.outline != null or scan.grabbable != null or scan.receiver != null
	if not model.is_edit:
		return
	model.enable_outline = scan.outline != null
	if scan.zone:
		_read_zone(model, scan.zone)
	if scan.grabbable:
		_read_grabbable(model, scan.grabbable)
	if scan.receiver:
		_read_receiver(model, scan.receiver)


## The text of the input of a trigger for the dropdowns: the action, "(custom key)" or "".
static func input_of(trigger: Resource) -> String:
	if trigger == null:
		return ""
	if trigger.get("input_override") != null:
		return _Model.CUSTOM_KEY
	return String(trigger.get("interaction_input_action_name"))


## True for a resource that is a file of its own, shared with other scenes, and false for
## one that lives inside the scene.
static func is_shared(resource: Resource) -> bool:
	return resource != null and not resource.resource_path.is_empty() and not "::" in resource.resource_path


func _read_zone(model: RefCounted, zone: Node) -> void:
	model.display_name = zone.get("display_name")
	model.prompt_text = zone.get("interaction_text")
	model.input_action = StringName(input_of(zone.get("interaction_trigger")))
	for action in zone.get("actions"):
		if action:
			model.extra_actions.append(_read_action(action))


func _read_action(action: Resource) -> Dictionary:
	return {
		"id": String(action.get("id")),
		"input_action": input_of(action.get("trigger")),
		"text": action.get("text"),
		"ref": action,
		"copy_trigger": "",
		"copy_resource": "",
	}


func _read_grabbable(model: RefCounted, grabbable: Node) -> void:
	model.enable_grab = true
	for kind in grabbable.get("kinds"):
		if kind and not kind.resource_path.is_empty() and not "::" in kind.resource_path:
			model.kind_paths.append(kind.resource_path)
	model.create_handle = grabbable.get("grab_handle") != null
	model.throw_multiplier = grabbable.get("throw_force_multiplier")


func _read_receiver(model: RefCounted, receiver: Node) -> void:
	model.enable_receiver = true
	for use in receiver.get("uses"):
		if use == null:
			continue
		var row := _read_action(use)
		var kind: Resource = use.get("kind")
		row["kind"] = kind.resource_path if is_shared(kind) else ""
		model.uses.append(row)
