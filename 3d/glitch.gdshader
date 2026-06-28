shader_type canvas_item;

//uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
//uniform sampler2D MOTION_TEXTURE;  // Motion vectors
//uniform float datamosh_amount : hint_range(0.0, 1.0) = 0.5;
//uniform float noise_strength : hint_range(0.0, 1.0) = 0.5;
//uniform int glitch_button = 0;
//
//void fragment() {
	//vec2 uv = SCREEN_UV;
	//vec4 motion = texture(MOTION_TEXTURE, uv);
	//vec2 motion_vector = motion.rg * 0.03;
//
	//float noise = fract(sin(dot(uv * TIME, vec2(12.9898, 78.233))) * 43758.5453);
	//noise *= noise_strength;
//
	//vec2 glitch_uv = uv - motion_vector * (datamosh_amount + noise);
//
	//vec4 glitched_color = texture(SCREEN_TEXTURE, glitch_uv);
//
	//COLOR = mix(texture(SCREEN_TEXTURE, uv), glitched_color, glitch_button > 0 ? 1.0 : datamosh_amount);
//}
