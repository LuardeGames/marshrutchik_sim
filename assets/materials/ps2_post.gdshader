shader_type canvas_item;
// Retro-console styling pass: ordered (Bayer) dithering breaks smooth
// colour ramps into a stipple instead of a clean gradient, a coarse colour
// quantization removes the "too clean" modern look, plus a little grain,
// scanline darkening and vignette. A stand-in for the imperfections of a
// PS2-era GPU/CRT rather than a literal shader port.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
// Was tuned so subtle it was nearly invisible in play - pushed up across the
// board so the retro/CRT read is unmistakable instead of just a faint haze.
uniform float dither_strength : hint_range(0.0, 1.0) = 0.6;
uniform float color_levels : hint_range(4.0, 64.0) = 13.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.07;
uniform float scanline_strength : hint_range(0.0, 0.3) = 0.14;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 color = texture(screen_tex, SCREEN_UV).rgb;

	ivec2 pix = ivec2(mod(FRAGCOORD.xy, 4.0));
	float threshold = BAYER[pix.y * 4 + pix.x] / 16.0;
	color += (threshold - 0.5) * (dither_strength / color_levels);
	color = floor(color * color_levels + 0.5) / color_levels;

	float grain = (hash13(vec3(FRAGCOORD.xy, TIME)) - 0.5) * grain_strength;
	color += grain;

	float scan = mod(FRAGCOORD.y, 2.0) < 1.0 ? 1.0 : 1.0 - scanline_strength;
	color *= scan;

	vec2 uv = SCREEN_UV - 0.5;
	float vig = 1.0 - dot(uv, uv) * vignette_strength * 2.2;
	color *= clamp(vig, 0.0, 1.0);

	COLOR = vec4(color, 1.0);
}
