class_name AizuProximitySprite extends Sprite3D

## Zone this sprite reacts to. If null, reacts to every zone.
@export var zone: AizuInteractionZone
## If set, the sprite shows the icon of the zone's trigger input. A zone whose input
## has no icon in the set does not show the sprite at all. If null, [member texture]
## is used as it is.
@export var icon_set: AizuProximityIconSet

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
		if not _apply_icon(found_zone):
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
		_in_proximity = false
		_tween = AizuTween.fade_out(self, _tween)
	elif detector.detection_mode == AizuInteractionDetector.DetectionMode.TARGET:
		_is_targeted = false
		if _in_proximity:
			_tween = AizuTween.fade_in(self, _tween)


# False when an icon set is used and it has no icon for this zone.
func _apply_icon(for_zone: AizuInteractionZone) -> bool:
	if not icon_set:
		return true
	var icon := icon_set.get_icon_for_trigger(for_zone.interaction_trigger)
	if not icon:
		return false
	texture = icon
	return true
