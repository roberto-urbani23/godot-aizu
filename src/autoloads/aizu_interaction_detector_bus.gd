extends Node

signal zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone)
signal zone_lost(detector: AizuInteractionDetector, zone: AizuInteractionZone)

signal zone_locked(zone: AizuInteractionZone)
signal zone_unlocked(zone: AizuInteractionZone)
