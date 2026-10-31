shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform float active : hint_range(0.0,1.0) = 0.0;
// Candidate appearance, not a measured competitor alpha.
uniform float fill_opacity : hint_range(0.0,0.5) = 0.18;
uniform float rim_opacity : hint_range(0.0,0.5) = 0.28;
void fragment(){
 float d=length(UV-vec2(0.5))*2.0;
 float radius=mix(0.34,0.84,progress);
 float edge=abs(d-radius);
 float rim=1.0-smoothstep(0.025,0.075,edge);
 float face=1.0-smoothstep(radius-0.10,radius+0.025,d);
 float fade=pow(1.0-progress,1.15)*smoothstep(0.0,0.07,progress);
 vec3 tint=mix(vec3(0.46,0.76,0.88),vec3(0.88,0.97,1.0),smoothstep(-0.6,0.6,0.5-UV.y));
 float alpha=(face*fill_opacity+rim*rim_opacity*(1.0-face*fill_opacity))*fade*active;
 COLOR=vec4(tint,alpha);
}
