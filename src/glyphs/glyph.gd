class_name AizuGlyph extends Resource
## The picture shown for one physical input: a key, a mouse button, a gamepad
## button or a gamepad axis (triggers). Set only one of them.

@export var key: Key = KEY_NONE
@export var mouse_button: MouseButton = MOUSE_BUTTON_NONE
@export var joypad_button: JoyButton = JOY_BUTTON_INVALID
@export var joypad_axis: JoyAxis = JOY_AXIS_INVALID
@export var texture: Texture2D
