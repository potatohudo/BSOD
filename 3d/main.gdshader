shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Number of glitch strips
uniform int glitch_count = 0;
uniform float glitch_y[64];    // Y positions (0.0–1.0)
uniform float glitch_x[64];    // Start X positions
uniform float glitch_w[64];    // Widths

uniform float glitch_strength = 0.05;

vec2 apply_glitch_from_data(vec2 uv) {
    for (int i = 0; i < glitch_count; i++) {
        if (abs(uv.y - glitch_y[i]) < 0.001) { // match row
            if (uv.x >= glitch_x[i] && uv.x <= glitch_x[i] + glitch_w[i]) {
                float shift = glitch_strength;
                return uv + vec2(shift, 0.0);
            }
        }
    }
    return uv;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    uv = apply_glitch_from_data(uv);
    COLOR = texture(SCREEN_TEXTURE, uv);
}
