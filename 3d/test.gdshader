shader_type spatial;

uniform sampler2D Texture;

uniform float flow = 0;

uniform float glow = 1.0;

uniform bool glossy = false;

uniform bool has_bump = false;

uniform sampler2D normal_map;

void vertex() {
	
}

void fragment() {
	
	vec2 uv = vec2(UV.x + TIME * flow, UV.y + TIME * flow);
	vec4 noise = texture(Texture, uv);
	
	vec3 color = vec3(noise.r, noise.g, noise.b);
	//vec3 final_color = color * vec3(0, 0, .25);
	
	ALBEDO = color * glow;
	if (glossy == true) {
		METALLIC = 1.0;
		ROUGHNESS = 0.0;
	} else {
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
	}
	
	if (has_bump == true) {
		vec4 normmap = texture(normal_map, uv);
		NORMAL_MAP = vec3(normmap.r, normmap.g, normmap.b) * 1.;
	}
	
	
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
