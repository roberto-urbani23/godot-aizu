@tool
extends RefCounted
## The choices of the player of the wizard. The steps write them, the plan reads them.

## True when the object already has nodes of the addon: the wizard edits them.
var is_edit: bool = false
var display_name: String = ""

# Zone
## The input of a trigger that has its own key (not an input action of the project).
const CUSTOM_KEY := "(custom key)"
var input_action: StringName = &""
var prompt_text: String = ""
var create_zone_shape: bool = true
## Name for the copy of the primary trigger, when that trigger is a shared file and the
## input was changed.
var primary_copy_name: String = ""
## Extra actions of the zone: { "id", "input_action", "text" } and, for the ones that are
## already in the scene, also { "ref": Resource, "copy_trigger": String, "copy_resource": String }.
## The input is [constant CUSTOM_KEY] for a trigger that has its own key and is left as it is.
var extra_actions: Array[Dictionary] = []

# Outline
var enable_outline: bool = true

# Grab
var enable_grab: bool = false
var create_body: bool = false
## Kinds picked among the existing ones, as resource paths.
var kind_paths: Array[String] = []
## Names of kinds to create in kinds_folder.
var new_kind_names: Array[String] = []
var kinds_folder: String = "res://"
var create_handle: bool = false
var throw_multiplier: float = 1.0

# Receiver
var enable_receiver: bool = false
## One per kind accepted: { "kind", "input_action", "text", "id" } and, for the ones that
## are already in the scene, also { "ref", "copy_trigger", "copy_resource" } as the extra actions.
## "kind" is a resource path, or "new:<name>" for a kind to create in kinds_folder.
var uses: Array[Dictionary] = []

# Script
var enable_script: bool = false
var script_path: String = ""
var script_class_name: String = ""
