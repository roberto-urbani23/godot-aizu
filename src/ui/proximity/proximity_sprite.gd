class_name AizuProximitySprite extends Sprite3D

## Zone this sprite reacts to. If null, reacts to every zone.
@export var zone: AizuInteractionZone

var _tween: Tween
var _in_proximity: bool = false
var _is_targeted: bool = false


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)


func _on_zone_found(detector: AizuInteractionDetector, found_zone: AizuInteractionZone) -> void:
	if zone and found_zone != zone:
		return
	if detector.detection_mode == AizuInteractionDetector.DetectionMode.PROXIMITY:
		_in_proximity = true
		if not _is_targeted:
			_tween = AizuTween.fade_in(self, _tween)
	elif detector.detection_mode == AizuInteractionDetector.DetectionMode.TARGET:
		_is_targeted = true
		_tween = AizuTween.fade_out(self, _tween)


func _on_zone_lost(detector: AizuInteractionDetector, lost_zone: AizuInteractionZone) -> void:
	if zone and lost_zone != zone:
		return
	if detector.detection_mode == AizuInteractionDetector.DetectionMode.PROXIMITY:
		_in_proximity = false
		_tween = AizuTween.fade_out(self, _tween)
	elif detector.detection_mode == AizuInteractionDetector.DetectionMode.TARGET:
		_is_targeted = false
		if _in_proximity:
			_tween = AizuTween.fade_in(self, _tween)
