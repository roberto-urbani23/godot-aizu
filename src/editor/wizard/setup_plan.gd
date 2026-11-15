@tool
extends RefCounted
## Turns the choices of the wizard into what has to change in the scene: nodes and
## resources to create, values to change, nodes to remove, and the script lines to add.
## It compares the choices with what the scene has now, so the same code creates an
## object and edits one.
##
## Building the plan creates the nodes in memory only: nothing touches the scene or the
## disk until [method apply]. The summary step shows [member lines] and the dialog
## calls [method discard] when it closes without applying.
##
## Meshes, bodies, collision shapes and the files of the kinds are never touched, except
## that meshes are moved when the wizard creates the body for them. A resource that is a
## file shared with other scenes is never changed: a copy with the new values is saved
## under the name the player gave.

const _MeshBounds := preload("res://addons/godot-aizu/src/editor/mesh_bounds.gd")
const _ScriptWriter := preload("res://addons/godot-aizu/src/editor/wizard/script_writer.gd")
const _Scan := preload("res://addons/godot-aizu/src/editor/wizard/setup_scan.gd")
const _Model := preload("res://addons/godot-aizu/src/editor/wizard/setup_model.gd")
const _Reader := preload("res://addons/godot-aizu/src/editor/wizard/setup_reader.gd")
const _ITEM_KIND_SCRIPT := preload("res://addons/godot-aizu/src/interactable/item_kind.gd")
const _ITEM_USE_SCRIPT := preload("res://addons/godot-aizu/src/interactable/item_use.gd")
const _TRIGGER_SCRIPT := preload("res://addons/godot-aizu/src/interactable/interaction_trigger.gd")
const _ACTION_SCRIPT := preload("res://addons/godot-aizu/src/interactable/interaction_action.gd")
const _OUTLINE_MATERIAL := "res://addons/godot-aizu/src/materials/outline.tres"
## Extra room around the mesh for the box of the zone, on every side.
const _ZONE_MARGIN := 0.05

## What will happen, one line each, for the summary.
var lines: PackedStringArray = []
## The lines added to the script, for the preview. Empty without a script.
var script_added: PackedStringArray = []
var notes: PackedStringArray = []
## Lines of the script that point to nodes this plan removes: "line 12: grabbable.used_on...".
var script_orphans: PackedStringArray = []
## What stops the plan from being applied, for example two copies with the same name.
var errors: PackedStringArray = []

var zone_node: Node
var grabbable_node: Node
var receiver_node: Node

var _model: RefCounted
var _scan: RefCounted
var _scene_root: Node
var _created: Array[Dictionary] = []  # { "node", "parent" } in the order they are added
var _moves: Array[Dictionary] = []  # { "node", "from", "to" }
var _new_files: Array[Dictionary] = []  # { "resource", "path" }
var _changes: Array[Dictionary] = []  # { "object", "property", "value", "old" }
var _removed: Array[Dictionary] = []  # { "node", "parent", "index" }
var _removed_names: Array[String] = []  # names of the script variables that held a removed node
var _kinds: Dictionary = {}  # token -> Resource
var _script_path: String = ""
var _script_text: String = ""
var _script_is_new: bool = false
var _script_changed: bool = false
var _script_exports: Dictionary = {}  # export name in the script -> node
var _applied: bool = false


func build(model: RefCounted, scan: RefCounted) -> void:
	_model = model
	_scan = scan
	_scene_root = scan.scene_root
	var object_root: Node3D = scan.object_root

	var host: Node3D = scan.body
	var space: Node3D = scan.body if scan.body else object_root
	if host == null and model.enable_grab and model.create_body:
		host = _make_body(object_root)
	if host == null:
		host = object_root

	if host is RigidBody3D and _has_no_shape(host) and not _meshes().is_empty():
		_add_box_shape(host, space, 0.0, "body")

	_build_zone(host, space)
	if scan.outline:
		if not model.enable_outline:
			_remove(scan.outline, "the outline '%s'" % scan.outline.name)
	elif model.enable_outline and not _meshes().is_empty():
		_build_outline(host)
	if scan.grabbable:
		if model.enable_grab:
			_edit_grabbable(host, space)
		else:
			_remove_grabbable()
	elif model.enable_grab:
		_build_grabbable(host, space)
	if scan.receiver:
		if model.enable_receiver:
			_edit_receiver()
		else:
			_remove(scan.receiver, "the receiver '%s'" % scan.receiver.name)
	elif model.enable_receiver:
		_build_receiver(object_root)
	if model.enable_script:
		_build_script()
	_find_script_orphans()
	if (
		_created.is_empty()
		and _changes.is_empty()
		and _removed.is_empty()
		and _new_files.is_empty()
		and _moves.is_empty()
		and not _script_changed
	):
		lines.append("Nothing to change: the scene already looks like this.")


