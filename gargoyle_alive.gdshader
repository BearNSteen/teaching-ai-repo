shader_type spatial;

uniform vec4 stone_color : source_color = vec4(0.35, 0.32, 0.28, 1.0);
uniform float awakening_intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_texture;

// Random noise function
float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void vertex() {
    // Subtle vertex displacement based on noise and time
    float displacement = sin(TIME * 2.0 + VERTEX.y * 4.0) * 0.02 * awakening_intensity;
    VERTEX += NORMAL * displacement;
}

void fragment() {
    // Base stone color
    vec3 base_color = stone_color.rgb;

    // Create cracks effect
    vec2 uv = UV * 4.0;
    float crack_pattern = abs(sin(uv.x * 10.0 + TIME) * sin(uv.y * 10.0 + TIME));
    float cracks = step(0.97 - awakening_intensity * 0.4, crack_pattern);

    // Glowing veins effect
    float vein_pattern = abs(sin(uv.x * 5.0 - TIME) * sin(uv.y * 5.0 + TIME * 0.5));
    float veins = smoothstep(0.8, 0.85, vein_pattern) * awakening_intensity;

    // Pulsing glow in eye sockets
    float dist_from_eyes = min(
        length(UV - vec2(0.3, 0.7)),  // Left eye
        length(UV - vec2(0.7, 0.7))   // Right eye
    );
    float eye_glow = smoothstep(0.1, 0.0, dist_from_eyes) * awakening_intensity;

    // Combine effects
    vec3 crack_color = vec3(0.8, 0.1, 0.0);
    vec3 vein_color = vec3(0.7, 0.0, 0.0);
    vec3 eye_color = vec3(1.0, 0.2, 0.0);

    vec3 final_color = base_color;
    final_color = mix(final_color, crack_color, cracks * awakening_intensity);
    final_color = mix(final_color, vein_color, veins);
    final_color = mix(final_color, eye_color, eye_glow);

    // Add rim lighting
    float rim = 1.0 - dot(NORMAL, VIEW);
    rim = pow(rim, 4.0) * awakening_intensity;
    final_color += vec3(0.5, 0.0, 0.0) * rim;

    ALBEDO = final_color;

    // Add emission for glowing parts
    EMISSION = (crack_color * cracks + vein_color * veins + eye_color * eye_glow) * awakening_intensity;

    // Vary roughness to make awakening parts look different
    ROUGHNESS = mix(0.9, 0.3, awakening_intensity * (cracks + veins + eye_glow));
}
