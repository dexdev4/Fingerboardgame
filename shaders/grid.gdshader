// Light ground with a world-space grid so motion and speed are easy to read.
// Minor lines every `minor_spacing` units (0.1 u = 1 cm real), major every `major_spacing`.
// Lines are drawn with fwidth() so they stay ~line_width pixels wide at any distance,
// and minor lines fade out where they would get denser than the pixels (no shimmering).
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.70, 0.71, 0.73);
uniform vec3 minor_color : source_color = vec3(0.58, 0.60, 0.63);
uniform vec3 major_color : source_color = vec3(0.40, 0.43, 0.48);
uniform float minor_spacing = 0.1;
uniform float major_spacing = 1.0;
uniform float line_width = 1.2;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1 on a grid line, 0 between lines.
float grid(vec2 p, float spacing) {
	vec2 cell = p / spacing;
	vec2 dist = abs(fract(cell - 0.5) - 0.5) / fwidth(cell);  // distance to nearest line, in pixels
	return 1.0 - min(min(dist.x, dist.y) / line_width, 1.0);
}

void fragment() {
	vec2 p = world_pos.xz;
	float px = max(fwidth(p.x), fwidth(p.y));                   // world units per pixel
	float minor_fade = clamp(1.0 - px * 4.0 / minor_spacing, 0.0, 1.0);
	vec3 col = mix(base_color, minor_color, grid(p, minor_spacing) * minor_fade);
	col = mix(col, major_color, grid(p, major_spacing));
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
