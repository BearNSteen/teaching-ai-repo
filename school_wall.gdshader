shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float brick_width : hint_range(0.1, 2.0) = 0.4;
uniform float brick_height : hint_range(0.1, 2.0) = 0.2;
uniform float mortar_thickness : hint_range(0.01, 0.1) = 0.03;
uniform sampler2D noise_texture;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float variation : hint_range(0.0, 1.0) = 0.3;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    // Scale UVs for brick pattern
    vec2 uv = UV * vec2(1.0/brick_width, 1.0/brick_height);
    
    // Offset every other row
    float row = floor(uv.y);
    uv.x += step(0.5, fract(row * 0.5)) * 0.5;
    
    // Create brick pattern
    vec2 brick_uv = fract(uv);
    
    // Add some variation to brick edges
    vec2 noise_uv = UV * 10.0;
    float edge_noise = texture(noise_texture, noise_uv).r * variation;
    
    // Calculate brick edges
    float h_mortar = step(1.0 - mortar_thickness, brick_uv.y) + 
                     step(brick_uv.y, mortar_thickness + edge_noise);
    float v_mortar = step(1.0 - mortar_thickness, brick_uv.x) + 
                     step(brick_uv.x, mortar_thickness + edge_noise);
    
    // Combine edges
    float mortar = clamp(h_mortar + v_mortar, 0.0, 1.0);
    
    // Get per-brick variation
    vec2 brick_id = floor(uv);
    float brick_rand = random(brick_id) * variation;
    
    // Mix colors
    vec4 brick_color = base_color * (1.0 - brick_rand);
    vec4 final_color = mix(brick_color, mortar_color, mortar);
    
    // Add slight noise to surface
    float surface_noise = texture(noise_texture, UV * 5.0).r * 0.1;
    
    ALBEDO = final_color.rgb + surface_noise;
    ROUGHNESS = roughness;
    
    // Normal mapping
    NORMAL_MAP = texture(noise_texture, UV * 5.0).rgb;
    NORMAL_MAP_DEPTH = 0.5;
}