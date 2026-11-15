@abstract
class_name AizuInteractionDetector extends Node3D

enum DetectionMode { PROXIMITY, TARGET }

@export var detection_mode: DetectionMode = DetectionMode.PROXIMITY
@export var priority: int = 0

var _suspended: bool = false


func _ready() -> void:
	AizuInteractionDetectorBus.zone_unlocked.connect(_on_zone_unlocked)


## A suspended detector reports nothing: the zones it was reporting are lost
## right away, and checked again when it resumes. Used while the interactor is
## locked (menu, cutscene).
func set_suspended(value: bool) -> void:
	if value == _suspended:
		return
	if value:
		for zone in _get_active_zones():
			AizuInteractionDetectorBus.zone_lost.emit(self, zone)
		_suspended = true
		_on_suspended()
	else:
		_suspended = false
		_on_resumed()


func is_suspended() -> bool:
	return _suspended


## Makes the detector look through a body, for example the one the player holds
## in front of the camera, which would hide whatever is behind it. Detectors
## that cannot be blocked need nothing here.
func ignore_body(_body: CollisionObject3D) -> void:
	pass


func unignore_body(_body: CollisionObject3D) -> void:
	pass


func _report_zone_found(zone: AizuInteractionZone) -> void:
	if _suspended or not _should_report(zone):
		return
	AizuInteractionDetectorBus.zone_found.emit(self, zone)


func _report_zone_lost(zone: AizuInteractionZone) -> void:
	if _suspended or not _should_report(zone):
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


# Zones this detector is reporting right now.
func _get_active_zones() -> Array[AizuInteractionZone]:
	return []


func _on_suspended() -> void:
	pass


func _on_resumed() -> void:
	for zone in _get_active_zones():
		recheck_zone(zone)
