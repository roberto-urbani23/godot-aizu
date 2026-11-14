shader_type spatial;
render_mode blend_mix, cull_front, unshaded;

uniform vec4 color : source_color = vec4(1,0,0,1);
uniform float size : hint_range(1.0, 1.5, 0.01) = 1.05;
// Set per mesh by AizuInteractableOutline: the shell grows around the middle of
// the mesh, not around its origin, so meshes with an origin at a corner (a door
// on its hinge) are outlined in place.
instance uniform vec3 outline_center = vec3(0.0);

void vertex() {
	VERTEX = outline_center + (VERTEX - outline_center) * size;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
