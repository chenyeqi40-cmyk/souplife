extends Control
const FRIDGE=Rect2(12,489,213,173)
const WINDOW=Rect2(49,118,1193,488)
const ARENA=Rect2(53,122,1185,480)
var game
var hunt:Panel
var cold:Panel
var closeup:Panel
var title:Label
var detail:Label
var portrait:TextureRect
var hunt_note:Label
var cold_labels=[]
var cold_slots=[]
var cold_pictures=[]
var targets=[]
var armed=false
var cooldown=0.0
var startled=-1.0
var pointer=Vector2.ZERO
var hit_count=0
var shots=0
var total_hunted=0
var cold_pinned=false
var cold_suppressed=false
var fridge_amount=0.0
var door:MeshInstance3D
var hinge:Node3D
var recess:MeshInstance3D
var grabbed=-1
var grab_start=Vector2.ZERO
var drag_pic:TextureRect
var closeup_age=0.0
var hunt_paint:Control
var hunt_button:Button
var hunt_background:TextureRect
var hunt_room:TextureRect
var window_content:Control
var rifle:TextureRect
var recoil=0.0
var drops=[]
var ammo=6
var reload_remaining=0.0
var bolt_age=-1.0
var muzzle_time=0.0
var casings=[]
var ammo_label:Label
var reload_button:Button
const RELOAD_SECONDS=1.05
const SCOPE_ZOOM=3.2
const SCOPE_RADIUS=228.0
const LOOT_BAG=Vector2(1207,676)
const COLD_IDS=[11,12,13,14,15,16]
const HUNT_REGIONS=[
	{"name":"嫩掌蜥的晒背坡","animal":"嫩掌蜥","plural":"蜥蜴","meat":11},
	{"name":"响石岩坡","animal":"响石岩兔","plural":"岩兔","meat":15},
	{"name":"白盐浅滩","animal":"盐帆泽鸭","plural":"泽鸭","meat":16}
]
const CABIN_SOURCE=Rect2(276,108,780,392.4375)
const FULL_WINDOW=Rect2(305.859375,137.25,727.0,297.375)
const RARE_CHANCE=.20
var cabin_view:Control
var hunt_header:Control
var drive_clip:Control
var drive_scene:TextureRect
var drive_outside:MeshInstance3D
var drive_material:ShaderMaterial
var exterior_was_visible=true
var character_was_visible=false
var travel_seed=0
var trip_count=0
var rare_hunted=0
var hunt_rng=RandomNumberGenerator.new()
var scope_view:ColorRect
var scope_button:Button
var scope_active=false
var phase="idle"
var phase_age=0.0
var drive_amount=0.0
var hint_label:Label
var loot_layer:Control
var loot_toasts=[]
var next_loot_id=1
var loot_claimed={}
var impact_marks=[]
var bag_bounce=0.0
var animation_texture:Texture2D
var regional_animation:Texture2D
var hunt_title:Label
var active_region=0
var active_encounter_key=""
var region_hunted=[0,0,0]
var encounters={}
var empty_announced=false
var migration_notice=false

