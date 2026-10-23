shader_type canvas_item;
render_mode unshaded;
// The rear half of the bottle-foot ellipse belongs behind the liquid.
// Original texture is preserved; side walls, the front base rim and all other
// reflections stay on the foreground glass pass.
uniform bool rear_pass = false;
void fragment() {
	vec4 glass = texture(TEXTURE, UV);
	float horizontal = 1.0 - smoothstep(0.145, 0.205, abs(UV.x - 0.5));
	float vertical = smoothstep(0.826, 0.842, UV.y) * (1.0 - smoothstep(0.868, 0.883, UV.y));
	float rear_ellipse = horizontal * vertical;
	glass.a *= rear_pass ? rear_ellipse : (1.0 - rear_ellipse);
	COLOR = glass;
}
