extends Node

signal zone_found(
	detector: AizuInteractionDetector,
	interactable: AizuInteractable,
	zone: AizuInteractionZone
)

signal zone_lost(
	detector: AizuInteractionDetector,
	interactable: AizuInteractable,
	zone: AizuInteractionZone
)
