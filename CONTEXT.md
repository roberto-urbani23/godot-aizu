# Aizu

Interaction system for Godot 4: finds what the player can interact with and lets the player act on it.

## Language

**Zone**:
Something the player can interact with, offering one or more actions.
_Avoid_: Interactable, hotspot

**Action**:
One thing the player can do to a zone, with its own input and prompt text.
_Avoid_: Command, verb

**Interactor**:
The one who triggers actions, usually the player.
_Avoid_: Actor, user

**Grab**:
The player takes an object and carries it around, until the player lets go or throws it.
_Avoid_: Pick up, carry, hold

**Grabbable**:
A rigid body that can be grabbed and thrown, marked by the `AizuGrabbable` component. Only rigid bodies for now.
_Avoid_: Throwable, carryable, pickable

**Grab point**:
The spot the grabbed object is carried to and the direction it is thrown along, usually in front of the player's camera.
_Avoid_: Hold point, carry anchor

**Grab handle**:
The spot of a grabbable that is carried to the grab point. Its center of mass unless the grabbable names another spot.
_Avoid_: Grab anchor, pivot

**Throw**:
Releasing a grabbed object with a push. Possible only for a grabbable.
_Avoid_: Launch, toss
