class_name AizuAreaDetector extends AizuInteractionDetector

const _COLLISION_LAYER := 4  # layer 3: proximity
const _COLLISION_MASK  := 2  # layer 2: interactable

@export var area: Area3D

# zone -> overlap count (supports multi-collider zones)
var _zone_overlaps: Dictionary = {}


func _ready() -> void:
	if not area:
		push_error("AizuAreaDetector: area not set")
		return

	area.collision_layer = _COLLISION_LAYER
	area.collision_mask = _COLLISION_MASK

	area.area_entered.connect(_on_area_entered)
	area.area_exited.connect(_on_area_exited)


func _on_area_entered(detected: Area3D) -> void:
	var zone := detected as AizuInteractionZone
	if not zone:
		return

	var was_zero: bool = not _zone_overlaps.has(zone) or _zone_overlaps[zone] == 0
	_zone_overlaps[zone] = _zone_overlaps.get(zone, 0) + 1

	if was_zero:
		_report_zone_found(zone)


func _on_area_exited(detected: Area3D) -> void:
	var zone := detected as AizuInteractionZone
	if not zone or not _zone_overlaps.has(zone):
		return

	_zone_overlaps[zone] -= 1

	if _zone_overlaps[zone] <= 0:
		_zone_overlaps.erase(zone)
		_report_zone_lost(zone)
