shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(0.4,0.4,0.4,1.0);
uniform float grain_scale = 35.0;
uniform float variation = 0.12;
uniform bool paving = false;
varying vec3 world_pos;
float noise(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float grit = noise(floor(world_pos.xz * grain_scale));
 float patches = noise(floor(world_pos.xz * 0.7));
 vec3 color = tint.rgb * (1.0 + (grit-0.5)*variation + (patches-0.5)*0.08);
 if (paving) {
  vec2 tile = fract(world_pos.xz * 1.6);
  float seam = step(tile.x,0.025) + step(tile.y,0.025);
  color *= 1.0 - min(seam,1.0)*0.25;
 }
 ALBEDO = color;
 ROUGHNESS = 0.94;
}
