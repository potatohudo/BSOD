// res://fractals_spatial.shader
shader_type spatial;
render_mode unshaded;

uniform vec2 u_res = vec2(1024.0, 768.0);
uniform float u_zoom : hint_range(0.01, 10.0) = 1.0;
uniform int u_iter : hint_range(1, 2048) = 256;
uniform int u_mode = 0;
uniform vec3 u_color_offset = vec3(0.4, 0.6, 0.8);

const int MAX_STEPS = 2048;

void fragment() {
    // UV comes from the mesh's UVs (quad/plane). Center & aspect-correct similar to 2D.
    vec2 uv0 = (UV - vec2(0.5)) * vec2(u_res.x / max(1.0, u_res.y), 1.0) * u_zoom;
    vec2 z = uv0;
    vec2 c = uv0;
    float t = 0.0;

    for (int i = 0; i < MAX_STEPS; i++) {
        if (i >= u_iter) break;
        if (u_mode == 0) {
            z = vec2(z.x*z.x - z.y*z.y, 2.0*z.x*z.y) + c;
        } else {
            z = vec2(abs(z.x), abs(z.y));
            z = vec2(z.x*z.x - z.y*z.y, 2.0*z.x*z.y) + c;
        }
        if (length(z) > 4.0) {
            t = float(i) / float(u_iter);
            break;
        }
    }

    vec3 col = 0.5 + 0.5 * cos(6.2831853 * (u_color_offset + t));
    ALBEDO = col;
    ALPHA  = 1.0;
}
