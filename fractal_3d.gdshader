shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always;

// per-instance + global control
uniform int u_instance_count : hint_range(1,4096) = 128;
uniform float u_field_radius = 5.0;
uniform float u_slice_scale = 1.0;
uniform float u_global_rot = 0.0; // radians rotation of whole field

// per-slice parameter API
uniform int u_slice_param_sel = 0; // 0=None,1=u_zrot,2=u_krot,3=u_bonusStar,4=u_bonusM
uniform float u_slice_param_min = -1.0;
uniform float u_slice_param_max = 1.0;

uniform vec2 u_res = vec2(1024.0, 768.0);
uniform float u_time = 0.0;
uniform float u_zoom : hint_range(0.000001, 1e6) = 1.0;
uniform int u_iter : hint_range(1, 4096) = 512;
uniform vec2 u_offset = vec2(0.0, 0.0);

// base fractal params
uniform float u_rot = 0.0;
uniform float u_zrot = 1.3;
uniform float u_krot = 0.0;

uniform float u_dist = 0.0;
uniform float u_hue = 0.4;
uniform float u_blend = 0.05;
uniform bool u_smooth = true;
uniform bool u_parallax = false;
uniform bool u_invert = false;
uniform float u_parallax_softness : hint_range(0.0,1.0) = 0.25;
uniform bool u_parallax_glow = true;

uniform int u_mode = 0;
uniform float u_mexp : hint_range(1.0,8.0) = 2.0;
uniform float u_jmix : hint_range(0.0,1.0) = 0.0;
uniform float u_jre : hint_range(-4.0,4.0) = -0.8;
uniform float u_jim : hint_range(-4.0,4.0) = 0.156;
uniform float u_bonusM = 0.0;
uniform float u_starOff : hint_range(-2.3,5.0) = 0.5;
uniform float u_starScale : hint_range(0.0,5.0) = 1.0;
uniform float u_bonusStar : hint_range(-3.8,3.2) = 0.0;
uniform float u_novaR : hint_range(0.0,5.0) = 1.0;
uniform float u_novaP : hint_range(1.0,8.0) = 2.0;
uniform float u_bonusNova = 0.0;
uniform float u_burnBonus = 0.0;
uniform float u_lyA : hint_range(0.0,4.0) = 3.5;
uniform float u_lyB : hint_range(0.0,4.0) = 2.8;
uniform float u_lyMask = 3.0;
uniform int u_lyLen = 20;

const int MAX_STEPS = 2048;

mat2 rot2(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(vec2(c, -s), vec2(s, c));
}

