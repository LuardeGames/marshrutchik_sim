shader_type spatial;
uniform sampler2D facade_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.72,0.70,0.64,1.0);
uniform bool instance_colors = false;
varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// Texture tiles 4 floors per 13.4m vertically - matches WorldBuilder's
	// FLOOR_HEIGHT (3.35m/storey) so raising that constant doesn't stretch
	// the window rows out of proportion with the real floor lines.
	float horizontal = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
	vec2 tex_uv = vec2(horizontal / 12.0, -world_pos.y / 13.4);
	vec3 paint = instance_colors ? COLOR.rgb : tint.rgb;
	vec3 color = texture(facade_texture, tex_uv).rgb * mix(vec3(1.0), paint * 1.6, 0.25);

	// Weathering, PS2-era-panelka style: no facade this old and unmaintained
	// is a flat clean color. Vertical rain/rust streaks running down from
	// window-sill height, patchy grime blotches, and a grimier base - all
	// derived from world position so seams between adjacent boxes still line
	// up and MultiMesh batches stay a single draw call.
	float streak_mask = noise(vec2(horizontal * 0.35, 0.0));
	float streak = pow(clamp(1.0 - fract(world_pos.y * 0.28 + streak_mask * 3.0), 0.0, 1.0), 4.0);
	streak *= smoothstep(0.35, 0.75, streak_mask);
	color = mix(color, color * 0.55, streak * 0.5);

	float blotch = noise(vec2(horizontal * 0.9, world_pos.y * 0.9)) * noise(vec2(horizontal * 0.21, world_pos.y * 0.21));
	color = mix(color, color * 0.8, smoothstep(0.45, 0.75, blotch) * 0.4);

	// Grime builds up near the ground and fades out by roughly one storey up.
	float ground_grime = 1.0 - smoothstep(0.0, 3.0, world_pos.y);
	color = mix(color, vec3(0.14,0.15,0.13), ground_grime * 0.55);
	if (world_pos.y < 0.65) color = mix(color, vec3(0.16,0.19,0.17),0.7);
	if (abs(world_normal.y)>0.5) color=vec3(0.16,0.18,0.17);

	ALBEDO=color;
	ROUGHNESS=0.95;
}
