class_name AizuProximityIconSet extends Resource
## Maps keys and mouse buttons to the icon an [AizuProximitySprite] shows. The addon
## ships no icons: build a set from whatever icon pack the game uses. Inputs without
## an entry have no icon.

@export var icons: Array[AizuProximityIcon]:
	set(value):
		icons = value
		_dirty = true

var _by_key: Dictionary = {}
var _by_mouse_button: Dictionary = {}
var _dirty: bool = true


## Returns the icon for an event, or null if the set has none for it.
func get_icon(event: InputEvent) -> Texture2D:
	_rebuild_if_needed()

	var key_event := event as InputEventKey
	if key_event:
		return _by_key.get(_get_keycode(key_event))

	var mouse_event := event as InputEventMouseButton
	if mouse_event:
		return _by_mouse_button.get(mouse_event.button_index)

	return null


## Returns the icon for the first of the trigger's inputs that has one.
func get_icon_for_trigger(trigger: AizuInteractionTrigger) -> Texture2D:
	if not trigger:
		return null
	for event in trigger.get_input_events():
		var texture := get_icon(event)
		if texture:
			return texture
	return null


func _rebuild_if_needed() -> void:
	if not _dirty:
		return
	_dirty = false
	_by_key.clear()
	_by_mouse_button.clear()

	for icon in icons:
		if not icon or not icon.texture:
			continue
		if icon.key != KEY_NONE:
			_by_key[icon.key] = icon.texture
		elif icon.mouse_button != MOUSE_BUTTON_NONE:
			_by_mouse_button[icon.mouse_button] = icon.texture


# Physical-only events (what the Input Map editor stores) are mapped to the key
# printed on the player's layout, so the icon matches what they see.
func _get_keycode(event: InputEventKey) -> Key:
	if event.keycode != KEY_NONE:
		return event.keycode
	if DisplayServer.get_name() == "headless":
		return event.physical_keycode
	var from_layout := DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
	return from_layout if from_layout != KEY_NONE else event.physical_keycode
