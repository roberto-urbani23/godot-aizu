class_name AizuGlyphSet extends Resource
## Maps inputs to the glyph shown for them, in proximity sprites and in the
## interaction prompt. The addon ships no glyphs: build a set from whatever icon
## pack the game uses. Inputs without an entry have no glyph.

@export var glyphs: Array[AizuGlyph]:
	set(value):
		glyphs = value
		_dirty = true

var _by_key: Dictionary = {}
var _by_mouse_button: Dictionary = {}
var _by_joypad_button: Dictionary = {}
var _by_joypad_axis: Dictionary = {}
var _dirty: bool = true


## Returns the glyph for an event, or null if the set has none for it.
func get_glyph(event: InputEvent) -> Texture2D:
	_rebuild_if_needed()

	var key_event := event as InputEventKey
	if key_event:
		return _by_key.get(_get_keycode(key_event))

	var mouse_event := event as InputEventMouseButton
	if mouse_event:
		return _by_mouse_button.get(mouse_event.button_index)

	var button_event := event as InputEventJoypadButton
	if button_event:
		return _by_joypad_button.get(button_event.button_index)

	var motion_event := event as InputEventJoypadMotion
	if motion_event:
		return _by_joypad_axis.get(motion_event.axis)

	return null


## Returns the glyph for the first of the trigger's inputs that has one, looking
## at the device in use first: a player on a gamepad sees gamepad glyphs when the
## action has both.
func get_glyph_for_trigger(trigger: AizuInteractionTrigger) -> Texture2D:
	return get_glyph_for_device(trigger, AizuInputDevice.is_gamepad)


## Same as [method get_glyph_for_trigger] for a chosen device.
func get_glyph_for_device(trigger: AizuInteractionTrigger, prefer_gamepad: bool) -> Texture2D:
	if not trigger:
		return null
	for event in trigger.get_input_events(prefer_gamepad):
		var texture := get_glyph(event)
		if texture:
			return texture
	return null


func _rebuild_if_needed() -> void:
	if not _dirty:
		return
	_dirty = false
	_by_key.clear()
	_by_mouse_button.clear()
	_by_joypad_button.clear()
	_by_joypad_axis.clear()

	for glyph in glyphs:
		if not glyph or not glyph.texture:
			continue
		if glyph.key != KEY_NONE:
			_by_key[glyph.key] = glyph.texture
		elif glyph.mouse_button != MOUSE_BUTTON_NONE:
			_by_mouse_button[glyph.mouse_button] = glyph.texture
		elif glyph.joypad_button != JOY_BUTTON_INVALID:
			_by_joypad_button[glyph.joypad_button] = glyph.texture
		elif glyph.joypad_axis != JOY_AXIS_INVALID:
			_by_joypad_axis[glyph.joypad_axis] = glyph.texture


# Physical-only events (what the Input Map editor stores) are mapped to the key
# printed on the player's layout, so the glyph matches what they see.
func _get_keycode(event: InputEventKey) -> Key:
	if event.keycode != KEY_NONE:
		return event.keycode
	if DisplayServer.get_name() == "headless":
		return event.physical_keycode
	var from_layout := DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
	return from_layout if from_layout != KEY_NONE else event.physical_keycode
