shader_type canvas_item;

uniform sampler2D source_texture;
uniform float pixel_size : hint_range(1.0, 8.0) = 3.0;
uniform float color_band_levels : hint_range(1.0, 256.0) = 8.0;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.1;
uniform float ghost_intensity : hint_range(0.0, 0.5) = 0.2;
uniform float fog_intensity : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    vec2 uv = UV;

    // Simulate pixelation
    uv = floor(uv * vec2(TEXTURE_PIXEL_SIZE) / pixel_size) * pixel_size / vec2(TEXTURE_PIXEL_SIZE);

    // Fetch from external texture to avoid framebuffer conflicts
    vec4 color = texture(source_texture, uv);

    // Color banding
    color.rgb = floor(color.rgb * color_band_levels) / color_band_levels;

    // Flickering noise
    float noise = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
    color.rgb += noise * noise_intensity;

    // Fake distortion by shifting UVs slightly
    float offset = sin(uv.y * 10.0) * distortion_strength;
    vec4 distorted_color = texture(source_texture, uv + vec2(offset, 0.0));

    // Blend original and distorted color
    color = mix(color, distorted_color, 0.5);

    // Ghosting effect
    vec4 ghost = texture(source_texture, uv + vec2(-ghost_intensity, ghost_intensity));
    color = mix(color, ghost, ghost_intensity);

    // Fog effect
    float dist = length(uv - 0.5);
    color.rgb = mix(color.rgb, vec3(0.5), fog_intensity * dist);

    COLOR = color;
}
