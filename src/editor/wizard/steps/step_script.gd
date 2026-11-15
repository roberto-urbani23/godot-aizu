@tool
extends "res://addons/godot-aizu/src/editor/wizard/steps/step.gd"
## The script of the object, where it reacts to what the nodes announce.

const _Ui := preload("res://addons/godot-aizu/src/editor/wizard/steps/ui.gd")

var _enable: CheckBox
var _body: VBoxContainer
var _existing: Label
var _fields: VBoxContainer
var _path: LineEdit
var _class_name: LineEdit


func _init() -> void:
	title = "Script"


func build() -> Control:
	var box := _Ui.column()
	_enable = _Ui.check("Write the script of the object", false)
	_enable.toggled.connect(func(pressed: bool) -> void: _body.visible = pressed)
	_body = _Ui.column()
	_existing = _Ui.label("")
	_fields = _Ui.column()
	_path = _Ui.line("", "res://levels/my_level/my_object.gd")
	_class_name = _Ui.line("", "optional")
	_fields.add_child(_Ui.row("Script file", _path))
	_fields.add_child(_Ui.row("class_name", _class_name))
	_body.add_child(
		_Ui.label("The script gets an @export for each node of the object, the connections to their signals in _ready() and an empty function for each. You will see exactly what is written in the last step.")
	)
	_body.add_child(_existing)
	_body.add_child(_fields)
	box.add_child(_enable)
	box.add_child(_body)
	return box


func enter() -> void:
	_enable.button_pressed = model.enable_script
	_body.visible = _enable.button_pressed
	var script: Script = scan.get_object_script()
	if script:
		var built_in := script.resource_path.is_empty() or "::" in script.resource_path
		_existing.text = (
			"The script is built into the scene: the wizard cannot change it."
			if built_in
			else "The object already has the script %s. Lines are only added to it: nothing that is there is changed, moved or removed." % script.resource_path
		)
		_fields.visible = false
		if built_in:
			_enable.button_pressed = false
			_enable.disabled = true
			_body.visible = false
		return
	_existing.text = "The object has no script: a new one is created."
	_fields.visible = true
	if model.script_path.is_empty():
		model.script_path = _default_path()
	_path.text = model.script_path
	_class_name.text = model.script_class_name


func leave() -> void:
	model.enable_script = _enable.button_pressed and not _enable.disabled
	model.script_path = _path.text.strip_edges()
	model.script_class_name = _class_name.text.strip_edges()


func problem() -> String:
	if not _enable.button_pressed or scan.get_object_script():
		return ""
	var path := _path.text.strip_edges()
	if not path.begins_with("res://") or not path.ends_with(".gd"):
		return "The script file must be a res://... .gd path."
	if FileAccess.file_exists(path):
		return "%s already exists. Pick another file name, or attach that script to the object first." % path
	var script_class := _class_name.text.strip_edges()
	if not script_class.is_empty() and not script_class.is_valid_ascii_identifier():
		return "'%s' is not a valid class name." % script_class
	return ""


func _default_path() -> String:
	var scene_path: String = scan.scene_root.scene_file_path
	var folder: String = scene_path.get_base_dir() if not scene_path.is_empty() else "res://"
	return folder.path_join(String(scan.object_root.name).to_snake_case() + ".gd")
