class_name AizuInteractableOutline extends Node
## Outlines meshes while one of the given zones is targeted.
##
## The outline is not drawn on the meshes themselves. Each mesh gets a hidden copy
## on [constant VISUAL_LAYER], seen only by the [AizuOutlineOverlay] camera, so the
## outline is rendered outside the world's post-process. The copies share the
## original mesh and one shared material: nothing is duplicated per outline.

## Visual layer (1-20) used for outline copies. The world camera must not render it.
## Make sure no other node in your project uses it.
const VISUAL_LAYER := 19

static var _mask_material: ShaderMaterial

@export var mesh_to_outlines: Array[MeshInstance3D]
## Use one shared ShaderMaterial resource for every outline in the game.
@export var outline_material: ShaderMaterial
@export var zones: Array[AizuInteractionZone]

var _copies: Array[MeshInstance3D] = []


func _ready() -> void:
	for mesh in mesh_to_outlines:
		_copies.append(_make_copy(mesh))
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)


func _make_copy(source: MeshInstance3D) -> MeshInstance3D:
	var copy := MeshInstance3D.new()
	copy.mesh = source.mesh
	copy.layers = 1 << (VISUAL_LAYER - 1)
	copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	copy.material_override = _get_mask_material()
	copy.material_overlay = outline_material
	copy.visible = false
	source.add_child.call_deferred(copy) # the scene may still be setting up its children
	return copy


# Invisible material that only writes depth, so the outline shell shows as a rim
# around the mesh instead of a filled silhouette. Created once, shared by all.
static func _get_mask_material() -> ShaderMaterial:
	if _mask_material:
		return _mask_material
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, depth_draw_always;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
"""
	_mask_material = ShaderMaterial.new()
	_mask_material.shader = shader
	_mask_material.render_priority = -1
	return _mask_material


func _on_zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	if zone not in zones:
		return
	_set_outlined(true)


func _on_zone_lost(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	if zone not in zones:
		return
	_set_outlined(false)


func _set_outlined(value: bool) -> void:
	for copy in _copies:
		copy.visible = value
