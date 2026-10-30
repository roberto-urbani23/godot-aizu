# godot-aizu

Interaction system for Godot 4. Detects when the player is near or targeting an interactable zone, then fires a signal when the player triggers it.

## Setup

Enable the plugin in Project > Project Settings > Plugins.

Add `AizuInteractionManager` as a `Node` anywhere in your scene tree.

## Making something interactable

Add an `AizuInteractionZone` (extends `Area3D`) as a child of your object. Give it a `CollisionShape3D`. Set the `interaction_trigger` export to an `AizuInteractionTrigger` resource with your input action.

```
MyObject (MeshInstance3D)
  AizuInteractionZone (Area3D)
    CollisionShape3D
```

The zone handles collision layers automatically. You do not need to set them by hand.

## Detecting zones

Add an `AizuInteractionDetector` subclass to your player character. Two are provided:

`AizuAreaDetector` uses an `Area3D` for proximity detection. Assign any `Area3D` node to its `area` export.

`AizuShapecastDetector` uses a `ShapeCast3D` for line-of-sight targeting. Assign any `ShapeCast3D` node to its `shapecast` export.

Each detector has a `detection_mode` export:

- `PROXIMITY`: contributes to the nearby zones list (`nearby_changed`)
- `TARGET`: sets `current_target` on the manager, which drives interaction

A character typically has both: one `AizuAreaDetector` in PROXIMITY mode for UI hints, and one `AizuShapecastDetector` in TARGET mode for actual interaction.

## Listening for events

Connect to `AizuInteractionDetectorBus` from anywhere:

```gdscript
func _ready() -> void:
    AizuInteractionDetectorBus.zone_found.connect(_on_zone_found)

func _on_zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
    print("player near: ", zone.name)
```

Connect to `interacted` on a specific zone:

```gdscript
@export var my_zone: AizuInteractionZone

func _ready() -> void:
    my_zone.interacted.connect(_on_interacted)

func _on_interacted() -> void:
    print("triggered!")
```

Or connect to `AizuInteractionManager` signals directly:

```gdscript
@export var manager: AizuInteractionManager

func _ready() -> void:
    manager.nearby_changed.connect(_on_nearby_changed)
    manager.target_changed.connect(_on_target_changed)
```

## Zone flags

`AizuInteractionZone` has two boolean exports:

| | is_detectable | is_interactable |
|---|---|---|
| PROXIMITY detector reports it | yes | no |
| TARGET detector reports it | yes | yes (either flag is enough) |
| Input triggers `interacted` | no | yes |

Use cases:

- `is_detectable = false, is_interactable = true`: player can interact but gets no UI hint
- `is_detectable = true, is_interactable = false`: shows up in proximity UI, but input does nothing
- Both false: invisible to all detectors, no interaction

## AizuInteractionTrigger

A `Resource` that defines what input fires the interaction. Set either:

- `interaction_input_action_name`: an input action from your project's Input Map
- `input_override`: a specific `InputEvent`

## Collision layers

The addon uses layers 2 and 3 internally. Do not assign other physics objects to these layers.

| Layer | Bitmask | Used for |
|---|---|---|
| 2 | 2 | `AizuInteractionZone` |
| 3 | 4 | Detector areas |
