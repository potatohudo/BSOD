shader_type canvas_item;

uniform sampler2D current_position;
uniform sampler2D previous_position;

void fragment() {
    vec2 current = texture(current_position, UV).xy;
    vec2 previous = texture(previous_position, UV).xy;
    COLOR.rg = current - previous;
    COLOR.ba = vec2(0.0);
}