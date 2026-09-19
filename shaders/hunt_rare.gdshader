shader_type canvas_item;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
    vec4 color = texture(TEXTURE, UV);
    if (color.r > .65 && color.b > .6 && color.g < .35) color.a = 0.0;
    // Only the green cactus pixels in the top part of each animation cell
    // change pigment. The shared warm body, limbs, eyes and silhouette stay intact.
    float cell_y = fract(UV.y * 2.0);
    if (cell_y < .68 && color.g > color.r * .96 && color.g > color.b * 1.25 && color.g > .12) {
        float light = dot(color.rgb, vec3(.23, .65, .12));
        color.rgb = vec3(.28 + light * .90, .10 + light * .26, .09 + light * .20);
    }
    COLOR = color * vertex_tint;
}
