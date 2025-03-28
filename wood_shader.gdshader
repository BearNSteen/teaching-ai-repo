shader_type spatial;

uniform vec4 wood_color : source_color = vec4(0.4, 0.25, 0.1, 1.0);
uniform vec4 wood_color_dark : source_color = vec4(0.2, 0.1, 0.05, 1.0);
uniform float grain_strength : hint_range(0.0, 1.0) = 0.3;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform float grain_scale = 40.0;
uniform vec2 uv_scale = vec2(1.0, 1.0);

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// 2D Noise based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

void fragment() {
    vec2 scaled_uv = UV * uv_scale;
    
    // Create base wood grain pattern
    float grain = noise(scaled_uv * grain_scale);
    grain = mix(grain, noise(scaled_uv * grain_scale * 2.0), 0.5);
    
    // Add some vertical streaks
    float streaks = noise(vec2(scaled_uv.x * 5.0, scaled_uv.y * 50.0));
    grain = mix(grain, streaks, 0.5);
    
    // Create rings
    float rings = sin(scaled_uv.x * 20.0 + grain * 2.0);
    rings = smoothstep(-1.0, 1.0, rings);
    
    // Combine patterns
    float final_pattern = mix(grain, rings, grain_strength);
    
    // Mix colors based on pattern
    vec4 final_color = mix(wood_color, wood_color_dark, final_pattern);
    
    ALBEDO = final_color.rgb;
    ROUGHNESS = roughness;
}