@tool
extends RefCounted
## Base of the steps of the wizard. A step builds its controls once, takes what it
## shows from the model when it is entered and writes what was chosen back when it is
## left, so going back and forth keeps the choices.

var title: String = ""
var model: RefCounted
var scan: RefCounted


## Builds the controls of the step. Called once.
func build() -> Control:
	return Control.new()


## Called every time the step is shown.
func enter() -> void:
	pass


## Called when the player leaves the step, backwards or forwards.
func leave() -> void:
	pass


## Why the player cannot go on from this step, empty if they can.
func problem() -> String:
	return ""
