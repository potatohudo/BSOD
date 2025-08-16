shader_type spatial;

uniform float sway_amplitude : hint_range(0.0, 15.0) = 5.0;      // base amplitude in degrees
uniform float sway_speed : hint_range(0.0, 5.0) = 1.0;           // swing speed
uniform float amplitude_variation : hint_range(0.0, 10.0) = 2.0; // how much it varies
uniform float amplitude_speed : hint_range(0.0, 5.0) = 0.5;      // how fast it varies
uniform vec3 sway_axis = vec3(0.0, 0.0, 1.0);

void vertex() {
	// pivot at the top of the capsule
	vec3 pivot = vec3(0.0, 0.5, 0.0);
	vec3 pos = VERTEX - pivot;

	// compute world position of this vertex
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// dynamic amplitude over time (wind gusts)
	float dynamic_amp = sway_amplitude + sin(TIME * amplitude_speed) * amplitude_variation;

	// wave offset based on world-space XZ position
	float offset = (world_pos.x + world_pos.z) * 0.3;
	float t = TIME * sway_speed + offset;
	float angle = radians(sin(t) * dynamic_amp);

	// rotation around arbitrary axis (Rodrigues' formula)
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
