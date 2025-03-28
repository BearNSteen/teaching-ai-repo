shader_type spatial;

uniform vec4 grid_color : source_color = vec4(0.5, 0.5, 0.5, 0.8);
uniform float grid_size = 1.0;
uniform float line_width = 0.02;

void fragment() {
    // Get world position and add offset of half a grid size
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz + vec3(grid_size * 0.5);
    
    // Calculate grid lines based on world position
    vec2 grid = abs(fract(world_pos.xz / grid_size) - 0.5);
    float line = min(grid.x, grid.y);
    
    // Create the line effect with smoothing
    float mask = smoothstep(line_width, 0.0, line);
    
    // Output final color
    ALBEDO = grid_color.rgb;
    ALPHA = mask * grid_color.a;
}
