shader_type spatial;

uniform vec3 marble_base_color : source_color = vec3(0.2, 0.15, 0.15);  // Dark, reddish-black base
uniform vec3 marble_vein_color : source_color = vec3(0.35, 0.2, 0.1);   // Dark, burnt orange veins
uniform vec3 energy_color : source_color = vec3(0.8, 0.1, 0.0);         // Bright, hellish red
uniform float marble_scale = 2.0;
uniform float energy_intensity : hint_range(0.0, 1.0) = 0.6;            // Slightly more intense
uniform float energy_speed : hint_range(0.0, 2.0) = 1.2;                // Slightly faster
uniform float roughness : hint_range(0.0, 1.0) = 0.8;                   // Rougher surface

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

// Modified marble pattern for more aggressive, brimstone-like appearance
float marble_pattern(vec3 p) {
    // Create more aggressive veining direction
    float vein_direction = p.x + p.y * 1.2 + p.z * 0.8;

    // Add fractal noise for volcanic-like variation
    float noise = fractal_noise(p * marble_scale);

    // Create sharper, more aggressive pattern
    float marble = sin(vein_direction * 4.0 + noise * 6.0) * 0.5 + 0.5;

    // Add crack-like details
    marble = smoothstep(0.2, 0.8, marble);
    marble += fractal_noise(p * marble_scale * 5.0) * 0.2;

    return marble;
}

// Modified energy line pattern for more demonic appearance
float energy_line(vec3 p, float time) {
    // Create more vertical flow direction for hellfire effect
    vec3 flow_dir = normalize(vec3(0.5, 1.0, 0.3));
    float flow = dot(p, flow_dir);

    // Create more aggressive flowing pattern
    float pattern = sin(flow * 8.0 + time * energy_speed);

    // Add turbulent noise
    float noise = fractal_noise(p * 2.5 + time * energy_speed * 0.3) * 2.5;
    pattern += noise;

    // Create sharper, more flame-like lines
    pattern = smoothstep(0.6, 0.95, pattern);

    // Add flickering intensity
    float intensity_var = fractal_noise(p * 4.0 - time * energy_speed * 0.2);
    pattern *= smoothstep(0.1, 0.9, intensity_var);

    return pattern;
}

void fragment() {
    // Get world position and normalize scale
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * 0.5;

    // Generate base marble with more contrast
    float marble = marble_pattern(world_pos);
    vec3 marble_color = mix(marble_base_color, marble_vein_color, marble);

    // Generate energy lines with flame effect
    float energy = energy_line(world_pos, TIME);

    // Combine patterns with stronger energy effect
    vec3 final_color = marble_color;
    final_color = mix(final_color, energy_color, energy * energy_intensity);

    // Add stronger glow to energy lines
    float emission_strength = energy * energy_intensity * 1.5;

    // Output with enhanced contrast
    ALBEDO = final_color;
    ROUGHNESS = roughness + (1.0 - energy) * 0.15;
    EMISSION = energy_color * emission_strength * 2.5;
}
