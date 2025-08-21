shader_type canvas_item;

// Viewport capture
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Script-driven glitch parameters
uniform int glitch_count;
uniform float glitch_y[64];
uniform float glitch_x[64];
uniform float glitch_w[64];

// Config toggles
uniform bool use_palette = true;
uniform bool use_lossy = true;

// Core parameters
uniform int color_amount = 64; // 2 – 250
uniform float lossy_amount = 1.0; // 0.0–1.0

// Glitch settings
uniform float glitch_strength = 0.05; // offset intensity
uniform bool glitch_rgb_split = true;

// Quantization helper
vec3 quantize_color(vec3 color, int steps) {
	return floor(color * float(steps)) / float(steps);
}

// Apply glitch offset from script arrays
vec2 apply_script_glitches(vec2 uv) {
	for (int i = 0; i < glitch_count; i++) {
		// Match row
		if (abs(uv.y - glitch_y[i]) < 0.002) {
			// Inside glitch strip
			if (uv.x > glitch_x[i] && uv.x < glitch_x[i] + glitch_w[i]) {
				uv.x += glitch_strength;
			}
		}
	}
	return uv;
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Apply glitch UV offset from script
	vec2 glitch_uv = apply_script_glitches(uv);

	// RGB split option
	vec4 col;
	if (glitch_rgb_split && glitch_count > 0) {
		float r = texture(SCREEN_TEXTURE, apply_script_glitches(uv + vec2(0.001, 0.0))).r;
		float g = texture(SCREEN_TEXTURE, apply_script_glitches(uv)).g;
		float b = texture(SCREEN_TEXTURE, apply_script_glitches(uv - vec2(0.001, 0.0))).b;
		col = vec4(r, g, b, 1.0);
	} else {
		col = texture(SCREEN_TEXTURE, glitch_uv);
	}

	// Lossy compression simulation
	vec3 lossy = col.rgb;
	if (use_lossy) {
		float precision = mix(256.0, 2.0, lossy_amount);
		lossy = floor(lossy * precision) / precision;
	}

	// Palette quantization
	vec3 final_col = lossy;
	if (use_palette) {
		final_col = quantize_color(lossy, color_amount);
	}

	COLOR = vec4(final_col, col.a);
}
