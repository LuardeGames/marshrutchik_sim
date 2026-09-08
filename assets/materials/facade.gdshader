shader_type spatial;
uniform sampler2D facade_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.72,0.70,0.64,1.0);
uniform bool instance_colors = false;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 float horizontal = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
 vec2 tex_uv = vec2(horizontal / 12.0, -world_pos.y / 12.0);
 vec3 paint = instance_colors ? COLOR.rgb : tint.rgb;
 vec3 color = texture(facade_texture, tex_uv).rgb * mix(vec3(1.0), paint * 1.6, 0.25);
 if (world_pos.y < 0.65) color = mix(color, vec3(0.16,0.19,0.17),0.7);
 if (abs(world_normal.y)>0.5) color=vec3(0.16,0.18,0.17);
 ALBEDO=color;
 ROUGHNESS=0.92;
}
