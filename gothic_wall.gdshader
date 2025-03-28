shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo : source_color = vec3(0.8, 0.8, 0.8);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform vec2 uv_scale = vec2(4.0, 4.0);
uniform float mortar_width : hint_range(0.0, 0.5) = 0.03;
uniform vec3 mortar_color : source_color = vec3(0.7, 0.7, 0.7);
uniform float stone_noise_scale = 10.0;
uniform float color_variation : hint_range(0.0, 1.0) = 0.2;

vec2 random(vec2 uv) {
    return fract(sin(vec2(dot(uv, vec2(127.1, 311.7)), dot(uv, vec2(269.5, 183.3)))) * 43758.5453);
}

vec3 voronoi(vec2 uv) {
    vec2 grid = floor(uv);
    vec2 f = fract(uv);

    vec3 res = vec3(8.0);

    for(int y = -1; y <= 1; y++) {
        for(int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = random(grid + neighbor);
            point = 0.5 + 0.5 * sin(6.2831 * point);

            vec2 diff = neighbor + point - f;
            float dist = length(diff);

            if(dist < res.x) {
                res = vec3(dist, diff);
            }
        }
    }

    return res;
}

void fragment() {
    vec2 uv = UV * uv_scale;
    vec3 vor = voronoi(uv * stone_noise_scale);

    float stone_pattern = vor.x;
    vec2 stone_id = floor(uv * stone_noise_scale);
    float random_value = random(stone_id).x;

    float mortar = smoothstep(mortar_width, mortar_width + 0.01, stone_pattern);

    // Stone color variation
    vec3 stone_color = albedo * (1.0 + color_variation * (random_value - 0.5));
    stone_color = clamp(stone_color, 0.0, 1.0);

    vec3 final_color = mix(mortar_color, stone_color, mortar);

    ALBEDO = final_color;
    ROUGHNESS = roughness;
    ALPHA = 1.0;

    // Simple normal mapping
    vec3 vor_x = voronoi(uv * stone_noise_scale + vec2(0.01, 0.0));
    vec3 vor_y = voronoi(uv * stone_noise_scale + vec2(0.0, 0.01));
    vec3 normal = normalize(vec3(vor_x.x - vor.x, vor_y.x - vor.x, 0.1));
    NORMAL_MAP = normal;

    // Ensure no transparency
    ALPHA_SCISSOR_THRESHOLD = 1.0;
}