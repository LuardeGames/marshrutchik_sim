shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(0.72,0.70,0.64,1.0);
uniform bool instance_colors = false;
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 float horizontal = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
 vec2 grid = vec2(horizontal/2.8, world_pos.y/3.0);
 vec2 cell = fract(grid);
 float seed = hash(floor(grid));
 vec3 paint = instance_colors ? COLOR.rgb : tint.rgb;
 float grain = hash(floor(vec2(horizontal,world_pos.y)*55.0));
 vec3 color = paint * (0.94 + grain*0.12);
 float panel = step(cell.x,0.012) + step(cell.y,0.014);
 color *= 1.0-min(panel,1.0)*0.24;
 if (abs(world_normal.y) < 0.5) {
  bool frame = cell.x>0.19 && cell.x<0.80 && cell.y>0.25 && cell.y<0.83;
  bool glass = cell.x>0.22 && cell.x<0.77 && cell.y>0.29 && cell.y<0.79;
  if(frame) color = vec3(0.83,0.82,0.75);
  if(glass) {
   color = mix(vec3(0.13,0.23,0.29),vec3(0.40,0.52,0.56),seed);
   if (seed>0.77) color = vec3(0.67,0.55,0.34);
   if (seed>0.35 && cell.x>0.62) color = vec3(0.62,0.61,0.52);
   if (abs(cell.x-0.49)<0.014 || abs(cell.y-0.64)<0.009) color=vec3(0.78,0.78,0.72);
  }
  if(cell.y>0.21 && cell.y<0.25 && cell.x>0.17 && cell.x<0.82) color=vec3(0.39,0.41,0.39);
  if(world_pos.y<0.9) color=paint*0.55;
 } else { color=vec3(0.24,0.26,0.25)*(0.9+grain*0.15); }
 ALBEDO=color;
 ROUGHNESS=0.88;
}
