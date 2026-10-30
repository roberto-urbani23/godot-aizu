class_name AizuInteractable extends Node

signal interacted

@export var interaction_trigger: AizuInteractionTrigger

func _input(event: InputEvent) -> void:
	if interaction_trigger and interaction_trigger.is_triggered(event):
		interacted.emit()
