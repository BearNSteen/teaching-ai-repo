shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.2, 0.6, 0.8);
uniform float rain_speed : hint_range(0.1, 1.0) = .2;

float raindrop(vec2 uv, float time, float index) {
    vec2 pos = vec2(
        fract(sin(index * 12.9898) * 43758.5453),
        fract(time + sin(index * 78.233) * 43758.5453)
    );

    float drop = smoothstep(0.03, 0.0, distance(uv, pos));

    float ripple = 0.0;
    float ripple_time = fract(time + 0.5);
    for (int i = 0; i < 3; i++) {
        float r = float(i) * 0.1 + ripple_time * 0.3;
        ripple += (0.02 / abs(distance(uv, pos) - r)) *
                  smoothstep(0.0, 0.1, ripple_time) *
                  (1.0 - smoothstep(0.4, 1.0, ripple_time));
    }

    return drop + ripple;
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * rain_speed;

    float effect = 0.0;
    for (int i = 0; i < 20; i++) {
        effect += raindrop(uv, time, float(i));
    }

    vec3 color = water_color + effect * 0.5;

    ALBEDO = color;
    ROUGHNESS = 0.1;
    METALLIC = 0.5;
    EMISSION = color * 0.1;
    NORMAL = normalize(vec3(dFdx(effect), dFdy(effect), 1.0));
}