func setup(g):
	game=g;size=Vector2(1280,800);mouse_filter=2;z_index=60
	hunt_button=game._button(game.ui,"收摊后 · 去晒背坡",Rect2(32,626,235,33),open_hunt,game.PAPER,14)
	hunt_button.tooltip_text="嫩掌蜥在晒背坡缓慢游走。偶见红掌变体，红纹肉香更浓，是要冷藏保存的稀有美味。"
	hunt=game._panel(self,Rect2(0,0,1280,800),Color("323f42"));hunt.hide()
	drive_clip=Control.new();drive_clip.size=Vector2(1280,714);drive_clip.clip_contents=true;drive_clip.mouse_filter=2;hunt.add_child(drive_clip)
	drive_scene=TextureRect.new();drive_scene.texture=game.viewport3d.get_texture();drive_scene.expand_mode=1;drive_scene.stretch_mode=0;drive_scene.size=Vector2(1280,714);drive_scene.texture_filter=1;drive_scene.mouse_filter=2;drive_clip.add_child(drive_scene)
	# The original live cabin is the travel camera. A separate paper plane is
	# behind its existing frame and awning, so nothing on the counter moves.
	drive_material=ShaderMaterial.new();drive_material.shader=load("res://shaders/hunt_drive.gdshader");drive_material.set_shader_parameter("terrain",load("res://assets/hunt_wilderness.png"))
	var outside=Rect2(268,98,808,369)
	var outside_uv=Rect2((outside.position-FULL_WINDOW.position)/FULL_WINDOW.size,outside.size/FULL_WINDOW.size)
	drive_outside=game._quad("HuntTravelOutsideOnly",Rect2(outside.position*1.2265625,outside.size*1.2265625),-3.8,drive_material,outside_uv);drive_outside.hide()
	cabin_view=Control.new();cabin_view.size=Vector2(1280,714);cabin_view.mouse_filter=2;hunt.add_child(cabin_view)
	# The close camera samples the same live cabin as the trip. The original
	# window board, awning and strip lamp stay in their continuous positions.
	var room_tex=AtlasTexture.new();room_tex.atlas=game.viewport3d.get_texture()
	room_tex.region=Rect2(276.0/1280*room_tex.atlas.get_width(),108.0/714*room_tex.atlas.get_height(),780.0/1280*room_tex.atlas.get_width(),392.4375/714*room_tex.atlas.get_height())
	hunt_room=TextureRect.new();hunt_room.texture=room_tex;hunt_room.expand_mode=1;hunt_room.stretch_mode=0;hunt_room.position=Vector2(0,70);hunt_room.size=Vector2(1280,644);hunt_room.texture_filter=1;hunt_room.mouse_filter=2;cabin_view.add_child(hunt_room)
	window_content=Control.new();window_content.position=WINDOW.position;window_content.size=WINDOW.size;window_content.clip_contents=true;window_content.mouse_filter=2;cabin_view.add_child(window_content)
	var bg=TextureRect.new();bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.texture=load("res://assets/hunt_wilderness.png");bg.size=WINDOW.size;bg.stretch_mode=TextureRect.STRETCH_SCALE;bg.texture_filter=1;bg.mouse_filter=2;window_content.add_child(bg)
	hunt_background=bg
	# The wilderness is now drawn by the original 3D viewport behind its awning.
	# Keep this material as the shared travel coordinate source, not a covering layer.
	bg.hide()
	var terrain=ShaderMaterial.new();terrain.shader=load("res://shaders/hunt_terrain.gdshader");bg.material=terrain
	var screen_copy=BackBufferCopy.new();screen_copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;hunt.add_child(screen_copy)
	scope_view=ColorRect.new();scope_view.position=Vector2(0,70);scope_view.size=Vector2(1280,644);scope_view.mouse_filter=2;scope_view.hide()
	var glass=ShaderMaterial.new();glass.shader=load("res://shaders/hunt_scope.gdshader");scope_view.material=glass;hunt.add_child(scope_view)
	hunt_header=Control.new();hunt_header.size=Vector2(1280,70);hunt_header.mouse_filter=2;hunt.add_child(hunt_header)
	hunt_title=game._label(hunt_header,"收摊后 / 嫩掌蜥的晒背坡",Rect2(30,14,510,33),21,game.PAPER)
	ammo_label=game._label(hunt_header,"弹仓 6 / 6",Rect2(573,22,135,26),16,game.PAPER)
	scope_button=game._button(hunt_header,"开镜 · 右键",Rect2(713,16,162,39),func():set_scoped(not scope_active),game.PAPER,16)
	reload_button=game._button(hunt_header,"换弹 · R",Rect2(889,16,184,39),begin_reload,game.PAPER,16)
	game._button(hunt_header,"返回休息",Rect2(1100,16,148,39),leave_hunt,game.PAPER,16)
	hunt_note=game._label(hunt,"关好摊窗，准备去晒背坡。",Rect2(32,724,1216,29),17,Color("fff0c8"))
	hint_label=game._label(hunt,"右键开镜 · 移动鼠标瞄准 · 左键射击 · R 换弹 · 收获会自动飞回背包",Rect2(32,760,1216,27),16,game.PAPER)
	rifle=make_icon(hunt,null,Rect2(623,356,850,465));rifle.pivot_offset=Vector2(680,391)
	var rifle_file="res://assets/hunt_rifle_scope.png" if ResourceLoader.exists("res://assets/hunt_rifle_scope.png") else "res://assets/hunt_rifle.png"
	if ResourceLoader.exists(rifle_file):rifle.texture=load(rifle_file)
	if ResourceLoader.exists("res://assets/hunt_lizard_motion.png"):animation_texture=load("res://assets/hunt_lizard_motion.png")
	if ResourceLoader.exists("res://assets/hunt_regional_motion.png"):regional_animation=load("res://assets/hunt_regional_motion.png")
	loot_layer=Control.new();loot_layer.size=Vector2(1280,714);loot_layer.mouse_filter=2;hunt.add_child(loot_layer)
	hunt_paint=load("res://scripts/hunt_paint.gd").new();hunt_paint.field=self;hunt_paint.size=Vector2(1280,714);hunt_paint.mouse_filter=2;hunt.add_child(hunt_paint)
	cold=Panel.new();cold.position=Vector2(17,490);cold.size=Vector2(206,134);cold.z_index=43
	cold.add_theme_stylebox_override("panel",StyleBoxEmpty.new());cold.mouse_filter=2;add_child(cold);cold.hide()
	var lining=TextureRect.new();lining.position=Vector2.ZERO;lining.size=cold.size
	var lining_art=AtlasTexture.new();lining_art.atlas=load("res://assets/fridge_interior.png")
	lining_art.region=Rect2(57,75,1424,875);lining.texture=lining_art
	lining.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;lining.stretch_mode=TextureRect.STRETCH_SCALE;lining.texture_filter=1;lining.mouse_filter=2;cold.add_child(lining)
	for i in range(COLD_IDS.size()):
		var slot=Control.new();slot.position=Vector2(20+i%2*85,10+int(i/2)*32);slot.size=Vector2(80,31);slot.mouse_filter=1
		slot.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;cold.add_child(slot);cold_slots.append(slot)
		var p=make_icon(slot,food_icon(COLD_IDS[i]),Rect2(0,0,61,30));cold_pictures.append(p)
		var l=game._label(slot,"",Rect2(56,13,24,16),10,Color("f4edd5"));l.horizontal_alignment=1
		l.add_theme_color_override("font_shadow_color",Color("27352e"));l.add_theme_constant_override("shadow_outline_size",3);cold_labels.append(l)
	closeup=game._panel(self,Rect2(0,0,1280,800),Color(.06,.08,.09,.91));closeup.z_index=90;closeup.hide()
	var paper=game._panel(closeup,Rect2(341,103,598,575),game.PAPER)
	title=game._label(paper,"",Rect2(28,18,540,35),25)
	portrait=make_icon(paper,null,Rect2(142,62,314,285))
	detail=game._label(paper,"",Rect2(35,365,526,123),18)
	game._button(paper,"收好了",Rect2(189,506,220,43),func():closeup.hide(),game.TEAL,17)
	drag_pic=make_icon(self,null,Rect2(0,0,102,85));drag_pic.z_index=200;drag_pic.hide()
	# The reference's horizontal door seam is at screen y=622..627.
	# Only the upper door (ending at y=624) swings; the lower door stays in the supplied cabin art.
	var dark=StandardMaterial3D.new();dark.albedo_color=Color("293e3d");dark.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;dark.cull_mode=BaseMaterial3D.CULL_DISABLED
	recess=game._quad("ColdInterior",Rect2(15*1.22656,490*1.22656,207*1.22656,132*1.22656),1.17,dark);recess.hide()
	door=game.prep.reference_piece("OpeningFridgeDoor",Rect2(12,488,212,136),Rect2(12.0/1280,488.0/714,212.0/1280,136.0/714),1.19)
	hinge=Node3D.new();game.world.add_child(hinge);hinge.position=door.position-Vector3(212*.012265625/2,0,0)
	door.reparent(hinge,true)
	for id in COLD_IDS:
		var m=game.prep.cut_meat_sprite("ColdTopping"+str(id),id,Rect2(626+(id-11)*36,549,66,48),1.97) if id in [11,14,15,16] else game.prep._sprite("ColdTopping"+str(id),"regional_food.png" if id==12 else "wildlife.png",1 if id==12 else 4,1 if id==12 else 2,Rect2(626+(id-11)*36,549,66,48),1.97)
		m.material_override.set_shader_parameter("magenta_key",true);m.hide();game.toppings.append(m);game.service.original_positions.append(m.position)
	for m in [game.service.special_meshes[2],game.toppings[10]]:
		m.material_override.set_shader_parameter("art",load("res://assets/wildlife.png"))
		game.prep._tile(m,4,2)

