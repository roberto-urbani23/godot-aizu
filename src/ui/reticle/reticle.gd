class_name AizuReticle extends TextureRect

@export var texture_active: Texture2D
@export var texture_inactive: Texture2D


func _ready() -> void:
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)
	texture = texture_inactive


func _on_zone_found(detector: AizuInteractionDetector, _zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	texture = texture_active


func _on_zone_lost(detector: AizuInteractionDetector, _zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	texture = texture_inactive
