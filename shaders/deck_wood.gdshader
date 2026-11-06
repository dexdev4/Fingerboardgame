// Deck underside and edges, driven by UV set in BoardVisuals:
//  - edges:     UV.y in [0,1] across the thickness (0 = bottom ply) → stacked maple plies
//               with fine grain along the length
//  - underside: UV.y in [2,3] (2 + position across the width), UV.x = 0 nose … 1 tail
//               → a simple graphic: striped ends, solid middle, a round logo
shader_type spatial;
render_mode cull_disabled;

uniform vec3 maple : source_color = vec3(0.86, 0.70, 0.48);
uniform vec3 ply_dark : source_color = vec3(0.55, 0.38, 0.22);
uniform vec3 graphic_a : source_color = vec3(0.85, 0.20, 0.15);
uniform vec3 graphic_b : source_color = vec3(0.95, 0.92, 0.85);
uniform float plies = 5.0;

void fragment() {
	if (UV.y < 1.5) {
		float ply = fract(UV.y * plies);
		// Maple grain running along the deck: fine streaks that vary from ply to ply.
		float layer = floor(UV.y * plies);
		float grain = sin(UV.x * 900.0 + layer * 13.0 + sin(UV.x * 60.0 + layer) * 3.0) * 0.5 + 0.5;
		vec3 wood = maple * (0.88 + 0.12 * grain);
		ALBEDO = mix(wood, ply_dark, smoothstep(0.75, 0.95, ply) * 0.8);
	} else {
		vec2 p = vec2(UV.x, UV.y - 2.0);                  // both 0..1
		float stripes = step(0.5, fract(p.x * 16.0));
		vec3 col = mix(graphic_a, graphic_b, stripes);
		float middle = step(0.28, p.x) * step(p.x, 0.72);
		col = mix(col, graphic_a, middle);
		// Logo: a ring in the middle (stretched to stay round on the long, thin deck).
		float r = length((p - 0.5) * vec2(3.4, 1.0));
		col = mix(col, graphic_b, step(0.22, r) * step(r, 0.32));
		// Tail/nose wear: every pop scrapes the tips on the ground, so near the ends the print
		// is scratched through to the maple — streaky along the board, heavier at the very tip.
		float tip = max(smoothstep(0.86, 0.99, p.x), smoothstep(0.14, 0.01, p.x));
		float scratch = fract(sin(dot(floor(vec2(p.x * 260.0, p.y * 40.0)), vec2(12.9898, 78.233))) * 43758.5453);
		float worn = clamp(tip * 1.4 - scratch * 0.6, 0.0, 1.0);
		col = mix(col, maple * 0.9, worn);
		ALBEDO = col;
	}
	ROUGHNESS = 0.6;
}
