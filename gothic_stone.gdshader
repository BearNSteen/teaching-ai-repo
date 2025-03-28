shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform sampler2D texture_normal : hint_normal;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform vec2 uv_scale = vec2(1.0, 1.0);

void fragment() {
    vec2 scaled_uv = UV * uv_scale;

    // Add some variation to the color
    float noise = fract(sin(dot(scaled_uv, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 variation = vec3(noise * 0.1 - 0.05);

    ALBEDO = (albedo.rgb + variation);
    ROUGHNESS = roughness;
    NORMAL_MAP = texture(texture_normal, scaled_uv).rgb;
}