## Makes the changes, as a single action of the editor undo. Returns false if it could
## not write a file.
func apply(undo_redo: EditorUndoRedoManager) -> bool:
	if not errors.is_empty():
		return false
	for file in _new_files:
		DirAccess.make_dir_recursive_absolute(file["path"].get_base_dir())
		if ResourceSaver.save(file["resource"], file["path"]) != OK:
			push_error("Aizu: could not save %s" % file["path"])
			return false
		file["resource"].take_over_path(file["path"])

	var new_script: Script
	if _script_changed:
		new_script = _write_script()
		if new_script == null:
			return false

	var object_root: Node3D = _scan.object_root
	# The undo runs backwards: the script, the moves, then the nodes, children first.
	var action_name := "Aizu: edit '%s'" if _model.is_edit else "Aizu: make '%s' interactable"
	undo_redo.create_action(action_name % object_root.name, 0, _scene_root, true)
	for item in _created:
		var node: Node = item["node"]
		undo_redo.add_do_method(item["parent"], "add_child", node, true)
		undo_redo.add_do_method(node, "set_owner", _scene_root)
		undo_redo.add_do_reference(node)
		undo_redo.add_undo_method(item["parent"], "remove_child", node)
	for move in _moves:
		# Leaving a parent drops the owner, so it is set again after each move.
		undo_redo.add_do_method(move["node"], "reparent", move["to"], true)
		undo_redo.add_do_method(move["node"], "set_owner", _scene_root)
		undo_redo.add_undo_method(move["node"], "set_owner", _scene_root)
		undo_redo.add_undo_method(move["node"], "reparent", move["from"], true)
	for change in _changes:
		undo_redo.add_do_property(change["object"], change["property"], change["value"])
		undo_redo.add_undo_property(change["object"], change["property"], change["old"])
	for item in _removed:
		var gone: Node = item["node"]
		undo_redo.add_do_method(item["parent"], "remove_child", gone)
		undo_redo.add_undo_reference(gone)
		# The undo runs backwards: it puts the node back, moves it to its place, then owns it.
		undo_redo.add_undo_method(gone, "set_owner", _scene_root)
		undo_redo.add_undo_method(item["parent"], "move_child", gone, item["index"])
		undo_redo.add_undo_method(item["parent"], "add_child", gone, true)
	if new_script and _script_is_new:
		undo_redo.add_do_property(object_root, "script", new_script)
		undo_redo.add_undo_property(object_root, "script", null)
	for export_name in _script_exports:
		undo_redo.add_do_property(object_root, export_name, _script_exports[export_name])
	undo_redo.commit_action()
	_applied = true

	if not _new_files.is_empty() or _script_changed:
		EditorInterface.get_resource_filesystem().scan()
	return true


## Frees what was created in memory and never added to the scene.
func discard() -> void:
	if _applied:
		return
	for item in _created:
		var node: Node = item["node"]
		if is_instance_valid(node) and not node.is_inside_tree():
			node.free()
	_created.clear()


func _meshes() -> Array[Node3D]:
	return _scan.meshes


func _add(node: Node, parent: Node, text: String) -> void:
	_created.append({ "node": node, "parent": parent })
	lines.append("+ %s, under '%s'" % [text, parent.name])


