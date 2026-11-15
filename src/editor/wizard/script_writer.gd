@tool
extends RefCounted
## Writes the script of the object: a new one, or the lines that are missing in an
## existing one. It only ever adds lines. Nothing that is already in the script is
## changed, moved or removed.

## Result of [method build].
class Result:
	## The whole text of the script after the changes.
	var text: String = ""
	## The lines that are added, in order, for the preview.
	var added: PackedStringArray = []
	## Name each export got in the script, by its key.
	var names: Dictionary = {}
	## Things the player should know, for example a _ready() that could not be extended.
	var notes: PackedStringArray = []


## [param exports]: { "key", "name", "type" }.
## [param connections]: { "export": key of an export, "signal", "handler" }.
## [param handlers]: { "name", "params": "use: AizuItemUse", "comment" }.
## An existing script is passed as [param existing]; an empty string builds a new one.
static func build(
	existing: String,
	extends_type: String,
	script_class: String,
	exports: Array[Dictionary],
	connections: Array[Dictionary],
	handlers: Array[Dictionary]
) -> Result:
	var result := Result.new()
	var is_new := existing.strip_edges().is_empty()
	var lines: PackedStringArray = [] if is_new else existing.split("\n")
	var declared := _read_declarations(lines)

	if is_new:
		if not script_class.is_empty():
			lines.append("class_name %s" % script_class)
			result.added.append(lines[-1])
		lines.append("extends %s" % extends_type)
		result.added.append(lines[-1])

	var export_lines := PackedStringArray()
	for item in exports:
		var export_name := _pick_name(item, declared, export_lines, result)
		result.names[item["key"]] = export_name
	_insert_exports(lines, export_lines, result)

	var connect_lines := PackedStringArray()
	for item in connections:
		var target: String = result.names[item["export"]]
		var needle := "%s.%s.connect(" % [target, item["signal"]]
		if "\n".join(lines).contains(needle):
			continue
		connect_lines.append("%s%s)" % [needle, item["handler"]])
	_insert_connections(lines, connect_lines, result)

	var handler_blocks: Array[PackedStringArray] = []
	for item in handlers:
		var func_name: String = item["name"]
		if declared.has(func_name) or _has_function(lines, func_name):
			continue
		var block := PackedStringArray()
		if item.has("comment"):
			block.append("## %s" % item["comment"])
		block.append("func %s(%s) -> void:" % [func_name, item.get("params", "")])
		var body: PackedStringArray = item.get("body", PackedStringArray())
		if body.is_empty():
			block.append("\tpass")
		for line in body:
			block.append("\t" + line)
		handler_blocks.append(block)
	_append_handlers(lines, handler_blocks, result)

	result.text = "\n".join(lines)
	if not result.text.ends_with("\n"):
		result.text += "\n"
	return result


# name -> type string ("" if untyped), for every top-level var, const, func and signal.
static func _read_declarations(lines: PackedStringArray) -> Dictionary:
	var declared := {}
	var variable := RegEx.create_from_string(
		"^(?:@\\w+(?:\\([^)]*\\))?\\s+)*var\\s+(\\w+)\\s*(?::\\s*([\\w\\.\\[\\]]+))?"
	)
	var other := RegEx.create_from_string("^(?:static\\s+)?(?:const|func|signal|enum)\\s+(\\w+)")
	for line in lines:
		var found := variable.search(line)
		if found:
			declared[found.get_string(1)] = found.get_string(2)
			continue
		found = other.search(line)
		if found:
			declared[found.get_string(1)] = ""
	return declared


# Reuses a var that is already exported with the same type, otherwise looks for a free name.
static func _pick_name(
	item: Dictionary, declared: Dictionary, export_lines: PackedStringArray, result: Result
) -> String:
	var wanted: String = item["name"]
	if declared.has(wanted) and declared[wanted] == item["type"]:
		return wanted
	var chosen := wanted
	var number := 2
	while declared.has(chosen):
		chosen = "%s_%d" % [wanted, number]
		number += 1
	if chosen != wanted:
		result.notes.append("'%s' is taken in the script, the export is called '%s'." % [wanted, chosen])
	declared[chosen] = item["type"]
	export_lines.append("@export var %s: %s" % [chosen, item["type"]])
	return chosen


