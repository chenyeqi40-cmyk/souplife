shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D art : source_color, filter_nearest;
uniform vec4 source_rect=vec4(0,0,1,1);
uniform vec4 tint : source_color=vec4(1);
uniform float night=0.0;
uniform float sunset=0.0;
uniform float overcast=0.0;
uniform float growth=1.0;
uniform bool plant=false;
uniform bool leaves_only=false;
uniform bool packet=false;
uniform float torn=0.0;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=UV;
 vec4 tex=texture(art,source_rect.xy+p*source_rect.zw);
 if(packet){
   float edge=mix(.06,.015,smoothstep(.68,1.,p.y));
   if(p.x<edge || p.x>1.-edge) discard;
   if(torn>.5 && p.y<.06+.018*mod(floor(p.x*14.),2.)) discard;
 }
 if(plant){
   bool green=tex.g>tex.r*1.06 && tex.g>tex.b*1.13;
   if(leaves_only){if(!green || p.y>.70) discard;}
   else if(growth<.999 && p.x>.13 && p.x<.89 && p.y>.05 && p.y<.83){
     vec2 clean=vec2(.08,p.y);
     tex=texture(art,source_rect.xy+clean*source_rect.zw);
     float s=.25+.75*growth;
     vec2 q=(p-vec2(.5,.66))/s+vec2(.5,.66);
     vec4 leaf=texture(art,source_rect.xy+q*source_rect.zw);
     if(growth>.01 && q.x>.14 && q.x<.89 && q.y>.05 && q.y<.7 && leaf.g>leaf.r*1.06 && leaf.g>leaf.b*1.13) tex=leaf;
   }
 }
 if(tex.a<.5) discard;
 vec3 c=tex.rgb*tint.rgb;
 ALBEDO=c*.38;
 float pool=exp(-length((world_pos.xy-vec2(-1.,1.))*vec2(.28,.26)));
 EMISSION=c*.91*mix(vec3(1.),vec3(.36,.43,.68),clamp(night*.66+overcast*.25,0.,.84));
 EMISSION+=c*vec3(.58,.29,.065)*pool*max(night,overcast*.64);
 EMISSION=mix(EMISSION,EMISSION*vec3(1.08,.87,.77),sunset*.45);
 ROUGHNESS=1.;
}
