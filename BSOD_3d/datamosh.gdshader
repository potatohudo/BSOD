shader_type canvas_item;

// Textures from compositor
uniform sampler2D current_frame;
uniform sampler2D previous_frame;
uniform sampler2D motion_vectors;

// Parameters
uniform float motion_threshold : hint_range(0, 1) = 0.1;
uniform float block_size : hint_range(2, 64) = 16.0;
uniform float distortion_strength : hint_range(0, 2) = 0.5;
uniform float color_shift : hint_range(0, 0.1) = 0.02;
uniform float frame_persistence : hint_range(0, 1) = 0.9;

float luma(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

vec2 quantize_uv(vec2 uv, float size) {
    vec2 blocks = vec2(1.0) / size;
    return floor(uv * blocks) / blocks;
}

void fragment() {
    // Quantize UV coordinates for blocky effect
    vec2 block_uv = quantize_uv(UV, block_size);

    // Motion vector analysis
    vec2 motion = texture(motion_vectors, block_uv).rg;
    float motion_amount = length(motion);

    // Frame difference analysis
    vec4 current = texture(current_frame, UV);
    vec4 previous = texture(previous_frame, UV);
    float frame_diff = abs(luma(current.rgb) - luma(previous.rgb));

    // Create distortion mask
    float distortion_mask = step(motion_threshold, motion_amount) * frame_diff;

    // Offset UVs based on motion vectors
    vec2 distorted_uv = UV + (motion * distortion_strength * distortion_mask);

    // Sample with channel separation
    vec4 color;
    color.r = texture(current_frame, distorted_uv - vec2(color_shift)).r;
    color.g = texture(current_frame, distorted_uv).g;
    color.b = texture(current_frame, distorted_uv + vec2(color_shift)).b;
    color.a = 1.0;

    // Blend with previous frame
    vec4 final = mix(color, previous, frame_persistence);

    // Add compression artifacts in high-motion areas
    final.rgb += (fract(sin(TIME + UV.x * 1000.0))) * 0.1 * distortion_mask;

    COLOR = final;
}