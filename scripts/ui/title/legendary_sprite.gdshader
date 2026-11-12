// Title-screen legendary: per-pixel flame flicker, core pulse and eye blink on one texture.
// `kinds` holds each pixel's animation (red channel * 255 / 40): 0 none, 1 flicker, 2 core (accent),
// 3 core, 4 eye. Core (accent) pixels take their color from `accent`, so the sprite follows the theme.
shader_type canvas_item;

uniform sampler2D kinds : filter_nearest;
uniform vec2 sprite_size = vec2(32.0, 23.0);
uniform vec4 accent : source_color = vec4(0.184, 0.847, 1.0, 1.0);
uniform float time = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float ease(float p) {
	return p * p * (3.0 - 2.0 * p);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	int k = int(round(texture(kinds, UV).r * 255.0 / 40.0));
	vec2 px = floor(UV * sprite_size);
	float bright = 1.0;
	float alpha = 1.0;
	if (k == 1) {
		// Flicker: opacity 1 -> .55 (30%) -> 1 at 1.4x brightness (55%) -> .75 (80%) -> 1, 0.6-1.4 s.
		float dur = 0.6 + 0.8 * hash(px);
		float p = fract(time / dur + hash(px + 17.0));
		if (p < 0.3) {
			alpha = mix(1.0, 0.55, ease(p / 0.3));
		} else if (p < 0.55) {
			alpha = mix(0.55, 1.0, ease((p - 0.3) / 0.25));
		} else if (p < 0.8) {
			alpha = mix(1.0, 0.75, ease((p - 0.55) / 0.25));
		} else {
			alpha = mix(0.75, 1.0, ease((p - 0.8) / 0.2));
		}
		bright = p < 0.55 ? mix(1.0, 1.4, ease(p / 0.55)) : mix(1.4, 1.0, ease((p - 0.55) / 0.45));
	} else if (k == 2 || k == 3) {
		// Core pulse: brightness 1 -> 1.7 -> 1 over 1.8 s.
		float p = fract(time / 1.8);
		bright = 1.0 + 0.7 * (p < 0.5 ? ease(p * 2.0) : ease(2.0 - p * 2.0));
		if (k == 2) {
			c.rgb = accent.rgb;
		}
	} else if (k == 4) {
		// Blink: squash to 10% height (around the pixel's middle) for the last 5% of every 4 s.
		if (fract(time / 4.0) >= 0.95 && abs(fract(UV.y * sprite_size.y) - 0.5) > 0.05) {
			alpha = 0.0;
		}
	}
	COLOR = vec4(min(c.rgb * bright, vec3(1.0)), c.a * alpha);
}
