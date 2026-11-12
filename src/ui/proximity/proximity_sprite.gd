class_name AizuProximitySprite extends Sprite3D

## Zone this sprite reacts to. If null, reacts to every zone.
@export var zone: AizuInteractionZone
## If set, the sprite shows the glyph of the zone's input. A zone whose input has
## no glyph in the set does not show the sprite at all. If null, [member texture]
## is used as it is.
@export var glyph_set: AizuGlyphSet

var _tween: Tween
var _in_proximity: bool = false
var _is_targeted: bool = false
var _near_zone: AizuInteractionZone


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)
	AizuInputDevice.device_changed.connect(_on_device_changed)


func _on_zone_found(detector: AizuInteractionDetector, found_zone: AizuInteractionZone) -> void:
	if zone and found_zone != zone:
		return
	if detector.detection_mode == AizuInteractionDetector.DetectionMode.PROXIMITY:
		_near_zone = found_zone
		if not _apply_glyph(found_zone):
			return
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
		_near_zone = null
		_in_proximity = false
		_tween = AizuTween.fade_out(self, _tween)
	elif detector.detection_mode == AizuInteractionDetector.DetectionMode.TARGET:
		_is_targeted = false
		if _in_proximity:
			_tween = AizuTween.fade_in(self, _tween)


# The player switched between keyboard and gamepad: show the glyph of the new
# device, or hide the sprite if that device has none.
func _on_device_changed(_is_gamepad: bool) -> void:
	if not glyph_set or not is_instance_valid(_near_zone):
		return
	var had_glyph := _in_proximity
	_in_proximity = _apply_glyph(_near_zone)
	if _in_proximity == had_glyph or _is_targeted:
		return
	_tween = AizuTween.fade_in(self, _tween) if _in_proximity else AizuTween.fade_out(self, _tween)


# False when a glyph set is used and it has no glyph for this zone.
func _apply_glyph(for_zone: AizuInteractionZone) -> bool:
	if not glyph_set:
		return true
	for action in for_zone.get_actions():
		var glyph := glyph_set.get_glyph_for_trigger(action.trigger)
		if glyph:
			texture = glyph
			return true
	return false
