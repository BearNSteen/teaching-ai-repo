shader_type spatial;

uniform vec3 marble_base_color : source_color = vec3(0.7, 0.7, 0.7);
uniform vec3 marble_vein_color : source_color = vec3(0.4, 0.4, 0.4);
uniform vec3 energy_color : source_color = vec3(0.3, 0.5, 1.0);
uniform float marble_scale = 2.0;
uniform float energy_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float energy_speed : hint_range(0.0, 2.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;

// Improved value noise
float hash(vec3 p) {
    p = fract(p * vec3(443.8975,397.2973, 491.1871));
    p += dot(p.zxy, p.yxz + 19.19);
    return fract(p.x * p.y * p.z);
}

// Smooth interpolation
vec3 smooth_pos(vec3 p) {
    return p * p * (3.0 - 2.0 * p);
}

// Value noise with better interpolation
float value_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = smooth_pos(f);

    return mix(
        mix(
            mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
            mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x),
            f.y),
        mix(
            mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
            mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x),
            f.y),
        f.z);
}

// Fractal sum for more natural patterns
float fractal_noise(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for(int i = 0; i < 5; i++) {
        value += amplitude * value_noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

// Improved marble pattern
float marble_pattern(vec3 p) {
    // Create primary veining direction
    float vein_direction = p.x + p.y + p.z;

    // Add fractal noise for natural variation
    float noise = fractal_noise(p * marble_scale);

    // Create marble-like pattern
    float marble = sin(vein_direction * 3.0 + noise * 5.0) * 0.5 + 0.5;

    // Add additional detail noise
    marble = smoothstep(0.0, 1.0, marble);
    marble += fractal_noise(p * marble_scale * 4.0) * 0.15;

    return marble;
}

// Improved energy line pattern
float energy_line(vec3 p, float time) {
    // Create main flow direction
    vec3 flow_dir = normalize(vec3(1.0, 1.0, 0.5));
    float flow = dot(p, flow_dir);

    // Create smooth flowing pattern
    float pattern = sin(flow * 6.0 + time * energy_speed);

    // Add noise to flow
    float noise = fractal_noise(p * 2.0 + time * energy_speed * 0.2) * 2.0;
    pattern += noise;

    // Create sharp lines
    pattern = smoothstep(0.7, 0.9, pattern);

    // Add variation to line intensity
    float intensity_var = fractal_noise(p * 3.0 - time * energy_speed * 0.1);
    pattern *= smoothstep(0.2, 0.8, intensity_var);

    return pattern;
}

void fragment() {
    // Get world position and normalize scale
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * 0.5;

    // Generate base marble
    float marble = marble_pattern(world_pos);
    vec3 marble_color = mix(marble_base_color, marble_vein_color, marble);

    // Generate energy lines
    float energy = energy_line(world_pos, TIME);

    // Combine patterns
    vec3 final_color = marble_color;
    final_color = mix(final_color, energy_color, energy * energy_intensity);

    // Add glow to energy lines
    float emission_strength = energy * energy_intensity;

    // Output
    ALBEDO = final_color;
    ROUGHNESS = roughness + (1.0 - energy) * 0.1;
    EMISSION = energy_color * emission_strength * 2.0;
}
