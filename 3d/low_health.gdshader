shader_type canvas_item;


uniform float noise_scale = 7.0;

uniform float blob_threshold = 0.5;
uniform float blob_softness = 0.1;

uniform float plasma_scale = 3.0;
uniform float plasma_speed = 1.0;
uniform float plasma_strength = 0.2;

uniform float center_size = 0.3;
uniform float center_blur = 0.25;


uniform sampler2D noise_tex;
uniform sampler2D noise_mask;

render_mode blend_premul_alpha;


void fragment() {
    vec2 uv = UV;
    float t = TIME;

    float step_time = floor(t / 0.1);

    float seed = fract(sin(step_time * 12.9898) * 43758.5453);

    vec2 offset = vec2(
        fract(seed * 13.37),
        fract(seed * 91.7)
    );

    // Base noise
    vec2 noise_uv = fract(uv * noise_scale + offset);
    vec4 noise_sample = texture(noise_tex, noise_uv);

    // Mask (bigger blobs: lower scale usually)
    vec2 mask_uv = uv * 1.0;
    vec4 mask_sample = texture(noise_mask, mask_uv);

	float mask_value = texture(noise_mask, uv).r;

	// small spatial variation
	float variation = texture(noise_mask, uv * 2.50 + t * 0.01).r * 0.2;

	float dynamic_threshold = blob_threshold 
	    + sin(t * 0.8) * 0.2
	    + variation;

	float blob = smoothstep(
	    dynamic_threshold - blob_softness,
	    dynamic_threshold + blob_softness,
	    mask_value
	);
	
	//central mask
    float dist = distance(UV, vec2(0.5));

    float center_mask = smoothstep(
        center_size,
        center_size + center_blur,
        dist
    );

    float alpha = 1.0 - blob;

    COLOR = vec4(noise_sample.rgb, noise_sample.a * alpha * center_mask);
}

