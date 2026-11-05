// Deck underside and edges, driven by UV set in BoardVisuals:
//  - edges:     UV.y in [0,1] across the thickness (0 = bottom ply) → stacked maple plies
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
		ALBEDO = mix(maple, ply_dark, smoothstep(0.75, 0.95, ply) * 0.8);
	} else {
		vec2 p = vec2(UV.x, UV.y - 2.0);                  // both 0..1
		float stripes = step(0.5, fract(p.x * 16.0));
		vec3 col = mix(graphic_a, graphic_b, stripes);
		float middle = step(0.28, p.x) * step(p.x, 0.72);
		col = mix(col, graphic_a, middle);
		// Logo: a ring in the middle (stretched to stay round on the long, thin deck).
		float r = length((p - 0.5) * vec2(3.4, 1.0));
		col = mix(col, graphic_b, step(0.22, r) * step(r, 0.32));
		ALBEDO = col;
	}
	ROUGHNESS = 0.6;
}
