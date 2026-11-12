extends Node
## Tracks which kind of device the player used last, so glyphs and prompts can
## switch between keyboard/mouse and gamepad.

signal device_changed(is_gamepad: bool)

## Joystick drift below this is not treated as the player using the gamepad.
const _AXIS_THRESHOLD := 0.5

var is_gamepad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		_set_gamepad(false)
	elif event is InputEventJoypadButton:
		_set_gamepad(true)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > _AXIS_THRESHOLD:
		_set_gamepad(true)


func _set_gamepad(value: bool) -> void:
	if value == is_gamepad:
		return
	is_gamepad = value
	device_changed.emit(is_gamepad)
