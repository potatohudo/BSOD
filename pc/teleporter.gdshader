shader_type canvas_item;

uniform sampler2D SCREENSHOT : source_color, filter_linear_mipmap;
uniform float warp_amount = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.y += sin(uv.x * 20.0) * 0.01 * warp_amount;
	uv.x += warp_amount * (uv.y - 0.5) * 2.0;

	COLOR = texture(SCREENSHOT, uv);
}
