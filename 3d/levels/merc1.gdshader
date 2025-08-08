shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled, depth_prepass_alpha;

uniform vec3 base_color : source_color = vec3(0.6, 0.6, 0.6);
uniform float distortion_strength = 0.3;
uniform float wave_speed = 2.0;
uniform float wave_scale = 10.0;

uniform float shimmer_speed = 1.5;
uniform float shimmer_strength = 0.08;

uniform sampler2D matcap : source_color;
uniform bool flip_horizontal = false;
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);

uniform float refraction_split = 2.0;
uniform float refraction_split_power : hint_range(0.01, 10.0) = 1.0;
uniform float refraction_affect = 0.6;
uniform vec3 gradient_basis = vec3(3.0, 3.0, 3.0);

////////////////////////////////////
// 0G Waterfall Distortion
uniform float y_distort_strength = 0.2; // how much it stretches up/down
uniform float y_distort_speed = 1.0;    // animation speed
uniform float y_distort_freq = 2.0;     // wave frequency along Y

// Holes / Separation
uniform float hole_density : hint_range(0.0, 1.0) = 0.2; // fraction of area with holes
uniform float hole_size : hint_range(0.05, 1.0) = 0.2;   // hole radius (smaller = more detailed)
uniform float hole_speed = 0.5;                          // animation speed of holes

varying vec2 matcap_uv;
varying vec3 world_pos;
varying vec3 world_normal;

float fresnel(vec3 view_dir, vec3 normal, float power) {
    return pow(1.0 - max(dot(view_dir, normal), 0.0), power);
}

void vertex() {
    float t = TIME;
    vec3 pos = VERTEX;

    // Original mercury displacement
    pos.y += sin((VERTEX.x + VERTEX.z) * wave_scale + t * wave_speed) * distortion_strength;
    pos.x += cos((VERTEX.z - VERTEX.y) * wave_scale + t * wave_speed) * distortion_strength;
    pos.z += sin((VERTEX.y + VERTEX.x) * wave_scale * 0.5 + t * wave_speed * 1.2) * distortion_strength * 0.5;

    // Extra vertical waterfall-like wobble
    pos.y += sin(VERTEX.y * y_distort_freq + t * y_distort_speed) * y_distort_strength;

    VERTEX = pos;

    // Matcap UV calc
    vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec3 view_dir = normalize(-view_pos.xyz);
    vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

    vec3 up_vector = vec3(0.0, 1.0, 0.0);
    vec3 right_vector = vec3(1.0, 0.0, 0.0);

    vec3 ref_vector = (abs(view_dir.y) > 0.9) ? right_vector : up_vector;
    vec3 tangent = normalize(cross(ref_vector, view_dir));
    vec3 bitangent = cross(view_dir, tangent);

    vec2 coords = vec2(dot(view_normal, tangent), dot(view_normal, bitangent));
    coords.x = flip_horizontal ? -coords.x : coords.x;
    coords.y = -coords.y;

    matcap_uv = (coords * 0.496 + 0.5) * uv_scale + uv_offset;

    // Store world-space info
    world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float t = TIME;

    METALLIC = 1.0;
    ROUGHNESS = 0.02;

    // Base + matcap
    vec3 color = base_color;
    vec3 matcap_color = texture(matcap, matcap_uv).rgb;
    if (matcap_color == vec3(0.0)) {
        matcap_color = vec3(0.8);
    }
    color = mix(color, matcap_color, 0.8);

    // Shimmer
    float shimmer = sin((UV.x + UV.y) * 30.0 + t * shimmer_speed);
    shimmer = shimmer * 0.5 + 0.5;
    color += vec3(1.0, 0.9, 0.95) * shimmer_strength * shimmer;

    // Fresnel
    vec3 view_dir = normalize(-VIEW);
    color += fresnel(view_dir, NORMAL, 4.0) * 0.3;

    // Refraction gradient
    vec3 fixed_world_normal = normalize(world_normal);
    vec3 look_dir = normalize(world_pos);
    float look_dot = pow(abs(dot(look_dir, fixed_world_normal)), refraction_split_power);
    vec3 reflection_dir = reflect(look_dir, fixed_world_normal);
    vec3 gradient_direction = gradient_basis * reflection_dir;
    float gradient = gradient_direction.x + gradient_direction.y + gradient_direction.z + t;
    vec3 refraction = 0.5 + 0.5 * sin(vec3(-1.0, 0.0, 1.0) *
        (1.0 - look_dot) * refraction_split + gradient);
    color = mix(color, color * (1.0 - refraction * refraction_affect), 0.5);

    // --- Holes ---
    float hole_pattern = sin(UV.x * (20.0 / hole_size) + t * hole_speed) *
                         sin(UV.y * (20.0 / hole_size) + t * hole_speed);
    hole_pattern = abs(hole_pattern);
    float hole_mask = step(hole_density, hole_pattern);

    ALBEDO = color;
    ALPHA = hole_mask;

    // Distorted normal
    vec3 normal_offset = vec3(
        sin(UV.y * 40.0 + t * wave_speed * 1.5),
        cos(UV.x * 40.0 + t * wave_speed * 1.5),
        0.0
    );
    NORMAL = normalize(NORMAL + normal_offset * 0.5);
}
