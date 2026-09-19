shader_type canvas_item;
uniform vec2 pixel_grid=vec2(640.,360.);
void fragment(){
 vec2 p=(floor(UV*pixel_grid)+.5)/pixel_grid;
 COLOR=texture(TEXTURE,p);
}
