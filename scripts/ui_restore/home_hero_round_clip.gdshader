shader_type canvas_item;
uniform vec2 clip_size = vec2(552.0, 535.0);
uniform float corner_radius = 43.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
 vec2 source_size = vec2(1.0) / TEXTURE_PIXEL_SIZE;
 float cover_scale = max(clip_size.x / source_size.x, clip_size.y / source_size.y);
 vec2 sample_uv = (UV - vec2(0.5)) * clip_size / (source_size * cover_scale) + vec2(0.5);
 vec2 q = abs((UV - vec2(0.5)) * clip_size) - clip_size * 0.5 + vec2(corner_radius);
 float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
 float aa = max(fwidth(d), 0.5);
 COLOR = texture(TEXTURE, sample_uv) * vertex_tint;
 COLOR.a *= 1.0 - smoothstep(-aa, aa, d);
}
