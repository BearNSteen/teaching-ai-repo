shader_type spatial;

uniform vec3 marble_base_color : source_color = vec3(0.75, 0.78, 0.8);  // Softer, pearl-like white
uniform vec3 marble_vein_color : source_color = vec3(0.65, 0.7, 0.75);  // Gentle, azure-tinted veins
uniform vec3 energy_color : source_color = vec3(0.85, 0.8, 0.5);       // Soft golden glow
uniform float marble_scale = 2.0;
uniform float energy_intensity : hint_range(0.0, 1.0) = 0.5;           // Moderate intensity
uniform float energy_speed : hint_range(0.0, 2.0) = 0.8;               // Slightly slower for a more serene feel
uniform float roughness : hint_range(0.0, 1.0) = 0.3;                  // Smoother surface for a polished look

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

// Modified marble pattern for a more ethereal, heavenly appearance
float marble_pattern(vec3 p) {
    // Create softer, more flowing veining direction
    float vein_direction = p.x * 0.5 + p.y + p.z * 0.7;

    // Add fractal noise for celestial-like variation
    float noise = fractal_noise(p * marble_scale);

    // Create softer, more ethereal pattern
    float marble = sin(vein_direction * 2.0 + noise * 4.0) * 0.5 + 0.5;

    // Add subtle, flowing details
    marble = smoothstep(0.3, 0.7, marble);
    marble += fractal_noise(p * marble_scale * 3.0) * 0.1;

    return marble;
}

// Modified energy line pattern for a more angelic, radiant appearance
float energy_line(vec3 p, float time) {
    // Create radial flow direction for divine light effect
    vec3 flow_dir = normalize(vec3(cos(time * 0.2), 1.0, sin(time * 0.2)));
    float flow = dot(p, flow_dir);

    // Create softer, more radiant flowing pattern
    float pattern = sin(flow * 4.0 + time * energy_speed);

    // Add gentle, swirling noise
    float noise = fractal_noise(p * 1.5 + time * energy_speed * 0.2) * 1.5;
    pattern += noise;

    // Create softer, more glowing lines
    pattern = smoothstep(0.3, 0.7, pattern);

    // Add pulsating intensity
    float intensity_var = sin(time * 0.5) * 0.5 + 0.5;
    pattern *= mix(0.5, 1.0, intensity_var);

    return pattern;
}

void fragment() {
    // Get world position and normalize scale
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * 0.5;

    // Generate base marble with subtle variations
    float marble = marble_pattern(world_pos);
    vec3 marble_color = mix(marble_base_color, marble_vein_color, marble);

    // Generate energy lines with radiant effect
    float energy = energy_line(world_pos, TIME);

    // Combine patterns with stronger, more ethereal energy effect
    vec3 final_color = marble_color;
    final_color = mix(final_color, energy_color, energy * energy_intensity);

    // Add stronger, pulsating glow to energy lines
    float emission_strength = energy * energy_intensity * (sin(TIME * 2.0) * 0.2 + 1.8);

    // Output with enhanced radiance
    ALBEDO = final_color;
    ROUGHNESS = roughness - (energy * 0.2); // Smoother where energy lines are
    EMISSION = energy_color * emission_strength * 3.0;

    // Add subtle rim lighting for a halo effect
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
    EMISSION += energy_color * fresnel * 0.5;
}
