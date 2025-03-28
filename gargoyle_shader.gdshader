shader_type spatial;

uniform vec3 stone_color : source_color = vec3(0.4, 0.38, 0.35);
uniform vec3 dark_stone_color : source_color = vec3(0.2, 0.19, 0.17);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float weathering : hint_range(0.0, 1.0) = 0.7;
uniform sampler2D noise_texture; // You'll need to provide a noise texture

varying vec3 vertex_pos;
varying vec3 normal;

// Random function for noise generation
float random(vec2 pos) {
    return fract(sin(dot(pos.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// Improved value noise
float value_noise(vec2 pos) {
    vec2 i = floor(pos);
    vec2 f = fract(pos);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

// Fractal Brownian Motion for more natural looking noise
float fbm(vec2 pos) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for(int i = 0; i < 5; i++) {
        value += amplitude * value_noise(pos * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

void vertex() {
    vertex_pos = VERTEX;
    normal = NORMAL;

    // Add subtle vertex displacement for surface roughness
    float displacement = fbm(VERTEX.xy * 5.0 + VERTEX.yz * 3.0) * 0.02;
    VERTEX += NORMAL * displacement * weathering;
}

void fragment() {
    // Base noise for stone texture
    float noise = fbm(vertex_pos.xy * 4.0 + vertex_pos.yz * 2.0);

    // Additional noise for weathering effects
    float weather_noise = fbm(vertex_pos.xy * 2.0 + vertex_pos.yz * 3.0);

    // Combine noises for final color
    vec3 final_color = mix(stone_color, dark_stone_color, noise * 0.6);

    // Add weathering effect
    float weather_factor = smoothstep(0.3, 0.7, weather_noise) * weathering;
    final_color = mix(final_color, dark_stone_color * 0.8, weather_factor);

    // Edge darkening
    float edge_factor = abs(dot(normal, vec3(0.0, 1.0, 0.0)));
    final_color *= mix(0.7, 1.0, edge_factor);

    // Surface properties
    float metallic = 0.0;
    float rough = roughness + noise * 0.1;

    // Output to shader
    ALBEDO = final_color;
    METALLIC = metallic;
    ROUGHNESS = rough;

    // Add slight ambient occlusion in crevices
    float ao = mix(1.0, 0.5, weather_factor);
    AO = ao;

    // Add some subsurface scattering for a slight translucent effect in thin areas
    SSS_STRENGTH = 0.1;
}