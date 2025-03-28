shader_type spatial;

uniform vec4 brick_color : source_color = vec4(0.65, 0.45, 0.4, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform float brick_width : hint_range(0.0, 1.0) = 0.5;
uniform float brick_height : hint_range(0.0, 1.0) = 0.25;
uniform float mortar_size : hint_range(0.0, 0.1) = 0.02;
uniform sampler2D normal_texture : hint_normal;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

varying vec2 world_pos;

//render_mode cull_disabled;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    vec2 uv = world_pos;
    
    // Calculate brick pattern
    vec2 brick_num = floor(uv / vec2(brick_width, brick_height));
    vec2 brick_pos = fract(uv / vec2(brick_width, brick_height));
    
    // Offset every other row
    float offset = floor(brick_num.y / 2.0);
    brick_pos.x += (offset * 0.5);
    brick_pos.x = fract(brick_pos.x);
    
    // Add variation to brick color
    vec3 brick_variation = brick_color.rgb * (0.9 + 0.2 * random(brick_num));
    
    // Calculate mortar lines
    float top = step(brick_pos.y, mortar_size / brick_height);
    float bottom = step(1.0 - mortar_size / brick_height, brick_pos.y);
    float left = step(brick_pos.x, mortar_size / brick_width);
    float right = step(1.0 - mortar_size / brick_width, brick_pos.x);
    
    float mortar = clamp(top + bottom + left + right, 0.0, 1.0);
    
    vec3 color = mix(brick_variation, mortar_color.rgb, mortar);
    
    // Apply normal map
    vec3 normal = texture(normal_texture, UV).rgb;
    NORMAL_MAP = normal;
    
    ALBEDO = color;
    ROUGHNESS = roughness;
}