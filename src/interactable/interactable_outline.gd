class_name AizuInteractableOutline extends Node

@export var mesh_to_outlines: Array[MeshInstance3D]
@export var outline_material: ShaderMaterial

var _my_zones: Array[AizuInteractionZone] = []


func _ready() -> void:
	for child in get_parent().find_children("*", "AizuInteractionZone", true, false):
		_my_zones.append(child as AizuInteractionZone)

	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)

	_warm_up_shader()


# Forces shader compilation on frame 1, before any interaction occurs.
func _warm_up_shader() -> void:
	if not outline_material:
		return
	for mesh in mesh_to_outlines:
		mesh.material_overlay = outline_material
	await get_tree().process_frame
	for mesh in mesh_to_outlines:
		mesh.material_overlay = null


func _on_zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	if zone not in _my_zones:
		return
	for mesh in mesh_to_outlines:
		mesh.material_overlay = outline_material


func _on_zone_lost(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	if zone not in _my_zones:
		return
	for mesh in mesh_to_outlines:
		mesh.material_overlay = null
