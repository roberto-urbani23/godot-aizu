class_name AizuShapecastDetectorComponent extends AizuInteractionDetector

@export var shapecast: ShapeCast3D


func _ready() -> void:
	if !shapecast:
		push_error("Aizu Addon Error: Shapecast missing")


func _physics_process(_delta: float) -> void:
	if !shapecast:
		return

	if !shapecast.is_colliding():
		return

	var collider := shapecast.get_collider(0) as Node
	if !collider:
		return

	_report_candidate(collider)