vec4 rot4D(vec4 v, float a){
    float c = cos(a), s = sin(a);
    // rotate XY and ZW pairs (simple pairing)
    float nx = v.x*c - v.w*s;
    float nw = v.x*s + v.w*c;
    float ny = v.y*c - v.z*s;
    float nz = v.y*s + v.z*c;
    return vec4(nx, ny, nz, nw);
}
float hash12(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
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
vec3 paletteL(float t,float h){ return 0.5 + 0.5*cos(6.28318*(vec3(h,h+0.33,h+0.67)+t)); }

// per-instance normalized index
varying float v_inst_norm;
void vertex(){
    v_inst_norm = float(INSTANCE_ID) / max(1.0, float(u_instance_count - 1));
}

void fragment(){
    // normalized slice index t in [0,1]
    float t = v_inst_norm;
    // map to -1..1 then angle
    float tt = t * 2.0 - 1.0;
    float ang = tt * 3.14159265; // half-turn mapping; you can change range

    // rotate the ring by global rotation uniform
    float total_ang = ang + u_global_rot;

    // set inst_pos on a ring in XZ plane; use tt for vertical variation
    vec3 inst_pos = vec3(cos(total_ang), 0.0, sin(total_ang)) * u_field_radius + vec3(0.0, tt * (u_field_radius * 0.2), 0.0);
    // slice mapping normalized
    float slice_z = inst_pos.z / u_field_radius;
    float slice_k = length(inst_pos.xy) / u_field_radius;

    // compute a per-slice param (0..1) from t (you can make different mappings)
    float param_t = t; // 0..1 across slices
    // allow symmetry mapping (center stronger) - optional
    float c_t = abs(param_t - 0.5) * 2.0; // 0=center, 1=edges
    float mapped = param_t; // default linear

    // pick mapped based on selection (you can expand)
    float param_value = mix(u_slice_param_min, u_slice_param_max, mapped);

    // start with base values
    float local_krot = u_krot + slice_k * u_slice_scale;
    float local_zrot = u_zrot + slice_z * u_slice_scale;
    float local_bonusStar = u_bonusStar;
    float local_bonusM = u_bonusM;

    // apply selected param: sel 1=zrot, 2=krot, 3=bonusStar, 4=bonusM
    if (u_slice_param_sel == 1) {
        local_zrot += param_value;
    } else if (u_slice_param_sel == 2) {
        local_krot += param_value;
    } else if (u_slice_param_sel == 3) {
        local_bonusStar += param_value;
    } else if (u_slice_param_sel == 4) {
        local_bonusM += param_value;
    }

    // --- uv space and distortion (same as before) ---
    vec2 uv0 = (UV - vec2(0.5) + u_offset) * vec2(u_res.x / max(1.0, u_res.y), 1.0) * u_zoom;
    uv0 = rot2(u_rot) * uv0;
    if (u_dist > 0.0){
        uv0 += u_dist * vec2(hash12(uv0*3.0 + u_time), hash12(uv0*-2.0 + u_time*1.5));
    }

    vec4 state = vec4(uv0, 0.0, 0.0);
    vec3 col = vec3(0.0);
    float iterReached = 0.0;
    float escapeLen = 0.0;

    for (int i = 0; i < MAX_STEPS; i++){
        if (i >= u_iter) break;
        if (abs(local_krot) > 1e-6) state = rot4D(state, local_krot);

        vec2 z = state.xy;
        vec2 c = mix(uv0, vec2(u_jre, u_jim), u_jmix);

        if (u_mode == 0){
            float r = length(z);
            float th = atan(z.y, z.x);
            float rp = pow(max(r, 1e-10), u_mexp);
            z = vec2(rp*cos(th*u_mexp), rp*sin(th*u_mexp)) + c + vec2(local_bonusM, 0.0);
        } else if (u_mode == 1){
            float d2 = max(dot(z,z),1e-6);
            z = abs(z)/d2 - vec2(u_starOff);
            z = rot2(local_zrot)*z;
            z *= u_starScale;
            z += vec2(local_bonusStar, 0.0);
        } else if (u_mode == 2){
            float p = max(1.0, u_novaP);
            vec2 zp = c_pow(z,p);
            vec2 zpm1 = c_pow(z,max(1.0,p-1.0));
            vec2 num = zp - vec2(1.0,0.0);
            vec2 den = c_mul(zpm1, vec2(p,0.0));
            vec2 frac = c_div(num, den);
            z = z - u_novaR * frac + vec2(u_bonusNova,0.0);
        } else if (u_mode == 3){
            z = vec2(abs(z.x),abs(z.y));
            z = vec2(z.x*z.x - z.y*z.y, 2.0*z.x*z.y) + c + vec2(u_burnBonus,0.0);
        } else if (u_mode == 4){
            int L = int(clamp(float(u_lyLen),5.0,128.0));
            float x = clamp(uv0.y*0.5+0.5,1e-6,0.999999);
            float sum = 0.0;
            for (int n=0;n<128;n++){
                if (n>=L) break;
                float maskf = floor(mod(u_lyMask / pow(2.0, float(n)), 2.0));
                int b = int(maskf + 0.5);
                float r = (b == 0) ? u_lyA : u_lyB;
                x = clamp(r * x * (1.0 - x), 1e-9, 1.0 - 1e-9);
                float deriv = abs(r * (1.0 - 2.0 * x));
                sum += log(max(deriv, 1e-9));
            }
            float ly = sum / float(L);
            z = vec2(ly, ly);
        }

        z = rot2(local_zrot) * z;
        state.xy = z;

        float len = length(z);
        float tcol = float(i) / float(u_iter);
        vec3 pcol = paletteL(tcol, u_hue);
        float weight = u_smooth ? smoothstep(0.0, 3.0, len) : 1.0;
        col = mix(col, pcol, u_blend * weight);

        if (len > 3.0){
            iterReached = float(i);
            escapeLen = len;
            break;
        }
        uv0 = z;
    }

    float tNorm = (iterReached == 0.0) ? 1.0 : iterReached / (iterReached + 8.0);
    if (u_smooth && iterReached > 0.0){
        float sm = log2(log2(escapeLen + 1.0));
        tNorm = clamp(tNorm - sm * 0.1, 0.0, 1.0);
    }

    vec3 finalCol = mix(vec3(0.0), col, smoothstep(0.0, 1.0, tNorm));
    float alpha = 1.0;
    if (u_parallax){
        float lum = dot(finalCol, vec3(0.299, 0.587, 0.114));
        float fade = pow(clamp(lum / max(u_parallax_softness, 1e-5), 0.0, 1.0), 1.5);
        alpha = (u_invert) ? fade : (1.0 - fade);
        if (u_parallax_glow) finalCol += 0.3 * (1.0 - fade) * vec3(u_hue, 0.5 * u_hue, 1.0 - u_hue);
    }

    // soft edges
    float edge = smoothstep(0.0, 0.2, UV.x) * smoothstep(0.0, 0.2, 1.0 - UV.x)
               * smoothstep(0.0, 0.2, UV.y) * smoothstep(0.0, 0.2, 1.0 - UV.y);
    alpha *= edge;

    ALBEDO = pow(finalCol, vec3(1.2));
    ALPHA  = alpha;
}
