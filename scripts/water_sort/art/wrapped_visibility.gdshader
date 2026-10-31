shader_type canvas_item;
render_mode unshaded;
uniform sampler2D visibility_mask : filter_nearest, repeat_disable;
uniform bool covered = false;
uniform vec2 native_origin = vec2(0.0);
uniform vec2 native_scale = vec2(1.0);
void fragment() {
    // Fragment COLOR already includes this sprite's texture and modulation.
    vec4 original = COLOR;
    vec2 pixel = native_origin + UV / TEXTURE_PIXEL_SIZE * native_scale;
    if (covered) {
        float inside = step(0.0,pixel.x)*step(0.0,pixel.y)*step(pixel.x,165.0)*step(pixel.y,410.0);
        original.a *= texture(visibility_mask,pixel/vec2(165.0,410.0)).a * inside;
    }
    COLOR = original;
}
