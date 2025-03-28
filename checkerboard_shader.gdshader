shader_type spatial;

uniform vec4 color1 : source_color;
uniform vec4 color2 : source_color;
uniform float size = 1.0;

void fragment() {
    int x = int(UV.x * size);
    int y = int(UV.y * size);

    if ((x + y) % 2 == 0) {
        ALBEDO = color1.rgb;
    } else {
        ALBEDO = color2.rgb;
    }
}