shader_type spatial;

uniform vec4 line_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float line_width : hint_range(0.0, 0.1) = 0.02;

void fragment() {
    // Convert view space position to sphere coordinates
    vec3 sphere_coords = VERTEX;

    // Calculate the angle from the Z axis
    float angle = atan(sphere_coords.x, sphere_coords.y);

    // Calculate the distance from the Z axis
    float distance = length(sphere_coords.xy);

    // Check if the current fragment is within the line width
    if (distance < line_width) {
        ALBEDO = line_color.rgb;
    } else {
        // Discard the fragment to make it transparent
        discard;
    }
}