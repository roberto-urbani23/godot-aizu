class_name AizuReticle extends TextureRect

@export var texture_active: Texture2D
@export var texture_inactive: Texture2D
## Scale of the reticle while something is targeted. 1 means no size change.
@export_range(0.5, 3.0, 0.05) var active_scale: float = 1.0
## Time of the change between the two states. 0 changes at once.
@export_range(0.0, 0.5, 0.01) var transition_seconds: float = 0.0

var _tween: Tween


func _ready() -> void:
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)
	texture = texture_inactive
	resized.connect(_update_pivot)
	_update_pivot()


func _on_zone_found(detector: AizuInteractionDetector, _zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	texture = texture_active
	_scale_to(active_scale)


func _on_zone_lost(detector: AizuInteractionDetector, _zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	texture = texture_inactive
	_scale_to(1.0)


func _scale_to(target: float) -> void:
	if _tween:
		_tween.kill()
	if transition_seconds <= 0.0:
		scale = Vector2.ONE * target
		return
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * target, transition_seconds)


func _update_pivot() -> void:
	pivot_offset = size * 0.5
