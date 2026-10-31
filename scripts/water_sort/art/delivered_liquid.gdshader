shader_type canvas_item;
render_mode unshaded;
uniform vec4 pigment : source_color = vec4(0.1,0.5,0.9,1.0);
uniform vec4 top_pigment : source_color = vec4(0.25,0.3,0.95,1.0);
uniform float film_width=0.0;
uniform float film_direction=-1.0;
uniform float film_walls[57];
uniform vec2 gravity_axis = vec2(0.0,1.0);
uniform float top_level = 382.0;
uniform float bottom_level = 410.0;
uniform bool exposed_surface = false;
uniform vec2 surface_center = vec2(82.5,382.0);
uniform vec2 ellipse_radius = vec2(63.0,14.0);
uniform vec2 bottom_center = vec2(82.5,382.0);
uniform float bottom_radius = 63.0;
uniform float incoming_center_x = 82.5;
uniform float incoming = 0.0;
uniform float ripple = 0.0;
uniform float ripple_clock = 0.0;
uniform float surface_slope = 0.0;
uniform bool cover_upper_layers = false;
uniform sampler2D visibility_mask : filter_nearest, repeat_disable;
void fragment() {
	float mask_alpha=texture(TEXTURE,UV).a;
	vec2 pixel=UV/TEXTURE_PIXEL_SIZE;
	vec2 tangent=vec2(gravity_axis.y,-gravity_axis.x);
	float height=dot(pixel,gravity_axis);
	float along=dot(pixel-surface_center,tangent);
	float wave=sin(along*0.042+ripple_clock*22.0)*ripple*1.8+along*surface_slope;
	float top_u=along/max(ellipse_radius.x,1.0);
	// Match the free surface's 16px optical-depth cap. A long chord when
	// sideways must not magnify the internal sag until it hides a whole band.
	float front_arc=min(32.0*ellipse_radius.x/111.0,16.0)*sqrt(max(0.0,1.0-top_u*top_u));
	float bottom_u=dot(pixel-bottom_center,tangent)/max(bottom_radius,1.0);
	float bottom_arc=min(32.0*bottom_radius/111.0,16.0)*sqrt(max(0.0,1.0-bottom_u*bottom_u));
	float edge=top_level+(exposed_surface ? wave : front_arc);
	float lower_edge=bottom_level+bottom_arc;
	float within_band=1.0-smoothstep(lower_edge-0.6,lower_edge+0.6,height);
	float coverage=smoothstep(edge-0.6,edge+0.6,height)*within_band;
	if (film_width>0.0 && pixel.y>=19.0 && pixel.y<75.0) {
		float wall=film_walls[clamp(int(floor(pixel.y))-19,0,55)];
		float u=film_direction<0.0 ? pixel.x-wall : wall-pixel.x;
		float film=smoothstep(-0.25,0.25,u)*(1.0-smoothstep(film_width-0.25,film_width+0.25,u));
		coverage=max(coverage,film);
	}
	// A broad cylindrical light falloff, no repeated vertical pigment bands.
	float side=clamp((pixel.x-16.0)/133.0,0.0,1.0);
	float cylinder=0.96+0.04*sin(side*3.14159265);
	float depth=clamp((height-top_level)/max(bottom_level-top_level,1.0),0.0,1.0);
	vec3 color=pigment.rgb*cylinder;
	if (exposed_surface) {
		vec2 offset=pixel-surface_center;
		vec2 normalized=vec2(along,(dot(offset,gravity_axis)-wave))/ellipse_radius;
		float radius=dot(normalized,normalized);
		float surface=(1.0-smoothstep(0.94,1.04,radius))*within_band;
		if (film_width<=0.0) { coverage=max(coverage,surface); }
		else { surface*=coverage; }
		// Only the top free surface has perspective. Its offset reflection is
		// soft and asymmetric; internal color boundaries have no white rings.
		vec3 top_color=top_pigment.rgb;
		color=mix(color,top_color,surface);
		float stream=(1.0-smoothstep(2.0,6.0,abs(pixel.x-incoming_center_x)))*incoming;
		color=mix(color,min(vec3(1.0),color*1.08),stream*0.3);
	}
	if (cover_upper_layers) { coverage*=texture(visibility_mask,pixel/vec2(165.0,410.0)).a; }
	COLOR=vec4(color,pigment.a*mask_alpha*coverage);
}
