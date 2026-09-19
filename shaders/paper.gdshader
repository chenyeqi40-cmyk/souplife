shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D art : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform float fill = 0.35;
uniform float night = 0.0;
uniform float sunset = 0.0;
uniform float overcast = 0.0;
uniform bool exterior = false;
uniform bool cabin = true;
uniform float alpha_cut = 0.42;
uniform bool tile_override = false;
uniform float tile_rows = 2.0;
uniform vec4 tile_rect = vec4(0,0,1,1);
uniform bool frame_override=false;
uniform vec4 frame_rect=vec4(0,0,1,1);
uniform vec2 frame_source=vec2(1,1);
uniform bool magenta_key=false;
uniform bool glass_key=false;
uniform bool portrait=false;
uniform float meat_cuts=-1.;
uniform int broth_flavor=-1;
uniform float background_band=0.;
uniform float background_rows=1.;
varying vec3 world_pos;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
    // Only the chopping-board whole piece opts in. Its anchored remainder
    // loses a strip at each knife contact instead of being squashed sideways.
    if(meat_cuts>=0. && fract(UV.x*3.)>.86-meat_cuts*.21)discard;
    vec2 art_uv = UV;
    if (tile_override) { art_uv = tile_rect.xy + fract(UV * vec2(3.0,tile_rows)) * tile_rect.zw; }
    if(frame_override) art_uv=frame_rect.xy+UV*frame_source*frame_rect.zw;
    if(portrait){ art_uv=(floor(art_uv*vec2(704.,352.))+.5)/vec2(704.,352.); }
    vec4 tex = texture(art, art_uv);
    if(magenta_key && tex.r>tex.g*1.5 && tex.b>tex.g*1.5 && tex.b>.2) discard;
    if(portrait && tex.r>.84 && tex.g<.2 && tex.b<.2) discard;
    if (tex.a < alpha_cut) { discard; }
    vec3 col = tex.rgb * tint.rgb;
    if(broth_flavor>0 && tex.r>tex.g*1.6 && tex.g<.46 && tex.b<.3){
        float broth_mask=1.-smoothstep(.30,.46,tex.g);
        vec3 soup_color=broth_flavor==1 ? mix(vec3(.62,.60,.49),vec3(.93,.91,.78),tex.r) : mix(vec3(.71,.25,.035),vec3(.99,.55,.11),tex.r);
        col=mix(col,soup_color,broth_mask);
    }
    float local_y=exterior ? UV.y*background_rows-background_band : UV.y;
    float sky = 1.0 - smoothstep(0.20,0.52,local_y);
    if (exterior) {
        float grey = dot(col,vec3(.299,.587,.114));
        col = mix(col,vec3(grey*.81,grey*.88,grey*.97),overcast*.62);
        vec3 sunset_sky = mix(vec3(.76,.29,.24),vec3(.98,.66,.32),clamp(local_y/.55,0.0,1.0));
        col = mix(col,sunset_sky,sky*sunset*.9);
    }
    ALBEDO = col * 0.32;
    EMISSION = col * fill;
    if (cabin) {
        float lamp_pool = exp(-length((world_pos.xy-vec2(-1.0,1.0))*vec2(.28,.26)));
        float plant_pool = exp(-length((world_pos.xy-vec2(6.4,.0))*vec2(.5,.20)));
        float shadow=clamp(night*.66+overcast*.25,0.,.84);
        EMISSION=col*fill*mix(vec3(1.),vec3(.36,.43,.68),shadow);
        float sunbeam=exp(-pow((world_pos.x+world_pos.y*.7+1.8)*.35,2.));
        float low_room=1.-smoothstep(-.7,1.1,world_pos.y);
        EMISSION=mix(EMISSION,EMISSION*vec3(1.04,.94,.87),sunset*.55);
        EMISSION+=col*vec3(.095,.049,.012)*sunbeam*sunset*low_room*(1.-overcast*.8);
        EMISSION += col * vec3(.58,.29,.065)*lamp_pool*max(night,overcast*.64);
        EMISSION += col * vec3(.025,.23,.20)*plant_pool*night;
    }
    ROUGHNESS = 1.0;
    if (exterior) {
        vec3 night_sky = vec3(0.035,0.080,0.14);
        float darkness = sky * night * 0.8 * (1.0-sunset*.8);
        ALBEDO = mix(ALBEDO, night_sky * 0.3, darkness);
        EMISSION = mix(EMISSION, night_sky * 0.5, darkness);
    }
}
