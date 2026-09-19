extends Node
var game
var active=-1
var age=0.0
var level=8.0
var from_level=8.0
var valve=0.0
var surface:MeshInstance3D
const DURATION=2.4

func setup(g):
	game=g
	surface=game.prep.reference_piece("AnimatedReservoir",Rect2(1094,32,175,180),Rect2(1094.0/1280,32.0/714,175.0/1280,180.0/714),1.6)
	var mat=surface.material_override
	mat.shader=load("res://shaders/reservoir.gdshader")
	# Explicitly retain the original atlas when replacing its crop shader.
	mat.set_shader_parameter("art",load("res://assets/rv_atlas_v3.png"))
	mat.set_shader_parameter("source_rect",Vector4(1094.0/1280,32.0/714,175.0/1280,180.0/714))

func start(index:int)->bool:
	if active>=0 or index<0 or index>3:return false
	if game.prep.farm_growth[index]>=1:game._notice("先采下长好的菜，再给根系浇水。");return false
	if game.prep.farm_water[index]>=1:game._notice("水已经够了，等新叶长出来。");return false
	if game.prep.water_store<=0:game._notice("储水罐空了，去营地水井补些净水。");return false
	active=index;age=0;from_level=level
	game.prep.water_store-=1
	game.audio.play_at("water",.75,-14)
	game._notice("拧开水龙头……净水正在流向根系。")
	game._save()
	return true

func tick(delta:float):
	if active>=0:
		age+=delta
		valve=smoothstep(0,.35,age)*(1.0-smoothstep(2.0,DURATION,age))
		level=lerpf(from_level,float(game.prep.water_store),smoothstep(.35,2.0,age))
		if age>.35 and age<2.0:game.prep.water_fx[active]=.18
		if age>=DURATION:
			game.prep.farm_water[active]=1
			game._notice("浇水完成 · 根系开始再生，阀门已关好。")
			active=-1;valve=0;game.prep.refresh();game._save()
	else:level=move_toward(level,float(game.prep.water_store),delta*2)
	surface.material_override.set_shader_parameter("water_level",clampf(level/20.0,0,1))
	surface.material_override.set_shader_parameter("valve",valve)
	game.prep.water_label.text="净水 %d · %s"%[game.prep.water_store,"正在浇灌" if active>=0 else "营地可补水"]

func to_save()->Dictionary:
	return {"active":active,"age":age,"level":level,"from":from_level}

func restore(d:Dictionary):
	active=clampi(int(d.get("active",-1)),-1,3);age=clampf(float(d.get("age",0)),0,DURATION)
	level=float(d.get("level",game.prep.water_store));from_level=float(d.get("from",level))