func atlas(cell:int,inner:Rect2=Rect2(0,0,1,1))->AtlasTexture:
	var a=AtlasTexture.new();a.atlas=load("res://assets/wildlife.png")
	var s=Vector2(a.atlas.get_width()/3.0,a.atlas.get_height()/2.0)
	a.region=Rect2(Vector2(cell%3,int(cell/3))*s+inner.position*s,inner.size*s)
	if cell<2:a.region=Rect2(0 if cell==0 else 546,105,546 if cell==0 else 523,318)
	return a

func food_icon(id:int)->Texture2D:
	if id in [15,16]:
		var meat=AtlasTexture.new();meat.atlas=load("res://assets/hunt_regional_meat.png")
		var cell=Vector2(meat.atlas.get_width()/2.0,meat.atlas.get_height())
		meat.region=Rect2(Vector2(cell.x if id==16 else 0.0,0),cell)
		return meat
	if id in [11,14]:
		if ResourceLoader.exists("res://assets/lizard_meat.png"):
			var meat=AtlasTexture.new();meat.atlas=load("res://assets/lizard_meat.png")
			var cell=Vector2(meat.atlas.get_width()/2.0,meat.atlas.get_height())
			meat.region=Rect2(Vector2(cell.x if id==14 else 0.0,0),cell)
			return meat
		return atlas(2,Rect2(.10,.18,.69,.72))
	if id==12:return game._ingredient_icon(9)
	if id==13:return atlas(4)
	return game._ingredient_icon(id)

func make_icon(parent,tex,rect:Rect2)->TextureRect:
	var p=TextureRect.new();p.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;p.texture=tex;p.position=rect.position;p.size=rect.size;p.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;p.texture_filter=1;p.mouse_filter=2
	var m=ShaderMaterial.new();m.shader=load("res://shaders/icon_key.gdshader");p.material=m;parent.add_child(p);return p

func modal_open()->bool:
	return hunt.visible or cold.visible or closeup.visible

func close_fridge():
	cold_pinned=false;cold_suppressed=true;cold.hide()

func open_hunt():
	if game.title_screen.visible or closeup.visible or hunt.visible:return
	var cycle=game.get("day_cycle")
	if cycle==null or not cycle.can_hunt():
		game._notice("先结束今天的营业，再出发打猎。");return
	if game.stage!=0 or not game.selected.is_empty() or game.prep.board_item>=0:
		game._notice("先收好这碗面和砧板，再去晒背坡。");return
	active_region=clampi(game.economy.map_index,0,2)
	active_encounter_key=str(game.day)+":"+str(active_region)
	for key in encounters.keys():
		if not str(key).begins_with(str(game.day)+":"):encounters.erase(key)
	_configure_biome()
	game.v4.close_conversation();game.backpack.pinned=false;close_fridge();game.economy.panel.hide()
	if cycle.has_method("dismiss_management"):cycle.dismiss_management()
	# Finish pending rewards before beginning another trip, including a restored
	# save whose first field tick has not run yet.
	_flush_loot()
	for drop in drops:if is_instance_valid(drop.pic):drop.pic.queue_free()
	drops.clear();loot_toasts.clear()
	for a in targets:if is_instance_valid(a.pic):a.pic.queue_free()
	targets.clear();armed=false;startled=-1;cooldown=0;hit_count=0;shots=0;recoil=0;reload_remaining=0;bolt_age=-1;muzzle_time=0;casings.clear();impact_marks.clear();empty_announced=false
	phase="driving";phase_age=0.0;drive_amount=0.0;scope_active=false
	trip_count+=1
	if travel_seed==0:travel_seed=int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec())
	hunt_rng.seed=travel_seed+trip_count*7919
	_set_travel_offset(0.0)
	pointer=WINDOW.get_center()
	hunt_background.modulate=Color("8196b6") if game.hour>=19 or game.hour<6 else Color("edb68d") if game.hour>=17 else Color.WHITE
	drive_material.set_shader_parameter("tint",hunt_background.modulate)
	hunt_room.modulate=Color.WHITE
	character_was_visible=game.character.visible;game.character.hide()
	var exterior=game.world.find_child("Exterior_Skyline",true,false)
	exterior_was_visible=exterior.visible;exterior.hide();drive_outside.show()
	fridge_amount=0.0;hinge.rotation.y=0.0;recess.hide()
	drive_clip.show();drive_scene.scale=Vector2.ONE;drive_scene.position=Vector2.ZERO;cabin_view.hide()
	hunt.move_child(hunt_paint,hunt.get_child_count()-1)
	hunt_note.text="去%s的路上。我们留在车里，看窗外慢慢向后退。"%HUNT_REGIONS[active_region].name
	rifle.hide();scope_view.hide();_set_cabin_zoom(1.0)
	hunt_header.hide();hint_label.text="看着窗外的风景就好。停稳后再开镜狩猎。 · Esc 返回休息"
	scope_button.disabled=true;reload_button.disabled=true
	hunt.show()
	game._save()

