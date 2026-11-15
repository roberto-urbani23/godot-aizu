@tool
extends RefCounted
## Small helpers to build the controls of the steps, so the steps read as a list of rows.


static func label(text: String, wrap: bool = true) -> Label:
	var node := Label.new()
	node.text = text
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.custom_minimum_size.x = 420.0
	return node


static func heading(text: String) -> Label:
	var node := label(text, false)
	node.add_theme_font_size_override("font_size", 16)
	return node


static func check(text: String, pressed: bool) -> CheckBox:
	var node := CheckBox.new()
	node.text = text
	node.button_pressed = pressed
	return node


static func line(text: String, placeholder: String = "") -> LineEdit:
	var node := LineEdit.new()
	node.text = text
	node.placeholder_text = placeholder
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## A dropdown with [param items]; [param selected_text] is selected if it is one of them.
static func option(items: PackedStringArray, selected_text: String = "") -> OptionButton:
	var node := OptionButton.new()
	for item in items:
		node.add_item(item)
	var at := items.find(selected_text)
	node.selected = at if at >= 0 else 0
	return node


static func row(label_text: String, control: Control) -> HBoxContainer:
	var box := HBoxContainer.new()
	var caption := Label.new()
	caption.text = label_text
	caption.custom_minimum_size.x = 140.0
	box.add_child(caption)
	box.add_child(control)
	return box


static func column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	return box


## An id for an action made from its prompt text ("{interaction_key} Cut" gives "cut"),
## or from [param fallback] when there is no usable text. It is made unique among
## [param taken], which gets the new id.
static func make_id(text: String, fallback: String, taken: Dictionary) -> String:
	var plain := text.replace("{interaction_key}", "").strip_edges()
	var id := plain.to_snake_case()
	var cleaned := ""
	for character in id:
		if character == "_" or (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			cleaned += character
	id = cleaned.strip_edges()
	if id.is_empty():
		id = fallback.to_snake_case()
	var candidate := id
	var number := 2
	while taken.has(candidate) or candidate == "primary":
		candidate = "%s_%d" % [id, number]
		number += 1
	taken[candidate] = true
	return candidate


static func selected_text(node: OptionButton) -> String:
	return node.get_item_text(node.selected) if node.selected >= 0 else ""
