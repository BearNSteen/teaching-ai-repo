shader_type spatial;

uniform vec3 color1 : source_color = vec3(1.0, 0.3, 0.0);   // Red-orange
uniform vec3 color2 : source_color = vec3(0.8, 0.2, 0.5);   // Purple-red
uniform vec3 color3 : source_color = vec3(1.0, 0.6, 0.2);   // Orange
uniform vec3 color4 : source_color = vec3(1.0, 0.8, 0.3);   // Yellow

uniform float scale = 2.0;
uniform float speed = 0.1;
uniform float blend_strength = 0.5;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

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

void fragment() {
    vec2 uv = UV * scale;
    float time = TIME * speed;

    // Create multiple noise layers
    float n1 = noise(uv + time);
    float n2 = noise(uv * 2.0 + vec2(time * -0.5, time));
    float n3 = noise(uv * 4.0 + vec2(time * 0.3, time * -0.7));

    // Blend colors based on noise
    vec3 color = mix(color1, color2, n1);
    color = mix(color, color3, n2 * blend_strength);
    color = mix(color, color4, n3 * blend_strength);

    ALBEDO = color;
    EMISSION = color * 0.1;  // Slight glow
}
