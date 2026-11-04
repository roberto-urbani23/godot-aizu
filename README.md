# godot-aizu

Interaction system for Godot 4. Detects when the player is near or targeting an interactable zone, then fires a signal when the player triggers it.

The addon ships scripts and two reticle textures. Create your own scenes in your game and attach the provided scripts.

## How it works

```
Detector (on the player)  ->  Bus  ->  Manager / UI scripts
        finds a zone                    react to it

Manager  ->  zone.interacted  ->  your code
        input matches the zone trigger
```

- An `AizuInteractionZone` marks something the player can interact with.
- An `AizuInteractionDetector` on the player finds zones and reports them on `AizuInteractionDetectorBus`.
- `AizuInteractionManager` picks the zone being targeted and emits its `interacted` signal when the input matches.
- UI scripts listen to the bus and show or hide themselves.

## Setup

1. Enable the plugin in Project > Project Settings > Plugins. It registers the `AizuInteractionDetectorBus` autoload.
2. Add an `AizuInteractionManager` (`Node`) anywhere in your scene tree. One is enough, for example under the player.
3. Add detectors to the player (see [Detecting zones](#detecting-zones)).
4. Add zones to the objects (see [Making something interactable](#making-something-interactable)).

## Making something interactable

Add an `AizuInteractionZone` (extends `Area3D`) as a child of your object. Give it a `CollisionShape3D`. Set `interaction_trigger` to an `AizuInteractionTrigger` resource with your input action.

```
Chest (Node3D)
  MeshInstance3D
  AizuInteractionZone (Area3D)
    CollisionShape3D
```

The zone sets its own collision layer and mask. You do not need to set them by hand.

React to the interaction by connecting to `interacted`:

```gdscript
extends Node3D

@export var zone: AizuInteractionZone

func _ready() -> void:
    zone.interacted.connect(_on_interacted)

func _on_interacted() -> void:
    print("chest opened")
```

### Zone exports

| Export | Type | Description |
|---|---|---|
| `interaction_trigger` | AizuInteractionTrigger | defines the input that fires the zone |
| `is_detectable` | bool | whether detectors report this zone |
| `is_interactable` | bool | whether input can trigger `interacted` |
| `interaction_text` | String | optional label text, supports `{interaction_key}` |
| `redetect_on_unlock` | bool | auto-recheck detectors after unlock |
| `enabled` | bool | master switch. When false the zone is locked |
| `linked_zones` | Array[AizuInteractionZone] | zones that follow this one when it is enabled, disabled, locked or suspended |

### Zone flags

| | is_detectable | is_interactable |
|---|---|---|
| PROXIMITY detector reports it | yes | no |
| TARGET detector reports it | yes | yes (either flag is enough) |
| Input triggers `interacted` | no | yes |

A zone with `is_detectable` on and `is_interactable` off is only a hint: the proximity UI shows, but pressing the key does nothing.

### Lock and unlock

A locked zone is not detected, cannot be triggered and shows no UI. The zone keeps its `is_detectable` and `is_interactable` values: locking never rewrites them.

| Member | Description |
|---|---|
| `enabled` | master switch. Set it to false to lock the zone, true to unlock it |
| `lock()` / `unlock()` | lock or unlock by hand. Calling them twice does nothing |
| `lock_for(seconds)` | locks for a while, then restores it. Overlapping calls are safe: the zone unlocks after the last one ends |
| `is_locked()` | whether the zone is locked for any reason |

A zone stays locked while any of `enabled`, `lock()` or `lock_for()` asks for it. Calling `unlock()` does not override `enabled = false`.

Locking emits `zone_lost` for every detector tracking the zone, so all UI components update automatically. Unlocking makes the detectors recheck the zone (unless `redetect_on_unlock` is off), so the UI comes back if the player is still in range.

```gdscript
zone.lock_for(2.0)
```

### Objects with several zones

Link the zones to each other with `linked_zones`, in both directions. Everything done to one of them, `enabled`, `lock()`, `unlock()` and `lock_for()`, is applied to the others too.

```
Door
  DoorMesh
    FrontZone (AizuInteractionZone)   linked_zones = [../BackZone]
    BackZone  (AizuInteractionZone)   linked_zones = [../FrontZone]
```

Use it when one object has an icon or a trigger on each side. Without the link, using one side would leave the other side's prompt on screen.

Setting `enabled` in the inspector is applied to the linked zones when the scene starts. Setting it from code later is applied to them immediately.

### Example: a door

Connect the `interacted` signal of every zone to the door script in the scene, so the script does not need a reference to each zone. It only needs one zone to switch and suspend them all.

```gdscript
class_name Door extends Node3D

@export var can_interact: bool = true:
    set(value):
        can_interact = value
        if _zone:
            _zone.enabled = value

@onready var _zone: AizuInteractionZone = $DoorMesh/FrontZone

func _ready() -> void:
    _zone.enabled = can_interact

# Connected to FrontZone.interacted and BackZone.interacted in the scene.
func _on_interacted() -> void:
    toggle()
    _zone.lock_for(1.5) # no prompt while the door moves
```

With `can_interact` off the door shows nothing and ignores the key. Turning it on at runtime makes the prompts come back.

## Detecting zones

Add an `AizuInteractionDetector` subclass to your player. Two are provided.

| Detector | Export | Uses |
|---|---|---|
| `AizuAreaDetector` | `area` (Area3D) | overlap, for proximity |
| `AizuShapecastDetector` | `shapecast` (ShapeCast3D) | line of sight, for targeting |

The detector configures the node you assign: layers and mask. Assign any `Area3D` or `ShapeCast3D` of your player.

`AizuShapecastDetector` targets only the **first** thing the cast touches. Its `occluder_mask` export sets which physics layers block the view (default: layer 1). If a blocker, such as a wall or the door itself, is closer than a zone, nothing is targeted. Locked zones do not block.

Both share these exports:

| Export | Description |
|---|---|
| `detection_mode` | `PROXIMITY` or `TARGET` |
| `priority` | when several `TARGET` detectors find a zone, the highest wins |

- `PROXIMITY`: contributes to the nearby zones list. Drives hint UI such as `AizuProximitySprite`.
- `TARGET`: sets `current_target` on the manager, which drives the real interaction. Drives `AizuReticle` and `AizuInteractionText`.

A character typically has both: an `AizuAreaDetector` in PROXIMITY mode and an `AizuShapecastDetector` in TARGET mode.

```
Player (CharacterBody3D)
  AizuInteractionManager
  AizuAreaDetector          area = ../DetectionArea, mode = PROXIMITY
  AizuShapecastDetector     shapecast = ../Head/InteractionShapeCast, mode = TARGET
  DetectionArea (Area3D)
    CollisionShape3D
  Head (Node3D)
    InteractionShapeCast (ShapeCast3D)
```

The detection mode is easy to forget: a shapecast detector left on `PROXIMITY` finds zones but never becomes the target, so the reticle and the key do nothing.

## AizuInteractionManager

Picks the targeted zone and forwards the input.

| Member | Description |
|---|---|
| `current_target` | zone currently targeted, or null |
| `nearby_zones` | zones reported by any detector that are detectable |
| `target_changed(zone)` | signal |
| `nearby_changed(zones)` | signal |

On every unhandled input event it asks `current_target.interaction_trigger` whether the event matches. If it does and the zone is interactable, it emits `interacted` on the zone and marks the event as handled.

## Listening for events

Connect to `AizuInteractionDetectorBus` from anywhere:

| Signal | Emitted when |
|---|---|
| `zone_found(detector, zone)` | a detector starts reporting a zone |
| `zone_lost(detector, zone)` | a detector stops reporting a zone, or the zone is locked |
| `zone_locked(zone)` | a zone became locked |
| `zone_unlocked(zone)` | a zone became unlocked |

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

## UI scripts

These scripts have no bundled scenes. Create a scene in your game, set the node type, and attach the script.

### AizuReticle (TextureRect)

Switches between `texture_active` and `texture_inactive` when a `TARGET` detector finds or loses a zone. Textures are in `src/assets/images/`.

```
Reticle (TextureRect, centered on screen)   script = AizuReticle
```

### AizuInteractionText (Label)

Hidden by default. Shows `zone.interaction_text` when a `TARGET` detector finds a zone, with `{interaction_key}` replaced by the real key. Stays hidden if the zone has no trigger or the text is empty.

With `interaction_text = "Press {interaction_key} to open"` and the action bound to E, it shows `Press E to open`.

Place it where you want it on screen, for example just to the right of the reticle. Set the font and size on the label itself.

### AizuProximitySprite (Sprite3D)

A hint icon in the world. It starts hidden, fades in when a `PROXIMITY` detector finds its zone, fades out while a `TARGET` detector has it targeted (the reticle takes over), and fades back in if the player stays near but looks away.

| Export | Description |
|---|---|
| `zone` | the zone it reacts to. If null it reacts to every zone |

Use one sprite per zone when an object has several zones, so each icon sits next to its own interaction point:

```
Door
  DoorMesh
    FrontZone (AizuInteractionZone)
    BackZone (AizuInteractionZone)
    FrontSprite (AizuProximitySprite)   zone = ../FrontZone
    BackSprite (AizuProximitySprite)    zone = ../BackZone
```

Put the zones and the sprites under the node that moves, so they follow it.

If you wrap the sprite in your own scene (for example to add an `AnimationPlayer`), expose a `zone` export on the root and forward it to the sprite in `_ready`. An instanced scene does not let you edit the inner node's exports.

### AizuInteractableOutline (Node)

Outlines one or more meshes while a `TARGET` detector has one of the given zones targeted.

| Export | Description |
|---|---|
| `mesh_to_outlines` | meshes that get the outline |
| `outline_material` | the `ShaderMaterial` that draws the outline |
| `zones` | zones that trigger the outline |

The outline is not drawn on your meshes. Each mesh gets a hidden copy on visual layer 19 (`AizuInteractableOutline.VISUAL_LAYER`), and that copy is drawn by a separate camera, so the outline is not touched by the post-process of your world viewport (pixelation, dithering, palette).

The copies share the original mesh and `outline_material`, and the depth-only material that hides the inside of the silhouette is created once for the whole game. Assign the **same** `ShaderMaterial` resource (a `.tres` in your project, loaded as an `ext_resource`) to every outline. Never create one per object.

Layer 19 must be free: nothing else in your project can render on it. Check addons that use visual layers (Sky3D's fog mesh uses layer 20).

It needs an `AizuOutlineOverlay` in the scene, see below.

### AizuOutlineOverlay (SubViewportContainer)

Shows the outline copies on top of the world viewport. Add one to the scene that holds your world viewport, after it and before the HUD:

```
Main
  SubViewportContainer          world, with the post-process
    SubViewport
      Player
        Head
          Camera3D              cull_mask: everything except layer 19
  OutlineOverlay                AizuOutlineOverlay, mouse_filter = Ignore
    SubViewport                 transparent_bg = true, same size as the world viewport
      Camera3D                  cull_mask: only layer 19, physics_interpolation_mode = Off,
                                environment: an Environment with background = Clear Color
  HUD
```

| Export | Description |
|---|---|
| `source_camera` | the world camera. The overlay camera copies its transform, `fov`, `near` and `far` every frame |
| `overlay_camera` | the camera inside the overlay's SubViewport |

Layer 19 is `262144` as a cull mask. A camera that renders layers 1 to 18 and 20 is `786431`.

The overlay camera needs its own `Environment` with `background_mode = Clear Color`. Without it the camera uses the world's environment and paints the sky over the whole screen, without the post-process.

The overlay stays hidden for its first 3 frames so the outline shader compiles before the first outline appears.

The overlay only renders the outline copies, so world geometry does not hide the outline. This is fine for objects the player is looking at directly: an object behind a wall is never targeted.

## AizuInteractionTrigger

A `Resource` that defines what input fires the interaction. Set either:

- `interaction_input_action_name`: an input action from your project's Input Map
- `input_override`: a specific `InputEvent`, used instead of the action if set

Use `get_key_as_string()` to get the key name as a string. Use `format_text(text)` to replace `{interaction_key}` in a string:

```gdscript
zone.interaction_trigger.format_text("Press {interaction_key} to open")
# returns "Press E to open"
```

One trigger resource can be shared by several zones.

## Collision layers

The addon uses layers 2 and 3 internally. Do not assign other physics objects to these layers.

| Layer | Bitmask | Used for |
|---|---|---|
| 2 | 2 | AizuInteractionZone |
| 3 | 4 | Detector areas |

## Troubleshooting

| Symptom | Check |
|---|---|
| `Could not find type "Aizu..."` | the editor has not scanned the addon yet. Reload the project |
| Nothing is detected | a detector is missing, or its `area` / `shapecast` export is empty |
| Proximity works, reticle and key do not | the shapecast detector is still on `PROXIMITY` |
| Key does nothing | no `AizuInteractionManager` in the scene, or the zone has no `interaction_trigger` |
| Outline never shows | no `AizuOutlineOverlay` in the scene, or the world camera still renders layer 19 |
| Outline is pixelated or dithered | the meshes are outlined in the world viewport. Check the overlay setup |
| World looks different after setting up the overlay | another node uses the layer that the world camera now skips |
| Icon or text visible when it should not be | the zone is not locked. Set `enabled = false` or call `lock()` |
| One side of an object keeps its prompt after interacting | the zones are not linked both ways in `linked_zones` |
