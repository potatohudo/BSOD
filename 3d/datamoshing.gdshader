shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D motion_vectors;

uniform float datamosh_strength : hint_range(0.0, 1.0) = 0.5;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float block_size : hint_range(1.0, 64.0) = 32.0;

float random(vec2 st) {
	return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;

	// Create blocky sampling
	vec2 block_uv = floor(uv * block_size) / block_size;

	// Sample motion vector and remap from [0,1] to [-1,1]
	vec2 motion = texture(motion_vectors, uv).rg * 2.0 - 1.0;

	// Generate per-block noise
	float noise = random(block_uv + TIME);

	// Combine motion and noise based on datamosh_strength
	vec2 datamosh_offset = mix(motion, vec2(noise), datamosh_strength);

	// Apply displacement
	vec2 displaced_uv = clamp(uv + datamosh_offset, vec2(0.0), vec2(1.0));
	vec4 glitched_color = texture(screen_texture, displaced_uv);

	// Sample the original color
	vec4 base_color = texture(screen_texture, uv);

	// Final mix based on global intensity
	COLOR = mix(base_color, glitched_color, strength);
}
