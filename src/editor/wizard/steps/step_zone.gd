@tool
extends "res://addons/godot-aizu/src/editor/wizard/steps/step.gd"
## The zone: what the player aims at, and the actions it offers.

const _Ui := preload("res://addons/godot-aizu/src/editor/wizard/steps/ui.gd")
const _Reader := preload("res://addons/godot-aizu/src/editor/wizard/setup_reader.gd")
const _Model := preload("res://addons/godot-aizu/src/editor/wizard/setup_model.gd")
const _ActionRow := preload("res://addons/godot-aizu/src/editor/wizard/steps/action_row.gd")
const _SharedCopy := preload("res://addons/godot-aizu/src/editor/wizard/steps/shared_copy.gd")

var _action: OptionButton
var _text: LineEdit
var _shape: CheckBox
var _primary_copy_box: VBoxContainer
var _primary_copy: RefCounted
var _original_input: String = ""
var _extra_box: VBoxContainer
var _rows: Array[RefCounted] = []
var _text_was_edited: bool = false
var _filled: bool = false


func _init() -> void:
	title = "Zone"


func build() -> Control:
	var box := _Ui.column()
	_action = _Ui.option(_actions())
	_action.item_selected.connect(func(_i: int) -> void: _refresh_primary_copy())
	_text = _Ui.line("", "{interaction_key} Interact")
	_text.text_changed.connect(func(_t: String) -> void: _text_was_edited = true)
	_shape = _Ui.check("Create a box shape that covers the meshes", true)
	_primary_copy_box = _Ui.column()
	_extra_box = _Ui.column()
	var add := Button.new()
	add.text = "Add an extra action"
	add.pressed.connect(func() -> void: _add_row({}))

	box.add_child(
		_Ui.label("The primary action of the zone. Pick '(none)' for an object that has no action of its own, for example one that only receives grabbed objects.")
	)
	box.add_child(_Ui.row("Input", _action))
	box.add_child(_primary_copy_box)
	box.add_child(_Ui.row("Prompt text", _text))
	box.add_child(_Ui.label("{interaction_key} is replaced by the key or button of the input."))
	box.add_child(_shape)
	box.add_child(_Ui.heading("Extra actions (optional)"))
	box.add_child(_Ui.label("Other things the player can do to it, each with its own input and prompt text."))
	box.add_child(_extra_box)
	box.add_child(add)
	return box


func enter() -> void:
	var has_shape := false
	if scan.zone:
		for child in scan.zone.get_children():
			if child is CollisionShape3D:
				has_shape = true
	_shape.disabled = has_shape or scan.meshes.is_empty()
	if not _filled:
		_filled = true
		_fill_first_time()
	if not model.is_edit and not _text_was_edited:
		_text.text = "{interaction_key} Grab" if model.enable_grab else "{interaction_key} Interact"
	_shape.button_pressed = model.create_zone_shape and not _shape.disabled


func leave() -> void:
	var picked := _Ui.selected_text(_action)
	model.input_action = StringName(picked) if picked != "(none)" else &""
	model.prompt_text = _text.text.strip_edges()
	model.create_zone_shape = _shape.button_pressed
	model.primary_copy_name = _primary_copy.copy_name() if _primary_copy else ""
	model.extra_actions.clear()
	var taken := {}
	for row in _rows:
		taken[row.to_dict()["id"]] = true
	for row in _rows:
		var item: Dictionary = row.to_dict()
		if item["ref"] == null and item["text"].is_empty():
			continue
		if String(item["id"]).is_empty():
			item["id"] = _Ui.make_id(item["text"], "action", taken)
		model.extra_actions.append(item)


func problem() -> String:
	var names := {}
	if _primary_copy:
		if _primary_copy.problem() != "":
			return _primary_copy.problem()
		if _primary_copy.is_required():
			names[_primary_copy.path()] = true
	for row in _rows:
		if row.problem() != "":
			return row.problem()
		for path in row.copy_paths():
			if names.has(path):
				return "Two copies would be saved as %s: give them different names." % path
			names[path] = true
	return ""


func _fill_first_time() -> void:
	var wanted := String(model.input_action) if model.input_action != &"" else "interact"
	if model.is_edit and scan.zone:
		wanted = String(model.input_action)
		_text.text = model.prompt_text
		var trigger: Resource = scan.zone.get("interaction_trigger")
		if wanted == _Model.CUSTOM_KEY:
			_action.add_item(_Model.CUSTOM_KEY)
		if _Reader.is_shared(trigger):
			_primary_copy = _SharedCopy.new(trigger, "trigger")
			_primary_copy_box.add_child(_primary_copy.control)
	_original_input = wanted
	var items := _actions()
	var at := -1
	for i in _action.item_count:
		if _action.get_item_text(i) == wanted:
			at = i
	_action.selected = at if at >= 0 else (items.find(wanted) if items.has(wanted) else 0)
	_refresh_primary_copy()
	for item in model.extra_actions:
		_add_row(item)


func _refresh_primary_copy() -> void:
	if _primary_copy:
		var picked := _Ui.selected_text(_action)
		var current := "" if picked == "(none)" else picked
		_primary_copy.set_required(current != _original_input)


func _actions() -> PackedStringArray:
	var items: PackedStringArray = ["(none)"]
	items.append_array(scan.input_actions)
	return items


func _add_row(item: Dictionary) -> void:
	var row := _ActionRow.new(item, _actions(), null, "{interaction_key} Inspect")
	_rows.append(row)
	_extra_box.add_child(row.control)
	row.remove_requested.connect(_remove_row.bind(row))


func _remove_row(row: RefCounted) -> void:
	_rows.erase(row)
	row.control.queue_free()
