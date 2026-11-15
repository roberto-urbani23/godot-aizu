@tool
extends "res://addons/godot-aizu/src/editor/wizard/steps/step.gd"
## What the wizard found in the scene, and the name of the object.

const _Ui := preload("res://addons/godot-aizu/src/editor/wizard/steps/ui.gd")

var _summary: Label
var _name_edit: LineEdit


func _init() -> void:
	title = "Object"


func build() -> Control:
	var box := _Ui.column()
	_summary = _Ui.label("")
	_name_edit = _Ui.line("", "Shown under the reticle, for example 'Door'")
	box.add_child(_summary)
	box.add_child(_Ui.row("Display name", _name_edit))
	box.add_child(
		_Ui.label("Optional: leave it empty to show no name.")
	)
	return box


func enter() -> void:
	if scan.error.is_empty():
		_name_edit.editable = true
		if model.display_name.is_empty() and not model.is_edit:
			model.display_name = String(scan.object_root.name).capitalize()
		_name_edit.text = model.display_name
	else:
		_name_edit.editable = false
	_summary.text = _describe()


func leave() -> void:
	model.display_name = _name_edit.text.strip_edges()


func problem() -> String:
	return scan.error


func _describe() -> String:
	if not scan.error.is_empty():
		return scan.error
	var found := PackedStringArray()
	found.append("Object: '%s' (%s)" % [scan.object_root.name, scan.object_root.get_class()])
	found.append("Meshes found: %d" % scan.meshes.size())
	found.append("RigidBody3D: %s" % (("'%s'" % scan.body.name) if scan.body else "none"))
	found.append("Already in the scene (you can change or remove it in the next steps):" if model.is_edit else "Already in the scene:")
	var existing := PackedStringArray()
	for item in [["zone", scan.zone], ["outline", scan.outline], ["grabbable", scan.grabbable], ["receiver", scan.receiver]]:
		if item[1]:
			existing.append("  %s '%s'" % [item[0], item[1].name])
	if existing.is_empty():
		existing.append("  nothing")
	found.append_array(existing)
	var script: Script = scan.get_object_script()
	found.append("Script: %s" % (script.resource_path if script else "none"))
	return "\n".join(found)
