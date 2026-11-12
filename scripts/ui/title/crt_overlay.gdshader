// Title layers 11-13: scanlines (4 px repeat: 2 clear, then black 22% for ~1 px), a 140 px accent
// scan bar sweeping down every 6 s (peak 6%), and an inset vignette (160 px blur, black 85%).
// Sizes are in the 1280x720 frame's px. CRT (scanlines + bar) can be switched off; the vignette stays.
shader_type canvas_item;

uniform vec2 rect_size = vec2(320.0, 180.0);
uniform vec2 frame_origin = vec2(0.0);
uniform float frame_scale = 0.25;
uniform bool crt = true;
uniform float scan_bar_y = -140.0;   // top of the bar, frame px
uniform vec4 accent : source_color = vec4(0.184, 0.847, 1.0, 1.0);

void fragment() {
	vec2 px = UV * rect_size;
	vec2 p = (px - frame_origin) / frame_scale;
	vec4 out_c = vec4(0.0);
	if (crt) {
		float bar = (p.y - scan_bar_y) / 140.0;
		if (bar >= 0.0 && bar <= 1.0) {
			float a = 0.06 * (1.0 - abs(bar * 2.0 - 1.0));
			out_c = vec4(accent.rgb, a);
		}
		float row = mod(p.y, 4.0);
		if (row >= 2.0 && row < 3.0) {
			out_c = vec4(mix(out_c.rgb, vec3(0.0), 0.22 / max(out_c.a + 0.22, 0.001)), out_c.a + 0.22 * (1.0 - out_c.a));
		}
	}
	// Vignette from the screen edges (in frame px, so it scales with the scene).
	vec2 size_f = rect_size / frame_scale;
	vec2 e = min(px / frame_scale, size_f - px / frame_scale);
	float ax = 0.5 * (1.0 - smoothstep(-80.0, 80.0, e.x));
	float ay = 0.5 * (1.0 - smoothstep(-80.0, 80.0, e.y));
	float v = 0.85 * (1.0 - (1.0 - ax) * (1.0 - ay)) * 2.0;
	v = clamp(v, 0.0, 0.85);
	out_c = vec4(mix(out_c.rgb, vec3(0.0), v / max(out_c.a + v, 0.001)), out_c.a + v * (1.0 - out_c.a));
	COLOR = out_c;
}
