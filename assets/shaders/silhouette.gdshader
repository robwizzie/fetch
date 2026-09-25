shader_type spatial;
// Drawn as a second pass on a dog's materials, only where something stands between the dog and
// the camera: the inverted depth test passes behind walls and fails where the dog is in view.
render_mode unshaded, cull_back, depth_draw_never, depth_test_inverted, blend_mix, shadows_disabled, skip_vertex_transform;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.6);
// The pass is nudged this far toward the camera. A dog's own legs and ears sit closer than this
// to the rest of it, so the dog never shows through itself; a wall or a prop is further.
uniform float self_margin = 0.45;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX.z += self_margin;
}

void fragment() {
	// A soft rim so the shape reads as a body, not a flat sticker.
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = tint.rgb * (0.75 + rim * 0.5);
	ALPHA = tint.a * (0.7 + rim * 0.3);
}