func _has_no_shape(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionShape3D:
			return false
	for move in _moves:
		if move["node"] is CollisionShape3D:
			return false
	return true


func _make_body(object_root: Node3D) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Body"
	_add(body, object_root, "RigidBody3D 'Body'")
	for child in object_root.get_children():
		if _belongs_to_the_body(child):
			_moves.append({ "node": child, "from": object_root, "to": body })
			lines.append("> move '%s' under 'Body'" % child.name)
	return body


# The visible parts and the shapes of the object go with the body, and so does its zone,
# which has to follow the body when it is carried. The other nodes of the addon, and
# everything else, stay where they are.
func _belongs_to_the_body(node: Node) -> bool:
	if node.get_script() == _Scan.ZONE_SCRIPT:
		return true
	for script in [_Scan.OUTLINE_SCRIPT, _Scan.GRABBABLE_SCRIPT, _Scan.RECEIVER_SCRIPT]:
		if node.get_script() == script:
			return false
	if node is CollisionShape3D or node is MeshInstance3D or node is CSGShape3D:
		return true
	return node is Node3D and not _MeshBounds.collect_meshes(node).is_empty()


func _add_box_shape(parent: Node3D, space: Node3D, margin: float, what: String) -> void:
	var fitted := _MeshBounds.fit(_meshes(), space)
	var shape := BoxShape3D.new()
	shape.size = fitted.size + Vector3.ONE * margin * 2.0
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	collision.shape = shape
	collision.position = fitted.get_center()
	_add(collision, parent, "CollisionShape3D 'Shape' (box around the meshes, for the %s)" % what)


func _build_zone(host: Node3D, space: Node3D) -> void:
	if _scan.zone:
		zone_node = _scan.zone
		_edit_zone()
	else:
		zone_node = Area3D.new()
		zone_node.name = "Zone"
		zone_node.set_script(_Scan.ZONE_SCRIPT)
		zone_node.set("display_name", _model.display_name)
		zone_node.set("interaction_text", _model.prompt_text)
		var trigger := _make_trigger(_model.input_action)
		if trigger:
			zone_node.set("interaction_trigger", trigger)
		var extra: Array = []
		for item in _model.extra_actions:
			extra.append(_new_row_resource(item, false))
		if not extra.is_empty():
			zone_node.set("actions", extra)
		_add(zone_node, host, "Area3D 'Zone' (AizuInteractionZone)")
		if _model.prompt_text.is_empty() or _model.input_action == &"":
			notes.append("The zone has no input or no text: it will have no prompt.")
	var has_shape := false
	for child in zone_node.get_children():
		if child is CollisionShape3D:
			has_shape = true
	if _model.create_zone_shape and not has_shape and not _meshes().is_empty():
		var parent_space: Node3D = space
		_add_box_shape_for_zone(zone_node, parent_space)


func _add_box_shape_for_zone(zone: Node, space: Node3D) -> void:
	var fitted := _MeshBounds.fit(_meshes(), space)
	var shape := BoxShape3D.new()
	shape.size = fitted.size + Vector3.ONE * _ZONE_MARGIN * 2.0
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	collision.shape = shape
	collision.position = fitted.get_center()
	_add(collision, zone, "CollisionShape3D 'Shape' (box around the meshes)")


func _build_outline(host: Node3D) -> void:
	if _scan.outline:
		lines.append("= reuse the outline '%s'" % _scan.outline.name)
		return
	var outline := Node.new()
	outline.name = "Outline"
	outline.set_script(_Scan.OUTLINE_SCRIPT)
	var mesh_list: Array = []
	for mesh in _meshes():
		mesh_list.append(mesh)
	outline.set("mesh_to_outlines", mesh_list)
	outline.set("outline_material", load(_OUTLINE_MATERIAL))
	outline.set("zones", [zone_node])
	_add(outline, host, "Node 'Outline' (AizuInteractableOutline, %d mesh)" % mesh_list.size())


# The zone has to be under the body to follow it when it is carried.
func _warn_if_zone_is_apart(host: Node3D) -> void:
	if zone_node and zone_node.get_parent() != host and not _is_moved(zone_node):
		notes.append("The zone '%s' is not under the body '%s': it will not follow it when it is carried. Move it under the body." % [zone_node.name, host.name])


func _is_moved(node: Node) -> bool:
	for move in _moves:
		if move["node"] == node:
			return true
	return false


func _build_grabbable(host: Node3D, space: Node3D) -> void:
	_warn_if_zone_is_apart(host)
	if _scan.grabbable:
		grabbable_node = _scan.grabbable
		lines.append("= reuse the grabbable '%s'" % grabbable_node.name)
		return
	if not host is RigidBody3D:
		notes.append("The grab needs a RigidBody3D and there is none: the grabbable was not created.")
		return
	grabbable_node = Node.new()
	grabbable_node.name = "Grabbable"
	grabbable_node.set_script(_Scan.GRABBABLE_SCRIPT)
	grabbable_node.set("body", host)
	grabbable_node.set("zone", zone_node)
	var kind_list: Array = []
	for path in _model.kind_paths:
		kind_list.append(_resolve_kind(path))
	for kind_name in _model.new_kind_names:
		kind_list.append(_resolve_kind("new:" + kind_name))
	grabbable_node.set("kinds", kind_list)
	grabbable_node.set("throw_force_multiplier", _model.throw_multiplier)
	if _model.create_handle:
		var handle := Marker3D.new()
		handle.name = "GrabHandle"
		handle.position = _MeshBounds.fit(_meshes(), space).get_center()
		_add(handle, host, "Marker3D 'GrabHandle'")
		grabbable_node.set("grab_handle", handle)
	_add(grabbable_node, host, "Node 'Grabbable' (AizuGrabbable, %d kind)" % kind_list.size())


func _build_receiver(object_root: Node3D) -> void:
	if _scan.receiver:
		receiver_node = _scan.receiver
		lines.append("= reuse the receiver '%s'" % receiver_node.name)
		return
	receiver_node = Node.new()
	receiver_node.name = "Receiver"
	receiver_node.set_script(load("res://addons/godot-aizu/src/interactable/item_receiver.gd"))
	receiver_node.set("zones", [zone_node])
	var uses: Array = []
	for item in _model.uses:
		uses.append(_new_row_resource(item, true))
	receiver_node.set("uses", uses)
	_add(receiver_node, object_root, "Node 'Receiver' (AizuItemReceiver, %d use)" % uses.size())


func _build_script() -> void:
	var object_root: Node3D = _scan.object_root
	var existing_script: Script = object_root.get_script()
	var existing_text := ""
	_script_is_new = true
	if existing_script:
		if existing_script.resource_path.is_empty() or "::" in existing_script.resource_path:
			notes.append("The script of the object is built into the scene: add the lines by hand.")
			return
		existing_text = existing_script.source_code
		_script_path = existing_script.resource_path
		_script_is_new = false
	else:
		_script_path = _model.script_path

	var exports: Array[Dictionary] = []
	var connections: Array[Dictionary] = []
	var handlers: Array[Dictionary] = []
	if zone_node:
		exports.append({ "key": "zone", "name": "zone", "type": "AizuInteractionZone" })
		if not _model.enable_grab:
			connections.append({ "export": "zone", "signal": "interacted", "handler": "_on_interacted" })
			handlers.append({ "name": "_on_interacted", "params": "" })
		if not _model.extra_actions.is_empty():
			connections.append(
				{ "export": "zone", "signal": "action_triggered", "handler": "_on_action_triggered" }
			)
			handlers.append(
				{
					"name": "_on_action_triggered",
					"params": "action: AizuInteractionAction, by: Node",
					"body": _match_on("action.id", _model.extra_actions),
				}
			)
	if grabbable_node:
		exports.append({ "key": "grabbable", "name": "grabbable", "type": "AizuGrabbable" })
		if not _model.kind_paths.is_empty() or not _model.new_kind_names.is_empty():
			connections.append(
				{ "export": "grabbable", "signal": "used_on", "handler": "_on_used_on" }
			)
			handlers.append(
				{
					"name": "_on_used_on",
					"params": "target: AizuItemReceiver, item_use: AizuItemUse",
					"comment": "The grabbable was used on a receiver. If you do nothing it stays in the hands.",
				}
			)
	if receiver_node:
		exports.append({ "key": "receiver", "name": "receiver", "type": "AizuItemReceiver" })
		connections.append({ "export": "receiver", "signal": "used", "handler": "_on_used" })
		handlers.append(
			{
				"name": "_on_used",
				"params": "item_use: AizuItemUse, held: AizuGrabbable, by: Node",
				"comment": "A held grabbable was used on this object.",
				"body": _match_on("item_use.id", _model.uses) if _model.uses.size() > 1 else PackedStringArray(),
			}
		)

	var result := _ScriptWriter.build(
		existing_text, object_root.get_class(), _model.script_class_name, exports, connections, handlers
	)
	_script_text = result.text
	script_added = result.added
	notes.append_array(result.notes)
	var nodes := { "zone": zone_node, "grabbable": grabbable_node, "receiver": receiver_node }
	_script_changed = not result.added.is_empty()
	for key in result.names:
		var export_name: String = result.names[key]
		# An export the player already assigned is left alone.
		if nodes[key] and object_root.get(export_name) == null:
			_script_exports[export_name] = nodes[key]
	if _script_is_new:
		lines.append("+ new script %s" % _script_path)
	elif _script_changed:
		lines.append("+ %d lines added to the script %s" % [result.added.size(), _script_path])
	else:
		lines.append("= the script %s already has everything" % _script_path)


# A match over the ids of [param items], with an empty branch for each.
func _match_on(expression: String, items: Array[Dictionary]) -> PackedStringArray:
	var body := PackedStringArray()
	if items.is_empty():
		return body
	body.append("match %s:" % expression)
	for item in items:
		body.append("\t&\"%s\":" % item["id"])
		body.append("\t\tpass")
	return body


func _write_script() -> Script:
	var object_root: Node3D = _scan.object_root
	if _script_is_new:
		DirAccess.make_dir_recursive_absolute(_script_path.get_base_dir())
		var script := GDScript.new()
		script.source_code = _script_text
		if ResourceSaver.save(script, _script_path) != OK:
			push_error("Aizu: could not save %s" % _script_path)
			return null
		return load(_script_path)
	var existing: Script = object_root.get_script()
	existing.source_code = _script_text
	if ResourceSaver.save(existing, _script_path) != OK:
		push_error("Aizu: could not save %s" % _script_path)
		return null
	existing.reload()
	return existing


func _make_trigger(input_action: StringName) -> Resource:
	if input_action == &"":
		return null
	var trigger: Resource = _TRIGGER_SCRIPT.new()
	trigger.set("interaction_input_action_name", input_action)
	return trigger


# A new action or use from a row of the model.
func _new_row_resource(item: Dictionary, with_kind: bool) -> Resource:
	var resource: Resource = _ITEM_USE_SCRIPT.new() if with_kind else _ACTION_SCRIPT.new()
	resource.set("id", StringName(item["id"]))
	resource.set("text", item["text"])
	if with_kind:
		resource.set("kind", _resolve_kind(item["kind"]))
	var wanted: String = item["input_action"]
	if wanted != "" and wanted != _Model.CUSTOM_KEY:
		resource.set("trigger", _make_trigger(StringName(wanted)))
	lines.append("+ %s '%s'" % ["use" if with_kind else "action", item["id"]])
	return resource


#region Editing what is in the scene

# Sets a property of something that is in the scene, as part of the undo action.
func _change(object: Object, property: StringName, value: Variant, text: String) -> void:
	var old: Variant = object.get(property)
	if typeof(old) == typeof(value) and not value is Array and old == value:
		return
	if value is Array and old is Array and _same_items(old, value):
		return
	_changes.append({ "object": object, "property": property, "value": value, "old": old })
	lines.append("~ %s" % text)


func _same_items(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for i in first.size():
		if first[i] != second[i]:
			return false
	return true


# Takes a node out of the scene, as part of the undo action. The script variables that
# held it are emptied, and remembered for the warning about the script.
func _remove(node: Node, text: String) -> void:
	_removed.append({ "node": node, "parent": node.get_parent(), "index": node.get_index() })
	lines.append("- remove %s" % text)
	var object_root: Node3D = _scan.object_root
	var script: Script = object_root.get_script()
	if script == null:
		return
	for property in script.get_script_property_list():
		if property["type"] == TYPE_OBJECT and object_root.get(property["name"]) == node:
			_removed_names.append(property["name"])
			_change(object_root, property["name"], null, "the script variable '%s' no longer holds it" % property["name"])


func _is_shared(resource: Resource) -> bool:
	return _Reader.is_shared(resource)


# The file for a resource that is saved because it is a copy of a shared one.
func _new_file(resource: Resource, copy_name: String, original: Resource) -> void:
	var path := original.resource_path.get_base_dir().path_join(copy_name + ".tres")
	for file in _new_files:
		if file["path"] == path:
			errors.append("Two copies would be saved as %s: give them different names." % path)
	if FileAccess.file_exists(path):
		errors.append("%s already exists: pick another name." % path)
	_new_files.append({ "resource": resource, "path": path })
	lines.append("+ copy of %s saved as %s" % [original.resource_path.get_file(), path])


# The trigger the object should have for the input chosen. An unchanged trigger is kept.
# One that lives in the scene is changed in place, one that is a shared file is copied.
func _desired_trigger(current: Resource, wanted: String, copy_name: String) -> Resource:
	if wanted == _Model.CUSTOM_KEY:
		return current
	if current != null and _Reader.input_of(current) == wanted:
		return current
	if wanted == "":
		return null
	if current == null:
		return _make_trigger(StringName(wanted))
	if _is_shared(current):
		var copy: Resource = current.duplicate()
		copy.set("interaction_input_action_name", StringName(wanted))
		copy.set("input_override", null)
		_new_file(copy, copy_name, current)
		return copy
	_change(current, &"interaction_input_action_name", StringName(wanted), "input of the trigger: %s" % wanted)
	_change(current, &"input_override", null, "the trigger has no key of its own now")
	return current


func _edit_zone() -> void:
	var zone := zone_node
	lines.append("= the zone '%s'" % zone.name)
	_change(zone, &"display_name", _model.display_name, "display name: '%s'" % _model.display_name)
	_change(zone, &"interaction_text", _model.prompt_text, "prompt text: '%s'" % _model.prompt_text)
	var current: Resource = zone.get("interaction_trigger")
	var desired := _desired_trigger(current, String(_model.input_action), _model.primary_copy_name)
	if desired != current:
		_change(zone, &"interaction_trigger", desired, "primary input of the zone: %s" % _model.input_action)
	_edit_rows(zone, &"actions", _model.extra_actions, false)


# Brings the actions of the zone, or the uses of the receiver, to the rows of the model.
func _edit_rows(owner: Object, property: StringName, rows: Array[Dictionary], with_kind: bool) -> void:
	var current: Array = owner.get(property)
	var desired: Array = []
	for row in rows:
		var ref: Resource = row.get("ref")
		if ref == null:
			desired.append(_new_row_resource(row, with_kind))
		else:
			desired.append(_edit_row_resource(ref, row, with_kind))
	for item in current:
		if item != null and not desired.has(item) and not _was_copied(item):
			lines.append("- remove %s '%s'" % ["use" if with_kind else "action", item.get("id")])
	_change(owner, property, desired, "the %s of %s" % ["uses" if with_kind else "extra actions", owner.name])


# True if a copy took the place of the resource.
func _was_copied(resource: Resource) -> bool:
	for file in _new_files:
		if file.get("original") == resource:
			return true
	return false


func _edit_row_resource(ref: Resource, row: Dictionary, with_kind: bool) -> Resource:
	var trigger_now: Resource = ref.get("trigger")
	var trigger_wanted := _desired_trigger(trigger_now, row["input_action"], row["copy_trigger"])
	var wanted_text: String = row["text"]
	var text_changed: bool = ref.get("text") != wanted_text
	var trigger_changed := trigger_wanted != trigger_now
	var kind_wanted: Resource = null
	var kind_changed := false
	if with_kind and row.get("kind", "") != "":
		kind_wanted = _resolve_kind(row["kind"])
		kind_changed = kind_wanted != ref.get("kind")
	if not (text_changed or trigger_changed or kind_changed):
		return ref

	var label := "use '%s'" % row["id"] if with_kind else "action '%s'" % row["id"]
	if _is_shared(ref):
		var copy: Resource = ref.duplicate()
		copy.set("text", wanted_text)
		copy.set("trigger", trigger_wanted)
		if kind_changed:
			copy.set("kind", kind_wanted)
		_new_file(copy, row["copy_resource"], ref)
		_new_files[-1]["original"] = ref
		return copy
	if text_changed:
		_change(ref, &"text", wanted_text, "%s: text '%s'" % [label, wanted_text])
	if trigger_changed:
		_change(ref, &"trigger", trigger_wanted, "%s: input" % label)
	if kind_changed:
		_change(ref, &"kind", kind_wanted, "%s: kind" % label)
	return ref


func _edit_grabbable(host: Node3D, space: Node3D) -> void:
	grabbable_node = _scan.grabbable
	_warn_if_zone_is_apart(host)
	lines.append("= the grabbable '%s'" % grabbable_node.name)
	var kinds: Array = []
	for path in _model.kind_paths:
		kinds.append(_resolve_kind(path))
	for kind_name in _model.new_kind_names:
		kinds.append(_resolve_kind("new:" + kind_name))
	_change(grabbable_node, &"kinds", kinds, "kinds of the grabbable (%d)" % kinds.size())
	_change(grabbable_node, &"throw_force_multiplier", _model.throw_multiplier, "throw force x%s" % _model.throw_multiplier)
	var handle: Node = grabbable_node.get("grab_handle")
	if _model.create_handle and handle == null:
		var marker := Marker3D.new()
		marker.name = "GrabHandle"
		marker.position = _MeshBounds.fit(_meshes(), space).get_center()
		_add(marker, host, "Marker3D 'GrabHandle'")
		_change(grabbable_node, &"grab_handle", marker, "the grabbable has a GrabHandle")
	elif not _model.create_handle and handle != null:
		_change(grabbable_node, &"grab_handle", null, "the grabbable has no GrabHandle")
		_remove(handle, "the marker '%s'" % handle.name)


func _remove_grabbable() -> void:
	var handle: Node = _scan.grabbable.get("grab_handle")
	_remove(_scan.grabbable, "the grabbable '%s'" % _scan.grabbable.name)
	if handle != null:
		_remove(handle, "the marker '%s'" % handle.name)


func _edit_receiver() -> void:
	receiver_node = _scan.receiver
	lines.append("= the receiver '%s'" % receiver_node.name)
	_edit_rows(receiver_node, &"uses", _model.uses, true)


# The lines of the script that mention a variable that held a node that is removed.
func _find_script_orphans() -> void:
	if _removed_names.is_empty():
		return
	var script: Script = _scan.object_root.get_script()
	if script == null or script.source_code.is_empty():
		return
	var found := {}
	var source_lines := script.source_code.split("\n")
	for variable in _removed_names:
		var pattern := RegEx.create_from_string("\\b%s\\b" % variable)
		for i in source_lines.size():
			if pattern.search(source_lines[i]) and not found.has(i):
				found[i] = true
				script_orphans.append("line %d: %s" % [i + 1, source_lines[i].strip_edges()])

#endregion


# An existing kind is loaded; a new one is created in memory and saved when applied.
func _resolve_kind(token: String) -> Resource:
	if _kinds.has(token):
		return _kinds[token]
	var kind: Resource
	if token.begins_with("new:"):
		var path: String = _model.kinds_folder.path_join(token.trim_prefix("new:").to_snake_case() + ".tres")
		if FileAccess.file_exists(path):
			kind = load(path)
			lines.append("= reuse the kind %s" % path)
		else:
			kind = _ITEM_KIND_SCRIPT.new()
			_new_files.append({ "resource": kind, "path": path })
			lines.append("+ item kind %s" % path)
	else:
		kind = load(token)
	_kinds[token] = kind
	return kind
