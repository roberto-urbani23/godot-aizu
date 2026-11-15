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

1. Enable the plugin in Project > Project Settings > Plugins. It registers two autoloads: `AizuInteractionDetectorBus` and `AizuInputDevice`.
2. Add an `AizuInteractionManager` (`Node`) anywhere in your scene tree. One is enough, for example under the player. Set its `interactor` to the player and its `detectors` to the detectors you add in the next step.
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
| `interaction_trigger` | AizuInteractionTrigger | input of the primary action |
| `display_name` | String | optional name of the object ("Door", "Old merchant"). The prompt shows it as its first line while the zone is targeted, even if the zone has no action to offer. Goes through `tr()` |
| `interaction_text` | String | prompt text of the primary action, supports `{interaction_key}` |
| `actions` | Array[AizuInteractionAction] | more actions, each with its own input and text, see [Several actions](#several-actions-on-one-zone) |
| `is_detectable` | bool | whether detectors report this zone |
| `is_interactable` | bool | whether input can trigger `interacted` |
| `redetect_on_unlock` | bool | auto-recheck detectors after unlock |
| `enabled` | bool | master switch. When false the zone is locked |
| `linked_zones` | Array[AizuInteractionZone] | zones that follow this one when it is enabled, disabled, locked or suspended |

### Several actions on one zone

The primary action is `interaction_trigger` plus `interaction_text`: enough for most objects, and `interacted` fires when it is triggered. For more, add `AizuInteractionAction` resources to `actions`.

| Action member | Description |
|---|---|
| `id` | name to tell actions apart |
| `trigger` | the input that fires it |
| `text` | prompt row, supports `{interaction_key}` |
| `enabled` | a disabled action is not shown and cannot fire |

The prompt texts go through `tr()`: write them in English, that text is the translation key, and add the other languages to your translation file. English needs no entry. Placeholders such as `{interaction_key}` stay in the translated text.

Every action that fires emits `action_triggered(action, by)` on the zone, the primary one included. `by` is the `interactor` of the manager.

```gdscript
func _on_action_triggered(action: AizuInteractionAction, by: Node) -> void:
	match action.id:
		&"open":
			toggle()
		&"lock":
			locked = not locked
```

The prompt shows one row per enabled action: `[E] Open`, `[F] Lock`. If two actions use the same input, the first one wins (the primary action comes first).

Changing `interaction_text`, the actions or their `enabled` flag while the zone is targeted redraws the prompt: no need to lock and unlock the zone to refresh it. An action resource is shared by every scene that uses it: make it unique in the Inspector if instances need to change it separately.

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
| `interactor` | node passed as `by` when an action fires, usually the player |
| `detectors` | detectors that get suspended while the manager is locked |
| `set_lock(reason, on)` / `is_locked()` | lock the interaction for a named reason |
| `set_locked(on)` | `set_lock` with a single reason, handy to connect to a signal |
| `lock_changed(is_locked)` | signal |
| `held` / `is_holding()` | the grabbable being carried, or null, see [Grabbing](#grabbing-and-throwing) |
| `grab(grabbable)` / `drop()` / `throw()` | grab, let go and throw by code |
| `grab_point`, `throw_trigger`, `base_throw_force`, `grab_stiffness`, `max_grab_speed`, `drop_text`, `throw_text` | grab settings, see [Grabbing](#grabbing-and-throwing) |
| `grabbed`, `released`, `thrown`, `held_changed` | signals |

On every unhandled input event it goes through the actions of `current_target` and fires the first enabled one whose input matches, then marks the event as handled.

### Locking the interaction

`set_lock(&"menu", true)` stops the interaction, for example during a menu or a cutscene. Several reasons can be active at once and the interaction comes back when all are released. While locked the manager ignores input and suspends the detectors in `detectors`: they report their zones as lost, so the reticle, the prompt, the proximity sprites and the outlines all hide. Zones come back when the lock ends.

If your player has its own lock, connect its signal to `set_locked` from the scene or from a script of your game: this addon does not know about any player controller.

```
player.lock_changed(is_locked)  ->  AizuInteractionManager.set_locked(is_locked)
```

## Grabbing and throwing

A player can carry a `RigidBody3D` around and throw it. Add an `AizuGrabbable` (`Node`) next to the body, wire its exports and give the zone an action that grabs.

```
Crate (RigidBody3D)
  CollisionShape3D
  AizuInteractionZone (Area3D)     <- primary action grabs
    CollisionShape3D
  AizuGrabbable (Node)             <- body: Crate, zone: the zone above
```

| `AizuGrabbable` export | Description |
|---|---|
| `body` | the body carried. Frozen bodies cannot be grabbed |
| `zone` | the zone that offers the grab, usually a child of the body |
| `grab_action_id` | id of the action of the zone that grabs. `primary` (the primary action) by default |
| `grab_handle` | optional `Marker3D` child of the body: the point carried to the grab point, for example the tail of a fish. Without it the body is carried by its center of mass |
| `kinds` | `AizuItemKind` resources: what this grabbable is for the receivers it can be used on, see [Using a held item](#using-a-held-item-on-something) |
| `continuous_collision` | on by default: turns on continuous collision detection on the body from the grab until it rests after being let go, so a small or thin body (a knife, a key) thrown fast does not go through the floor |
| `throw_force_multiplier` | multiplies the base throw force of the manager. 1 changes nothing |

Signals `grabbed`, `released` (drop or throw) and `thrown` (only a throw, right after `released`) fire on the grabbable and on the manager. `used_on(receiver, use)` fires on the grabbable only, see below.

On the `AizuInteractionManager`, set `grab_point` to a `Marker3D`, usually a child of the camera a little in front of it. It is where the body is carried and the direction of a throw (its -Z axis).

| Manager export | Description |
|---|---|
| `grab_point` | where the held body is carried, and the throw direction |
| `throw_trigger` | input that throws. Dropping uses the input that grabbed |
| `base_throw_force` | impulse of a throw. Multiplied by the `throw_force_multiplier` of the grabbable. As an impulse it depends on the mass: a body of 1 kg leaves at this speed in m/s |
| `grab_stiffness` | how hard the body is pulled to the grab point, in 1/s |
| `max_grab_speed` | speed limit of that pull, in m/s (and in radians per second for the turn) |
| `drop_text`, `throw_text` | rows of the prompt while holding. They go through `tr()` |

How it works:

- The body keeps real physics while held: the manager sets its velocity every physics frame to pull its center of mass to the grab point, so it collides with the world and pushes other bodies. Gravity is off while held. It keeps the orientation it had at the grab, relative to the grab point, so it turns with the camera. It is never dropped for being far: it keeps pulling.
- It does not collide with the `interactor` while held, when the interactor is a physics body.
- While holding, the zone of the body is locked and the body and its zone are ignored by the detectors, so they never hide what the player aims at. Other zones are active only if something can be done with what is held, see [below](#using-a-held-item-on-something). The input of the grab action drops the body, which keeps its velocity. `throw_trigger` throws it.
- A lock of the manager (`set_lock`) drops the body. A body freed while held is forgotten.
- Set the `manager` export of `AizuInteractionPrompt` or `AizuInteractionText` and they show the drop and throw rows while something is held.

## Using a held item on something

A knife on a piece of meat, a key on a door: add an `AizuItemReceiver` (`Node`) to the object that receives the item. The grabbable and the receiver never know each other: the link is a resource, an `AizuItemKind` (a `.tres` file you create once per kind, for example `knife.tres`, `red_key.tres`). No strings, no enums.

1. Give the grabbable the kinds it is in `kinds` (a grabbable can have several).
2. On the receiver, set `zones` to the zones of the object (both sides of a door, for example) and add one `AizuItemUse` to `uses` for every kind it accepts.

| `AizuItemUse` | Description |
|---|---|
| `kind` | the `AizuItemKind` accepted |
| `trigger`, `text`, `enabled`, `id` | as in an action of a zone: the input, the prompt text (with `{interaction_key}`) and an on/off switch |

While the player holds a grabbable:

- a zone is active only if one of its receivers has an enabled use for a kind held. All the other zones are not detected: no reticle, outline or prompt, and their own actions cannot be triggered;
- an active zone shows the prompts of those uses instead of its own actions, then the drop and throw rows;
- if the input of a use is also the input of drop or throw, the use wins while the player aims at the zone, and the prompt does not show the row it replaces. Aiming elsewhere, the input drops or throws as usual.

With nothing held, a zone behaves as usual. A zone that only has receivers (no primary action and no `actions`) is not detected at all.

Two signals, one for each side. Connect them from the script of each object:

| Signal | On | Use |
|---|---|---|
| `used(use, grabbable, by)` | `AizuItemReceiver` | the script of the meat or the door reacts (cut, unlock) |
| `used_on(receiver, use)` | `AizuGrabbable` | the script of the knife or the key decides what happens to it: a key frees itself, a knife does nothing and stays in the hands |

Nothing happens to the held item by itself: if nobody listens to `used_on`, it stays in the hands.

```
Meat (Node3D, script connects Receiver.used)
  AizuInteractionZone (Area3D)        <- no primary action: only the receiver uses it
  AizuItemReceiver                    <- zones: [the zone], uses: [knife -> "{interaction_key} Cut"]
```

Set `enabled` of a use to turn it off, for example once the meat is all cut. Uses are resources shared by every instance of a scene: make them unique if instances differ.

## Listening for events

Connect to `AizuInteractionDetectorBus` from anywhere:

| Signal | Emitted when |
|---|---|
| `zone_found(detector, zone)` | a detector starts reporting a zone |
| `zone_lost(detector, zone)` | a detector stops reporting a zone, or the zone is locked |
| `zone_locked(zone)` | a zone became locked |
| `grab_requested(grabbable, by)` | the grab action of a grabbable was triggered. The manager whose `interactor` is `by` grabs it |

The bus also keeps `is_holding` and `held_kinds`, set by the manager while it holds a grabbable. The zones read them. They are global: with two managers in one game (split screen) they would interfere.
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

| Export | Description |
|---|---|
| `active_scale` | scale while something is targeted. 1 means no size change |
| `transition_seconds` | time of the change. 0 changes at once |

```
Reticle (TextureRect, centered on screen)   script = AizuReticle
```

### AizuInteractionText (Label)

Hidden by default. Shows `zone.interaction_text` when a `TARGET` detector finds a zone, with `{interaction_key}` replaced by the real key. Stays hidden if the zone has no trigger or the text is empty.

With `interaction_text = "Press {interaction_key} to open"` and the action bound to E, it shows `Press E to open`.

Place it where you want it on screen, for example just to the right of the reticle. If the zone has a `display_name`, it is the first line. Set the font and size on the label itself.

Set its optional `manager` export to show the drop and throw rows while the player holds something.

### AizuInteractionPrompt (RichTextLabel)

Like `AizuInteractionText`, but `{interaction_key}` can be a glyph drawn inside the text, and every enabled action of the zone gets a row. With the primary action `interaction_text = "{interaction_key} Open"` bound to E, it shows the E glyph followed by `Open`.

| Export | Description |
|---|---|
| `glyph_set` | optional [`AizuGlyphSet`](#glyphs). If null, or if an input has no glyph, the key name is written as text instead |
| `glyph_height` | height of the glyph in pixels |
| `fade_in_seconds` | fade in time. 0 shows the prompt at once |
| `fade_out_seconds` | fade out time, short by default. 0 hides it at once |
| `manager` | optional. While it holds something the prompt shows the drop and throw rows, and the name of the zone it aims at |

The rows follow the zone while it is targeted: a change of text, of actions or of the device in use (keyboard or gamepad) redraws them. Use it instead of `AizuInteractionText`, not together with it. The text is centered, so place the node where you want it and give it a width.

### AizuProximitySprite (Sprite3D)

A hint icon in the world. It starts hidden, fades in when a `PROXIMITY` detector finds its zone, fades out while a `TARGET` detector has it targeted (the reticle takes over), and fades back in if the player stays near but looks away.

| Export | Description |
|---|---|
| `zone` | the zone it reacts to. If null it reacts to every zone |
| `glyph_set` | optional [`AizuGlyphSet`](#glyphs). If set, the sprite shows the glyph of the input that fires the zone |
| `render_in_overlay` | draw the sprite on the overlay layer, outside a post-processed world view |
| `occlusion_mask` | physics layers that hide the sprite while they are between the camera and it. 0 turns it off |

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

#### Glyphs

With a `glyph_set` the sprite shows the key or button that fires the zone (an `F` for a zone bound to F) instead of a fixed texture. The addon ships no glyphs, so you build the set from whatever icon pack your game uses. The same set also feeds `AizuInteractionPrompt`.

1. Create an `AizuGlyphSet` resource.
2. Add one `AizuGlyph` per input: set `key`, `mouse_button`, `joypad_button` or `joypad_axis` (triggers), and the `texture`.
3. Assign the set to the `glyph_set` of every `AizuProximitySprite` and `AizuInteractionPrompt` that should show glyphs.

If the zone's input has no entry in the set, that sprite never shows and nothing is reported as an error. The prompt writes the key name instead, so a row is never lost. If the action has several events (keyboard and gamepad), the autoload `AizuInputDevice` tells which device the player used last, and the glyph of that device is used first. Physical-only keys from the Input Map are shown as the key printed on the player's layout.

The choice is per sprite: leave `glyph_set` empty on a sprite to keep its own `texture`, for example a generic hint for a zone that has no trigger. One set resource can be shared by all sprites and prompts.

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

## Editor helper

Select an `AizuInteractionZone` in the editor: the Inspector has a **Create shape from mesh** button. It adds a box `CollisionShape3D` that fits all the meshes and CSG shapes next to the zone (under the zone's parent), with a small margin. It can be undone, and it does nothing if the zone already has a shape.

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
| Key does nothing | no `AizuInteractionManager` in the scene, the manager is locked, or the zone has no `interaction_trigger` and no enabled action |
| A row is missing from the prompt | the action is disabled, has no text, or has no trigger |
| The prompt shows the key name, not the glyph | the `glyph_set` is empty on the prompt, or has no glyph for that input |
| Outline never shows | no `AizuOutlineOverlay` in the scene, or the world camera still renders layer 19 |
| Outline is pixelated or dithered | the meshes are outlined in the world viewport. Check the overlay setup |
| World looks different after setting up the overlay | another node uses the layer that the world camera now skips |
| Icon or text visible when it should not be | the zone is not locked. Set `enabled = false` or call `lock()` |
| One side of an object keeps its prompt after interacting | the zones are not linked both ways in `linked_zones` |
