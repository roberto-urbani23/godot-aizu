@tool
extends EditorPlugin

const _ZoneInspectorPlugin := preload("res://addons/godot-aizu/src/editor/zone_inspector_plugin.gd")

var _zone_inspector_plugin: EditorInspectorPlugin

func _enter_tree() -> void:
	add_autoload_singleton(
		"AizuInteractionDetectorBus",
		"res://addons/godot-aizu/src/autoloads/aizu_interaction_detector_bus.gd"
	)
	add_autoload_singleton(
		"AizuInputDevice",
		"res://addons/godot-aizu/src/autoloads/aizu_input_device.gd"
	)
	_zone_inspector_plugin = _ZoneInspectorPlugin.new()
	_zone_inspector_plugin.undo_redo = get_undo_redo()
	add_inspector_plugin(_zone_inspector_plugin)

func _exit_tree() -> void:
	remove_autoload_singleton("AizuInteractionDetectorBus")
	remove_autoload_singleton("AizuInputDevice")
	remove_inspector_plugin(_zone_inspector_plugin)
