@tool
extends RefCounted
## The name of the copy of a shared resource. A resource that is a file of its own is
## shared with other scenes, so the wizard never changes it: when a value of it has to
## change, the changed copy is saved as a new file with the name given here.

const _Ui := preload("res://addons/godot-aizu/src/editor/wizard/steps/ui.gd")

var control: HBoxContainer
var _resource: Resource
var _label: Label
var _name_edit: LineEdit


func _init(resource: Resource, what: String) -> void:
	_resource = resource
	control = HBoxContainer.new()
	_label = Label.new()
	_label.text = "'%s' is shared with other scenes. Name of the copy with the changes:" % (
		resource.resource_path.get_file() if resource else ""
	)
	_name_edit = _Ui.line("", "name of the new %s file" % what)
	var extension := Label.new()
	extension.text = ".tres"
	control.add_child(_label)
	control.add_child(_name_edit)
	control.add_child(extension)
	control.visible = false


## Shows or hides the field: it is only needed when something of the resource changes.
func set_required(required: bool) -> void:
	control.visible = required


func is_required() -> bool:
	return control.visible


func copy_name() -> String:
	return _name_edit.text.strip_edges()


## Where the copy is saved: next to the original file.
func path() -> String:
	return _resource.resource_path.get_base_dir().path_join(copy_name() + ".tres")


## Why the player cannot go on, empty if the name is fine or not needed.
func problem() -> String:
	if not control.visible:
		return ""
	var typed := copy_name()
	if typed.is_empty():
		return "Give a name to the copy of '%s' (it is shared, so it cannot be changed)." % _resource.resource_path.get_file()
	if not typed.is_valid_filename():
		return "'%s' is not a valid file name." % typed
	if FileAccess.file_exists(path()):
		return "%s already exists: pick another name." % path()
	return ""
