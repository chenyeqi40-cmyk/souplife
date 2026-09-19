shader_type canvas_item;
render_mode unshaded;
uniform sampler2D world_snapshot : hint_screen_texture, filter_nearest;
uniform vec2 aim = vec2(645.5, 362.0);
uniform vec2 lens = vec2(645.5, 362.0);
uniform vec2 view_size = vec2(1280.0, 800.0);
uniform float magnification = 3.2;
uniform float radius = 228.0;
uniform float kick = 0.0;
void fragment() {
    vec2 pixel = SCREEN_UV * view_size;
    vec2 delta = pixel - lens;
    float distance_to_center = length(delta);
    if (distance_to_center > radius) {
        COLOR = vec4(0.018, 0.025, 0.024, 0.985);
    } else {
        // Sample the already rendered live world, including the moving animals.
        // Hit testing uses this same aim coordinate, never a second fake target.
        vec2 source = aim + delta / magnification + vec2(0.0, kick * 3.0);
        source = floor(source / 2.0 + 0.5) * 2.0;
        vec4 seen = texture(world_snapshot, source / view_size);
        float rim = smoothstep(radius - 28.0, radius, distance_to_center);
        COLOR = vec4(seen.rgb * (1.0 - 0.35 * rim), 1.0);
    }
}
