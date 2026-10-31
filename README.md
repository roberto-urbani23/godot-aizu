# godot-aizu

Interaction system for Godot 4. Detects when the player is near or targeting an interactable zone, then fires a signal when the player triggers it.

The addon ships scripts only. Create your own scenes in your game and attach the provided scripts.

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

### Zone exports

| Export | Type | Description |
|---|---|---|
| `interaction_trigger` | AizuInteractionTrigger | defines the input that fires the zone |
| `is_detectable` | bool | whether detectors report this zone |
| `is_interactable` | bool | whether input can trigger `interacted` |
| `interaction_text` | String | optional label text, supports `{interaction_key}` |
| `redetect_on_unlock` | bool | auto-recheck detectors after unlock |

### Zone flags

| | is_detectable | is_interactable |
|---|---|---|
| PROXIMITY detector reports it | yes | no |
| TARGET detector reports it | yes | yes (either flag is enough) |
| Input triggers `interacted` | no | yes |

### Lock and unlock

Call `lock()` to disable all detection and interaction for a zone. It emits `zone_lost` for every detector currently tracking it, so all UI components update automatically.

Call `unlock()` to restore the previous state. Detectors recheck the zone automatically.

```gdscript
zone.lock()
await get_tree().create_timer(2.0).timeout
zone.unlock()
```

## Detecting zones

Add an `AizuInteractionDetector` subclass to your player character. Two are provided:

`AizuAreaDetector` uses an `Area3D` for proximity detection. Assign any `Area3D` node to its `area` export.

`AizuShapecastDetector` uses a `ShapeCast3D` for line-of-sight targeting. Assign any `ShapeCast3D` node to its `shapecast` export.

Each detector has a `detection_mode` export:

- `PROXIMITY`: contributes to the nearby zones list
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

To filter by detector type, check `detection_mode` in the callback:

```gdscript
func _on_zone_found(detector: AizuInteractionDetector, zone: AizuInteractionZone) -> void:
    if detector.detection_mode != AizuInteractionDetector.DetectionMode.PROXIMITY:
        return
    print("proximity only: ", zone.name)
```

Connect to `interacted` on a specific zone:

```gdscript
@export var my_zone: AizuInteractionZone

func _ready() -> void:
    my_zone.interacted.connect(_on_interacted)

func _on_interacted() -> void:
    print("triggered!")
```

## UI scripts

These scripts have no bundled scenes. Create a scene in your game, set the node type, and attach the script.

**AizuProximitySprite** (Sprite3D): shows when the player enters proximity, hides when targeting. Fades in/out automatically.

**AizuReticle** (TextureRect): switches between `texture_active` and `texture_inactive` based on whether a TARGET zone is in range.

**AizuInteractionText** (Label): shows `zone.interaction_text` formatted with the actual key when a TARGET zone is found. Hidden when `interaction_text` is empty.

**AizuInteractableOutline** (Node): applies a `ShaderMaterial` as `material_overlay` on one or more meshes when a TARGET zone is found. Warms up the shader on frame 1 to avoid first-time lag.

```gdscript
# AizuInteractableOutline exports
@export var mesh_to_outlines: Array[MeshInstance3D]
@export var outline_material: ShaderMaterial
@export var zones: Array[AizuInteractionZone]
```

## AizuInteractionTrigger

A `Resource` that defines what input fires the interaction. Set either:

- `interaction_input_action_name`: an input action from your project's Input Map
- `input_override`: a specific `InputEvent`

Use `get_key_as_string()` to get the key name as a string. Use `format_text(text)` to replace `{interaction_key}` in a string:

```gdscript
zone.interaction_trigger.format_text("Press {interaction_key} to open")
# returns "Press E to open"
```

## Collision layers

The addon uses layers 2 and 3 internally. Do not assign other physics objects to these layers.

| Layer | Bitmask | Used for |
|---|---|---|
| 2 | 2 | AizuInteractionZone |
| 3 | 4 | Detector areas |
