shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 glass_color : source_color = vec4(0.8, 0.9, 1.0, 0.1);
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float fresnel_power : hint_range(0.0, 10.0) = 1.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
    float rim = rim_strength * fresnel;

    ALBEDO = glass_color.rgb;
    ALPHA = clamp(glass_color.a + rim, 0.0, 1.0);
    ROUGHNESS = roughness;
    METALLIC = 0.2;
    SPECULAR = 0.5;
}