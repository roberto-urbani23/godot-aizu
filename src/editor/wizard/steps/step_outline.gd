@tool
extends "res://addons/godot-aizu/src/editor/wizard/steps/step.gd"
## The outline drawn around the object while it is aimed at.

const _Ui := preload("res://addons/godot-aizu/src/editor/wizard/steps/ui.gd")

var _enable: CheckBox
var _info: Label


func _init() -> void:
	title = "Outline"


func build() -> Control:
	var box := _Ui.column()
	_enable = _Ui.check("Outline the object when it is aimed at", true)
	_info = _Ui.label("")
	box.add_child(_enable)
	box.add_child(_info)
	return box


func enter() -> void:
	if scan.outline:
		_enable.text = "Outline the object when it is aimed at (untick to remove '%s')" % scan.outline.name
		_enable.button_pressed = model.enable_outline
		_enable.disabled = false
		_info.text = "The scene already has this outline."
	elif scan.meshes.is_empty():
		_enable.disabled = true
		_enable.button_pressed = false
		_info.text = "No mesh found under the object: there is nothing to outline."
	else:
		_enable.text = "Outline the object when it is aimed at"
		_enable.disabled = false
		_enable.button_pressed = model.enable_outline
		var names := PackedStringArray()
		for mesh in scan.meshes:
			names.append(mesh.name)
		_info.text = "Meshes that get the outline: %s." % ", ".join(names)


func leave() -> void:
	model.enable_outline = _enable.button_pressed and not _enable.disabled
