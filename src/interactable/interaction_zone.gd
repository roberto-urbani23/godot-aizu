class_name AizuInteractionZone extends Area3D

const COLLISION_LAYER := 2  # interactable layer

signal interacted

@export var interactable: AizuInteractable
@export var interaction_trigger: AizuInteractionTrigger


func _ready() -> void:
	if not interactable:
		push_error("AizuInteractionZone: interactable not set")
		return

	collision_layer = COLLISION_LAYER
	collision_mask = 0