func capacity()->int:
	if game and game.economy:
		if "magazine_10" in game.economy.upgrades:return 10
		if "magazine_8" in game.economy.upgrades:return 8
	return 6

func _configure_biome():
	hunt_title.text="收摊后 / "+HUNT_REGIONS[active_region].name
	var texture=load("res://assets/hunt_wilderness.png") if active_region==0 else load("res://assets/hunt_regions.png")
	drive_material.set_shader_parameter("terrain",texture)
	drive_material.set_shader_parameter("terrain_rect",Vector4(0,0,1,1) if active_region==0 else Vector4((active_region-1)*.5,0,.5,1))
	if active_region==0:hunt_background.texture=texture
	else:
		var panel=AtlasTexture.new();panel.atlas=texture
		panel.region=Rect2((active_region-1)*texture.get_width()/2.0,0,texture.get_width()/2.0,texture.get_height());hunt_background.texture=panel

func _set_cabin_zoom(amount:float):
	cabin_view.scale=Vector2.ONE*amount
	cabin_view.position=WINDOW.get_center()*(1.0-amount)

func _set_travel_offset(value:float):
	hunt_background.material.set_shader_parameter("travel_offset",value)
	drive_material.set_shader_parameter("travel_offset",value)

func _set_drive_camera(t:float):
	# Continuous crop of the same live scene, not a cut to a different room.
	var zoom=lerpf(1.0,1280.0/CABIN_SOURCE.size.x,t)
	drive_scene.scale=Vector2.ONE*zoom
	drive_scene.position=Vector2.ZERO.lerp(Vector2(0,70)-CABIN_SOURCE.position*(1280.0/CABIN_SOURCE.size.x),t)

func _population_plan(rng:RandomNumberGenerator,region:int=-1)->Array:
	if region<0:region=active_region
	var count=rng.randi_range(6,7)
	var rare_index=rng.randi_range(0,count-1) if region==0 and rng.randf()<RARE_CHANCE else -1
	var plan=[]
	for i in range(count):
		var column=i%4;var row=int(i/4)
		var width=rng.randf_range(111,138)
		var position=Vector2(147+column*259+rng.randf_range(-21,21),376+row*80+rng.randf_range(-13,13))
		plan.append({"rect":Rect2(position,Vector2(width,width*.59)),"rare":i==rare_index,"direction":-1 if rng.randf()<.5 else 1,"speed":rng.randf_range(68,99),"patrol":rng.randf_range(15,30),"region":region,"alive":true})
	return plan

func _arrive():
	phase="hunting";phase_age=0.0;armed=true;_set_cabin_zoom(1.0)
	drive_clip.hide();cabin_view.show()
	hunt_header.show();hint_label.text="右键开镜 · 移动鼠标瞄准 · 左键射击 · R 换弹 · 收获自动飞回背包 · Esc 返回"
	var population=_load_encounter()
	var has_rare=false
	for i in range(population.size()):
		var animal=population[i]
		if not animal.get("alive",true):continue
		var rect=Rect2(animal.rect.position-WINDOW.position,animal.rect.size)
		var pic=make_icon(window_content,animal_frame(active_region,0),rect)
		if animal.rare:
			var rare_material=ShaderMaterial.new();rare_material.shader=load("res://shaders/hunt_rare.gdshader");pic.material=rare_material;has_rare=true
		targets.append({"pic":pic,"alive":true,"rare":animal.rare,"direction":animal.direction,"speed":animal.speed,"patrol":animal.patrol,"region":active_region,"origin":rect.position,"walk_age":i*.27,"fall_age":-1.0,"last_frame":-1})
	_set_target_frames()
	rifle.visible=rifle.texture!=null
	scope_button.disabled=false
	hunt_note.text="发现红掌蜥！红色嫩掌藏着稀有美味。右键开镜，慢慢瞄准。" if has_rare else "停稳了。远处有 %d 只%s在走动——右键开镜，再扣动扳机。"%[targets.size(),HUNT_REGIONS[active_region].animal]
	_record_encounter();_check_empty();game._save()
	if ammo<=0:begin_reload()

func _load_encounter()->Array:
	if not encounters.has(active_encounter_key):return _population_plan(hunt_rng)
	var population=[]
	for saved in encounters[active_encounter_key]:
		population.append({"rect":Rect2(float(saved.x),float(saved.y),float(saved.w),float(saved.h)),"rare":bool(saved.get("rare",false)) and active_region==0,"alive":bool(saved.get("alive",false)),"direction":int(saved.get("direction",1)),"speed":float(saved.get("speed",80)),"patrol":float(saved.get("patrol",22)),"region":active_region})
	return population

