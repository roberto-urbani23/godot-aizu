class_name AizuInteractionZone extends Area3D

const COLLISION_LAYER := 2

signal interacted

@export var interaction_trigger: AizuInteractionTrigger
@export var is_interactable: bool = true
@export var is_detectable: bool = true
@export var redetect_on_unlock: bool = true

@export var interaction_text: String

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

var _is_locked: bool = false
var _manual_lock: bool = false
var _suspensions: int = 0


func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = 0
	if not enabled:
		for zone in linked_zones:
			zone.enabled = false


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
