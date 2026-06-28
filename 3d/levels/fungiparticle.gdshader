shader_type particles;
//
//uniform vec4 spore_color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
//uniform float size_min : hint_range(0.01, 0.1) = 0.02;
//uniform float size_max : hint_range(0.01, 0.2) = 0.05;
//
//void start() {
    //// randomize size for variation
    //float size = mix(size_min, size_max, randf());
    //SCALE = vec3(size);
//
    //// random upward drift
    //VELOCITY = vec3(randf() * 0.2 - 0.1, 1.0 + randf() * 0.5, randf() * 0.2 - 0.1);
//
    //// Lifespan randomness
    //LIFETIME = 3.0 + randf() * 2.0;
//}
//
//void process() {
    //// Gentle drifting (x/z wobble)
    //VELOCITY.x += (randf() - 0.5) * 0.01;
    //VELOCITY.z += (randf() - 0.5) * 0.01;
//
    //// fade out based on lifetime
    //float t = AGE / LIFETIME;
    //COLOR = spore_color * vec4(1.0, 1.0, 1.0, 1.0 - smoothstep(0.7, 1.0, t));