func _record_encounter():
	if phase!="hunting" or active_encounter_key.is_empty():return
	var stored=[]
	for a in targets:
		if not is_instance_valid(a.pic):continue
		var rect=a.pic.get_global_rect()
		stored.append({"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y,"alive":a.alive,"rare":a.get("rare",false),"direction":a.direction,"speed":a.speed,"patrol":a.patrol})
	encounters[active_encounter_key]=stored

func _check_empty():
	if empty_announced or phase!="hunting":return
	for a in targets:
		if a.alive or (a.fall_age>=0 and a.fall_age<.70):return
	empty_announced=true
	hunt_note.text="这片区域暂时不会有%s来了。收好材料，回房车休息吧。"%HUNT_REGIONS[active_region].plural
	game._save()

func animal_frame(region:int,frame:int)->Texture2D:
	if region==0:return lizard_frame(frame)
	var atlas_texture=AtlasTexture.new();atlas_texture.atlas=regional_animation
	var cell=Vector2(regional_animation.get_width()/4.0,regional_animation.get_height()/2.0)
	atlas_texture.region=Rect2(Vector2(frame,region-1)*cell+Vector2(3,3),cell-Vector2(6,6))
	return atlas_texture

func lizard_frame(frame:int)->Texture2D:
	if animation_texture:
		var a=AtlasTexture.new();a.atlas=animation_texture
		var cell=Vector2(animation_texture.get_width()/4.0,animation_texture.get_height()/2.0)
		a.region=Rect2(Vector2(frame%4,int(frame/4))*cell+Vector2(3,3),cell-Vector2(6,6))
		return a
	return atlas(1 if game.hour>=18 or game.hour<6 else 0)

func _set_target_frames():
	for a in targets:
		var frame=mini(7,4+int(a.fall_age/.18)) if a.fall_age>=0 else int(a.walk_age*7)%4
		if a.get("region",0)>0:frame=(2 if a.fall_age<.28 else 3) if a.fall_age>=0 else int(a.walk_age*7)%2
		if frame!=a.last_frame:a.pic.texture=animal_frame(a.get("region",0),frame);a.last_frame=frame
		a.pic.flip_h=a.direction<0

func set_scoped(value:bool):
	if value and (phase!="hunting" or not armed or reload_remaining>0):return
	scope_active=value;scope_view.visible=value
	scope_button.text="收镜 · 右键" if value else "开镜 · 右键"
	rifle.visible=armed and not value and rifle.texture!=null
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN if value else Input.MOUSE_MODE_VISIBLE
	if value and not empty_announced:hunt_note.text="镜中放大 3.2 倍。移动鼠标跟住它，左键射击。"
	_sync_scope()

func scope_aim()->Vector2:
	var edge=SCOPE_RADIUS/SCOPE_ZOOM+3.0
	return Vector2(clampf(pointer.x,WINDOW.position.x+edge,WINDOW.end.x-edge),clampf(pointer.y,WINDOW.position.y+edge,WINDOW.end.y-edge))

func _sync_scope():
	scope_view.material.set_shader_parameter("aim",scope_aim())
	scope_view.material.set_shader_parameter("lens",WINDOW.get_center())
	scope_view.material.set_shader_parameter("kick",recoil)

func world_to_lens(point:Vector2)->Vector2:
	return WINDOW.get_center()+(point-scope_aim())*SCOPE_ZOOM if scope_active else point

func leave_hunt():
	_record_encounter()
	_flush_loot()
	set_scoped(false);hunt.hide();armed=false;phase="idle";drive_outside.hide()
	game.world.find_child("Exterior_Skyline",true,false).visible=exterior_was_visible
	game.character.visible=character_was_visible
	game._refresh();game._save()

func show_species(region:int):
	if region==0:show_closeup("嫩掌蜥 / 偶见红掌变体",lizard_frame(0),"晒背坡 · 白天晒背，入夜缓行\n背上仙人掌储存香气，普通个体产鲜肉与嫩掌片。偶见红掌蜥，红纹皮下的肉香更浓，是稀有美味。\n蜥肉冷藏，切片后煮至五格。")
	elif region==1:show_closeup("响石岩兔",animal_frame(1,0),"铁轨哨站外 · 响石岩坡\n长耳听见远处碎石声，背肩矿质护甲挡住砂砾。吃低矮草木，身上的石甲不是共生植物。\n岩兔肉冷藏保存，切片后煮到四格。")
	else:show_closeup("盐帆泽鸭",animal_frame(2,0),"盐湖渡口外 · 白盐浅滩\n盐白冠羽像一面小帆，宽脚踩过软泥。它们沿浅水觅食，羽毛上结出的薄盐会在淡水中化开。\n泽鸭肉冷藏保存，切片后煮到三格。")

func shoot(p:Vector2)->bool:
	if not hunt.visible or phase!="hunting" or not armed or cooldown>0 or reload_remaining>0 or bolt_age>=0 or not ARENA.has_point(p):return false
	if empty_announced:return false
	if not scope_active:hunt_note.text="它们离得很远。先右键开镜，才能准确命中。";return false
	pointer=p
	var aim=scope_aim()
	if ammo<=0:begin_reload();return false
	cooldown=.52;shots+=1;recoil=1.0;ammo-=1;bolt_age=0.0;muzzle_time=.085
	game.audio.play_at("air_rifle",clampf(p.x/640-1,-1,1),-12)
	if startled<0:startled=0
	for a in targets:
		if a.alive and _target_hit(a,aim):
			a.alive=false;hit_count+=1;total_hunted+=1
			region_hunted[active_region]+=1
			if a.get("rare",false):rare_hunted+=1
			a.fall_age=0.0
			var foot=a.pic.get_global_rect().get_center();foot.y=minf(a.pic.get_global_rect().end.y-22,ARENA.end.y-43)
			impact_marks.append({"point":aim,"age":0.0})
			_spawn_drop(14 if a.get("rare",false) else HUNT_REGIONS[active_region].meat,foot+Vector2(-27 if active_region==0 else 0,0))
			if active_region==0:_spawn_drop(8,foot+Vector2(27,0))
			hunt_note.text="稀有美味！红掌蜥肉会单独收进冰箱，留给下一碗好面。" if a.get("rare",false) else "命中了！收获马上送回背包，留意其他%s的方向。"%HUNT_REGIONS[active_region].plural
			game._save();return true
	hunt_note.text="这次打偏了。留意它们移动的方向。";game._save();return false

func _target_hit(target:Dictionary,point:Vector2)->bool:
	var rect=target.pic.get_global_rect()
	if not rect.grow(-3).has_point(point):return false
	var texture:Texture2D=target.pic.texture
	var dimensions=texture.get_size()
	var fit=minf(rect.size.x/dimensions.x,rect.size.y/dimensions.y)
	var local=point-rect.position-(rect.size-dimensions*fit)*.5
	if local.x<0 or local.y<0 or local.x>=dimensions.x*fit or local.y>=dimensions.y*fit:return false
	var x=clampi(int(local.x/fit),0,int(dimensions.x)-1)
	var y=clampi(int(local.y/fit),0,int(dimensions.y)-1)
	if target.pic.flip_h:x=int(dimensions.x)-1-x
	var color=texture.get_image().get_pixel(x,y)
	return color.a>.1 and not (color.r>.65 and color.b>.6 and color.g<.35)

func begin_reload()->bool:
	if not hunt.visible or phase!="hunting" or not armed or reload_remaining>0 or bolt_age>=0 or ammo>=capacity():return false
	set_scoped(false)
	reload_remaining=RELOAD_SECONDS
	game.audio.play_at("tap",.55,-19)
	hunt_note.text=("弹仓空了，正在自动换弹……" if ammo==0 else "正在换弹……")+"装好 %d 发再抬起。"%capacity()
	return true

func rifle_point(uv:Vector2)->Vector2:
	if rifle.texture==null:return rifle.position+rifle.size*uv
	var tex_size=rifle.texture.get_size()
	var ratio=minf(rifle.size.x/tex_size.x,rifle.size.y/tex_size.y)
	var displayed=tex_size*ratio
	return rifle.get_global_transform()*((rifle.size-displayed)*.5+displayed*uv)

func _tick_rifle(delta:float):
	cooldown=maxf(0,cooldown-delta);muzzle_time=maxf(0,muzzle_time-delta)
	recoil=move_toward(recoil,0.0,delta*6.0)
	if bolt_age>=0:
		var before=bolt_age;bolt_age+=delta
		if before<.17 and bolt_age>=.17:
			casings.append({"position":rifle_point(Vector2(.57,.38)),"velocity":Vector2(108,-174),"age":0.0})
			game.audio.play_at("tap",.7,-22)
		if bolt_age>=.50:bolt_age=-1
	if reload_remaining>0:
		reload_remaining=maxf(0,reload_remaining-delta)
		if reload_remaining==0:
			ammo=capacity();game.audio.play_at("tap",.55,-17)
			hunt_note.text="这片区域暂时不会有%s来了。收好材料，回房车休息吧。"%HUNT_REGIONS[active_region].plural if empty_announced else "%d 发装好了。右键重新开镜，再寻找下一只。"%capacity()
			game._save()
	if ammo==0 and reload_remaining<=0 and bolt_age<0:begin_reload()
	for casing in casings:
		casing.age+=delta;casing.position+=casing.velocity*delta+Vector2(0,205*delta*delta);casing.velocity.y+=410*delta
	for i in range(casings.size()-1,-1,-1):
		if casings[i].age>.9:casings.remove_at(i)
	var aim=Vector2(clampf((pointer.x-WINDOW.get_center().x)/600,-1,1),clampf((pointer.y-WINDOW.get_center().y)/250,-1,1))
	var dip=sin((1.0-reload_remaining/RELOAD_SECONDS)*PI) if reload_remaining>0 else 0.0
	var anchor=Vector2(1320,815)+Vector2(aim.x*158,aim.y*112)
	var muzzle_local=Vector2(119,44)-rifle.pivot_offset
	var angle=wrapf((pointer-anchor).angle()-muzzle_local.angle(),-PI,PI)
	rifle.position=anchor-rifle.pivot_offset+Vector2(22,27)*recoil+Vector2(15,52)*dip
	rifle.rotation=clampf(angle,-.65,.65)-recoil*.045+dip*.13
	ammo_label.text="弹仓 %d / %d"%[ammo,capacity()]
	reload_button.text="换弹中…" if reload_remaining>0 else "上膛中…" if bolt_age>=0 else "换弹 · R"
	reload_button.disabled=reload_remaining>0 or bolt_age>=0 or ammo>=capacity()
	scope_button.disabled=reload_remaining>0
	_sync_scope()

func _spawn_drop(id:int,point:Vector2,uid:String="",age:float=0.0):
	if uid.is_empty():uid="hunt:"+str(next_loot_id);next_loot_id+=1
	if loot_claimed.has(uid):return
	for old in drops:if old.uid==uid:return
	var texture=game._ingredient_icon(8)
	if id in [11,14,15,16]:texture=food_icon(id)
	var pic=make_icon(loot_layer,texture,Rect2(point-Vector2(44,37),Vector2(88,74)));pic.pivot_offset=Vector2(44,37);pic.hide()
	drops.append({"uid":uid,"id":id,"region":active_region,"pic":pic,"picked":false,"point":point,"age":age,"launch":Vector2.ZERO})

func drop_at(point:Vector2)->int:
	# Compatibility entry point: rewards are automatic in the new hunting loop.
	return -1

func pick_drop(point:Vector2)->bool:
	return false

func _grant_drop(drop:Dictionary,save_now:bool=true):
	if drop.picked or loot_claimed.has(drop.uid):
		drop.picked=true;drop.pic.hide();return
	# Inventory and the transaction id are written together in the same game save.
	loot_claimed[drop.uid]=true;drop.picked=true;drop.pic.hide()
	game.prep.stock[int(drop.id)]+=1
	if hunt.visible:
		bag_bounce=1.0
		loot_toasts.append({"text":("稀有 · " if int(drop.id)==14 else "")+game.INGREDIENTS[int(drop.id)]+" +1","rare":int(drop.id)==14,"age":0.0,"row":loot_toasts.size()%3})
		game.audio.play_at("rustle",.7,-19)
	if save_now:game._save()

func _flush_loot():
	var count=0
	for drop in drops:
		if not drop.picked:count+=1;_grant_drop(drop,false)
	if count>0:game._save()

func _tick_loot(delta:float):
	bag_bounce=move_toward(bag_bounce,0.0,delta*4.5)
	if not hunt.visible:
		_flush_loot()
		if migration_notice:game._notice("之前留在猎场的材料，已经补收进背包和冰箱。");migration_notice=false
		return
	for drop in drops:
		if drop.picked:continue
		drop.age+=delta
		if drop.age<.56:continue
		if drop.launch==Vector2.ZERO:
			var projected=world_to_lens(drop.point)
			drop.launch=Vector2(clampf(projected.x,100,1140),clampf(projected.y,170,590))
		var age=drop.age-.56
		drop.pic.show()
		if age<.44:
			var t=age/.44
			drop.pic.position=drop.launch-Vector2(44,37)+Vector2(0,-sin(t*PI)*65)
			drop.pic.scale=Vector2.ONE*(.72+.28*sin(minf(1.0,t*2.0)*PI/2))
		elif age<1.12:
			var t=(age-.44)/.68
			var curve=t*t*(3.0-2.0*t)
			var middle=(drop.launch+LOOT_BAG)*.5+Vector2(0,-125)
			var position=(1.0-curve)*(1.0-curve)*drop.launch+2.0*(1.0-curve)*curve*middle+curve*curve*LOOT_BAG
			drop.pic.position=position-Vector2(44,37)
			drop.pic.scale=Vector2.ONE*lerpf(1.0,.24,curve)
		else:_grant_drop(drop)
	for toast in loot_toasts:toast.age+=delta
	for i in range(loot_toasts.size()-1,-1,-1):
		if loot_toasts[i].age>1.7:loot_toasts.remove_at(i)

func show_closeup(name_text:String,texture:Texture2D,story:String):
	title.text=name_text;portrait.texture=texture;detail.text=story;portrait.scale=Vector2(.86,.86);portrait.pivot_offset=portrait.size/2
	closeup_age=0;closeup.show();create_tween().tween_property(portrait,"scale",Vector2.ONE,.30).set_trans(Tween.TRANS_BACK)

func _input(event):
	if not game or (game.title_screen and game.title_screen.visible):return
	if event is InputEventMouseMotion:
		pointer=event.position
		if grabbed>=0:drag_pic.position=pointer-Vector2(51,42);drag_pic.visible=pointer.distance_to(grab_start)>8
	if closeup.visible:return
	if hunt.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
			leave_hunt();get_viewport().set_input_as_handled();return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_R:
			begin_reload();get_viewport().set_input_as_handled();return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE:
			set_scoped(not scope_active);get_viewport().set_input_as_handled();return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			pointer=event.position;set_scoped(not scope_active);get_viewport().set_input_as_handled();return
		if event is InputEventMouseButton and event.button_index==1 and event.pressed and ARENA.has_point(event.position):
			shoot(event.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index==1:
		pointer=event.position
		if not event.pressed and grabbed>=0:
			var id=grabbed;grabbed=-1;drag_pic.hide()
			var clicked=pointer.distance_to(grab_start)<=8
			close_fridge()
			if id in [11,14,15,16] and (clicked or game.prep.BOARD.has_point(pointer)):game.v5.put_meat_on_board(id)
			elif id not in [11,14,15,16] and (clicked or game.prep.POT.has_point(pointer)):game._select(id,true)
			get_viewport().set_input_as_handled();return
		if event.pressed and cold.visible:
			for i in range(COLD_IDS.size()):
				if cold_slots[i].get_global_rect().has_point(pointer):
					grabbed=COLD_IDS[i];grab_start=pointer;drag_pic.texture=food_icon(grabbed);get_viewport().set_input_as_handled();return
		if event.pressed and FRIDGE.has_point(pointer) and not on_controls() and not game.economy.panel.visible and not game.help_panel.visible:
			cold_pinned=not cold_pinned;cold_suppressed=false;get_viewport().set_input_as_handled()

func tick(delta:float):
	closeup_age+=delta
	_tick_loot(delta)
	var cycle=game.get("day_cycle")
	var available=cycle!=null and cycle.can_hunt()
	hunt_button.disabled=not available
	hunt_button.text="打猎"
	hunt_button.hide()
	var may_open=not hunt.visible and not closeup.visible and not game.economy.panel.visible and not game.help_panel.visible and not game.backpack.panel.visible and not on_controls()
	var bridge=Rect2(17,490,206,134)
	if not FRIDGE.has_point(pointer) and not cold.get_global_rect().has_point(pointer) and not bridge.has_point(pointer):cold_suppressed=false
	var want=may_open and not cold_suppressed and (cold_pinned or FRIDGE.has_point(pointer) or (cold.visible and (cold.get_global_rect().has_point(pointer) or bridge.has_point(pointer))))
	fridge_amount=move_toward(fridge_amount,1.0 if want else 0.0,delta*3.2)
	hinge.rotation.y=-fridge_amount*1.16;recess.visible=fridge_amount>.02
	cold.visible=want and fridge_amount>.72
	for i in range(COLD_IDS.size()):
		var count=game.prep.stock[COLD_IDS[i]]
		cold_labels[i].text="×"+str(count)
		cold_pictures[i].visible=count>0
		cold_slots[i].tooltip_text=game.INGREDIENTS[COLD_IDS[i]]+" ×"+str(count)+" · 点击取出 / 拖到砧板"
	if hunt.visible:
		_tick_hunt(delta)
		hunt_paint.queue_redraw()

func _tick_hunt(delta:float):
	phase_age+=delta
	var outdoor_tint=Color("8196b6") if game.hour>=19 or game.hour<6 else Color("edb68d") if game.hour>=17 else Color.WHITE
	outdoor_tint=outdoor_tint.lerp(Color("93a3b5"),game.rain_amount*.28+game.fog_amount*.15)
	hunt_background.modulate=hunt_background.modulate.lerp(outdoor_tint,1.0-exp(-delta*.40))
	drive_material.set_shader_parameter("tint",hunt_background.modulate)
	if phase=="driving":
		drive_amount=clampf(phase_age/3.0,0,1)
		var eased=drive_amount*drive_amount*(3.0-2.0*drive_amount)
		_set_travel_offset(eased*.24)
		_set_drive_camera(0.0)
		if drive_amount>=1.0:
			phase="approaching";phase_age=0.0;hunt_note.text="到了。车停稳了，我们往窗口靠近一点。"
		return
	if phase=="approaching":
		var t=clampf(phase_age/1.4,0,1)
		_set_drive_camera(t*t*(3.0-2.0*t))
		if t>=1.0:_arrive()
		return
	if phase!="hunting":return
	_tick_rifle(delta)
	if startled>=0:startled+=delta
	var herd_changed=false
	for i in range(targets.size()):
		var a=targets[i]
		if not a.alive:
			if a.fall_age>=0:
				a.fall_age+=delta
				a.pic.modulate=Color(1.45,1.2,.8) if a.fall_age<.12 else Color.WHITE
				a.pic.position.y=a.origin.y+minf(a.fall_age/.36,1.0)*7.0
				a.pic.position.x+=sin(a.fall_age*70.0)*maxf(0,.16-a.fall_age)*3.0
				if a.fall_age>1.9:a.pic.modulate.a=maxf(0,1.0-(a.fall_age-1.9)/.65)
			continue
		var fleeing=startled>.65+i*.08
		var speed=a.speed if fleeing else 10.0+i*2.0
		a.walk_age+=delta*(1.5 if fleeing else .8)
		a.pic.position.x+=a.direction*speed*delta
		if not fleeing and absf(a.pic.position.x-a.origin.x)>a.patrol:a.direction*=-1
		a.pic.position.y=a.origin.y+absf(sin(a.walk_age*7.0))*1.2
		if a.pic.position.x>WINDOW.size.x or a.pic.position.x+a.pic.size.x<0:a.alive=false;a.pic.hide();herd_changed=true
	_set_target_frames()
	_check_empty()
	if herd_changed:game._save()
	for impact in impact_marks:impact.age+=delta
	for i in range(impact_marks.size()-1,-1,-1):
		if impact_marks[i].age>.28:impact_marks.remove_at(i)

func to_save()->Dictionary:
	_record_encounter()
	var pending=[]
	for drop in drops:
		if not drop.picked:pending.append({"uid":drop.uid,"id":int(drop.id),"region":int(drop.get("region",0)),"x":drop.point.x,"y":drop.point.y,"age":drop.age})
	return {"loot_version":4,"hunted":total_hunted,"rare_hunted":rare_hunted,"region_hunted":region_hunted,"encounters":encounters,"travel_seed":travel_seed,"trip_count":trip_count,"pending":pending,"claimed":loot_claimed.keys(),"next_loot_id":next_loot_id,"ammo":ammo,"ammo_capacity":capacity()}
func restore(d:Dictionary):
	total_hunted=maxi(0,int(d.get("hunted",0)))
	rare_hunted=maxi(0,int(d.get("rare_hunted",0)))
	travel_seed=int(d.get("travel_seed",0));trip_count=maxi(0,int(d.get("trip_count",0)))
	var version=int(d.get("loot_version",0))
	var saved_ammo=int(d.get("ammo",capacity()))
	# Old full three-round magazines become the new full six-round magazine;
	# genuinely empty/partial magazines retain their remaining rounds.
	if version<4 and d.has("ammo") and saved_ammo==3:saved_ammo=capacity()
	ammo=clampi(saved_ammo,0,capacity())
	region_hunted=[0,0,0]
	var saved_regions=d.get("region_hunted",[])
	for i in range(mini(3,saved_regions.size())):region_hunted[i]=maxi(0,int(saved_regions[i]))
	encounters=d.get("encounters",{}).duplicate(true)
	next_loot_id=maxi(next_loot_id,int(d.get("next_loot_id",1)))
	for uid in d.get("claimed",[]):loot_claimed[str(uid)]=true
	for drop in drops:if is_instance_valid(drop.pic):drop.pic.queue_free()
	drops.clear()
	var pending=d.get("pending",[]) if int(d.get("loot_version",0))>=2 else d.get("ground",[])
	var legacy=int(d.get("loot_version",0))<2
	var legacy_base=str(JSON.stringify(pending).hash())+":"+str(total_hunted)
	for i in range(pending.size()):
		var item=pending[i]
		if int(item.get("id",-1)) in [8,11,14,15,16]:
			var uid="legacy:"+legacy_base+":"+str(i) if legacy else str(item.get("uid","restored:"+str(i)))
			_spawn_drop(int(item.id),Vector2(clampf(float(item.get("x",100)),ARENA.position.x+3,ARENA.end.x-44),clampf(float(item.get("y",520)),ARENA.position.y,ARENA.end.y-43)),uid,maxf(0,float(item.get("age",0))))
			for drop in drops:
				if drop.uid==uid:drop.region=clampi(int(item.get("region",0)),0,2)
	migration_notice=legacy and not pending.is_empty()

func on_controls()->bool:
	return (hunt_button.visible and hunt_button.get_global_rect().has_point(pointer)) or (game.get("navigation") and game.navigation.contains(pointer)) or (game.simmer and game.simmer.panel.visible and game.simmer.panel.get_global_rect().has_point(pointer))
