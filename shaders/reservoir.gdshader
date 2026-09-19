shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D art:source_color,filter_nearest;
uniform vec4 source_rect;
uniform float water_level=.4;
uniform float valve=0.;
uniform float night=0.;
uniform float sunset=0.;
uniform float overcast=0.;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}

// Every visible texel comes from the original RV atlas. The glass, water
// surface, bubbles and copper handle are sampled parts, never new shapes.
vec4 original(vec2 p){
 return texture(art,source_rect.xy+p/vec2(175.,180.)*source_rect.zw);
}

void fragment(){
 vec2 p=UV*vec2(175.,180.);
 vec4 c=original(p);
 vec2 center=vec2(81.,88.);
 vec2 radius=vec2(77.,77.);
 vec2 sphere=(p-center)/radius;
 // Leave the original rim and the bottom pipe connector absolutely fixed.
 if(length(sphere)<.89 && p.y>19. && p.y<146.){
   float line=mix(148.,36.,clamp(water_level,0.,1.));
   float source_line=68.;
   float half_surface=10.;
   float source_y;
   if(p.y<line-half_surface){
     source_y=mix(19.,source_line-half_surface,clamp((p.y-19.)/max(1.,line-half_surface-19.),0.,1.));
   }else if(p.y<=line+half_surface){
     // Keep the painted oval water-surface band; slide it down as water flows.
     source_y=source_line+(p.y-line);
   }else{
     source_y=mix(source_line+half_surface,146.,clamp((p.y-line-half_surface)/max(1.,146.-line-half_surface),0.,1.));
   }
   float target_width=sqrt(max(.04,1.-pow((p.y-center.y)/radius.y,2.)));
   float source_width=sqrt(max(.04,1.-pow((source_y-center.y)/radius.y,2.)));
   float source_x=center.x+(p.x-center.x)*source_width/target_width;
   c=original(vec2(source_x,source_y));
 }
 if(valve>.001){
   // The atlas handle is the small horizontal copper lever ABOVE the pipe.
   // Expose the adjacent original wall behind its closed position. The pipe,
   // connector and stem below y=155 stay in their original position.
   if(p.x>=112. && p.x<136. && p.y>=146. && p.y<155.)c=original(p+vec2(33.,0.));
   vec2 pivot=vec2(123.,151.);
   float angle=valve*1.20;
   vec2 d=p-pivot;
   vec2 q=pivot+vec2(cos(angle)*d.x+sin(angle)*d.y,-sin(angle)*d.x+cos(angle)*d.y);
   if(q.x>=112. && q.x<136. && q.y>=146. && q.y<155.){
     vec4 handle=original(q);
     // Exclude the cream wall between pixels of the original lever cutout.
     if(handle.b<.28 && handle.g<.65)c=handle;
   }
 }
 if(c.a<.5)discard;
 // Same room-light response as the other original-atlas moving pieces.
 ALBEDO=c.rgb*.38;
 float pool=exp(-length((world_pos.xy-vec2(-1.,1.))*vec2(.28,.26)));
 EMISSION=c.rgb*.91*mix(vec3(1.),vec3(.36,.43,.68),clamp(night*.66+overcast*.25,0.,.84));
 EMISSION+=c.rgb*vec3(.58,.29,.065)*pool*max(night,overcast*.64);
 EMISSION=mix(EMISSION,EMISSION*vec3(1.08,.87,.77),sunset*.45);
 ROUGHNESS=1.;
}
