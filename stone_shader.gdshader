shader_type spatial;

uniform vec4 stone_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform sampler2D noise_texture;
uniform float noise_scale = 10.0;  // Increased for finer detail
uniform float mortar_width : hint_range(0.0, 0.2) = 0.02;  // Reduced for sharper edges
uniform vec4 mortar_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform vec3 mesh_dimensions = vec3(1.0, 1.0, 1.0);
uniform float stone_size = 0.5;
render_mode cull_disabled;

float brick_pattern(vec2 uv, float brick_width, float brick_height) {
    vec2 position = uv / vec2(brick_width, brick_height);
    position.x += step(1.0, mod(position.y, 2.0)) * 0.5;
    position = fract(position);

    // Sharper edge definition
    vec2 smoothed_pos = smoothstep(
        vec2(0.0),
        vec2(mortar_width * 0.5),
        position
    ) * smoothstep(
        vec2(0.0),
        vec2(mortar_width * 0.5),
        vec2(1.0) - position
    );

    return min(smoothed_pos.x, smoothed_pos.y);
}

void fragment() {
    // Scale UVs based on mesh dimensions and desired stone size
    vec2 scaled_uv = UV * vec2(mesh_dimensions.x, mesh_dimensions.y) / stone_size;

    float brick = brick_pattern(scaled_uv, 1.0, 0.5);

    // More detailed noise layers
    vec4 noise1 = texture(noise_texture, scaled_uv * noise_scale);
    vec4 noise2 = texture(noise_texture, scaled_uv * noise_scale * 2.0);
    vec4 noise3 = texture(noise_texture, scaled_uv * noise_scale * 4.0);

    // Combine noise layers for more complex detail
    vec4 stone_detail = mix(
        mix(noise1, noise2, 0.5),
        noise3,
        0.25
    );

    // Create base stone color with stronger variation
    vec4 base_stone = stone_color * (stone_detail.r * 0.5 + 0.5);
    base_stone.rgb *= vec3(
        1.0,
        1.0 - stone_detail.g * 0.2,
        1.0 - stone_detail.b * 0.2
    );

    // Add edge highlights
    float edge = smoothstep(0.0, 0.1, brick);
    base_stone.rgb = mix(base_stone.rgb * 1.2, base_stone.rgb, edge);

    vec4 final_color = mix(mortar_color, base_stone, brick);

    // More pronounced normal mapping
    vec2 noise_normal = vec2(
        stone_detail.r - texture(noise_texture, scaled_uv * noise_scale + vec2(0.005, 0.0)).r,
        stone_detail.r - texture(noise_texture, scaled_uv * noise_scale + vec2(0.0, 0.005)).r
    ) * 10.0;  // Increased strength

    ALBEDO = final_color.rgb;
    ROUGHNESS = roughness - stone_detail.b * 0.3;  // More variation in roughness
    NORMAL = normalize(vec3(noise_normal, 1.0));
}