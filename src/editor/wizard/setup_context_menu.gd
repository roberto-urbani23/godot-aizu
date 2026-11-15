@tool
extends EditorContextMenuPlugin
## "Aizu: make interactable..." in the right click menu of a node of the Scene dock.

const _Launcher := preload("res://addons/godot-aizu/src/editor/wizard/setup_launcher.gd")


func _popup_menu(paths: PackedStringArray) -> void:
	if paths.size() == 1:
		add_context_menu_item("Aizu: make interactable...", _on_selected)


func _on_selected(nodes: Array) -> void:
	if nodes.size() == 1:
		_Launcher.open(nodes[0])
