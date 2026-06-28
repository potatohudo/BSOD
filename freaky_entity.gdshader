shader_type spatial;
render_mode unshaded, depth_draw_opaque;

uniform sampler2D screen_tex : hint_screen_texture;
uniform sampler2D noise_tex;

uniform float mesh_warp_strength = 0.3;
uniform float distortion_strength = 0.08;
uniform float time_scale = 1.5;
uniform float fresnel_power = 4.0;

varying vec3 world_pos;
varying vec3 view_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    float noise = texture(noise_tex, UV + TIME * time_scale).r;
    float displacement = (noise - 0.5) * mesh_warp_strength;

    VERTEX += NORMAL * displacement;

    view_normal = NORMAL;
}

void fragment() {
    vec2 screen_uv = SCREEN_UV;

    vec2 center = vec2(0.5);
    vec2 dir = screen_uv - center;
    float dist = length(dir);

    float radial_pull = distortion_strength / (dist + 0.2);

    vec2 noise = texture(noise_tex, UV + TIME).rg * 2.0 - 1.0;

    vec2 distortion = dir * radial_pull + noise * 0.03;

    vec3 warped = texture(screen_tex, screen_uv - distortion).rgb;

    float fresnel = pow(1.0 - dot(normalize(view_normal), VIEW), fresnel_power);

    vec3 glow = vec3(0.4, 0.6, 1.0) * fresnel;

    ALBEDO = warped + glow;
}