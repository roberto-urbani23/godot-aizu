@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_autoload_singleton(
		"AizuInteractionDetectorBus",
		"res://addons/godot-aizu/src/autoloads/aizu_interaction_detector_bus.gd"
	)

func _exit_tree() -> void:
	remove_autoload_singleton("AizuInteractionDetectorBus")
