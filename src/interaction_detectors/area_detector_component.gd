class_name AizuAreaDetectorComponent extends AizuInteractionDetector

@export var area: Area3D


func _ready() -> void:
	if !area:
		push_error("Aizu Addon Error: Area3D missing")
		return

	area.body_entered.connect(_on_body_entered)
	area.area_entered.connect(_on_area_entered)


func _on_body_entered(body: Node3D) -> void:
	_report_candidate(body)


func _on_area_entered(area: Area3D) -> void:
	_report_candidate(area)
