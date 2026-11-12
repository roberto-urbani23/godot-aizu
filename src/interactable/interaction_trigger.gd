class_name AizuInteractionTrigger extends Resource

@export var interaction_input_action_name: StringName
@export var input_override: InputEvent


func is_triggered(event: InputEvent) -> bool:
	if input_override:
		return input_override.is_match(event) and event.is_pressed() and not event.is_echo()

	if interaction_input_action_name:
		return event.is_action_pressed(interaction_input_action_name) and not event.is_echo()

	return false


## Every input that fires this trigger: the override, or the events of the action.
## The inputs of the preferred device come first.
func get_input_events(prefer_gamepad: bool = false) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	if input_override:
		events.append(input_override)
	elif interaction_input_action_name and InputMap.has_action(interaction_input_action_name):
		events.append_array(InputMap.action_get_events(interaction_input_action_name))

	var preferred: Array[InputEvent] = []
	var others: Array[InputEvent] = []
	for event in events:
		var is_gamepad_event := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if is_gamepad_event == prefer_gamepad:
			preferred.append(event)
		else:
			others.append(event)
	return preferred + others


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
			var kc := (
				key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
			)
			return OS.get_keycode_string(kc)
	return ""
