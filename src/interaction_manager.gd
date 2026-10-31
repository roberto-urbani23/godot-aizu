class_name AizuInteractionManager extends Node

signal target_changed(zone: AizuInteractionZone)
signal nearby_changed(zones: Array[AizuInteractionZone])

var current_target: AizuInteractionZone
var nearby_zones: Array[AizuInteractionZone] = []

# detector -> { zone: true }
var _detector_candidates: Dictionary = {}


func _ready() -> void:
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)
	AizuInteractionDetectorBus.zone_locked.connect(_on_zone_locked)


func _on_zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if not is_instance_valid(detector) or not is_instance_valid(zone):
		return
	if not _detector_candidates.has(detector):
		_detector_candidates[detector] = {}
	_detector_candidates[detector][zone] = true
	_update_nearby()
	_update_target()


func _on_zone_lost(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if not _detector_candidates.has(detector):
		return
	_detector_candidates[detector].erase(zone)
	if _detector_candidates[detector].is_empty():
		_detector_candidates.erase(detector)
	_update_nearby()
	_update_target()


func _update_nearby() -> void:
	var new_nearby: Array[AizuInteractionZone] = []
	for detector in _detector_candidates:
		for zone in _detector_candidates[detector]:
			if is_instance_valid(zone) and zone.is_detectable and not new_nearby.has(zone):
				new_nearby.append(zone)
	if new_nearby != nearby_zones:
		nearby_zones = new_nearby
		nearby_changed.emit(nearby_zones)


func _update_target() -> void:
	var new_target: AizuInteractionZone
	var highest_priority: int = -2147483648
	for detector in _detector_candidates:
		if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
			continue
		for zone in _detector_candidates[detector]:
			if not is_instance_valid(zone):
				continue
			if detector.priority > highest_priority:
				highest_priority = detector.priority
				new_target = zone
	if new_target == current_target:
		return
	current_target = new_target
	target_changed.emit(current_target)


func _on_zone_locked(zone: AizuInteractionZone) -> void:
	var to_emit: Array = []
	for detector in _detector_candidates:
		if _detector_candidates[detector].has(zone):
			to_emit.append(detector)
			_detector_candidates[detector].erase(zone)
	_update_nearby()
	_update_target()
	for detector in to_emit:
		AizuInteractionDetectorBus.zone_lost.emit(detector, zone)


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(current_target):
		return
	if not current_target.is_interactable:
		return
	if not current_target.interaction_trigger:
		return
	if current_target.interaction_trigger.is_triggered(event):
		current_target.interacted.emit()
		get_viewport().set_input_as_handled()
