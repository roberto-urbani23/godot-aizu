@abstract
class_name AizuInteractionDetector extends Node3D

enum DetectionMode {
	PROXIMITY,
	TARGET
}

@export var detection_mode: DetectionMode = DetectionMode.PROXIMITY
@export var priority: int = 0


func _report_zone_found(zone: AizuInteractionZone) -> void:
	AizuInteractionDetectorBus.zone_found.emit(self, zone.interactable, zone)


func _report_zone_lost(zone: AizuInteractionZone) -> void:
	AizuInteractionDetectorBus.zone_lost.emit(self, zone.interactable, zone)
