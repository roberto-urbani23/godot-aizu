@tool
extends EditorInspectorPlugin
## Adds a "Create shape from mesh" button to the inspector of an AizuInteractionZone:
## it adds a CollisionShape3D box that fits every mesh found under the zone's
## parent, so a zone needs no manual shape setup.

const _ZONE_SCRIPT := preload("res://addons/godot-aizu/src/interactable/interaction_zone.gd")
## Extra room around the mesh, on every side.
const _MARGIN := 0.05

var undo_redo: EditorUndoRedoManager


func _can_handle(object: Object) -> bool:
	return object is Node and object.get_script() == _ZONE_SCRIPT


func _parse_begin(object: Object) -> void:
	var button := Button.new()
	button.text = "Create shape from mesh"
	button.tooltip_text = "Adds a box CollisionShape3D that fits the meshes next to this zone."
	button.pressed.connect(create_shape.bind(object as Area3D))
	add_custom_control(button)


func create_shape(zone: Area3D) -> void:
	for child in zone.get_children():
		if child is CollisionShape3D:
			push_warning("Aizu: the zone already has a CollisionShape3D, nothing was added.")
			return

	var meshes: Array[GeometryInstance3D] = []
	_collect_meshes(zone.get_parent(), zone, meshes)
	if meshes.is_empty():
		push_warning("Aizu: no mesh found next to the zone, add a CollisionShape3D by hand.")
		return

	var from_world := zone.global_transform.affine_inverse()
	var fitted: AABB
	for i in meshes.size():
		var box: AABB = (from_world * meshes[i].global_transform) * meshes[i].get_aabb()
		fitted = box if i == 0 else fitted.merge(box)

	var shape := BoxShape3D.new()
	shape.size = fitted.size + Vector3.ONE * _MARGIN * 2.0
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	collision.shape = shape
	collision.position = fitted.get_center()

	var scene_root := EditorInterface.get_edited_scene_root()
	undo_redo.create_action("Create zone shape from mesh")
	undo_redo.add_do_method(zone, "add_child", collision, true)
	undo_redo.add_do_method(collision, "set_owner", scene_root)
	undo_redo.add_do_reference(collision)
	undo_redo.add_undo_method(zone, "remove_child", collision)
	undo_redo.commit_action()


# Meshes and CSG shapes only: labels and sprites do not describe the object.
func _collect_meshes(node: Node, skip: Node, result: Array[GeometryInstance3D]) -> void:
	for child in node.get_children():
		if child == skip:
			continue
		if child is MeshInstance3D or child is CSGShape3D:
			result.append(child)
		_collect_meshes(child, skip, result)
