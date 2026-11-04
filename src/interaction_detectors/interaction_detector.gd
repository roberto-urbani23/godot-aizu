@abstract
class_name AizuInteractionDetector extends Node3D

enum DetectionMode {
	PROXIMITY,
	TARGET
}

@export var detection_mode: DetectionMode = DetectionMode.PROXIMITY
@export var priority: int = 0


func _ready() -> void:
	AizuInteractionDetectorBus.zone_unlocked.connect(_on_zone_unlocked)


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
		return zone.can_be_detected()
	return zone.can_be_detected() or zone.can_be_triggered()


func _on_zone_unlocked(zone: AizuInteractionZone) -> void:
	if zone.redetect_on_unlock:
		recheck_zone(zone)


# Called when a zone unlocks and its redetect_on_unlock is true.
func recheck_zone(_zone: AizuInteractionZone) -> void:
	pass
