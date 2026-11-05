// Skatepark concrete. Projected in world space (top faces use XZ, walls use XY/ZY), so every
// obstacle shares one continuous texture and you can read speed from it:
//  - slab joints every `joint_spacing` units (10 cm real per unit) — the main motion cue
//  - two octaves of value noise for trowel marks and staining
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.66, 0.66, 0.64);
uniform vec3 stain_color : source_color = vec3(0.52, 0.52, 0.50);
uniform vec3 joint_color : source_color = vec3(0.30, 0.30, 0.30);
uniform float joint_spacing = 1.0;
uniform float joint_width = 0.012;   // world units
uniform float noise_scale = 6.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise in [0,1].
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec3 n = abs(world_normal);
	// Pick the projection plane facing the surface.
	vec2 p = n.y > 0.7 ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	float stain = noise(p * noise_scale * 0.15) * 0.6 + noise(p * noise_scale) * 0.4;
	vec3 col = mix(base_color, stain_color, smoothstep(0.35, 0.85, stain));
	// Fine grit so the surface never looks flat-shaded.
	col *= 0.93 + 0.07 * hash(floor(p * 400.0));
	// Slab joints (only on top faces), antialiased with fwidth.
	if (n.y > 0.7) {
		vec2 d = abs(fract(p / joint_spacing - 0.5) - 0.5) * joint_spacing;
		float line = min(d.x, d.y);
		float aa = fwidth(line);
		col = mix(joint_color, col, smoothstep(joint_width - aa, joint_width + aa, line));
	}
	ALBEDO = col;
	ROUGHNESS = 0.88;
}
