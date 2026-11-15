@tool
extends EditorPlugin

const _ZoneInspectorPlugin := preload("res://addons/godot-aizu/src/editor/zone_inspector_plugin.gd")
const _SetupContextMenu := preload("res://addons/godot-aizu/src/editor/wizard/setup_context_menu.gd")
const _SetupLauncher := preload("res://addons/godot-aizu/src/editor/wizard/setup_launcher.gd")
const _MENU_NAME := "Aizu: make interactable..."

var _zone_inspector_plugin: EditorInspectorPlugin
var _setup_context_menu: EditorContextMenuPlugin

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
	_setup_context_menu = _SetupContextMenu.new()
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE, _setup_context_menu)
	add_tool_menu_item(_MENU_NAME, _SetupLauncher.open_for_selection)

func _exit_tree() -> void:
	remove_autoload_singleton("AizuInteractionDetectorBus")
	remove_autoload_singleton("AizuInputDevice")
	remove_inspector_plugin(_zone_inspector_plugin)
	remove_context_menu_plugin(_setup_context_menu)
	remove_tool_menu_item(_MENU_NAME)
