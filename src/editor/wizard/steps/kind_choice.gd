@tool
extends RefCounted
## One row to choose an item kind: a dropdown with the kinds of the project, or a name
## typed to create a new one.

const _Ui := preload("res://addons/godot-aizu/src/editor/wizard/steps/ui.gd")

signal changed

var control: HBoxContainer
var _option: OptionButton
var _new_name: LineEdit
var _paths: PackedStringArray = [""]


func _init(kinds: Array[Dictionary], selected_token: String = "") -> void:
	control = HBoxContainer.new()
	_option = OptionButton.new()
	_option.add_item("(existing kind)")
	for kind in kinds:
		_option.add_item(kind["name"])
		_paths.append(kind["path"])
	_new_name = _Ui.line("", "or the name of a new kind")
	control.add_child(_option)
	control.add_child(_new_name)
	_option.item_selected.connect(func(_i: int) -> void: changed.emit())
	_new_name.text_changed.connect(func(_t: String) -> void: changed.emit())
	# A kind that was just saved may not be in the list of the project yet.
	if not selected_token.is_empty() and not selected_token.begins_with("new:") and not _paths.has(selected_token):
		_option.add_item(selected_token.get_file().get_basename())
		_paths.append(selected_token)
	if selected_token.begins_with("new:"):
		_new_name.text = selected_token.trim_prefix("new:")
	elif _paths.has(selected_token):
		_option.selected = _paths.find(selected_token)


## "new:<name>" for a kind to create, the path of an existing one, or "" if nothing is chosen.
func token() -> String:
	var typed := _new_name.text.strip_edges()
	if not typed.is_empty():
		return "new:" + typed
	return _paths[_option.selected] if _option.selected >= 0 else ""
