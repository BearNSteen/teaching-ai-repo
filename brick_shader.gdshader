shader_type spatial;

uniform vec3 brick_color : source_color;
uniform vec3 mortar_color : source_color;
uniform float brick_width = 0.5;
uniform float brick_height = 0.2;
uniform float mortar_thickness = 0.02;
uniform float well_radius = 1.0;
uniform float well_height = 1.0;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
    // Use local space coordinates instead of world space
    local_pos = VERTEX;
    local_normal = NORMAL;
}

float brick_pattern(vec2 uv, bool is_top) {
    if (is_top) {
        // For the top, use polar coordinates in local space
        float angle = atan(uv.y, uv.x);
        float radius = length(uv);
        uv = vec2(angle * well_radius, radius);
    } else {
        // For the sides, adjust y coordinate in local space
        uv.y = mod(uv.y, well_height);
    }

    vec2 pos = uv / vec2(brick_width, brick_height);
    pos.x += step(1.0, mod(pos.y, 2.0)) * 0.5; // offset every other row
    vec2 squared_pos = fract(pos);

    vec2 borders = step(vec2(mortar_thickness), squared_pos) *
                   step(vec2(mortar_thickness), 1.0 - squared_pos);
    return borders.x * borders.y;
}

void fragment() {
    bool is_top = abs(local_normal.y) > 0.99;
    vec2 uv;

    if (is_top) {
        uv = local_pos.xz;
    } else {
        // For sides, use local space coordinates
        float angle = atan(local_pos.z, local_pos.x);
        uv = vec2(angle * well_radius, local_pos.y);
    }

    float pattern = brick_pattern(uv, is_top);

    vec3 color = mix(mortar_color, brick_color, pattern);

    ALBEDO = color;
    ROUGHNESS = 0.8;
    METALLIC = 0.0;
}