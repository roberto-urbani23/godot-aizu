extends Sprite3D

var _tween: Tween
var _in_proximity: bool = false
var _is_targeted: bool = false


func _ready() -> void:
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)


func _on_zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if detector.detection_mode == AizuInteractionDetector.DetectionMode.PROXIMITY:
		_in_proximity = true
		if not _is_targeted:
			_tween = AizuTween.fade_in(self, _tween)
	elif detector.detection_mode == AizuInteractionDetector.DetectionMode.TARGET:
		_is_targeted = true
		_tween = AizuTween.fade_out(self, _tween)


func _on_zone_lost(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if detector.detection_mode == AizuInteractionDetector.DetectionMode.PROXIMITY:
		_in_proximity = false
		_tween = AizuTween.fade_out(self, _tween)
	elif detector.detection_mode == AizuInteractionDetector.DetectionMode.TARGET:
		_is_targeted = false
		if _in_proximity:
			_tween = AizuTween.fade_in(self, _tween)
