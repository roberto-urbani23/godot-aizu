@abstract
class_name AizuInteractionDetector extends Node3D

enum DetectionMode {
	PROXIMITY,
	TARGET
}

@export var detection_mode: DetectionMode = DetectionMode.PROXIMITY
@export var priority: int = 0


func _report_zone_found(zone: AizuInteractionZone) -> void:
	if not _should_report(zone):
		return
	AizuInteractionDetectorBus.zone_found.emit(self, zone)


func _report_zone_lost(zone: AizuInteractionZone) -> void:
	if not _should_report(zone):
		return
	AizuInteractionDetectorBus.zone_lost.emit(self, zone)


func _should_report(zone: AizuInteractionZone) -> bool:
	if detection_mode == DetectionMode.PROXIMITY:
		return zone.is_detectable
	# TARGET: report if detectable or interactable
	return zone.is_detectable or zone.is_interactable
