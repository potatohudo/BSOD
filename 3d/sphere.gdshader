shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, blend_mix, depth_draw_always, cull_disabled;

// === GROUP: Albedo ===
group_uniforms albedo;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;

// === GROUP: Roughness ===
group_uniforms roughness;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform sampler2D roughness_texture : hint_roughness_r;

// === GROUP: Refraction ===
group_uniforms refraction;
uniform float refraction : hint_range(-16, 16) = 0.5;
uniform sampler2D texture_refraction : filter_linear_mipmap, repeat_enable;
uniform vec4 refraction_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture;
uniform float distortion_amount : hint_range(0.0, 0.05) = 0.01;

// === GROUP: Reflection ===
group_uniforms reflection;
uniform samplerCube reflection_cubemap; // Optional environment map
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.4;

// === GROUP: Normal ===
group_uniforms normal;
uniform float normal_strength : hint_range(-16.0, 16.0) = 0.0;
uniform sampler2D normal_map : hint_normal;

// === GROUP: Misc ===
group_uniforms misc;
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float surface_contribution = 0.2;
uniform float specular_contribution = 0.2;
uniform float refraction_contribution = 1.0;

// === GROUP: UV ===
group_uniforms uv;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);

// --- Fresnel Helper ---
float SchlickFresnel(float u) {
    float m = 1.0 - u;
    float m2 = m * m;
    return m2 * m2 * m;
}

void vertex() {
    UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
    // Normal map
    NORMAL_MAP = texture(normal_map, UV).xyz;
    NORMAL_MAP_DEPTH = normal_strength;

    // Fresnel term
    float VdotN = dot(VIEW, NORMAL);
    float fresnel = clamp(SchlickFresnel(VdotN), 0.0, 1.0);

    // Albedo & roughness mix
    vec4 albedo_mix = texture(albedo_texture, UV) * albedo;
    float roughness_mix = texture(roughness_texture, UV).r * roughness;

    float a = mix(0.001, 1.0, albedo_mix.a);
    float a_factor_0 = mix(fresnel * edge_color.a, 1.0, a);
    float a_factor_1 = 0.5 * sqrt(a);
    float a_factor_2 = a_factor_0 + a_factor_1;

    ALBEDO = mix(edge_color.rgb * edge_color.a, albedo_mix.rgb * surface_contribution, a);
    ROUGHNESS = roughness_mix;
    SPECULAR = 0.5 * inversesqrt(specular_contribution);

    // Reconstruct perturbed normal for refraction
    vec3 unpacked_normal = NORMAL_MAP;
    unpacked_normal.xy = unpacked_normal.xy * 2.0 - 1.0;
    unpacked_normal.z = sqrt(max(0.0, 1.0 - dot(unpacked_normal.xy, unpacked_normal.xy)));
    vec3 ref_normal = normalize(
        mix(NORMAL,
            TANGENT * unpacked_normal.x + BINORMAL * unpacked_normal.y + NORMAL * unpacked_normal.z,
            NORMAL_MAP_DEPTH)
    );

    // Depth-based offset for more realistic bending
    float scene_depth = texture(depth_texture, SCREEN_UV).r;
    float frag_depth = FRAGCOORD.z;
    float depth_diff = clamp(scene_depth - frag_depth, -1.0, 1.0);
    vec2 depth_offset = normalize(SCREEN_UV - vec2(0.5)) * depth_diff * (refraction * 0.002);

    // Combine normal map offset and depth offset for refraction
    vec2 ref_ofs = SCREEN_UV
        - ref_normal.xy * dot(texture(texture_refraction, UV), refraction_texture_channel) * refraction
        + depth_offset
        + (ref_normal.xy * distortion_amount);

    // Sample screen with mip-based blur
    float ref_amount = 1.0 - albedo_mix.a;
    vec3 refracted_scene = textureLod(screen_texture, ref_ofs, ROUGHNESS * 8.0).rgb;

    // Optional environment reflection with Fresnel
    vec3 reflection_color = vec3(0.0);
    if (reflection_strength > 0.0) {
        vec3 I = normalize(-VIEW);
        vec3 R = reflect(I, NORMAL);
        reflection_color = texture(reflection_cubemap, R).rgb;
    }

    // Combine refraction + reflection
    vec3 combined_reflect_refract = mix(refracted_scene, reflection_color, fresnel * reflection_strength);

    // Emit refracted light
    EMISSION += (combined_reflect_refract * ref_amount * EXPOSURE *
                mix(vec3(mix(0.02, 0.1, a)), albedo_mix.rgb * refraction_contribution, a))
                / a_factor_2;

    ALBEDO *= 1.0 - ref_amount;
}
