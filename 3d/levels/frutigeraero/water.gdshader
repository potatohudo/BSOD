shader_type spatial;

uniform sampler2D normal_map;
uniform vec4 color: source_color = vec4(1, 1, 1, 1);


uniform float rapid = .05;

uniform float transparency: hint_range(0.0, 1.0, 0.01) = 1.0;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 uv = vec2(UV.x + TIME * rapid, UV.y);
	
	ALBEDO = vec3(color.r, color.g, color.b);
	
	vec4 bump = texture(normal_map, uv);
	NORMAL_MAP = vec3(bump.r, bump.g, bump.b);
	
	METALLIC = 0.0;
	ROUGHNESS = 0.;
	ALPHA = transparency;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
