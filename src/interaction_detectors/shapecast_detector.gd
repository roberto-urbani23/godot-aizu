class_name AizuShapecastDetector extends AizuInteractionDetector

const _COLLISION_MASK := 2  # layer 2: interactable

@export var shapecast: ShapeCast3D

var _current_zone: AizuInteractionZone


func _ready() -> void:
	if not shapecast:
		push_error("AizuShapecastDetector: shapecast not set")
		return

	shapecast.collision_mask = _COLLISION_MASK
	shapecast.collide_with_bodies = false
	shapecast.collide_with_areas = true


func _physics_process(_delta: float) -> void:
	if not shapecast:
		return

	var new_zone: AizuInteractionZone

	if shapecast.is_colliding():
		new_zone = shapecast.get_collider(0) as AizuInteractionZone

	if new_zone == _current_zone:
		return

	if _current_zone:
		_report_zone_lost(_current_zone)

	_current_zone = new_zone

	if _current_zone:
		_report_zone_found(_current_zone)
