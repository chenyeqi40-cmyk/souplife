shader_type canvas_item;
varying vec4 vertex_tint;
void vertex(){vertex_tint=COLOR;}
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 if(c.r>.65 && c.b>.6 && c.g<.35) c.a=0.;
 COLOR=c*vertex_tint;
}
