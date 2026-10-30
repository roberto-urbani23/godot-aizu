class_name AizuInteractionZone extends Area3D

const COLLISION_LAYER := 2  # interactable layer

signal interacted

@export var interaction_trigger: AizuInteractionTrigger
@export var is_interactable: bool = true
@export var is_detectable: bool = true

func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = 0