static func _insert_exports(
	lines: PackedStringArray, export_lines: PackedStringArray, result: Result
) -> void:
	if export_lines.is_empty():
		return
	var at := _first_function_start(lines)
	var block := PackedStringArray()
	if at < 0:
		at = _end_of_code(lines)
		if at > 0:
			block.append("")
	block.append_array(export_lines)
	block.append("")
	for i in block.size():
		lines.insert(at + i, block[i])
	result.added.append_array(export_lines)


# The line where the first function starts, going up over the comments written above it.
static func _first_function_start(lines: PackedStringArray) -> int:
	for i in lines.size():
		if lines[i].begins_with("func ") or lines[i].begins_with("static func "):
			var at := i
			while at > 0 and lines[at - 1].strip_edges().begins_with("#"):
				at -= 1
			return at
	return -1


# The index just after the last line with code.
static func _end_of_code(lines: PackedStringArray) -> int:
	var at := lines.size()
	while at > 0 and lines[at - 1].strip_edges().is_empty():
		at -= 1
	return at


static func _has_function(lines: PackedStringArray, func_name: String) -> bool:
	for line in lines:
		if line.begins_with("func %s(" % func_name) or line.begins_with("static func %s(" % func_name):
			return true
	return false


static func _insert_connections(
	lines: PackedStringArray, connect_lines: PackedStringArray, result: Result
) -> void:
	if connect_lines.is_empty():
		return
	var ready_at := -1
	for i in lines.size():
		if lines[i].begins_with("func _ready("):
			ready_at = i
			break

	if ready_at < 0:
		var end := _end_of_code(lines)
		var block := PackedStringArray()
		if end > 0:
			block.append("")
			block.append("")
		block.append("func _ready() -> void:")
		for line in connect_lines:
			block.append("\t" + line)
		for i in block.size():
			lines.insert(end + i, block[i])
		result.added.append("func _ready() -> void:")
		for line in connect_lines:
			result.added.append("\t" + line)
		return

	# The body of _ready runs until the next line that starts at the left edge.
	var header := lines[ready_at]
	if not header.strip_edges().ends_with(":"):
		# The body is on the same line as the header: do not touch it.
		_append_extra_function(lines, connect_lines, result)
		return
	var last_code := ready_at
	var indent := "\t"
	var seen_body := false
	for i in range(ready_at + 1, lines.size()):
		var line := lines[i]
		if line.strip_edges().is_empty():
			continue
		if not (line.begins_with("\t") or line.begins_with(" ")):
			break
		if not seen_body:
			indent = line.substr(0, line.length() - line.lstrip(" \t").length())
			seen_body = true
		last_code = i
	for i in connect_lines.size():
		lines.insert(last_code + 1 + i, indent + connect_lines[i])
		result.added.append(indent + connect_lines[i])


static func _append_extra_function(
	lines: PackedStringArray, connect_lines: PackedStringArray, result: Result
) -> void:
	var end := _end_of_code(lines)
	var block: PackedStringArray = ["", "", "func _connect_aizu_signals() -> void:"]
	for line in connect_lines:
		block.append("\t" + line)
	for i in block.size():
		lines.insert(end + i, block[i])
	result.added.append("func _connect_aizu_signals() -> void:")
	for line in connect_lines:
		result.added.append("\t" + line)
	result.notes.append("Your _ready() has its body on one line, so it was not changed. Call _connect_aizu_signals() from it.")


static func _append_handlers(
	lines: PackedStringArray, blocks: Array[PackedStringArray], result: Result
) -> void:
	if blocks.is_empty():
		return
	var end := _end_of_code(lines)
	var added := PackedStringArray()
	for block in blocks:
		if end + added.size() > 0:
			added.append("")
			added.append("")
		added.append_array(block)
		result.added.append_array(block)
	for i in added.size():
		lines.insert(end + i, added[i])
