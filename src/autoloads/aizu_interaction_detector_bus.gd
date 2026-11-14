extends Node

signal zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone)
signal zone_lost(detector: AizuInteractionDetector, zone: AizuInteractionZone)

signal zone_locked(zone: AizuInteractionZone)
signal zone_unlocked(zone: AizuInteractionZone)

## A grabbable asks to be grabbed by [param by], the interactor of a manager.
signal grab_requested(grabbable: AizuGrabbable, by: Node)
