@tool
extends "res://addons/godot-aizu/src/editor/wizard/steps/step.gd"
## Makes the object something the player can pick up and throw.

const _Ui := preload("res://addons/godot-aizu/src/editor/wizard/steps/ui.gd")
const _KindChoice := preload("res://addons/godot-aizu/src/editor/wizard/steps/kind_choice.gd")
const _SETTING_FOLDER := "aizu/wizard/kinds_folder"

var _enable: CheckBox
var _body: VBoxContainer
var _body_note: Label
var _create_body: CheckBox
var _kinds_box: VBoxContainer
var _kind_rows: Array[Dictionary] = []  # { "box", "choice" }
var _folder: LineEdit
var _handle: CheckBox
var _throw: SpinBox
var _dialog: EditorFileDialog
var _built_kinds: bool = false
var _handle_read: bool = false


func _init() -> void:
	title = "Grab"


func build() -> Control:
	var box := _Ui.column()
	_enable = _Ui.check("The player can grab and throw it", false)
	_enable.toggled.connect(_on_enable_toggled)
	_body = _Ui.column()
	_body_note = _Ui.label("")
	_create_body = _Ui.check("Create a RigidBody3D 'Body' and move the meshes under it", false)
	_kinds_box = _Ui.column()
	var add := Button.new()
	add.text = "Add a kind"
	add.pressed.connect(_add_kind_row.bind(""))
	_folder = _Ui.line("res://")
	var browse := Button.new()
	browse.text = "Browse"
	browse.pressed.connect(_on_browse)
	var folder_row := HBoxContainer.new()
	folder_row.add_child(_folder)
	folder_row.add_child(browse)
	_handle = _Ui.check("Create a GrabHandle marker (the point of the object that is carried)", false)
	_throw = SpinBox.new()
	_throw.min_value = 0.0
	_throw.max_value = 100.0
	_throw.step = 0.1
	_throw.value = 1.0

	_body.add_child(_body_note)
	_body.add_child(_create_body)
	_body.add_child(_Ui.heading("Kinds (optional)"))
	_body.add_child(
		_Ui.label("What this object is for the things it can be used on: a knife, a red key. Pick one that exists or type a new name.")
	)
	_body.add_child(_kinds_box)
	_body.add_child(add)
	_body.add_child(_Ui.row("Folder for new kinds", folder_row))
	_body.add_child(_handle)
	_body.add_child(_Ui.row("Throw force x", _throw))
	box.add_child(_enable)
	box.add_child(_body)
	return box


func enter() -> void:
	if not _built_kinds:
		_built_kinds = true
		_folder.text = _default_folder()
		_dialog = EditorFileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialog.access = FileDialog.ACCESS_RESOURCES
		_dialog.dir_selected.connect(_on_folder_picked)
		_folder.add_child(_dialog)
	_enable.disabled = false
	_enable.text = (
		"The player can grab and throw it (untick to remove '%s')" % scan.grabbable.name
		if scan.grabbable
		else "The player can grab and throw it"
	)
	_enable.button_pressed = model.enable_grab
	_body.visible = _enable.button_pressed
	if not _handle_read:
		_handle_read = true
		_handle.button_pressed = model.create_handle
		_throw.value = model.throw_multiplier
	if scan.body:
		_body_note.text = "RigidBody3D found: '%s'." % scan.body.name
		_create_body.visible = false
	else:
		_body_note.text = "The grab needs a RigidBody3D and there is none."
		_create_body.visible = true
		_create_body.button_pressed = model.create_body
	_create_body.disabled = scan.meshes.is_empty()
	if scan.grabbable:
		_create_body.visible = false
	if _kind_rows.is_empty():
		for path in model.kind_paths:
			_add_kind_row(path)
		for kind_name in model.new_kind_names:
			_add_kind_row("new:" + kind_name)


func leave() -> void:
	model.enable_grab = _enable.button_pressed and not _enable.disabled
	model.create_body = _create_body.visible and _create_body.button_pressed
	model.kind_paths.clear()
	model.new_kind_names.clear()
	for row in _kind_rows:
		var token: String = row["choice"].token()
		if token.begins_with("new:"):
			var kind_name := token.trim_prefix("new:")
			if not model.new_kind_names.has(kind_name):
				model.new_kind_names.append(kind_name)
		elif not token.is_empty() and not model.kind_paths.has(token):
			model.kind_paths.append(token)
	model.kinds_folder = _folder.text.strip_edges()
	model.create_handle = _handle.button_pressed
	model.throw_multiplier = _throw.value
	if not model.new_kind_names.is_empty():
		EditorInterface.get_editor_settings().set_setting(_SETTING_FOLDER, model.kinds_folder)


func problem() -> String:
	if not _enable.button_pressed or _enable.disabled:
		return ""
	if scan.grabbable == null and not scan.body and not _create_body.button_pressed:
		return "The grab needs a RigidBody3D: let the wizard create one, or add it to the scene first."
	for row in _kind_rows:
		var token: String = row["choice"].token()
		if token.begins_with("new:") and not _folder.text.begins_with("res://"):
			return "The folder for new kinds must start with res://."
	return ""


func _default_folder() -> String:
	var settings := EditorInterface.get_editor_settings()
	if settings.has_setting(_SETTING_FOLDER):
		return settings.get_setting(_SETTING_FOLDER)
	return "res://resources" if DirAccess.dir_exists_absolute("res://resources") else "res://"


func _on_enable_toggled(pressed: bool) -> void:
	_body.visible = pressed


func _add_kind_row(token: String) -> void:
	var row := HBoxContainer.new()
	var choice := _KindChoice.new(scan.kinds, token)
	choice.control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var remove := Button.new()
	remove.text = "Remove"
	row.add_child(choice.control)
	row.add_child(remove)
	_kinds_box.add_child(row)
	var entry := { "box": row, "choice": choice }
	_kind_rows.append(entry)
	remove.pressed.connect(_remove_kind_row.bind(entry))


func _remove_kind_row(entry: Dictionary) -> void:
	_kind_rows.erase(entry)
	entry["box"].queue_free()


func _on_browse() -> void:
	_dialog.current_dir = _folder.text
	_dialog.popup_file_dialog()


func _on_folder_picked(directory: String) -> void:
	_folder.text = directory
