class_name AizuItemUse extends AizuInteractionAction
## One rule of an [AizuItemReceiver]: a held item of this kind can be used on the
## receiver, with this input and this prompt text. It is an action, so [member id],
## [member trigger], [member text] and [member enabled] work as in a zone.
##
## The resource is shared by every scene that uses it. Make it unique (right
## click in the Inspector) if instances need to enable or disable it separately.

## The item kind this rule accepts.
@export var kind: AizuItemKind
