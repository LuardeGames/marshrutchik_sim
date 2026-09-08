shader_type sky;
// Layered cloud cover: broad grey banks with softer small-scale detail.
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
 vec3 d=normalize(EYEDIR);
 vec2 uv=d.xz/(max(d.y,0.0)+0.32);
 float cloud=noise(uv*2.0)*0.58+noise(uv*4.3)*0.28+noise(uv*9.0)*0.14;
 vec3 banks=mix(vec3(0.27,0.30,0.33),vec3(0.64,0.66,0.68),smoothstep(0.12,0.87,cloud));
 COLOR=mix(vec3(0.58,0.61,0.63),banks,smoothstep(0.0,0.20,d.y));
}
