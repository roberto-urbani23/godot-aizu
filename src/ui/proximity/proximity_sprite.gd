class_name AizuProximitySprite extends Sprite3D

## Zone this sprite reacts to. If null, reacts to every zone.
@export var zone: AizuInteractionZone
## If set, the sprite shows the glyph of the zone's input. A zone whose input has
## no glyph in the set does not show the sprite at all. If null, [member texture]
## is used as it is.
@export var glyph_set: AizuGlyphSet
## Draws the sprite on the overlay layer (see [AizuInteractableOutline]) instead of
## in the world. Use it when the world view is post-processed (pixelation, dither)
## and the glyph must stay sharp. It needs an [AizuOutlineOverlay] in the scene,
## and the world camera must not render that layer. The overlay has no world
## geometry to hide the sprite, which is what [member occlusion_mask] is for.
@export var render_in_overlay: bool = false
## Physics layers that hide the sprite: while one of them is between the camera
## and the sprite, the sprite fades out. 0 turns the check off.
@export_flags_3d_physics var occlusion_mask: int = 1

# A hit this close to the sprite does not count: the surface it sits on is not
# between it and the camera.
const _OCCLUSION_MARGIN := 0.15

var _tween: Tween
var _in_proximity: bool = false
var _is_targeted: bool = false
var _is_occluded: bool = false
var _is_shown: bool = false
var _near_zone: AizuInteractionZone


func _ready() -> void:
	if render_in_overlay:
		layers = 1 << (AizuInteractableOutline.VISUAL_LAYER - 1)
	modulate.a = 0.0
	visible = false
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)
	AizuInputDevice.device_changed.connect(_on_device_changed)


func _physics_process(_delta: float) -> void:
	if occlusion_mask == 0 or not _in_proximity:
		return
	var occluded := _check_occlusion()
	if occluded != _is_occluded:
		_is_occluded = occluded
		_update_shown()


func _on_zone_found(detector: AizuInteractionDetector, found_zone: AizuInteractionZone) -> void:
	if zone and found_zone != zone:
		return
	if detector.detection_mode == AizuInteractionDetector.DetectionMode.PROXIMITY:
		_near_zone = found_zone
		if not _apply_glyph(found_zone):
			return
		_in_proximity = true
		_is_occluded = occlusion_mask != 0 and _check_occlusion()
	elif detector.detection_mode == AizuInteractionDetector.DetectionMode.TARGET:
		_is_targeted = true
	_update_shown()


func _on_zone_lost(detector: AizuInteractionDetector, lost_zone: AizuInteractionZone) -> void:
	if zone and lost_zone != zone:
		return
	if detector.detection_mode == AizuInteractionDetector.DetectionMode.PROXIMITY:
		_near_zone = null
		_in_proximity = false
		_is_occluded = false
	elif detector.detection_mode == AizuInteractionDetector.DetectionMode.TARGET:
		_is_targeted = false
	_update_shown()


# The player switched between keyboard and gamepad: show the glyph of the new
# device, or hide the sprite if that device has none.
func _on_device_changed(_is_gamepad: bool) -> void:
	if not glyph_set or not is_instance_valid(_near_zone):
		return
	_in_proximity = _apply_glyph(_near_zone)
	_update_shown()


# Shown while the player is near, not looking at the zone and with a clear view.
func _update_shown() -> void:
	var want := _in_proximity and not _is_targeted and not _is_occluded
	if want == _is_shown:
		return
	_is_shown = want
	_tween = AizuTween.fade_in(self, _tween) if want else AizuTween.fade_out(self, _tween)


func _check_occlusion() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var from := camera.global_position
	var to := global_position
	var query := PhysicsRayQueryParameters3D.create(from, to, occlusion_mask)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	return from.distance_to(hit.position) < from.distance_to(to) - _OCCLUSION_MARGIN


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
