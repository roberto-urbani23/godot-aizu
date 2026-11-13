class_name AizuInteractionPrompt extends RichTextLabel
## Prompt of the targeted zone: one row per action, with
## [code]{interaction_key}[/code] drawn as a glyph inside the text, for example
## "{interaction_key} Open". Like [AizuInteractionText], but with glyphs.
##
## The rows follow the zone while it is targeted: a change of text, of actions
## or of the device in use (keyboard, gamepad) redraws them.

const _PLACEHOLDER := "{interaction_key}"

## Glyphs for the inputs. If null, or if an input has no glyph, its name is
## written as plain text instead.
@export var glyph_set: AizuGlyphSet
## Height of the inline glyph, in pixels.
@export var glyph_height: int = 28
## Fade in time. 0 shows the prompt at once.
@export_range(0.0, 1.0, 0.01) var fade_in_seconds: float = 0.12
## Fade out time. Short on purpose: the prompt should be gone as soon as the
## player looks away. 0 hides it at once.
@export_range(0.0, 1.0, 0.01) var fade_out_seconds: float = 0.05

var _zone: AizuInteractionZone
var _tween: Tween
var _refresh_queued: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	bbcode_enabled = false
	fit_content = true
	scroll_active = false
	AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)
	AizuInteractionDetectorBus.zone_lost.connect(_on_zone_lost)
	AizuInputDevice.device_changed.connect(_on_device_changed)


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
	_hide_prompt()


func _on_device_changed(_is_gamepad: bool) -> void:
	_queue_refresh()


func _forget_zone() -> void:
	if is_instance_valid(_zone) and _zone.prompt_changed.is_connected(_queue_refresh):
		_zone.prompt_changed.disconnect(_queue_refresh)
	_zone = null


# Several changes in one frame (new text, an action turned off, the zone locked)
# are drawn once, at the end of the frame, from the final state. Drawing each
# one would flash a row that the next change is about to remove.
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_instance_valid(_zone):
		return
	var rows: Array[AizuInteractionAction] = []
	if _zone.can_be_triggered():
		for action in _zone.get_actions():
			if action.can_trigger() and not action.text.is_empty():
				rows.append(action)
	if rows.is_empty():
		_hide_prompt()
		return

	clear()
	push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	for i in rows.size():
		if i > 0:
			newline()
		_add_row(rows[i])
	pop()
	_show_prompt()


func _add_row(action: AizuInteractionAction) -> void:
	var glyph: Texture2D = null
	if glyph_set:
		glyph = glyph_set.get_glyph_for_trigger(action.trigger)

	var parts := tr(action.text).split(_PLACEHOLDER)
	for i in parts.size():
		if i > 0:
			if glyph:
				add_image(glyph, glyph_height, glyph_height)
			else:
				add_text(action.trigger.get_key_as_string())
		if not parts[i].is_empty():
			add_text(parts[i])


func _show_prompt() -> void:
	if _tween:
		_tween.kill()
	visible = true
	if fade_in_seconds <= 0.0:
		modulate.a = 1.0
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade_in_seconds)


func _hide_prompt() -> void:
	if _tween:
		_tween.kill()
	if fade_out_seconds <= 0.0 or not visible:
		modulate.a = 0.0
		visible = false
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, fade_out_seconds)
	_tween.tween_callback(func() -> void: visible = false)
