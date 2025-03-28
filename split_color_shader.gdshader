shader_type spatial;
render_mode cull_disabled;

uniform vec4 color1 : source_color;
uniform vec4 color2 : source_color;
uniform float split_angle : hint_range(0, 180) = 90.0;

void fragment() {
    float angle_rad = radians(split_angle);
    vec2 rotated_uv = vec2(
        UV.x * cos(angle_rad) - UV.y * sin(angle_rad),
        UV.x * sin(angle_rad) + UV.y * cos(angle_rad)
    );

    if (rotated_uv.x > 0.5) {
        ALBEDO = color1.rgb;
    } else {
        ALBEDO = color2.rgb;
    }
}