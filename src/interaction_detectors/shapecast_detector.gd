class_name AizuShapecastDetector extends AizuInteractionDetector

const _ZONE_LAYER := 2  # layer 2: interactable

@export var shapecast: ShapeCast3D
## Physics layers that block the line of sight. The first thing the cast touches wins:
## if it is a blocker, nothing is targeted, even if a zone is behind it.
@export_flags_3d_physics var occluder_mask: int = 1

var _current_zone: AizuInteractionZone


func _ready() -> void:
	super()
	if not shapecast:
		push_error("AizuShapecastDetector: shapecast not set")
		return

	if detection_mode != DetectionMode.TARGET:
		push_warning(
			"AizuShapecastDetector: detection_mode is PROXIMITY, so it never sets a target."
		)

	shapecast.collision_mask = _ZONE_LAYER | occluder_mask
	shapecast.collide_with_areas = true
	shapecast.collide_with_bodies = true


# The cast clears _current_zone while the zone is locked, so on unlock the target
# is re-evaluated right away. Waiting for the next physics frame would let the
# proximity detector report the zone first and flash its hint icon.
func recheck_zone(_zone: AizuInteractionZone) -> void:
	if not shapecast:
		return
	shapecast.force_shapecast_update()
	_update_target()


func _physics_process(_delta: float) -> void:
	if not shapecast:
		return
	_update_target()


func _update_target() -> void:
	var new_zone := _find_first_zone()
	if new_zone == _current_zone:
		return

	if _current_zone:
		_report_zone_lost(_current_zone)

	_current_zone = new_zone

	if _current_zone:
		_report_zone_found(_current_zone)


# Returns the zone if it is the closest thing the cast touches, null if a blocker is closer.
func _find_first_zone() -> AizuInteractionZone:
	var closest_distance := INF
	var closest_zone: AizuInteractionZone
	var origin := shapecast.global_position

	for i in shapecast.get_collision_count():
		var collider := shapecast.get_collider(i)
		var zone := collider as AizuInteractionZone
		if zone:
			if not (zone.can_be_detected() or zone.can_be_triggered()):
				continue  # a locked zone neither gets targeted nor blocks
		elif not _is_occluder(collider):
			continue

		var distance := origin.distance_squared_to(shapecast.get_collision_point(i))
		if distance < closest_distance:
			closest_distance = distance
			closest_zone = zone

	return closest_zone


func _is_occluder(collider: Object) -> bool:
	var body := collider as CollisionObject3D
	return body != null and (body.collision_layer & occluder_mask) != 0
