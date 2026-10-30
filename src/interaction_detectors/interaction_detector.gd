@abstract
class_name AizuInteractionDetector extends Node3D


func _report_candidate(candidate: Node) -> void:
	if !candidate:
		return

	var interactable := AizuUtility.find_node_recursive(
		candidate,
		AizuInteractableComponent
	) as AizuInteractableComponent

	if !interactable:
		return

	AizuInteractionDetectorBus.interactable_found.emit(interactable)
