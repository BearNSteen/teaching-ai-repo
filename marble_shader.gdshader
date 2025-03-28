shader_type spatial;

uniform vec4 marble_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float marble_scale = 4.0;
uniform float marble_contrast = 2.0;

// Better random function that creates smoother transitions
vec2 random2(vec2 st) {
    st = vec2(dot(st,vec2(127.1,311.7)),
              dot(st,vec2(269.5,183.3)));
    return -1.0 + 2.0 * fract(sin(st) * 43758.5453123);
}

// Improved Perlin noise
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(dot(random2(i + vec2(0.0,0.0)), f - vec2(0.0,0.0)),
                   dot(random2(i + vec2(1.0,0.0)), f - vec2(1.0,0.0)), u.x),
               mix(dot(random2(i + vec2(0.0,1.0)), f - vec2(0.0,1.0)),
                   dot(random2(i + vec2(1.0,1.0)), f - vec2(1.0,1.0)), u.x), u.y);
}

// Seamless noise function
float seamless_noise(vec2 st) {
    vec2 scaled_st = st * 2.0 * PI;
    vec2 seamless_pt = vec2(sin(scaled_st.x), sin(scaled_st.y));
    return noise(seamless_pt);
}

// Improved FBM with seamless noise
float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    float angle = 0.5;
    vec2 rot = vec2(cos(angle), sin(angle));

    for(int i = 0; i < 6; i++) {
        value += amplitude * abs(seamless_noise(st * frequency));
        st = vec2(st.x * rot.x - st.y * rot.y,
                 st.x * rot.y + st.y * rot.x);
        frequency *= 2.17;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    // Rotate UV coordinates 90 degrees and then apply the shift
    vec2 shifted_uv = vec2(UV.y, UV.x); // Swap X and Y to rotate 90 degrees
    shifted_uv.x = fract(shifted_uv.x + 0.5); // Now shift along the new X axis

    vec2 centered_uv = shifted_uv * 2.0 - 1.0;
    float angle = atan(centered_uv.y, centered_uv.x);
    float radius = length(centered_uv);
    vec2 polar_uv = vec2(angle / (2.0 * PI) + 0.5, radius) * marble_scale;

    // Create seamless noise pattern
    float noise_val = fbm(polar_uv);
    float noise_val2 = fbm(polar_uv * 1.5 + vec2(2.0));
    float noise_val3 = fbm(polar_uv * 0.5 - vec2(1.0));

    // Combine the noise values in a more organic way
    float marble = sin(polar_uv.x * 4.0 + polar_uv.y * 4.0 +
                      noise_val * 4.0 + noise_val2 * 2.0 + noise_val3);
    marble = abs(marble);
    marble = pow(marble, marble_contrast);

    // Add subtle variation
    float variation = fbm(polar_uv * 0.3) * 0.1;
    marble = mix(marble, marble + variation, 0.5);

    // Create final color with more subtle mixing
    vec3 final_color = mix(marble_color.rgb * 0.8, marble_color.rgb, marble);
    final_color += (noise_val * 0.05);

    ALBEDO = final_color;
    METALLIC = 0.1;
    ROUGHNESS = 0.2 + noise_val * 0.1;
}