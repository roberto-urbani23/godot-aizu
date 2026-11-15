@tool
extends RefCounted
## Helpers shared by the editor tools to find the meshes of an object and the box
## that fits them.


## Meshes and CSG shapes under [param node], without [param skip] and what is under
## it. Labels and sprites do not describe the object.
static func collect_meshes(node: Node, skip: Node = null) -> Array[Node3D]:
	var result: Array[Node3D] = []
	_collect(node, skip, result)
	return result


## The box that fits [param meshes], in the local space of [param space]. The size is
## zero when there is nothing to fit.
static func fit(meshes: Array[Node3D], space: Node3D) -> AABB:
	var fitted := AABB()
	var from_world := space.global_transform.affine_inverse()
	var first := true
	for mesh in meshes:
		var local_box: AABB = mesh.get_aabb() if mesh.has_method("get_aabb") else AABB()
		var box: AABB = (from_world * mesh.global_transform) * local_box
		fitted = box if first else fitted.merge(box)
		first = false
	return fitted


static func _collect(node: Node, skip: Node, result: Array[Node3D]) -> void:
	for child in node.get_children():
		if child == skip:
			continue
		if child is MeshInstance3D or child is CSGShape3D:
			result.append(child)
		_collect(child, skip, result)
