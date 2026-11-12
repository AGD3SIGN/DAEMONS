// Title layer 1: radial gradient, ellipse at 50% / 38% of the 1280x720 frame (farthest-corner),
// bg-glow 0% -> bg-mid 45% -> bg-void 100%. Covers the whole screen so wide screens get no bars.
shader_type canvas_item;

uniform vec2 rect_size = vec2(320.0, 180.0);   // this ColorRect, in its own units
uniform vec2 frame_origin = vec2(0.0);         // where the 1280x720 frame's (0,0) sits in the rect
uniform float frame_scale = 0.25;              // rect units per frame px
uniform vec4 bg_glow : source_color = vec4(0.0706, 0.1333, 0.2902, 1.0);
uniform vec4 bg_mid : source_color = vec4(0.0392, 0.0706, 0.1882, 1.0);
uniform vec4 bg_void : source_color = vec4(0.0196, 0.0275, 0.0588, 1.0);

void fragment() {
	vec2 p = (UV * rect_size - frame_origin) / frame_scale;
	// CSS "ellipse farthest-corner at 50% 38%" on 1280x720: radii 1224.7 x 523.6.
	float d = length((p - vec2(640.0, 273.6)) / vec2(1224.7, 523.6));
	vec3 c = d < 0.45 ? mix(bg_glow.rgb, bg_mid.rgb, d / 0.45) : mix(bg_mid.rgb, bg_void.rgb, clamp((d - 0.45) / 0.55, 0.0, 1.0));
	COLOR = vec4(c, 1.0);
}
