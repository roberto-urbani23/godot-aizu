class_name AizuOutlineOverlay extends SubViewportContainer
## Draws the outlines in their own viewport, on top of the world viewport.
##
## Anything in the world viewport goes through your post-process (pixelation,
## dithering, palette). The outlines are rendered here instead, so they stay sharp
## and keep their real color. [AizuInteractableOutline] puts its meshes on
## [constant AizuInteractableOutline.VISUAL_LAYER]; this overlay is the only
## camera that sees that layer.
##
## Scene setup:
## [codeblock]
## OutlineOverlay (this, SubViewportContainer, mouse_filter = Ignore)
##   SubViewport (transparent_bg = true, same size as the world viewport)
##     Camera3D (cull_mask = only layer 19, physics_interpolation_mode = Off)
## [/codeblock]
## The world camera must NOT render layer 19.

## Camera of the world viewport. The overlay camera copies it every frame.
@export var source_camera: Camera3D
## Camera inside this overlay's SubViewport.
@export var overlay_camera: Camera3D

const _WARM_UP_FRAMES := 3


func _ready() -> void:
	# Outline shaders compile while the overlay is hidden, so the first
	# outline shown during play does not hitch.
	visible = false
	for i in _WARM_UP_FRAMES:
		await get_tree().process_frame
	visible = true


func _process(_delta: float) -> void:
	overlay_camera.global_transform = source_camera.get_global_transform_interpolated()
	overlay_camera.fov = source_camera.fov
	overlay_camera.near = source_camera.near
	overlay_camera.far = source_camera.far
