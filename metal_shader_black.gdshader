shader_type spatial;

uniform vec4 metal_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.3;
uniform float scratch_strength : hint_range(0.0, 1.0) = 0.3;
uniform float wear_strength : hint_range(0.0, 1.0) = 0.2;
uniform vec2 uv_scale = vec2(1.0, 1.0);
render_mode cull_disabled;
render_mode diffuse_burley;  // More physically accurate diffuse lighting
render_mode specular_schlick_ggx;  // More physically accurate specular reflection

// Pseudo-random function
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

// 2D noise function
float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Scratches pattern
float scratches(vec2 uv) {
    float n = 0.0;

    // Multiple layers of angled noise for scratches
    n += noise(uv * 50.0) * 0.5;
    n += noise(uv * 100.0 + vec2(0.2)) * 0.25;
    n += noise(uv * 200.0 + vec2(0.5)) * 0.125;
    n += noise(uv * 400.0 + vec2(0.7)) * 0.0625;

    return n;
}

// Wear pattern
float wear(vec2 uv) {
    float n = 0.0;

    // Multiple layers of noise for wear
    n += noise(uv * 10.0) * 0.5;
    n += noise(uv * 20.0 + vec2(0.3)) * 0.25;
    n += noise(uv * 40.0 + vec2(0.6)) * 0.125;

    return n;
}

void fragment() {
    // Scale UVs
    vec2 scaled_uv = UV * uv_scale;

    // Generate scratch and wear patterns
    float scratch = scratches(scaled_uv);
    float wear_pattern = wear(scaled_uv);

    // Combine patterns
    float pattern = mix(scratch, wear_pattern, 0.5);

    // Apply pattern to base color
    vec3 base_color = metal_color.rgb;
    vec3 scratch_color = mix(base_color, base_color * 0.9, pattern * scratch_strength);
    vec3 final_color = mix(scratch_color, scratch_color * 0.9, wear_pattern * wear_strength);

    // Output
    ALBEDO = final_color;
    METALLIC = metallic;
    ROUGHNESS = roughness + (pattern * 0.1);

    // Remove fresnel emission
    EMISSION = vec3(0.0);
}