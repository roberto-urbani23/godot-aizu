class_name AizuInteractionTrigger extends Resource

@export var interaction_input_action_name: StringName
@export var input_override: InputEvent


func is_triggered(event: InputEvent) -> bool:
	if input_override:
		return input_override.is_match(event) and event.is_pressed() and not event.is_echo()

	if interaction_input_action_name:
		return event.is_action_pressed(interaction_input_action_name) and not event.is_echo()

	return false

func format_text(text: String) -> String:
	if text.is_empty():
		return ""
	return text.replace("{interaction_key}", get_key_as_string())


func get_key_as_string() -> String:
	if input_override:
		return input_override.as_text()
	if not interaction_input_action_name:
		return ""
	var events := InputMap.action_get_events(interaction_input_action_name)
	for event in events:
		var key_event := event as InputEventKey
		if key_event:
			var kc := key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
			return OS.get_keycode_string(kc)
	return ""
