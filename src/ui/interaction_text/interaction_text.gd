class_name AizuInteractionText extends Label


func _ready() -> void:
	visible = false
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)


func _on_zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	if not zone.interaction_trigger:
		return
	var formatted := zone.interaction_trigger.format_text(zone.interaction_text)
	if formatted.is_empty():
		return
	text = formatted
	visible = true


func _on_zone_lost(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	visible = false
