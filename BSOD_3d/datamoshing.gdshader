shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// For datamoshing, supply a motion vector texture.
// If you don't have a separate one, you can (for now) assign the same viewport texture.
uniform sampler2D motion_vectors;
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float block_size : hint_range(1.0, 64.0) = 32.0;

//
// Simple random function to add noise variation
//
float random(vec2 st) {
    return fract(sin(dot(st, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;

    // Create a blocky grid effect:
    vec2 block_uv = floor(uv * block_size) / block_size;

    // Sample the motion vector texture.
    // Map the value from [0,1] to [-1,1] so it represents a displacement.
    vec2 motion = texture(motion_vectors, uv).rg * 2.0 - 1.0;

    // Generate noise per block to simulate unpredictable artifacting.
    float noise = random(block_uv + TIME);

    // Mix between the motion vector displacement and noise based on datamosh_strength.
    vec2 offset = mix(motion, vec2(noise), strength);

    // Displace the UV coordinates.
    vec2 displaced_uv = clamp(uv + offset, vec2(0.0), vec2(1.0));

    // Sample the screen texture at the displaced coordinates.
    vec4 color = texture(screen_texture, displaced_uv);
    COLOR = color;
}
