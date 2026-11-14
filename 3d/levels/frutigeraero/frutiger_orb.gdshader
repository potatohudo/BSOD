shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, unshaded;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask: source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0);
uniform float metallic : hint_range(0.0, 1.0);
uniform float specular : hint_range(0.0, 1.0);

uniform vec2 uv_speed = vec2(0.1, 0.1);
uniform float wave_y_height = 0.1;
uniform float wave_y_frequency = 4.0;
uniform float wave_y_speed = 2.0;
uniform float wave_x_height = 0.1;
uniform float wave_x_frequency = 4.0;
uniform float wave_x_speed = 2.0;
uniform float wave_z_height = 0.1;
uniform float wave_z_frequency = 4.0;
uniform float wave_z_speed = 2.0;

void vertex() {
    UV += uv_speed * TIME;
    VERTEX.y += sin(VERTEX.y * wave_y_frequency + TIME * wave_y_speed) * wave_y_height;
	VERTEX.y += sin(VERTEX.x * wave_x_frequency + TIME * wave_x_speed) * wave_x_height;
	VERTEX.z += sin(VERTEX.x * wave_z_frequency + TIME * wave_z_speed) * wave_z_height;
	VERTEX.z += sin(VERTEX.z * wave_z_frequency + TIME * wave_z_speed) * wave_z_height;
}

void fragment() {
    vec4 tex = texture(texture_albedo, UV);
	vec4 tex1 = texture(mask, UV2);
    ALBEDO = albedo.rgb * tex.rgb;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = specular;
    ALPHA *= albedo.a * tex.a;
	ALPHA *= albedo.a * tex1.a;
}