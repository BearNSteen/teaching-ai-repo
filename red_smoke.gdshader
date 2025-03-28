shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 smoke_color : source_color = vec3(0.1, 0.1, 0.1);
uniform vec3 fire_color : source_color = vec3(1.0, 0.0, 0.0);
uniform float speed = 0.3;
uniform float scale = 3.0;
uniform float intensity = 1.0;

float hash(float n) { return fract(sin(n) * 43758.5453123); }

float noise(vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);

    float n = p.x + p.y * 57.0;
    return mix(mix(hash(n + 0.0), hash(n + 1.0), f.x),
               mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y);
}

float fbm(vec2 x) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    for (int i = 0; i < 6; i++) {
        v += a * noise(x);
        x = x * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    // Adjust UV to account for rectangle dimensions
    vec2 uv = UV;
    uv.x *= 3.4; // Adjust based on aspect ratio (8.2/2.4 ≈ 3.4)
    uv *= scale;

    float time = TIME * speed;
    vec2 offset = vec2(sin(time), cos(time)) * 0.2;

    float smoke = fbm(uv + offset);
    smoke += 0.3 * fbm(uv * 2.0 - offset * 0.5);

    // Create vertical gradient (more fire at bottom, more smoke at top)
    float vertical_gradient = 1.0 - UV.y;

    // Adjust noise pattern
    float combined = smoothstep(0.3, 0.7, smoke) * intensity;

    // Blend colors with vertical gradient influence
    vec3 final_color = mix(smoke_color, fire_color, combined * vertical_gradient);

    ALBEDO = final_color;
    ROUGHNESS = 0.5;
    METALLIC = 0.0;
    EMISSION = fire_color * combined * vertical_gradient;
}