shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D motion_vectors; // Not used in this version

// Effect Controls
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform bool triggered = false;

// Distortion Settings
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.5;

// Heartbeat Settings
uniform float heartbeat_speed : hint_range(0.0, 10.0) = 5.0;
uniform float warp_intensity : hint_range(0.0, 2.0) = 1.0;

// Dissolve Settings
uniform float dissolve_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float dissolve_threshold : hint_range(0.0, 1.0) = 0.6;

// Original noise function
float random(vec2 st) {
	return fract(sin(dot(st, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	vec4 base_color = texture(screen_texture, uv);

	if (triggered) {
		// Heartbeat pulse (range: 0.3 to 1.0) affects noise only.
		float pulse = 0.3 + 0.7 * abs(sin(TIME * heartbeat_speed));

		// Warp offset: organic distortion NOT affected by heartbeat.
		vec2 warp_offset = vec2(
			sin(uv.y * 10.0 + TIME * 2.0),
			cos(uv.x * 10.0 + TIME * 2.0)
		) * warp_intensity;

		// Compute displaced UV using only the warp offset (multiplied by strength).
		vec2 displaced_uv = clamp(uv + warp_offset * strength, vec2(0.0), vec2(1.0));

		// Compute noise for dark spots (noise is affected by heartbeat).
		float noise_val = random(uv + TIME);
		float noise_dark = noise_val * noise_intensity * pulse;

		// Get the glitched color from the displaced coordinates.
		vec4 glitched_color = texture(screen_texture, displaced_uv);

		// Apply the noise as a darkening factor (multiply the color).
		vec4 noise_applied_color = glitched_color * (1.0 - noise_dark);

		// Dissolve effect: generate high-frequency noise for small, random smear spots.
		float small_noise = random(uv * 50.0 + TIME);
		float dissolve_mask = smoothstep(dissolve_threshold, dissolve_threshold + 0.1, small_noise * dissolve_intensity);

		// Create a blurred version by averaging nearby pixels.
		vec4 blurred_color = (
			texture(screen_texture, displaced_uv + vec2(0.005, 0.0)) +
			texture(screen_texture, displaced_uv + vec2(-0.005, 0.0)) +
			texture(screen_texture, displaced_uv + vec2(0.0, 0.005)) +
			texture(screen_texture, displaced_uv + vec2(0.0, -0.005))
		) / 4.0;

		// Mix the noise-applied color with the blurred version based on the dissolve mask.
		vec4 final_color = mix(noise_applied_color, blurred_color, dissolve_mask);

		COLOR = final_color;
	} else {
		COLOR = base_color;
	}
}
