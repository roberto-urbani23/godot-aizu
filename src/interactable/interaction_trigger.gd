class_name AizuInteractionTrigger extends Resource

@export var interaction_input_action_name: StringName
@export var input_override: InputEvent


func is_triggered(event: InputEvent) -> bool:
	if input_override:
		return input_override.is_match(event) and event.is_pressed() and not event.is_echo()

	if interaction_input_action_name:
		return event.is_action_pressed(interaction_input_action_name) and not event.is_echo()

	return false
