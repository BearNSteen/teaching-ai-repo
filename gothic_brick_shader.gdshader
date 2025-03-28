shader_type spatial;

uniform vec3 brick_color : source_color = vec3(0.3, 0.3, 0.3);
uniform vec3 mortar_color : source_color = vec3(0.2, 0.2, 0.2);
uniform float brick_width = 0.4;
uniform float brick_height = 0.15;
uniform float mortar_size = 0.015;
uniform float brick_roughness : hint_range(0.0, 1.0) = 0.8;
uniform float vertical_offset = 1;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 get_brick_uv(vec3 pos, vec3 normal) {
    vec2 uv;
    vec3 abs_normal = abs(normal);

    if (abs_normal.y > 0.5) {
        // Top or bottom face - keep as is
        uv = pos.xz;
    } else if (abs_normal.x > 0.5 || abs_normal.z > 0.5) {
        // Side faces aligned with X or Z axis - keep as is
        uv = abs_normal.x > abs_normal.z ? pos.zy : pos.xy;
    } else {
        // Slanted surface
        vec3 up = vec3(0.0, 1.0, 0.0);
        vec3 right = normalize(cross(up, normal));
        vec3 forward = cross(normal, right);
        uv.x = dot(pos, right);
        uv.y = dot(pos, forward);
    }

    // Shift the UV coordinates by half a brick to start with full bricks
    uv.y += brick_height * vertical_offset;

    return uv;
}

void fragment() {
    vec2 uv = get_brick_uv(world_pos, world_normal);

    vec2 brick_num = floor(uv / vec2(brick_width, brick_height));
    vec2 brick_pos = fract(uv / vec2(brick_width, brick_height));

    // Offset every other row
    float offset = floor(mod(brick_num.y, 2.0)) * 0.5;
    brick_pos.x += offset;
    brick_num.x -= offset;

    brick_pos = fract(brick_pos);

    // Calculate mortar lines
    float mx = step(mortar_size / brick_width, brick_pos.x);
    mx *= step(brick_pos.x, 1.0 - (mortar_size / brick_width));
    float my = step(mortar_size / brick_height, brick_pos.y);
    my *= step(brick_pos.y, 1.0 - (mortar_size / brick_height));

    float mortar = mx * my;

    vec3 color = mix(mortar_color, brick_color, mortar);

    // Add some random variation to brick color
    float variation = fract(sin(brick_num.x * 12.9898 + brick_num.y * 78.233) * 43758.5453);
    color *= 0.9 + 0.2 * variation;

    // Add edge wear/outline
    float edge = smoothstep(0.0, 0.1, brick_pos.x) *
                 smoothstep(0.0, 0.1, brick_pos.y) *
                 smoothstep(0.0, 0.1, 1.0 - brick_pos.x) *
                 smoothstep(0.0, 0.1, 1.0 - brick_pos.y);
    color *= edge * 0.9 + 0.1;

    ALBEDO = color;
    ROUGHNESS = brick_roughness;
}