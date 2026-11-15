extends Node

signal zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone)
signal zone_lost(detector: AizuInteractionDetector, zone: AizuInteractionZone)

signal zone_locked(zone: AizuInteractionZone)
signal zone_unlocked(zone: AizuInteractionZone)

## A grabbable asks to be grabbed by [param by], the interactor of a manager.
signal grab_requested(grabbable: AizuGrabbable, by: Node)

## True while a manager holds a grabbable. Zones read it to tell if they are of
## use: with something held, only zones with an item use for it are active.
var is_holding: bool = false
## Item kinds of the grabbable held, empty when nothing is held.
var held_kinds: Array[AizuItemKind] = []


## Called by the manager when it grabs a grabbable.
func set_held(kinds: Array[AizuItemKind]) -> void:
	is_holding = true
	held_kinds = kinds


## Called by the manager when it lets the grabbable go.
func clear_held() -> void:
	is_holding = false
	held_kinds = []
