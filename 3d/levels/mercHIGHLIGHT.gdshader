shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;

uniform float intensity : hint_range(0.0, 10.0) = 1.0;
uniform vec3 light_color : source_color = vec3(0.3, 0.6, 1.0); // bluish for testing
uniform float alpha_value : hint_range(0.0, 1.0) = 0.5; // optional control

void fragment() {
    // Debug pattern to show UV mapping
    EMISSION = vec3(UV.x, UV.y, 1.0) * intensity;

    // You can uncomment this to test the actual color instead
    // EMISSION = light_color * intensity;

    ALPHA = alpha_value;
}
