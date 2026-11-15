@tool
extends AcceptDialog
## The wizard: one step at a time, back and forth, and nothing is created until the
## last step is confirmed.

const _Scan := preload("res://addons/godot-aizu/src/editor/wizard/setup_scan.gd")
const _Model := preload("res://addons/godot-aizu/src/editor/wizard/setup_model.gd")
const _Reader := preload("res://addons/godot-aizu/src/editor/wizard/setup_reader.gd")
const _StepObject := preload("res://addons/godot-aizu/src/editor/wizard/steps/step_object.gd")
const _StepZone := preload("res://addons/godot-aizu/src/editor/wizard/steps/step_zone.gd")
const _StepOutline := preload("res://addons/godot-aizu/src/editor/wizard/steps/step_outline.gd")
const _StepGrab := preload("res://addons/godot-aizu/src/editor/wizard/steps/step_grab.gd")
const _StepReceiver := preload("res://addons/godot-aizu/src/editor/wizard/steps/step_receiver.gd")
const _StepScript := preload("res://addons/godot-aizu/src/editor/wizard/steps/step_script.gd")
const _StepSummary := preload("res://addons/godot-aizu/src/editor/wizard/steps/step_summary.gd")
const _Ui := preload("res://addons/godot-aizu/src/editor/wizard/steps/ui.gd")

var _scan: RefCounted
var _model: RefCounted
var _steps: Array = []
var _controls: Array[Control] = []
var _index: int = 0
var _header: Label
var _problem: Label
var _holder: VBoxContainer
var _back: Button
var _next: Button
var _applied: bool = false


## Prepares the wizard for [param node] and builds its steps.
func setup(node: Node) -> void:
	dialog_hide_on_ok = true
	_scan = _Scan.new()
	_scan.run(node, EditorInterface.get_edited_scene_root())
	_model = _Model.new()
	if _scan.error.is_empty():
		_Reader.new().fill(_model, _scan)
	title = (
		"Aizu: edit '%s'" % node.name if _model.is_edit else "Aizu: make '%s' interactable" % node.name
	)
	ok_button_text = "Apply" if _model.is_edit else "Create"
	_steps = [
		_StepObject.new(),
		_StepZone.new(),
		_StepOutline.new(),
		_StepGrab.new(),
		_StepReceiver.new(),
		_StepScript.new(),
		_StepSummary.new(),
	]

	var column := _Ui.column()
	_header = _Ui.heading("")
	_problem = _Ui.label("")
	_problem.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_holder = VBoxContainer.new()
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 380)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_holder)
	column.add_child(_header)
	column.add_child(scroll)
	column.add_child(_problem)
	add_child(column)

	for step in _steps:
		step.model = _model
		step.scan = _scan
		var control: Control = step.build()
		control.visible = false
		_holder.add_child(control)
		_controls.append(control)

	_back = add_button("Back", false, "back")
	_next = add_button("Next", true, "next")
	add_cancel_button("Cancel")
	custom_action.connect(_on_custom_action)
	confirmed.connect(_on_confirmed)
	visibility_changed.connect(_on_visibility_changed)
	_show_step(0)


func _show_step(index: int) -> void:
	_controls[_index].visible = false
	_index = index
	_steps[_index].enter()
	_controls[_index].visible = true
	_header.text = "Step %d of %d: %s" % [_index + 1, _steps.size(), _steps[_index].title]
	_problem.text = ""
	var last := _index == _steps.size() - 1
	_back.visible = _index > 0
	_next.visible = not last
	get_ok_button().visible = last
	var errors: PackedStringArray = _steps[-1].plan.errors if last and _steps[-1].plan else []
	get_ok_button().disabled = last and (_scan.error != "" or not errors.is_empty())


func _on_custom_action(action: StringName) -> void:
	if action == &"back" and _index > 0:
		_steps[_index].leave()
		_show_step(_index - 1)
	elif action == &"next" and _index < _steps.size() - 1:
		var why: String = _steps[_index].problem()
		if not why.is_empty():
			_problem.text = why
			return
		_steps[_index].leave()
		_show_step(_index + 1)


func _on_confirmed() -> void:
	var toaster := EditorInterface.get_editor_toaster()
	var plan: RefCounted = _steps[-1].plan
	if plan == null:
		toaster.push_toast("Aizu: the wizard has no plan to apply.", EditorToaster.SEVERITY_ERROR)
		return
	if plan.apply(EditorInterface.get_editor_undo_redo()):
		_applied = true
		toaster.push_toast(
			"Aizu: '%s' %s. Ctrl+Z undoes it."
			% [_scan.object_root.name, "updated" if _model.is_edit else "is now interactable"]
		)
	else:
		toaster.push_toast(
			"Aizu: could not create everything, see the Output panel.", EditorToaster.SEVERITY_ERROR
		)


# The dialog hides itself before it announces the confirmation, so the clean up waits for
# the confirmation to be handled.
func _on_visibility_changed() -> void:
	if not visible:
		_clean_up.call_deferred()


func _clean_up() -> void:
	if visible:
		return
	if not _applied:
		_steps[-1].discard_plan()
	queue_free()
