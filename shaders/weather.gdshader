shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float rain = 0.0;
uniform float dust = 0.0;
uniform float haze = 0.0;
uniform float elapsed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
    vec2 uv = floor(UV * vec2(440.0,180.0)) / vec2(440.0,180.0);
    vec2 p=uv * vec2(75.0,9.0);
    p.x+=uv.y*7.0;
    vec2 cell=floor(p);
    float h=hash(vec2(cell.x,0.0));
    float fall=fract(p.y-elapsed*(3.0+h*3.0)+h*20.0);
    float streak=step(fract(p.x),0.13)*step(0.58,fall)*step(fall,0.84)*step(0.3,h);
    vec2 dp=uv*vec2(95.0,48.0)+vec2(elapsed*13.0,-elapsed*1.3);
    float grain=step(0.965,hash(floor(dp)));
    float fog_wave=0.5+0.5*sin(uv.x*8.0+uv.y*5.0+elapsed*.2);
    ALBEDO=mix(vec3(.67,.82,.86),vec3(.76,.49,.25),dust);
    ALPHA=clamp(streak*rain*.52 + dust*(.10+grain*.30) + haze*(.06+.12*fog_wave),0.0,.65);
}
