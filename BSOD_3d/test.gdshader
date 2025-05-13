shader_type canvas_item;

uniform sampler2D motion_vectors;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 motion = texture(motion_vectors, uv);
    COLOR = vec4(motion.rg, 0.0, 1.0);  // Show motion as red/green
}