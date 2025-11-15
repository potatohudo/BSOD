shader_type canvas_item;

// ---------- Basic view / primary controls ----------
uniform vec2 u_res = vec2(1024.0, 768.0);

uniform float u_time = 0.0; // optional animation/noise driver
uniform float u_zoom : hint_range(0.000001, 1e6) = 1.0;
uniform int u_iter : hint_range(1, 4096) = 512;
uniform vec2 u_offset = vec2(0.0, 0.0); // pan offset in fractal space

// ---------- rotation / 4D support ----------
uniform float u_rot : hint_range(0.0, 6.2831853) = 0.0;  // XY rotation
uniform float u_zrot : hint_range(0.0, 6.2831853) = 1.3; // additional 2D rotation applied to z each iteration
uniform float u_krot : hint_range(0.0, 6.2831853) = 0.0; // 4D rotation angle (rotates XY-ZW plane pairs)

// ---------- appearance ----------
uniform float u_dist : hint_range(0.0, 1.0) = 0.0;   // small noise/distortion
uniform float u_hue : hint_range(0.0, 1.0) = 0.4;
uniform float u_blend : hint_range(0.0, 1.0) = 0.05;
uniform int u_smooth = 1; // 1 = smooth blending
uniform bool u_parallax = false;
uniform bool u_parallax_glow = true; // adds soft colored halo around black zones


uniform float u_parallax_softness : hint_range(0.0, 1.0) = 0.25;

uniform bool u_invert = false;   // parallax invert

// ---------- mode / hybrid params (all exposed) ----------
uniform int u_mode = 0; // 0=mandel,1=star,2=nova,3=burn,4=lyap(STILL not working :sob:)

// mandel/julia params
uniform float u_mexp : hint_range(1.0, 8.0) = 2.0;   // exponent
uniform float u_jmix : hint_range(0.0, 1.0) = 0.0;   // mix to julia constant
uniform float u_jre : hint_range(-4.0, 4.0) = -0.8;  // julia re
uniform float u_jim : hint_range(-4.0, 4.0) = 0.156; // julia im
uniform float u_bonusM = 0.0; // small translation

// star params
uniform float u_starOff : hint_range(-2.3, 5.0) = 0.5;
uniform float u_starScale : hint_range(0.0, 5.0) = 1.0;
uniform float u_bonusStar : hint_range(-3.8, 3.2) = 0.0;

// nova params
uniform float u_novaR : hint_range(0.0, 5.0) = 1.0;
uniform float u_novaP : hint_range(1.0, 8.0) = 2.0;
uniform float u_bonusNova = 0.0;

// burn params
uniform float u_burnBonus = 0.0;

// lyapunov params
uniform float u_lyA : hint_range(0.0, 4.0) = 3.5;
uniform float u_lyB : hint_range(0.0, 4.0) = 2.8;
uniform float u_lyMask = 3.0; // bitmask for AB pattern (store as float)
uniform int   u_lyLen = 20;   // sequence length used

// internal constants
const int MAX_STEPS = 2048; // shader loop upper bound (keeps compileable)

// ---------- utility functions ----------
mat2 rot2(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(vec2(c, s), vec2(-s, c));
}

vec4 rot4D(vec4 v, float a) {
    float c = cos(a);
    float s = sin(a);
    float nx = v.x * c - v.w * s;
    float nw = v.x * s + v.w * c;
    float ny = v.y * c - v.z * s;
    float nz = v.y * s + v.z * c;
    return vec4(nx, ny, nz, nw);
}
float hash12(vec2 p){
    return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453);
}
vec2 c_pow(vec2 z, float p){
    float r = length(z);
    if (r < 1e-12) return vec2(0.0);
    float th = atan(z.y, z.x);
    float rp = pow(r, p);
    return vec2(rp * cos(th * p), rp * sin(th * p));
}
vec2 c_mul(vec2 a, vec2 b){ return vec2(a.x*b.x - a.y*b.y, a.x*b.y + a.y*b.x); }
vec2 c_div(vec2 a, vec2 b){
    float d = max(dot(b,b), 1e-6);
    return vec2((a.x*b.x + a.y*b.y)/d, (a.y*b.x - a.x*b.y)/d);
}
float safeClamp(float v, float a, float b){ return clamp(v, a, b); }
vec3 paletteL(float t, float h){
    return 0.5 + 0.5 * cos(6.2831853 * (vec3(h, h + 0.33, h + 0.67) + t));
}

