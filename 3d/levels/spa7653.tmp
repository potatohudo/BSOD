shader_type spatial;

uniform float glow_intensity = 6.5; // No hint_range, but can be adjusted in the editor
uniform vec4 spark_color = vec4(1.0, 1.0, 1.0, 1.0); // No hint_color
uniform float time_factor = 0.0;

void fragment() {
    float glow = sin(time_factor * 3.1415) * glow_intensity;
    ALBEDO = spark_color.rgb;
    EMISSION = spark_color.rgb * glow;
}
