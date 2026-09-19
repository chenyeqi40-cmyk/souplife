shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D terrain : source_color, filter_nearest;
uniform float travel_offset = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 terrain_rect = vec4(0.0, 0.0, 1.0, 1.0);
void fragment() {
    vec2 uv = vec2(UV.x * .76 + travel_offset, UV.y);
    uv = (floor(uv * vec2(768.0, 320.0)) + .5) / vec2(768.0, 320.0);
    uv = terrain_rect.xy + clamp(uv, vec2(.001), vec2(.999)) * terrain_rect.zw;
    ALBEDO = texture(terrain, uv).rgb * tint.rgb;
}
