@tool
extends RefCounted
## What the wizard finds in the scene around the object. The wizard never looks for
## nodes at runtime: this runs once, in the editor, when the dialog opens.

const _MeshBounds := preload("res://addons/godot-aizu/src/editor/mesh_bounds.gd")
const ZONE_SCRIPT := preload("res://addons/godot-aizu/src/interactable/interaction_zone.gd")
const OUTLINE_SCRIPT := preload("res://addons/godot-aizu/src/interactable/interactable_outline.gd")
const GRABBABLE_SCRIPT := preload("res://addons/godot-aizu/src/interactable/grabbable.gd")
const RECEIVER_SCRIPT := preload("res://addons/godot-aizu/src/interactable/item_receiver.gd")
const KIND_CLASS := "AizuItemKind"

var scene_root: Node
var object_root: Node3D
var meshes: Array[Node3D] = []
var body: RigidBody3D
var zone: Area3D
var outline: Node
var grabbable: Node
var receiver: Node
## Why the wizard cannot work on this node, empty if it can.
var error: String = ""
## Names of the actions of the project, without the built-in ones.
var input_actions: PackedStringArray = []
## Existing item kinds: { "path": String, "name": String }.
var kinds: Array[Dictionary] = []


func run(node: Node, edited_root: Node) -> void:
	scene_root = edited_root
	if not node is Node3D:
		error = "The wizard works on a 3D node. '%s' is a %s." % [node.name, node.get_class()]
		return
	object_root = node
	if node != edited_root and not node.scene_file_path.is_empty():
		if not edited_root.is_editable_instance(node):
			error = (
				"'%s' is an instanced scene. Enable 'Editable Children' on it, or open its "
				+ "scene and run the wizard there."
			) % node.name
			return

	meshes = _MeshBounds.collect_meshes(object_root)
	body = _find_body()
	zone = _find_by_script(object_root, ZONE_SCRIPT) as Area3D
	outline = _find_by_script(object_root, OUTLINE_SCRIPT)
	grabbable = _find_by_script(object_root, GRABBABLE_SCRIPT)
	receiver = _find_by_script(object_root, RECEIVER_SCRIPT)
	_scan_input_actions()
	_scan_kinds(EditorInterface.get_resource_filesystem().get_filesystem())


func get_object_script() -> Script:
	return object_root.get_script() as Script if object_root else null


func _find_body() -> RigidBody3D:
	if object_root is RigidBody3D:
		return object_root
	for child in object_root.get_children():
		if child is RigidBody3D:
			return child
	return null


func _find_by_script(node: Node, script: Script) -> Node:
	for child in node.get_children():
		if child.get_script() == script:
			return child
		var deeper := _find_by_script(child, script)
		if deeper:
			return deeper
	return null


func _scan_input_actions() -> void:
	for property in ProjectSettings.get_property_list():
		var property_name: String = property["name"]
		if property_name.begins_with("input/") and not property_name.begins_with("input/ui_"):
			input_actions.append(property_name.trim_prefix("input/"))
	input_actions.sort()


func _scan_kinds(directory: EditorFileSystemDirectory) -> void:
	for i in directory.get_file_count():
		if directory.get_file_script_class_name(i) == KIND_CLASS:
			kinds.append(
				{ "path": directory.get_file_path(i), "name": directory.get_file(i).get_basename() }
			)
	for i in directory.get_subdir_count():
		_scan_kinds(directory.get_subdir(i))
