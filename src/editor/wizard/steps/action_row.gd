@tool
extends RefCounted
## One row of an action of the zone or of a use of a receiver: its input, its prompt
## text and, for a use, its kind. A row made from a resource of the scene remembers it, so
## the wizard changes that resource instead of making another.

signal remove_requested

const _Ui := preload("res://addons/godot-aizu/src/editor/wizard/steps/ui.gd")
const _Reader := preload("res://addons/godot-aizu/src/editor/wizard/setup_reader.gd")
const _Model := preload("res://addons/godot-aizu/src/editor/wizard/setup_model.gd")
const _KindChoice := preload("res://addons/godot-aizu/src/editor/wizard/steps/kind_choice.gd")
const _SharedCopy := preload("res://addons/godot-aizu/src/editor/wizard/steps/shared_copy.gd")

var control: VBoxContainer
var _ref: Resource
var _id: String = ""
var _kind: RefCounted
var _original_kind: String = ""
var _input: OptionButton
var _text: LineEdit
var _original_input: String = ""
var _original_text: String = ""
var _trigger_copy: RefCounted
var _resource_copy: RefCounted


## [param item] is a row of the model, or an empty dictionary for a new one. [param kinds]
## are the kinds of the project, or null for a row without a kind (an extra action).
func _init(
	item: Dictionary, actions: PackedStringArray, kinds: Variant, default_text: String
) -> void:
	_ref = item.get("ref")
	_id = item.get("id", "")
	_original_input = item.get("input_action", "interact")
	_original_text = item.get("text", "")

	var items := actions.duplicate()
	if _original_input == _Model.CUSTOM_KEY:
		items.insert(1, _Model.CUSTOM_KEY)
	_input = _Ui.option(items, _original_input)
	_text = _Ui.line(_original_text, default_text)
	var remove := Button.new()
	remove.text = "Remove"
	remove.pressed.connect(func() -> void: remove_requested.emit())

	var first := HBoxContainer.new()
	if kinds != null:
		_original_kind = item.get("kind", "")
		_kind = _KindChoice.new(kinds, _original_kind)
		_kind.control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		first.add_child(_kind.control)
		first.add_child(remove)
	var second := HBoxContainer.new()
	second.add_child(_input)
	second.add_child(_text)
	if kinds == null:
		second.add_child(remove)

	control = VBoxContainer.new()
	if kinds != null:
		control.add_child(first)
	control.add_child(second)
	var trigger: Resource = _ref.get("trigger") if _ref else null
	if _Reader.is_shared(trigger):
		_trigger_copy = _SharedCopy.new(trigger, "trigger")
		control.add_child(_trigger_copy.control)
	if _Reader.is_shared(_ref):
		_resource_copy = _SharedCopy.new(_ref, "action")
		control.add_child(_resource_copy.control)
	control.add_child(HSeparator.new())
	_input.item_selected.connect(func(_i: int) -> void: _refresh())
	_text.text_changed.connect(func(_t: String) -> void: _refresh())
	if _kind:
		_kind.changed.connect(_refresh)
	_refresh()


func is_empty() -> bool:
	return _kind != null and _kind.token().is_empty()


## The row as the model keeps it. A new row has no id yet: the step makes it.
func to_dict() -> Dictionary:
	var input := _Ui.selected_text(_input)
	var item := {
		"id": _id,
		"input_action": "" if input == "(none)" else input,
		"text": _text.text.strip_edges(),
		"ref": _ref,
		"copy_trigger": _trigger_copy.copy_name() if _trigger_copy else "",
		"copy_resource": _resource_copy.copy_name() if _resource_copy else "",
	}
	if _kind:
		item["kind"] = _kind.token()
	return item


## The files of the copies this row asks for, in the folders of the originals.
func copy_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for copy in [_trigger_copy, _resource_copy]:
		if copy and copy.is_required():
			paths.append(copy.path())
	return paths


func problem() -> String:
	for copy in [_trigger_copy, _resource_copy]:
		if copy and copy.problem() != "":
			return copy.problem()
	return ""


func _refresh() -> void:
	var item := to_dict()
	var input_changed: bool = item["input_action"] != ("" if _original_input == "(none)" else _original_input)
	var text_changed: bool = item["text"] != _original_text
	var kind_changed: bool = _kind != null and item["kind"] != _original_kind
	if _trigger_copy:
		_trigger_copy.set_required(input_changed)
	if _resource_copy:
		# Replacing the trigger changes the action too, so a shared action needs its copy.
		_resource_copy.set_required(text_changed or kind_changed or input_changed)
