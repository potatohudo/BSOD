shader_type spatial;

uniform float sway_amplitude : hint_range(0.0, 15.0) = 5.0;
uniform float sway_speed : hint_range(0.0, 5.0) = 1.0;
uniform float amplitude_variation : hint_range(0.0, 10.0) = 2.0;
uniform float amplitude_speed : hint_range(0.0, 5.0) = 0.5;
uniform vec3 sway_axis = vec3(0.0, 0.0, 1.0);

uniform bool fake_round_normals = true;  // enables rounding shader effect

void vertex() {
	// pivot at the top
	vec3 pivot = vec3(0.0, 0.5, 0.0);
	vec3 pos = VERTEX - pivot;

	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dynamic_amp = sway_amplitude + sin(TIME * amplitude_speed) * amplitude_variation;
	float offset = (world_pos.x + world_pos.z) * 0.3;
	float t = TIME * sway_speed + offset;
	float angle = radians(sin(t) * dynamic_amp);

	vec3 ax = normalize(sway_axis);
	float c = cos(angle);
	float s = sin(angle);

	mat3 rot = mat3(
		vec3(c + (1.0 - c) * ax.x * ax.x,
			 (1.0 - c) * ax.x * ax.y + s * ax.z,
			 (1.0 - c) * ax.x * ax.z - s * ax.y),
		vec3((1.0 - c) * ax.y * ax.x - s * ax.z,
			 c + (1.0 - c) * ax.y * ax.y,
			 (1.0 - c) * ax.y * ax.z + s * ax.x),
		vec3((1.0 - c) * ax.z * ax.x + s * ax.y,
			 (1.0 - c) * ax.z * ax.y - s * ax.x,
			 c + (1.0 - c) * ax.z * ax.z)
	);

	pos = rot * pos;
	VERTEX = pos + pivot;
}

void fragment() {
	// fake round normals for low-poly cylinders
	if (fake_round_normals) {
		vec3 normal_ws = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
		NORMAL = normalize(normal_ws);
	}
}
