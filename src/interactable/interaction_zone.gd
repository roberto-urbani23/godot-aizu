class_name AizuInteractionZone extends Area3D

const COLLISION_LAYER := 2

signal interacted

@export var interaction_trigger: AizuInteractionTrigger
@export var is_interactable: bool = true
@export var is_detectable: bool = true
@export var redetect_on_unlock: bool = true

var _locked_detectable: bool
var _locked_interactable: bool


func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = 0


func lock() -> void:
	_locked_detectable = is_detectable
	_locked_interactable = is_interactable
	is_detectable = false
	is_interactable = false
	AizuInteractionDetectorBus.zone_locked.emit(self)


func unlock() -> void:
	is_detectable = _locked_detectable
	is_interactable = _locked_interactable
	if not redetect_on_unlock:
		return
	for det in get_tree().get_nodes_in_group("aizu_detectors"):
		(det as AizuInteractionDetector).recheck_zone(self)
