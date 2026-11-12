class_name AizuInteractionZone extends Area3D

const COLLISION_LAYER := 2

const PRIMARY_ACTION_ID := &"primary"

## Fires when the primary action (interaction_trigger) is triggered. Enough for
## objects with a single thing to do.
signal interacted
## Fires for every action that gets triggered, the primary one included. [param by]
## is the interactor set on the manager, usually the player.
signal action_triggered(action: AizuInteractionAction, by: Node)
## The prompt of this zone changed (text, actions, their availability). UI redraws.
signal prompt_changed

## Input of the primary action. Without it the zone has no primary action.
@export var interaction_trigger: AizuInteractionTrigger:
	set(value):
		interaction_trigger = value
		prompt_changed.emit()
@export var is_interactable: bool = true:
	set(value):
		is_interactable = value
		prompt_changed.emit()
@export var is_detectable: bool = true
@export var redetect_on_unlock: bool = true

## Prompt text of the primary action.
@export var interaction_text: String:
	set(value):
		interaction_text = value
		prompt_changed.emit()

## More actions on top of the primary one, each with its own input and text.
@export var actions: Array[AizuInteractionAction]:
	set(value):
		for action in actions:
			if action and action.changed.is_connected(_on_action_changed):
				action.changed.disconnect(_on_action_changed)
		actions = value
		for action in actions:
			if action:
				action.changed.connect(_on_action_changed)
		prompt_changed.emit()

## Master switch. When false the zone is locked: not detected, not triggerable, no UI.
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		_sync_lock()
		for zone in linked_zones:
			zone.enabled = value

## Zones that follow this one for [member enabled], [method lock_for] and [method lock].
## Link them both ways, e.g. the two sides of a door handle.
@export var linked_zones: Array[AizuInteractionZone]

var _primary: AizuInteractionAction = AizuInteractionAction.new()
var _is_locked: bool = false
var _manual_lock: bool = false
var _suspensions: int = 0


func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = 0
	if not enabled:
		for zone in linked_zones:
			zone.enabled = false


## Every action of the zone, the primary one first. The primary action exists
## only when interaction_trigger is set.
func get_actions() -> Array[AizuInteractionAction]:
	var all: Array[AizuInteractionAction] = []
	if interaction_trigger:
		_primary.id = PRIMARY_ACTION_ID
		_primary.trigger = interaction_trigger
		_primary.text = interaction_text
		all.append(_primary)
	for action in actions:
		if action:
			all.append(action)
	return all


## Fires the signals of an action. Called by the manager.
func trigger_action(action: AizuInteractionAction, by: Node) -> void:
	action_triggered.emit(action, by)
	if action == _primary:
		interacted.emit()


func is_locked() -> bool:
	return _is_locked


func can_be_detected() -> bool:
	return is_detectable and not _is_locked


func can_be_triggered() -> bool:
	return is_interactable and not _is_locked


## Locks the zone and its linked zones until [method unlock] is called.
func lock() -> void:
	_manual_lock = true
	_sync_lock()
	for zone in linked_zones:
		zone._manual_lock = true
		zone._sync_lock()


func unlock() -> void:
	_manual_lock = false
	_sync_lock()
	for zone in linked_zones:
		zone._manual_lock = false
		zone._sync_lock()


## Locks the zone and its linked zones for [param seconds], then restores them.
## Overlapping calls are safe: the zone unlocks after the last one ends.
func lock_for(seconds: float) -> void:
	_suspend(1)
	await get_tree().create_timer(seconds).timeout
	_suspend(-1)


func _on_action_changed() -> void:
	prompt_changed.emit()


func _suspend(delta: int) -> void:
	_suspensions += delta
	_sync_lock()
	for zone in linked_zones:
		zone._suspensions += delta
		zone._sync_lock()


func _sync_lock() -> void:
	var locked := _manual_lock or not enabled or _suspensions > 0
	if locked == _is_locked:
		return
	_is_locked = locked
	if locked:
		AizuInteractionDetectorBus.zone_locked.emit(self)
	else:
		AizuInteractionDetectorBus.zone_unlocked.emit(self)
