// transparent_tube.gdshader
shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float transparency : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    ALBEDO = albedo.rgb;
    ROUGHNESS = roughness;
    ALPHA = 1.0 - transparency;
}