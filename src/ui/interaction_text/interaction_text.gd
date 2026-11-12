class_name AizuInteractionText extends Label
## Text prompt of the targeted zone, one line per action, with
## [code]{interaction_key}[/code] replaced by the key name. See
## [AizuInteractionPrompt] for glyphs instead of key names.

var _zone: AizuInteractionZone
var _refresh_queued: bool = false


func _ready() -> void:
	visible = false
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)


func _on_zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	_forget_zone()
	_zone = zone
	_zone.prompt_changed.connect(_queue_refresh)
	_queue_refresh()


func _on_zone_lost(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
	if detector.detection_mode != AizuInteractionDetector.DetectionMode.TARGET:
		return
	if zone != _zone:
		return
	_forget_zone()
	visible = false


func _forget_zone() -> void:
	if is_instance_valid(_zone) and _zone.prompt_changed.is_connected(_queue_refresh):
		_zone.prompt_changed.disconnect(_queue_refresh)
	_zone = null


# Several changes in one frame are drawn once, at the end of the frame, from the
# final state.
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_instance_valid(_zone):
		return
	var lines := PackedStringArray()
	if _zone.can_be_triggered():
		for action in _zone.get_actions():
			if not action.can_trigger():
				continue
			var line := action.trigger.format_text(action.text)
			if not line.is_empty():
				lines.append(line)
	text = "\n".join(lines)
	visible = not lines.is_empty()
