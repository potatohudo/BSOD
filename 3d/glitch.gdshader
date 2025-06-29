shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;  // Framebuffer
uniform sampler2D MOTION_TEXTURE;  // Motion vectors
uniform float datamosh_amount : hint_range(0.0, 1.0) = 0.5;  // Glitch strength
uniform float noise_strength : hint_range(0.0, 1.0) = 0.5;  // Noise corruption
uniform int glitch_button = 0;  // Toggle effect (0 = off, 1 = full corruption)

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 motion = texture(MOTION_TEXTURE, uv);  // Sample motion vector
	vec2 motion_vector = motion.rg * 0.03;  // Scale motion (adjust for effect strength)

	// **Generate Noise Per-Pixel**
	float noise = fract(sin(dot(uv * TIME, vec2(12.9898, 78.233))) * 43758.5453);
	noise *= noise_strength;

	// **Displace Pixels Based on Motion**
	vec2 glitch_uv = uv - motion_vector * (datamosh_amount + noise);

	// **Recycled Pixels (Previous Frame)**
	vec4 glitched_color = texture(SCREEN_TEXTURE, glitch_uv);

	// **Final Blend (Glitch Toggle)**
	COLOR = mix(texture(SCREEN_TEXTURE, uv), glitched_color, glitch_button > 0 ? 1.0 : datamosh_amount);
}
