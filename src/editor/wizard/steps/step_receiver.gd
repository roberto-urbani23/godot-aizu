@tool
extends "res://addons/godot-aizu/src/editor/wizard/steps/step.gd"
## Lets grabbed objects be used on this one: a knife on meat, a key on a door.

const _Ui := preload("res://addons/godot-aizu/src/editor/wizard/steps/ui.gd")
const _ActionRow := preload("res://addons/godot-aizu/src/editor/wizard/steps/action_row.gd")

var _enable: CheckBox
var _body: VBoxContainer
var _uses_box: VBoxContainer
var _rows: Array[RefCounted] = []
var _filled: bool = false


func _init() -> void:
	title = "Receiver"


func build() -> Control:
	var box := _Ui.column()
	_enable = _Ui.check("Grabbed objects can be used on it", false)
	_enable.toggled.connect(func(pressed: bool) -> void: _body.visible = pressed)
	_body = _Ui.column()
	_uses_box = _Ui.column()
	var add := Button.new()
	add.text = "Add a use"
	add.pressed.connect(func() -> void: _add_row({}))
	_body.add_child(_Ui.label("Needs a zone: the one in the scene, or the one the wizard creates."))
	_body.add_child(
		_Ui.label("One use for every kind of object it accepts, with its own input and prompt text: 'knife: {interaction_key} Cut'.")
	)
	_body.add_child(_uses_box)
	_body.add_child(add)
	box.add_child(_enable)
	box.add_child(_body)
	return box


func enter() -> void:
	_enable.disabled = false
	_enable.text = (
		"Grabbed objects can be used on it (untick to remove '%s')" % scan.receiver.name
		if scan.receiver
		else "Grabbed objects can be used on it"
	)
	_enable.button_pressed = model.enable_receiver
	_body.visible = _enable.button_pressed
	if not _filled:
		_filled = true
		for item in model.uses:
			_add_row(item)
		if _rows.is_empty():
			_add_row({})


func leave() -> void:
	model.enable_receiver = _enable.button_pressed
	model.uses.clear()
	var taken := {}
	for row in _rows:
		taken[row.to_dict()["id"]] = true
	for row in _rows:
		if row.is_empty():
			continue
		var item: Dictionary = row.to_dict()
		if item["text"].is_empty() and item["ref"] == null:
			item["text"] = "{interaction_key} Use"
		if String(item["id"]).is_empty():
			var kind_name: String = String(item["kind"]).trim_prefix("new:").get_file().get_basename()
			var plain: String = "" if item["text"] == "{interaction_key} Use" else item["text"]
			item["id"] = _Ui.make_id(plain, kind_name, taken)
		model.uses.append(item)


func problem() -> String:
	if not _enable.button_pressed:
		return ""
	var any_kind := false
	var names := {}
	for row in _rows:
		if not row.is_empty():
			any_kind = true
		if row.problem() != "":
			return row.problem()
		for path in row.copy_paths():
			if names.has(path):
				return "Two copies would be saved as %s: give them different names." % path
			names[path] = true
	if not any_kind:
		return "Add at least one use with a kind, or turn the receiver off."
	return ""


func _actions() -> PackedStringArray:
	var items: PackedStringArray = ["(none)"]
	items.append_array(scan.input_actions)
	return items


func _add_row(item: Dictionary) -> void:
	var row := _ActionRow.new(item, _actions(), scan.kinds, "{interaction_key} Use")
	_rows.append(row)
	_uses_box.add_child(row.control)
	row.remove_requested.connect(_remove_row.bind(row))


func _remove_row(row: RefCounted) -> void:
	_rows.erase(row)
	row.control.queue_free()
