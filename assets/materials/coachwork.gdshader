shader_type spatial;
render_mode cull_disabled;
uniform vec4 paint : source_color = vec4(0.8,0.7,0.4,1.0);
varying vec3 local_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { local_pos=VERTEX; }
void fragment() {
 float grain=hash(floor(local_pos.xz*95.0+local_pos.y*71.0));
 float grime=(1.0-smoothstep(0.65,1.2,local_pos.y))*0.25;
 float streak=hash(floor(vec2(local_pos.x+local_pos.z,local_pos.y*0.02)*28.0));
 ALBEDO=mix(paint.rgb,vec3(0.13,0.11,0.08),grime*(0.55+streak*0.45))*(0.98+grain*0.035);
 METALLIC=0.12;
 ROUGHNESS=0.48+grime;
}
