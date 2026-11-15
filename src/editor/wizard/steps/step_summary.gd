@tool
extends "res://addons/godot-aizu/src/editor/wizard/steps/step.gd"
## What is going to happen, before anything does.

const _Ui := preload("res://addons/godot-aizu/src/editor/wizard/steps/ui.gd")
const _Plan := preload("res://addons/godot-aizu/src/editor/wizard/setup_plan.gd")

## The plan shown now. The dialog applies it.
var plan: RefCounted
var _view: TextEdit


func _init() -> void:
	title = "Summary"


func build() -> Control:
	var box := _Ui.column()
	box.add_child(_Ui.label("Nothing has changed yet. Press the button to do all of this at once; one undo takes it back (files that were written stay)."))
	_view = TextEdit.new()
	_view.editable = false
	_view.custom_minimum_size = Vector2(520, 300)
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_view)
	return box


func enter() -> void:
	discard_plan()
	plan = _Plan.new()
	plan.build(model, scan)
	var text := PackedStringArray()
	if not plan.errors.is_empty():
		text.append("CANNOT APPLY YET:")
		for error in plan.errors:
			text.append("  x " + error)
		text.append("Go back and fix it.")
		text.append("")
	text.append_array(plan.lines)
	if not plan.notes.is_empty():
		text.append("")
		text.append("Notes:")
		for note in plan.notes:
			text.append("  " + note)
	if not plan.script_orphans.is_empty():
		text.append("")
		text.append("These lines of the script point to nodes that are removed. The wizard does not touch the script: change them yourself.")
		for line in plan.script_orphans:
			text.append("  ! " + line)
	if not plan.script_added.is_empty():
		text.append("")
		text.append("Added to the script:")
		for line in plan.script_added:
			text.append("  + " + line)
	_view.text = "\n".join(text)


func discard_plan() -> void:
	if plan:
		plan.discard()
		plan = null
