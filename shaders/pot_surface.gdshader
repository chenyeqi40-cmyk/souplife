shader_type spatial;
render_mode unshaded, cull_disabled;
uniform int water_state=0;
uniform float elapsed=0.;
uniform bool simmer=false;
uniform bool noodles=false;
uniform float night=0.;
uniform float sunset=0.;
uniform float overcast=0.;
uniform float boil_intensity=0.;
uniform int flavor=0;
void fragment(){
 vec2 px=floor(UV*vec2(90,30));
 vec2 p=(px+0.5)/vec2(90,30);
 float r=length((p-.5)*2.);
 if(r>1.) discard;
 vec3 c=mix(vec3(.34,.34,.39),vec3(.54,.53,.52),p.y);
 float ring=step(.88,r);
 if(water_state==1){
  c=mix(vec3(.32,.48,.50),vec3(.66,.74,.67),p.y*.65);
  float ripple=step(.965,sin(p.x*36.+sin(p.y*30.+elapsed)*2.+elapsed*1.2));
  c+=ripple*.07;
 }
 if(water_state==2){
  c=mix(vec3(.30,.15,.065),vec3(.66,.32,.09),p.y);
  if(flavor==1)c=mix(vec3(.71,.70,.60),vec3(.94,.91,.77),p.y);
  if(flavor==2)c=mix(vec3(.75,.29,.05),vec3(.98,.57,.16),p.y);
  if(noodles){
   float noodle=step(.55,sin(p.x*50.+sin(p.y*34.)*3.));
   c=mix(c,vec3(.77,.54,.21),noodle*.26);
  }
 }
 c=mix(c,vec3(.42,.43,.47),ring*.8);
 // Four places are indicated directly on the liquid / empty pot floor.
 bool cross=(abs(p.x-.5)<.009 && mod(px.y,5.)<2.) || (abs(p.y-.5)<.026 && mod(px.x,8.)<4.);
 if(water_state==0 && (!cross || r>.80)) discard;
 if(cross && r<.91) c=mix(c,vec3(.94,.90,.73),.6);
 // Bubbles grow from a pinprick to a ring before popping and starting again.
 if(simmer && water_state>0){
  for(int i=0;i<18;i++){
   float seed=float(i);
   float a=seed*2.39996;
   float distance_from_center=.11+mod(seed*.137,.30);
   vec2 center=.5+vec2(cos(a),sin(a))*distance_from_center;
   float age=fract(elapsed*(.48+boil_intensity*.85)+seed*.317);
   float radius=mix(.004,.025+boil_intensity*.024,age);
   float d=length((p-center)*vec2(1.,.75));
   float ring_bubble=1.-step(.008,abs(d-radius));
   float visible=step(seed/18.,boil_intensity)*step(age,.92);
   c=mix(c,mix(vec3(.90,.72,.35),vec3(.98,.96,.83),flavor==1?1.:0.),ring_bubble*visible*.78);
  }
 }
 c*=mix(vec3(1),vec3(.48,.57,.74),night*.53+overcast*.18);
 c+=vec3(.13,.065,.01)*(night+sunset*.7);
 ALBEDO=c;
}
