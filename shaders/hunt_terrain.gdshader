shader_type canvas_item;
render_mode unshaded;
uniform float travel_offset = 0.0;
varying vec4 cabin_tint;
void vertex() {
    cabin_tint = COLOR;
}
void fragment() {
    // A horizontal crop glides over the supplied wilderness; no road is added.
    vec2 uv = vec2(UV.x * 0.76 + travel_offset, UV.y);
    vec2 grid = vec2(768.0, 320.0);
    uv = (floor(uv * grid) + 0.5) / grid;
    COLOR = texture(TEXTURE, uv) * cabin_tint;
}