// ---------- main fragment (Hybrid engine) ----------
void fragment(){
    // compute aspect-corrected uv in fractal space
    vec2 uv0 = (UV - vec2(0.5) + u_offset) * vec2(u_res.x / max(1.0, u_res.y), 1.0) * u_zoom;
    // base XY rotation & tiny distortion
    uv0 = rot2(u_rot) * uv0;
    if (u_dist > 0.0) {
        uv0 += u_dist * vec2(hash12(uv0 * 3.0 + u_time), hash12(uv0 * -2.0 + u_time * 1.5));
    }

    // 4D state vector: xyzw where we set z,w initially to 0.0
    vec4 state = vec4(uv0, 0.0, 0.0);
    vec3 col = vec3(0.0);
    float iterReached = 0.0;
    float escapeLen = 0.0;

    for (int i = 0; i < MAX_STEPS; i++){
        if (i >= u_iter) break;

        // rotate in 4D around k axis
        if (abs(u_krot) > 0.000001) {
            state = rot4D(state, u_krot);
        }

        vec2 z = state.xy;
        vec2 c = mix(uv0, vec2(u_jre, u_jim), u_jmix);

        // --- Hybrid mode switching ---
        if (u_mode == 0) {
            // Mandelbrot/Julia: z^m + c (m = u_mexp)
            float r = length(z);
            float th = atan(z.y, z.x);
            float rp = pow(max(r, 1e-10), u_mexp);
            z = vec2(rp * cos(th * u_mexp), rp * sin(th * u_mexp)) + c + vec2(u_bonusM, 0.0);
            // z will be rotated by zrot after snippet
        } else if (u_mode == 1) {
            // Star folding (complex reciprocal-like folding)
            float d2 = max(dot(z, z), 1e-6);
            z = abs(z) / d2 - vec2(u_starOff, u_starOff);
            z = rot2(u_zrot) * z;
            z *= u_starScale;
            z += vec2(u_bonusStar, 0.0);
        } else if (u_mode == 2) {
            // Nova variant (Newton)
            float p = max(1.0, u_novaP);
            vec2 zp = c_pow(z, p);
            vec2 zpm1 = c_pow(z, max(1.0, p - 1.0));
            vec2 num = zp - vec2(1.0, 0.0);
            vec2 den = c_mul(zpm1, vec2(p, 0.0));
            vec2 frac = c_div(num, den);
            z = z - u_novaR * frac + vec2(u_bonusNova, 0.0);
        } else if (u_mode == 3) {
            // Burning ship
            z = vec2(abs(z.x), abs(z.y));
            z = vec2(z.x*z.x - z.y*z.y, 2.0 * z.x * z.y) + c + vec2(u_burnBonus, 0.0);
        } else if (u_mode == 4) {
            // Lyapunov sequence hybrid (compute exponent-like value and store in z)
            int L = int(safeClamp(float(u_lyLen), 5.0, 128.0));
            float x = safeClamp(uv0.y * 0.5 + 0.5, 1e-6, 0.999999);
            float sum = 0.0;
            for (int n = 0; n < 128; n++){
                if (n >= L) break;
                float maskf = floor(mod(u_lyMask / pow(2.0, float(n)), 2.0));
                int b = int(maskf + 0.5);
                float r = (b == 0) ? u_lyA : u_lyB;
                x = safeClamp(r * x * (1.0 - x), 1e-9, 1.0 - 1e-9);
                float deriv = abs(r * (1.0 - 2.0 * x));
                sum += log(max(deriv, 1e-9));
            }
            float ly = sum / float(L);
            z = vec2(ly, ly);
        }

        // apply the per-iteration z rotation (rotates complex result)
        z = rot2(u_zrot) * z;
        state.xy = z;

        // coloring blend: accumulate palette mix
        float len = length(z);
        float t = float(i) / float(u_iter);
        vec3 pcol = paletteL(t, u_hue);
        float weight = (u_smooth == 1) ? smoothstep(0.0, 3.0, len) : 1.0;
        col = mix(col, pcol, u_blend * weight);

        // escape test (same semantics as original)
        if (length(z) > 3.0) {
            iterReached = float(i);
            escapeLen = length(z);
            break;
        }

        // optional: feed z back into uv0 for some iterative hybrids (kept from original)
        uv0 = z;
    }

    float tNorm = (iterReached == 0.0) ? 1.0 : iterReached / (iterReached + 8.0);
    if (u_smooth == 1 && iterReached > 0.0) {
        float sm = log2(log2(escapeLen + 1.0));
        tNorm = safeClamp(tNorm - sm * 0.1, 0.0, 1.0);
    }
    vec3 finalCol = mix(vec3(0.0), col, smoothstep(0.0, 1.0, tNorm));
// ---------- Soft parallax transparency ----------
float alpha = 1.0;

if (u_parallax) {
    float lum = dot(finalCol, vec3(0.299, 0.587, 0.114));
    // fade controls smoothness of transparency
    float fade = pow(clamp(lum / max(u_parallax_softness, 1e-5), 0.0, 1.0), 1.5);

    // compute transparency
    alpha = (u_invert) ? fade : (1.0 - fade);

    // optional halo coloring
    if (u_parallax_glow) {
        finalCol += 0.3 * (1.0 - fade) * vec3(u_hue, 0.5 * u_hue, 1.0 - u_hue);
    }
}



    COLOR = vec4(pow(finalCol, vec3(1.2)), alpha);
}
