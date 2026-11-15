@tool
extends RefCounted
## Opens the wizard for a node of the scene being edited.

const _Dialog := preload("res://addons/godot-aizu/src/editor/wizard/setup_dialog.gd")


static func open(node: Node) -> Window:
	if EditorInterface.get_edited_scene_root() == null:
		push_warning("Aizu: open a scene first.")
		return null
	var dialog := _Dialog.new()
	dialog.setup(node)
	# The editor puts the dialog in its tree and shows it.
	EditorInterface.popup_dialog_centered(dialog, Vector2i(640, 560))
	return dialog


## The node the wizard works on when it is started from the menu: the selected node, or the
## root of the scene.
static func open_for_selection() -> void:
	var selected := EditorInterface.get_selection().get_top_selected_nodes()
	if not selected.is_empty():
		open(selected[0])
		return
	var root := EditorInterface.get_edited_scene_root()
	if root:
		open(root)
	else:
		push_warning("Aizu: open a scene first.")
