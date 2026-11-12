class_name AizuInteractionAction extends Resource
## One thing the player can do to a zone: its own input, its own prompt text and
## its own on/off switch. A zone can have several, shown as one row each.
##
## The resource is shared by every scene that uses it. Make it unique (right
## click in the Inspector) if instances need to enable or disable it separately.

## Tells the actions of a zone apart in [signal AizuInteractionZone.action_triggered].
@export var id: StringName = &""
@export var trigger: AizuInteractionTrigger:
	set(value):
		trigger = value
		emit_changed()
## Shown in the prompt. [code]{interaction_key}[/code] stands for the input of
## this action, as a glyph or as the key name.
@export var text: String = "":
	set(value):
		text = value
		emit_changed()
@export var enabled: bool = true:
	set(value):
		enabled = value
		emit_changed()


func can_trigger() -> bool:
	return enabled and trigger != null
