shader_type canvas_item;

uniform sampler2D screen_texture;   // Main viewport texture (set via TextureRect)
uniform sampler2D motion_vectors;   // Motion vector texture (assign a noise texture for testing)
uniform float strength : hint_range(0.0, 1.0) = 0.5;  // How strongly pixels are displaced
uniform bool triggered = false;     // When true, apply the datamosh effect

void fragment() {
    vec2 uv = UV;
    // Get the base color from the main viewport texture.
    vec4 base_color = texture(screen_texture, uv);

    if (triggered) {
        // Sample the motion vector texture.
        // (The values here are assumed to be in [0,1] so we map them to [-1,1].)
        vec2 motion = texture(motion_vectors, uv).rg * 2.0 - 1.0;
        // Displace the UV coordinates by the motion vector scaled by strength.
        vec2 displaced_uv = clamp(uv + motion * strength, vec2(0.0), vec2(1.0));
        // Sample the main texture at the displaced UVs.
        COLOR = texture(screen_texture, displaced_uv);
    } else {
        // If not triggered, output the original color.
        COLOR = base_color;
    }
}
