class_name AizuTween


static func fade_in(node: Node, tween: Tween, duration: float = 0.2) -> Tween:
	if tween:
		tween.kill()
	node.visible = true
	var t := node.create_tween()
	t.tween_property(node, "modulate:a", 1.0, duration)
	return t


static func fade_out(node: Node, tween: Tween, duration: float = 0.2) -> Tween:
	if tween:
		tween.kill()
	var t := node.create_tween()
	t.tween_property(node, "modulate:a", 0.0, duration)
	t.tween_callback(func(): node.visible = false)
	return t
