shader_type spatial;
render_mode depth_draw_opaque;

uniform sampler2D screen_tex : hint_screen_texture;
uniform sampler2D noise_tex;

uniform float slice_position = 0.0;
uniform float slice_thickness = 0.5;
uniform float distortion_strength = 0.02;
uniform float mesh_warp = 0.1;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    float noise = texture(noise_tex, UV + TIME).r;
    VERTEX += NORMAL * (noise - 0.5) * mesh_warp;
}

void fragment() {

    float slice_dist = abs(world_pos.z - slice_position);

    float slice_mask = smoothstep(slice_thickness, 0.0, slice_dist);

    float noise = texture(noise_tex, UV * 3.0 + TIME).r;
    float dissolve = step(slice_mask, noise);

    vec2 distortion_uv = texture(noise_tex, UV + TIME).rg * 2.0 - 1.0;
    vec3 warped = texture(screen_tex, SCREEN_UV + distortion_uv * distortion_strength).rgb;

    float edge = smoothstep(0.02, 0.0, slice_dist);
    EMISSION = vec3(0.8, 0.9, 1.0) * edge;

    ALBEDO = mix(ALBEDO, warped, 0.4) * dissolve;
}