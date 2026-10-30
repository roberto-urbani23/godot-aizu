class_name AizuUtility extends Node

static func find_node_recursive(node: Node, script: Script) -> Node:
	var current: Node = node

	while current:
		var result = _find_node_recursive(current, script)
		if result:
			return result

		current = current.get_parent()

	return null


static func _find_node_recursive(node: Node, script: Script) -> Node:
	if node.get_script() == script:
		return node

	for child in node.get_children():
		var result = _find_node_recursive(child, script)
		if result:
			return result

	return null
