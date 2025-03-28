shader_type spatial;

uniform vec3 shingle_color : source_color = vec3(0.2, 0.2, 0.25);
uniform float shingle_width = 0.2;
uniform float shingle_height = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

varying vec3 object_pos;

void vertex() {
    object_pos = VERTEX;
}

void fragment() {
    // Calculate UV coordinates for each face
    vec2 face_uv;
    if (abs(object_pos.z) > abs(object_pos.x)) {
        // Front/Back face
        face_uv = vec2(object_pos.x, object_pos.y);
    } else {
        // Left/Right face
        face_uv = vec2(object_pos.z, object_pos.y);
    }

    // Create repeating UV pattern
    vec2 uv = face_uv / vec2(shingle_width, shingle_height);

    vec2 shingle_pos = fract(uv);
    vec2 shingle_id = floor(uv);

    // Offset every other row
    float offset = floor(mod(shingle_id.y, 2.0)) * 0.5;
    shingle_pos.x += offset;
    shingle_id.x -= offset;
    shingle_pos = fract(shingle_pos);

    // Add some random variation to shingle color
    float variation = fract(sin(dot(shingle_id, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 color = shingle_color * (0.9 + 0.2 * variation);

    // Add edge wear/outline
    float edge = smoothstep(0.0, 0.1, shingle_pos.x) *
                 smoothstep(0.0, 0.1, shingle_pos.y) *
                 smoothstep(0.0, 0.1, 1.0 - shingle_pos.x) *
                 smoothstep(0.0, 0.1, 1.0 - shingle_pos.y);
    color *= edge * 0.9 + 0.1;

    ALBEDO = color;
    ROUGHNESS = roughness;
}