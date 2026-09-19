extends Control

const PAPER = Color("d9d6bf")
const INK = Color("282c2e")
const TEAL = Color("bbb59a")
const AMBER = Color("b8a578")
const INGREDIENTS = ["牛肉", "鸡蛋", "卷心菜", "辣油", "午餐肉", "小葱", "香菜", "菠菜", "去刺仙人掌", "哨站菌菇", "盐鳍鱼干", "嫩掌蜥肉", "霜苔茸", "盐鳍鲜鱼", "红掌蜥肉", "响石岩兔肉", "盐帆泽鸭肉"]
const WEATHER_NAMES = ["晴天 · 微风", "下雨 · 铁皮屋檐", "薄雾 · 寂静公路", "沙尘 · 远方来风"]
const PHASES = ["选配料", "烧水中", "水开了", "煮面中", "面煮好了", "可以出餐", "客人用餐"]
const ORDERS = [
	{"name":"老乔", "role":"巡路人", "texture":"traveller.png", "need":[0,1,3], "avoid":[], "order":"牛肉面，加个蛋，要辣。\n我坐一会儿，你慢慢来。", "story":"北边的信号塔又熄了。\n我捡了台收音机，可惜缺一节电池。\n……先吃口热的，再想办法。", "thanks":"这口辣汤，够我暖到下个路口了。\n要是有人卖电池，替我留意一下。"},
	{"name":"阿岚", "role":"路过的商人", "texture":"merchant.png", "need":[4,2], "avoid":[3], "order":"午餐肉面，加青菜，不放辣。\n外面风大，借你的屋檐歇歇脚。", "story":"老乔在找电池？我车里刚好还有。\n等雨小一点，我去替他装上。\n总得让这条公路有点声音。", "thanks":"汤真暖。电池就放你这里吧。\n告诉老乔，广播响了记得喊我。"},
	{"name":"老乔", "role":"带着好消息回来", "texture":"traveller.png", "need":[1,5], "avoid":[], "order":"今天清淡些，鸡蛋、葱花就好。\n我给你带了个好消息。", "story":"收音机响了。不是求救，是天气预报。\n说明那边也有人好好过日子。\n明早……还在这里开摊吧？", "thanks":"「旧公路营地，明日晴。」\n收音机里终于传来完整的一句话。\n房车里的灯，还亮着。"}
]

var simmer
var perfect_fx
var cabin_details
var fieldlife
var irrigation
var tutorial
var day_cycle
var navigation
var v4
var v5
var title_screen
static var new_game_requested=false
static var skip_title_once=false
var prep
var service
var backpack
var economy
var audio
var viewport3d: SubViewport
var world: Node3D
var camera: Camera3D
var env: Environment
var sun: OmniLight3D
var warm: OmniLight3D
var cyan: OmniLight3D
var character: MeshInstance3D
var character_material: ShaderMaterial
var materials: Array = []
var weather_material: ShaderMaterial
var bowl: MeshInstance3D
var toppings: Array = []
var fx: Control
var ui: Control
var coin_texture:ImageTexture
var font: Font
var dialogue: Label
var customer_label: Label
var order_label: Label
var hint: Label
var coins_label: Label
var chapter_label: Label
var weather_button: Button
var time_button: Button
var auto_button: Button
var cook_button: Button
var serve_button: Button
var clear_button: Button
var talk_button: Button
var ingredient_buttons: Array = []
var slots: Array = []
var receipt: Panel
var receipt_text: Label
var next_button: Button
var sound_button: Button
var help_panel: Panel
var layer_label: Label
var plant_button: Button
var narration: Label
var sound_off = false
var stage = 0
var cook_remaining = 0.0
var selected: Array = []
var coins = 28
var day = 1
var total_served = 0
var order_index = 0
var visits = {"老乔":0,"阿岚":0}
var hour = 9.0
var weather = 0
var auto_time = true
var auto_weather = true
var elapsed = 0.0
var weather_clock = 0.0
var light_night = 0.0
var daylight_amount=1.0
var sunset_amount=0.0
var rain_amount = 0.0
var dust_amount = 0.0
var fog_amount = 0.0
var chatting = false
var hydrated = false
var show_layers = false
var inspect_amount = 0.0
var notice_seconds = 0.0
var qa_mode = false
var demo_mode = false
var last_receipt = ""
var screenshot_dir = ""
var save_path = "user://stall_save_v4.json"
var qa_save_enabled = false
var closing = false
var scene_overlays: Array = []
var hotspots: Array = []

func _ready() -> void:
	demo_mode = OS.get_cmdline_user_args().has("--demo")
	var qa_title=OS.get_cmdline_user_args().has("--qa-title")
	qa_mode = OS.get_cmdline_user_args().has("--qa") or OS.get_cmdline_user_args().has("--qa-six") or OS.get_cmdline_user_args().has("--qa-eight") or OS.get_cmdline_user_args().has("--qa-nine") or OS.get_cmdline_user_args().has("--qa-ten") or demo_mode or qa_title
	get_tree().auto_accept_quit = false
	font = load("res://assets/fonts/StallSans.otf")
	font.antialiasing=TextServer.FONT_ANTIALIASING_GRAY
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_AUTO
	font.hinting=TextServer.HINTING_NORMAL
	_build_world()
	_build_coin_icon()
	_build_ui()
	_build_audio()
	prep=load("res://scripts/preparation.gd").new()
	add_child(prep)
	prep.setup(self)
	economy=load("res://scripts/roadlife.gd").new()
	add_child(economy)
	economy.setup(self)
	for index in [6,7]:
		var topping=prep._sprite("NewTopping"+str(index),"farm_packet.png",0 if index==6 else 2,3,Rect2(696+(index-6)*38,544,57,54),1.8)
		topping.hide()
		toppings.append(topping)
	for index in prep.FARM_IDS:prep.apply_leaf_art(toppings[index],index)
	world.find_child("WeatherOutsideWindow",true,false).position.z=-2.0
	service=load("res://scripts/service.gd").new()
	add_child(service)
	service.setup(self)
	backpack=load("res://scripts/backpack.gd").new()
	add_child(backpack)
	backpack.setup(self)
	v4=load("res://scripts/hearth.gd").new()
	add_child(v4)
	v4.setup(self)
	v5=load("res://scripts/interactions.gd").new()
	add_child(v5)
	v5.setup(self)
	fieldlife=load("res://scripts/fieldlife.gd").new()
	add_child(fieldlife);fieldlife.setup(self)
	simmer=load("res://scripts/simmer.gd").new()
	add_child(simmer);simmer.setup(self)
	irrigation=load("res://scripts/irrigation.gd").new()
	add_child(irrigation);irrigation.setup(self)
	tutorial=load("res://scripts/tutorial.gd").new()
	add_child(tutorial);tutorial.setup(self)
	day_cycle=load("res://scripts/day_cycle.gd").new()
	add_child(day_cycle);day_cycle.setup(self)
	perfect_fx=load("res://scripts/perfect_fx.gd").new()
	ui.add_child(perfect_fx);perfect_fx.setup(self)
	cabin_details=load("res://scripts/cabin_details.gd").new()
	add_child(cabin_details);cabin_details.setup(self)
	navigation=load("res://scripts/navigation.gd").new()
	ui.add_child(navigation);navigation.setup(self)
	_button(help_panel,"重新教学",Rect2(28,356,196,38),func():help_panel.hide();tutorial.restart(),TEAL,15)
	var fresh=new_game_requested
	new_game_requested=false
	if not qa_mode and not fresh:
		_load_save()
	_set_customer()
	if stage==6 and not service.eating:service.customer_frame(0 if v4.review_line==1 else service.review_frame())
	_refresh()
	_apply_lighting(1.0)
	title_screen=load("res://scripts/title_screen.gd").new()
	add_child(title_screen)
	title_screen.setup(self)
	if (qa_mode and not qa_title) or skip_title_once:
		title_screen.hide()
		if skip_title_once: v5.begin_arrival()
		skip_title_once=false
	if qa_mode:
		if not ResourceLoader.exists("res://房车场景.tscn"):
			_save_authored_world()
		call_deferred("_run_qa")

func _build_world() -> void:
	var screen = TextureRect.new()
	screen.position = Vector2.ZERO
	screen.size = Vector2(1280,714)
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	viewport3d = SubViewport.new()
	viewport3d.size = Vector2i(785,438)
	viewport3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport3d.own_world_3d = true
	add_child(viewport3d)
	screen.texture = viewport3d.get_texture()
	if ResourceLoader.exists("res://房车场景.tscn"):
		_load_authored_world()
		_add_fx()
		return
	world = Node3D.new()
	world.name = "PaperWorld"
	viewport3d.add_child(world)
	# Copy Blender meshes to plain nodes so the saved scene has no nested ownership.
	var blender_source: Node3D = load("res://assets/rv_layers.glb").instantiate()
	var imported = Node3D.new()
	imported.name = "ArtLayers"
	world.add_child(imported)
	for source_mesh in blender_source.find_children("*","MeshInstance3D",true,false):
		var paper = MeshInstance3D.new()
		paper.name = source_mesh.name
		paper.mesh = source_mesh.mesh.duplicate()
		for surface in range(paper.mesh.get_surface_count()): paper.mesh.surface_set_material(surface,null)
		paper.transform = source_mesh.transform
		imported.add_child(paper)
	blender_source.free()
	var layout: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/layers.json"))
	for layer in layout:
		var mesh: MeshInstance3D = imported.find_child(layer.name, true, false)
		if mesh == null:
			push_error("Missing Blender layer: " + str(layer.name))
			continue
		var mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/paper.gdshader")
		mat.set_shader_parameter("art", load("res://assets/" + layer.texture))
		mat.set_shader_parameter("exterior", layer.group == "exterior")
		mat.set_shader_parameter("fill", 0.96 if layer.group == "exterior" else 0.91)
		mat.set_shader_parameter("cabin", layer.group == "interior")
		mesh.material_override = mat
		materials.append({"mat":mat, "group":layer.group, "mesh":mesh})
		if layer.group == "customer":
			character = mesh
			character_material = mat
	camera = Camera3D.new()
	camera.name = "FixedServiceCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.75
	camera.position = Vector3(0,0,20)
	camera.current = true
	world.add_child(camera)
	var environment = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("303c41")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d3e5e6")
	env.ambient_light_energy = .45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	world.add_child(environment)
	sun = _light("ChangingDaylight", Vector3(-3,4,7), Color("fff0cd"), .6, 30)
	warm = _light("WarmCabinLamp", Vector3(-1,2.6,2.8), Color("ffd19a"), .55, 10)
	cyan = _light("HydroponicsLight", Vector3(6,0,2), Color("81e4d6"), .3, 7)
	weather_material = ShaderMaterial.new()
	weather_material.shader = load("res://shaders/weather.gdshader")
	var weather_mesh = _quad("WeatherOutsideWindow", Rect2(375,166,897,375),-.5,weather_material)
	weather_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bowl_mat = _paper_material("bowl.png")
	bowl = _quad("ServingBowl", Rect2(684,600,327,224),1.5,bowl_mat)
	bowl.visible = false
	var places = [Rect2(734,656,107,65), Rect2(765,635,112,82), Rect2(859,655,106,70), Rect2(821,688,65,42),Rect2(726,681,110,65),Rect2(825,667,89,62)]
	for i in range(6):
		var tm = _paper_material("ingredients.png")
		var uv = Rect2(float(i%3)/3.0,float(i/3)/2.0,1.0/3.0,.5)
		var topping = _quad("Topping_"+str(i),places[i],1.6+float(i)*.015,tm,uv)
		topping.visible = false
		toppings.append(topping)
	_add_fx()

func _add_fx() -> void:
	fx = load("res://scripts/effects.gd").new()
	fx.set("game",self)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.size = Vector2(1280,714)
	add_child(fx)

func _save_authored_world() -> void:
	for node in world.find_children("*","",true,false): node.owner = world
	var packed = PackedScene.new()
	var err = packed.pack(world)
	if err == OK: ResourceSaver.save(packed,"res://房车场景.tscn")

func _load_authored_world() -> void:
	world = load("res://房车场景.tscn").instantiate()
	viewport3d.add_child(world)
	camera = world.find_child("FixedServiceCamera",true,false)
	sun = world.find_child("ChangingDaylight",true,false)
	warm = world.find_child("WarmCabinLamp",true,false)
	cyan = world.find_child("HydroponicsLight",true,false)
	for node in world.find_children("*","WorldEnvironment",true,false): env = node.environment
	for node in world.find_children("*","MeshInstance3D",true,false):
		var mat = node.material_override
		if not mat is ShaderMaterial: continue
		if node.name == "WeatherOutsideWindow":
			weather_material=mat
			continue
		var group = "interior"
		if node.name == "Exterior_Skyline": group = "exterior"
		elif node.name == "Customer":
			group = "customer"
			character = node
			character_material = mat
		materials.append({"mat":mat,"group":group,"mesh":node})
		if node.name=="ServingBowl": bowl=node
	for i in range(6): toppings.append(world.find_child("Topping_"+str(i),true,false))

func _light(node_name: String, pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var lamp = OmniLight3D.new()
	lamp.name = node_name
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = radius
	world.add_child(lamp)
	return lamp

func _paper_material(texture_name: String) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/paper.gdshader")
	mat.set_shader_parameter("art",load("res://assets/"+texture_name))
	mat.set_shader_parameter("fill",.91)
	materials.append({"mat":mat,"group":"interior"})
	return mat

func _quad(node_name: String, rect: Rect2, depth: float, mat: Material, uv_rect: Rect2 = Rect2(0,0,1,1)) -> MeshInstance3D:
	var x = (rect.position.x-785)/100.0
	var y = (437.5-rect.position.y)/100.0
	var w = rect.size.x/100.0
	var h = rect.size.y/100.0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts = [Vector3(x,y-h,depth),Vector3(x+w,y-h,depth),Vector3(x+w,y,depth),Vector3(x,y,depth)]
	var a = uv_rect.position
	var b = uv_rect.end
	var uvs = [Vector2(a.x,b.y),Vector2(b.x,b.y),Vector2(b.x,a.y),Vector2(a.x,a.y)]
	for i in [0,1,2,0,2,3]:
		st.set_normal(Vector3(0,0,1))
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])
	var mesh = MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = st.commit()
	mesh.material_override = mat
	world.add_child(mesh)
	return mesh

func _style(bg: Color, border: Color = INK, width: int = 2) -> StyleBox:
	return load("res://scripts/pixel_ui.gd").frame(bg,border,width)

func _panel(parent: Node, rect: Rect2, color: Color = PAPER) -> Panel:
	var p = load("res://scripts/pixel_panel.gd").new()
	p.paper_color=color
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel",_style(color))
	parent.add_child(p)
	return p

func _label(parent: Node, text: String, rect: Rect2, font_size: int = 18, color: Color = INK) -> Label:
	var l = Label.new()
	l.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	l.position = rect.position
	l.size = rect.size
	l.text = text
	l.add_theme_font_override("font",font)
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, rect: Rect2, callback: Callable, color: Color = PAPER, font_size: int = 17) -> Button:
	var b = Button.new()
	b.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	b.position = rect.position
	b.size = rect.size
	b.text = text
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",font_size)
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_hover_color",INK)
	b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_color_override("font_disabled_color",Color("89938a"))
	b.add_theme_stylebox_override("normal",_style(color))
	b.add_theme_stylebox_override("hover",_style(color.lightened(.14),Color("f0bd71"),2))
	b.add_theme_stylebox_override("pressed",_style(color.darkened(.12)))
	b.add_theme_stylebox_override("disabled",_style(Color("b7b9aa"),Color("6d7970"),1))
	b.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),Color("f0bd71"),2))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _build_ui() -> void:
	ui = Control.new()
	ui.size = Vector2(1280,800)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var brand = _panel(ui,Rect2(18,14,259,62))
	_label(brand,"末日泡面摊",Rect2(15,4,230,32),26)
	_label(brand,"SOUPLIFE   /   荒路一碗",Rect2(16,36,230,18),11,Color("77664c"))
	var wallet = _panel(ui,Rect2(290,17,112,47))
	coins_label = _label(wallet,"",Rect2(12,7,96,30),21)
	var chapter = _panel(ui,Rect2(470,19,291,32),Color("bbcab7"))
	chapter_label = _label(chapter,"",Rect2(12,3,270,26),14,Color("343f3e"))
	chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather_button = _button(ui,"",Rect2(947,16,181,42),_cycle_weather,PAPER,15)
	time_button = _button(ui,"",Rect2(1137,16,124,42),_cycle_time,PAPER,15)
	auto_button = _button(ui,"自然流转  ON",Rect2(1137,64,124,29),_toggle_time,Color("91ada1"),12)
	_button(ui,"天气自动",Rect2(1041,64,86,29),_toggle_weather_auto,Color("91ada1"),12).name = "AutoWeather"
	var speech = _panel(ui,Rect2(330,163,230,235),Color("efe4cd"))
	scene_overlays.append(speech)
	customer_label = _label(speech,"",Rect2(15,11,201,27),20)
	_label(speech,"—  今日点单  —",Rect2(15,43,201,24),12,Color("89714e"))
	order_label = _label(speech,"",Rect2(15,74,200,92),17)
	talk_button = _button(speech,"聊一会儿",Rect2(15,181,200,37),_talk,Color("bcc7ad"),15)
	dialogue = order_label
	var ticket = _panel(ui,Rect2(876,435,175,32),Color("e1d5b8"))
	scene_overlays.append(ticket)
	_label(ticket,"慢慢做 · 我不赶时间",Rect2(8,3,160,25),13)
	var bar = _panel(ui,Rect2(0,712,1280,88),Color("263f3e"))
	_label(bar,"灶台手记",Rect2(20,10,160,25),18,Color("efe3c5"))
	hint = _label(bar,"",Rect2(20,39,206,37),12,Color("b8cbc0"))
	cook_button = _button(bar,"点火烧水",Rect2(784,13,176,60),_cook,AMBER,19)
	serve_button = _button(bar,"出餐",Rect2(973,13,154,60),_serve,Color("8eb6a3"),19)
	clear_button = _button(bar,"重新做",Rect2(1140,13,121,60),_reset_bowl,PAPER,16)
	# Side receipt never covers the customer or the cooking counter.
	receipt = _panel(ui,Rect2(53,133,211,296),Color("eee1c3"))
	_label(receipt,"本碗结算",Rect2(15,13,181,30),22)
	receipt_text = _label(receipt,"",Rect2(15,52,181,170),15)
	next_button = _button(receipt,"接待下一位",Rect2(15,236,181,43),_next_customer,Color("abc0a5"),16)
	receipt.hide()
	sound_button = _button(ui,"声音 开",Rect2(20,674,78,26),_toggle_sound,PAPER,12)
	_button(ui,"操作说明",Rect2(105,674,86,26),func(): help_panel.visible = not help_panel.visible,PAPER,12)
	var layers_debug_button=_button(ui,"片层视图",Rect2(198,674,86,26),_toggle_layers,PAPER,12)
	layers_debug_button.hide()
	narration = _label(ui,"",Rect2(575,655,288,52),12,Color("fff4d6"))
	narration.add_theme_color_override("font_shadow_color",Color("273b39"))
	narration.add_theme_constant_override("shadow_outline_size",5)
	narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer_label = _label(ui,"3D 片层查看：独立窗外 / 角色 / 车体 / 台面",Rect2(310,112,700,35),20,PAPER)
	layer_label.hide()
	help_panel = _panel(ui,Rect2(390,167,500,449),Color("eee3ca"))
	_label(help_panel,"今晚，慢慢做一碗面。",Rect2(27,21,445,38),26)
	_label(help_panel,"1  悬停食材看最佳格数，整肉切三刀，菜放旁边。\n2  空培养皿浇一次水；备料可右键收回。\n3  选牛肉、海鲜或蔬菜味，烧水、撕袋、下面。\n4  面和调料落锅开始计时，按火候先后加入食材。\n5  五格走满自动盛面，点成品或拖给客人。\n6  商店随时可用；接待完当天所有客人才能收摊。\n7  收摊后可打猎、送外卖；点日期屏开始下一天。\n8  猎场右键开镜、左键射击；六发打空自动换弹。\n\n每格四秒。全部食材最佳，会做出闪闪发光的完美面。\n商店可升级弹仓；三个猎场各有猎物，收获自动入包。\n点机器人看引导；顶柜看纪念品，冰箱冷藏鲜肉。\n空格：做面下一步   Enter：出餐 / 对话下一句\nM：静音   W：天气   T：时段   F11：全屏",Rect2(27,73,444,276),14)
	_button(help_panel,"知道了，开摊",Rect2(27,386,445,43),func():help_panel.hide(),TEAL,17)
	help_panel.hide()
	_hotspot(Rect2(357,483,183,157),_cook,"点击锅：烧水 / 下面 / 盛面")
	_hotspot(Rect2(590,487,205,174),func():
		if stage==5: _serve()
		elif stage==4: _cook(),"点击砧板：盛面 / 出餐")
	_hotspot(Rect2(574,184,258,250),func():
		_talk(),"点击客人：查看点单 / 聊天")
	# Help must remain above the transparent scene hotspots.
	ui.move_child(help_panel,ui.get_child_count()-1)

func _hotspot(rect: Rect2, callback: Callable, tip: String) -> void:
	var b = Button.new()
	b.position=rect.position
	b.size=rect.size
	b.flat=true
	b.focus_mode=Control.FOCUS_NONE
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.tooltip_text=tip
	for state in ["normal","hover","pressed","focus"]:
		b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	b.pressed.connect(callback)
	ui.add_child(b)
	hotspots.append(b)

func _ingredient_icon(index: int) -> AtlasTexture:
	var icon=AtlasTexture.new()
	if index in [6,2,7,5] and ResourceLoader.exists("res://assets/harvest_leaves.png"):
		icon.atlas=load("res://assets/harvest_leaves.png")
		icon.region=Rect2([6,2,7,5].find(index)*icon.atlas.get_width()/4.0,0,icon.atlas.get_width()/4.0,icon.atlas.get_height())
		return icon
	if index in [11,14] and ResourceLoader.exists("res://assets/lizard_meat.png"):
		icon.atlas=load("res://assets/lizard_meat.png")
		icon.region=Rect2((1 if index==14 else 0)*icon.atlas.get_width()/2.0,0,icon.atlas.get_width()/2.0,icon.atlas.get_height())
		return icon
	if index==10 and fieldlife:
		return fieldlife.atlas(4)
	if index>=11 and fieldlife:
		return fieldlife.food_icon(index)
	if index>=8:
		icon.atlas=load("res://assets/regional_food.png")
		icon.region=Rect2((index-8)*icon.atlas.get_width()/3.0,0,icon.atlas.get_width()/3.0,icon.atlas.get_height())
	elif index in [6,7]:
		icon.atlas=load("res://assets/farm_packet.png")
		var cell=0 if index==6 else 2
		icon.region=Rect2(cell*icon.atlas.get_width()/3.0,0,icon.atlas.get_width()/3.0,icon.atlas.get_height()/3.0)
	else:
		icon.atlas=load("res://assets/ingredients.png")
		icon.region=Rect2(index%3*icon.atlas.get_width()/3.0,int(index/3)*icon.atlas.get_height()/2.0,icon.atlas.get_width()/3.0,icon.atlas.get_height()/2.0)
	return icon

func _build_audio() -> void:
	audio=load("res://scripts/asmr.gd").new()
	add_child(audio)
	audio.setup(self)

func _sound(kind: String = "tap") -> void:
	var sounds={"tap":"tap","ding":"bowl","coins":"tap","ignite":"water","rustle":"tear","water":"water"}
	audio.play_at(sounds.get(kind,"tap"),-.25 if kind in ["ignite","rustle"] else 0,-14 if kind in ["tap","coins","ding"] else -10)

func _process(delta: float) -> void:
	if title_screen and title_screen.visible:
		if audio: audio.tick(delta)
		return
	elapsed += delta
	if prep and economy:
		prep.tick(delta)
		economy.tick(delta)
	if audio: audio.tick(delta)
	if service: service.tick(delta)
	if backpack: backpack.tick()
	if v4: v4.tick(delta)
	if v5: v5.tick(delta)
	if fieldlife: fieldlife.tick(delta)
	if irrigation: irrigation.tick(delta)
	if simmer: simmer.tick(delta)
	if tutorial: tutorial.tick(delta)
	if day_cycle:day_cycle.refresh()
	if perfect_fx:perfect_fx.tick(delta)
	if cabin_details:cabin_details.tick(delta)
	if auto_time:
		hour=minf(23.5,hour+delta/36.0)
	if auto_weather:
		weather_clock += delta
		if weather_clock >= 180.0:
			weather_clock = 0
			_set_weather((weather+1)%4)
	if stage == 1:
		cook_remaining -= delta
		if cook_remaining <= 0:
			stage += 1
			_sound("ding")
			_refresh()
			_save()
	if notice_seconds > 0:
		notice_seconds -= delta
		if notice_seconds <= 0: narration.text = ""
	_apply_lighting(delta)
	if is_instance_valid(fx): fx.queue_redraw()
	if is_instance_valid(character):
		character.position.y = sin(elapsed*1.15)*.018
		character.position.x = (v5.customer_offset if v5 else 0.0)+sin(elapsed*.31)*.008
	inspect_amount = move_toward(inspect_amount,1.0 if show_layers else 0.0,delta*2.0)
	camera.position = Vector3(inspect_amount*10,inspect_amount*2.2,20)
	camera.look_at(Vector3.ZERO,Vector3.UP)
	camera.size = 8.75+inspect_amount*4.0
	if time_button:
		time_button.text = "%02d:%02d · %s" % [int(hour),int(fmod(hour,1.0)*60),_period()]

func _apply_lighting(delta: float) -> void:
	var blend=1.0-exp(-delta*.40)
	daylight_amount=lerpf(daylight_amount,clampf(sin((hour-6.0)/14.0*PI)*1.5,0.0,1.0),blend)
	sunset_amount=lerpf(sunset_amount,clampf(1.0-abs(hour-18.0)/2.2,0.0,1.0),blend)
	var daylight=daylight_amount
	light_night=1.0-daylight
	var dusk=sunset_amount
	rain_amount=lerpf(rain_amount,1.0 if weather==1 else 0.0,blend*.8)
	dust_amount=lerpf(dust_amount,1.0 if weather==3 else 0.0,blend*.65)
	fog_amount=lerpf(fog_amount,1.0 if weather==2 else 0.0,blend*.65)
	var outdoors = Color("ffffff").lerp(Color("7196ba"),light_night*.74)
	outdoors = outdoors.lerp(Color("ed9267"),dusk*.52)
	outdoors = outdoors.lerp(Color("879dba"),rain_amount*.38)
	outdoors = outdoors.lerp(Color("cbbca0"),fog_amount*.23)
	outdoors = outdoors.lerp(Color("cc9656"),dust_amount*.49)
	for item in materials:
		var mat: ShaderMaterial = item.mat
		if item.group == "exterior":
			mat.set_shader_parameter("tint",outdoors.darkened(light_night*.3))
			mat.set_shader_parameter("night",light_night)
			mat.set_shader_parameter("sunset",dusk)
			mat.set_shader_parameter("overcast",rain_amount+fog_amount*.5)
		elif item.group == "customer":
			mat.set_shader_parameter("tint",Color.WHITE.lerp(Color("c9b898"),light_night*.35).lerp(Color("dfa788"),dusk*.2))
			mat.set_shader_parameter("night",light_night)
			mat.set_shader_parameter("overcast",rain_amount*.65)
		else:
			mat.set_shader_parameter("tint",Color.WHITE)
			mat.set_shader_parameter("night",light_night)
			mat.set_shader_parameter("sunset",dusk)
			mat.set_shader_parameter("overcast",rain_amount+fog_amount*.35+dust_amount*.2)
	env.ambient_light_energy = .5-daylight*.03-light_night*.25-rain_amount*.07
	env.ambient_light_color = Color("dcebf0").lerp(Color("718eae"),light_night)
	sun.light_energy = .6*daylight*(1.0-rain_amount*.5-fog_amount*.35-dust_amount*.3)
	sun.light_color = Color("fff2da").lerp(Color("ffad75"),dusk)
	sun.position.x = lerpf(sun.position.x,lerpf(-6,6,clampf((hour-7)/13,0,1)),blend)
	warm.light_energy = .50+light_night*.8+rain_amount*.15
	cyan.light_energy = .17+light_night*.58
	weather_material.set_shader_parameter("rain",rain_amount)
	weather_material.set_shader_parameter("dust",dust_amount)
	weather_material.set_shader_parameter("haze",fog_amount)
	weather_material.set_shader_parameter("elapsed",elapsed)

func _set_customer() -> void:
	if day_cycle and not day_cycle.has_customer() and not economy.delivery_mode:
		character.hide();customer_label.text="";order_label.text="";chatting=false
		if v4:v4.close_conversation()
		return
	var identity=str(economy.map_index)+":"+str(order_index)
	if v4 and identity!=v4.guest_identity:
		if stage<6: v4.new_guest()
		v4.guest_identity=identity
	var customer: Dictionary = service.order()
	service.customer_frame(0)
	customer_label.text = customer.name+"  /  "+customer.role
	customer_label.add_theme_font_size_override("font_size",17 if order_index==2 else 20)
	chatting = false
	order_label.text = customer.order
	if stage == 6: order_label.text = customer.thanks
	if economy and economy.delivery_mode:
		customer_label.text="外卖单 / "+economy.job.recipient
		order_label.text=economy.food_text(economy.job.need)+"。\n做好打包，送到"+economy.MAPS[int(economy.job.destination)].name+"。\n慢慢做，不限时。"

func _refresh() -> void:
	coins_label.text = str(coins)
	chapter_label.text = "第 %02d 天   /   旧公路营地" % day
	weather_button.text = WEATHER_NAMES[weather]
	auto_button.text = "自然流转  "+("ON" if auto_time else "OFF")
	var aw = ui.find_child("AutoWeather",true,false)
	if aw: aw.text = "天气自动" if auto_weather else "天气固定"
	cook_button.text = ["点火烧水","水正慢慢热…","撕开包装","五格后自动出锅","五格后自动出锅","已盛好热面","客人正在用餐"][stage]
	cook_button.disabled = stage in [1,5,6]
	if prep:
		if stage==2: cook_button.text="面饼和调料下锅" if prep.packet_stage==1 else "撕开包装"
		if prep.packet_busy: cook_button.disabled=true
		if stage==0 and prep.board_item>=0: cook_button.disabled=true
	serve_button.disabled = stage != 5 or (day_cycle and not day_cycle.has_customer() and not economy.delivery_mode)
	clear_button.disabled = stage == 6
	hint.text = ["砧板备料；最多四种入锅，调味料不占位。","可以听听风，水开会提醒。","面和调料下锅就开始计时，备好食材。","按熟度先后投料，五格后自动停火盛面。","五格已到，正在自动出锅。","端起这碗面，放到窗口长板。","听听客人的评价，再说声再见。"][stage]
	if prep:prep.enlarge_bowl_toppings()
	if prep:bowl.material_override.set_shader_parameter("broth_flavor",prep.flavor)
	bowl.visible = stage == 5 or stage == 6
	for i in range(toppings.size()): toppings[i].visible = bowl.visible and selected.has(i)
	receipt.visible = stage == 6
	receipt_text.text = last_receipt
	next_button.text = "结束对话"
	if prep: prep.refresh()
	if economy: economy.refresh_status()
	sound_button.text = "声音 关" if sound_off else "声音 开"
	if stage==6:
		order_label.text = service.order().thanks
		talk_button.text = "谢谢，下次见"
	else:
		talk_button.text = "回到点单" if chatting else "聊一会儿"
	if service: service.refresh()
	if v4: v4.refresh()
	if day_cycle:day_cycle.refresh()

func _select(index: int, prepared: bool=false, egg_landed:bool=false) -> bool:
	if v5 and v5.busy(): return false
	if v4 and v4.is_barter() and not v4.barter_accepted:
		v4.open_conversation()
		return false
	if stage>4 or index<0 or index>=INGREDIENTS.size():return false
	if stage<3:return prep.prepare_food(index,prepared)
	if selected.has(index) or (index!=3 and food_count()+(1 if prep.egg_pending() and not egg_landed else 0)>=4):return false
	if index in prep.MEAT_IDS and not prepared:
		_notice("整块肉要先拖到砧板，切三刀。")
		return false
	if prep.stock[index]<=0:
		_notice("食材用完了，去货架补货，或等蔬菜长好。")
		return false
	if index==1 and not egg_landed:return prep.cooking_fx.begin_egg()
	prep.stock[index]-=1
	selected.append(index)
	prep.on_added_to_pot(index)
	if simmer: simmer.track(index)
	if index==1: audio.play_at("splash",-.2,-13)
	elif index in [2,5,6,7]: audio.play_at("rustle",.65,-15)
	else: _sound()
	_refresh()
	_save()
	return true

func _remove_slot(index: int) -> void:
	if stage != 0 or index >= selected.size(): return
	prep.stock[int(selected[index])]+=1
	if simmer:simmer.portions.erase(int(selected[index]))
	selected.remove_at(index)
	_sound()
	_refresh()
	_save()

func _cook() -> void:
	if fieldlife and fieldlife.modal_open():return
	if v5 and v5.busy(): return
	if v4 and v4.is_barter() and not v4.barter_accepted:
		v4.open_conversation()
		return
	match stage:
		0:
			if prep.board_item>=0:
				_notice("先把砧板上的整块肉切好，备在砧板旁。")
				return
			if v4: v4.has_water=true
			stage = 1
			cook_remaining = 3.5
			_sound("ignite")
		2:
			if prep.packet_stage==0: prep.tear_packet()
			elif prep.packet_stage==1: prep.drop_noodles()
		3,4:
			_notice("这一锅会走满五格，随后自动停火盛面。")
			return
		_:
			return
	_refresh()
	_save()

func _finish_cooking_automatically()->void:
	if stage not in [3,4] or not simmer or simmer.elapsed<20.0:return
	prep.clear_board()
	simmer.finalize()
	v4.has_water=false
	service.restore_bowl()
	stage=5
	_sound("ding")
	_refresh()
	if simmer.perfect and perfect_fx:perfect_fx.trigger()
	_save()

func _serve() -> void:
	if fieldlife and fieldlife.modal_open():return
	if v5 and v5.busy(): return
	if stage != 5: return
	if perfect_fx:perfect_fx.stop()
	if economy.delivery_mode:
		economy.pack_delivery()
		return
	if day_cycle and not day_cycle.has_customer():
		_notice("窗口现在没有客人。收摊后可接下外卖委托，再做对应料理。")
		return
	service.start_meal()

func _next_customer() -> void:
	if stage != 6 or service.eating: return
	if v5:
		v5.begin_departure()
		return
	_finish_next_customer()

func _finish_next_customer() -> void:
	stage=0
	service.restore_bowl()
	if v4: v4.new_guest()
	prep.reset_packet()
	selected.clear()
	if simmer:simmer.reset()
	last_receipt = ""
	if day_cycle:day_cycle.finish_customer()
	_set_customer()
	_refresh()
	_save()

func _reset_bowl() -> void:
	if stage == 6: return
	if perfect_fx:perfect_fx.stop()
	var discarded=stage>=3
	stage = 0
	cook_remaining = 0
	if not discarded:
		for id in selected: prep.stock[int(id)]+=1
	selected.clear()
	if simmer:simmer.reset()
	prep.reset_packet()
	prep.clear_board()
	if v4: v4.has_water=false
	_notice("这碗已丢弃，重新备一碗。" if discarded else "配料已收回，重新备一碗。")
	_refresh()
	_save()

func _talk() -> void:
	if v5 and v5.busy(): return
	if economy.delivery_mode:
		_notice("这份热面要送给"+economy.job.recipient+"，不用赶路。")
		return
	if day_cycle and not day_cycle.has_customer():
		day_cycle.toggle_management();return
	if v4: v4.open_conversation()

func _cycle_weather() -> void:
	auto_weather = false
	_set_weather((weather+1)%4)
	_notice("天气已固定；点击「天气固定」可恢复自然变化。")

func _set_weather(index: int) -> void:
	weather = posmod(index,4)
	weather_clock = 0
	if weather_button: _refresh()
	_save()

func _cycle_time() -> void:
	var times = [8.0,12.5,18.0,22.0]
	var best = 0
	var dist = 100.0
	for i in range(4):
		if absf(hour-times[i]) < dist:
			dist = absf(hour-times[i])
			best = i
	hour = times[(best+1)%4]
	_refresh()
	_save()

func _period() -> String:
	if hour >= 6 and hour < 11: return "晨"
	if hour >= 11 and hour < 16.5: return "昼"
	if hour >= 16.5 and hour < 19.5: return "暮"
	return "夜"

func _toggle_time() -> void:
	auto_time = not auto_time
	_refresh()
	_save()

func _toggle_weather_auto() -> void:
	auto_weather = not auto_weather
	weather_clock = 0
	_refresh()
	_save()

func _water() -> void:
	if not hydrated:
		hydrated = true
		_sound("water")
		_notice("水珠落下，小葱又精神了一点。葱花可以免费取用。")
	_refresh()
	_save()

func _toggle_sound() -> void:
	sound_off = not sound_off
	audio.tick(1.0)
	_refresh()
	_save()

func _toggle_layers() -> void:
	show_layers = not show_layers
	layer_label.visible = show_layers
	for overlay in scene_overlays: overlay.visible = not show_layers
	for hotspot in hotspots:
		hotspot.mouse_filter = Control.MOUSE_FILTER_IGNORE if show_layers else Control.MOUSE_FILTER_STOP
	receipt.visible = stage==6 and not show_layers

func _notice(text: String) -> void:
	narration.text = text
	notice_seconds = 5.0

func _unhandled_key_input(event: InputEvent) -> void:
	if title_screen and title_screen.visible: return
	if fieldlife and fieldlife.modal_open():return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if economy.panel.visible:
		if event.keycode==KEY_ESCAPE: economy.panel.hide()
		return
	match event.keycode:
		KEY_SPACE: _cook()
		KEY_ENTER:
			if stage == 6:
				if v4.farewell_done: _next_customer()
				else: v4.advance_review()
			else: _serve()
		KEY_W: _cycle_weather()
		KEY_T: _cycle_time()
		KEY_M: _toggle_sound()
		KEY_F1: _toggle_layers()
		KEY_ESCAPE:
			if show_layers: _toggle_layers()
			else: help_panel.visible = not help_panel.visible
		KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _save() -> void:
	if qa_mode and not qa_save_enabled: return
	var state = {"version":5,"simmer":simmer.to_save() if simmer else {},"irrigation":irrigation.to_save() if irrigation else {},"fieldlife":fieldlife.to_save() if fieldlife else {},"tutorial":tutorial.to_save() if tutorial else {},"hearth":v4.to_save(),"service":{"satisfaction":service.satisfaction,"tip":service.last_tip,"guide":service.guide_visible,"eating":service.eating,"discarded":service.discarded,"journal":service.journal,"backpack":backpack.to_save() if backpack else {}},"preparation":prep.to_save(),"roadlife":economy.to_save(),"coins":coins,"day":day,"total_served":total_served,"order_index":order_index,"visits":visits,"hour":hour,"weather":weather,"selected":selected,"stage":stage,"remaining":cook_remaining,"hydrated":hydrated,"receipt":last_receipt,"sound_off":sound_off,"auto_time":auto_time,"auto_weather":auto_weather}
	state.version=6
	state.day_cycle=day_cycle.to_save() if day_cycle else {}
	state.service.reward_pending=service.reward_pending
	state.service.meal_gift=service.meal_gift
	var file = FileAccess.open(save_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(state))

func _load_save() -> void:
	if not FileAccess.file_exists(save_path): return
	var state = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not state is Dictionary or int(state.get("version",0)) not in [1,2,3,4,5,6]: return
	coins = maxi(0,int(state.get("coins",28)))
	day = maxi(1,int(state.get("day",1)))
	total_served = maxi(0,int(state.get("total_served",0)))
	order_index = clampi(int(state.get("order_index",0)),0,4)
	hour = fposmod(float(state.get("hour",9.0)),24.0)
	stage = clampi(int(state.get("stage",0)),0,6)
	cook_remaining = clampf(float(state.get("remaining",0)),0,4)
	selected.clear()
	for item in state.get("selected",[]):
		var index = int(item)
		if index >= 0 and index < INGREDIENTS.size() and not selected.has(index) and (index==3 or food_count()<4): selected.append(index)
	var saved_visits = state.get("visits",{})
	if saved_visits is Dictionary:
		for customer_name in saved_visits: visits[customer_name] = maxi(0,int(saved_visits.get(customer_name,0)))
	hydrated = bool(state.get("hydrated",false))
	last_receipt = str(state.get("receipt",""))
	sound_off = bool(state.get("sound_off",false))
	auto_time = bool(state.get("auto_time",true))
	auto_weather = bool(state.get("auto_weather",true))
	if state.has("preparation"): prep.restore(state.preparation)
	if state.has("roadlife"): economy.restore(state.roadlife)
	if state.has("service"):
		if backpack: backpack.restore(state.service.get("backpack",{}))
		service.satisfaction=int(state.service.get("satisfaction",100))
		service.last_tip=int(state.service.get("tip",0))
		service.guide_visible=bool(state.service.get("guide",true))
		service.discarded=int(state.service.get("discarded",0))
		service.reward_pending=bool(state.service.get("reward_pending",false))
		service.meal_gift=str(state.service.get("meal_gift",""))
		backpack.awarded_this_meal=service.meal_gift
		for flag in service.journal: service.journal[flag]=bool(state.service.get("journal",{}).get(flag,false))
		if bool(state.service.get("eating",false)) and stage==6:
			service.eating=true
			service.meal_time=0
	if state.has("hearth"): v4.restore(state.hearth)
	else: v4.has_water=stage in [1,2,3,4]
	if simmer:simmer.restore(state.get("simmer",{}))
	if irrigation:irrigation.restore(state.get("irrigation",{}))
	if fieldlife:fieldlife.restore(state.get("fieldlife",{}))
	if tutorial:tutorial.restore(state.get("tutorial",{}))
	if day_cycle:day_cycle.restore(state.get("day_cycle",{}))
	_set_weather(int(state.get("weather",0)))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		_shutdown()

func _shutdown() -> void:
	if closing: return
	closing=true
	if audio: audio.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _click_for_qa(point: Vector2) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	get_viewport().push_input(motion)
	for pressed in [true,false]:
		var click = InputEventMouseButton.new()
		click.position=point
		click.global_position=point
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=pressed
		get_viewport().push_input(click)

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join(filename))

func _run_qa() -> void:
	var script="res://scripts/demo.gd" if demo_mode else "res://scripts/verify_interactions.gd"
	if OS.get_cmdline_user_args().has("--qa-title"): script="res://scripts/verify_title_flow.gd"
	if OS.get_cmdline_user_args().has("--qa-six"):script="res://scripts/verify_six.gd"
	if OS.get_cmdline_user_args().has("--qa-eight"):script="res://scripts/verify_eight.gd"
	if OS.get_cmdline_user_args().has("--qa-nine"):script="res://scripts/verify_nine.gd"
	if OS.get_cmdline_user_args().has("--qa-ten"):script="res://scripts/verify_ten.gd"
	await load(script).new().run(self)


func food_count() -> int:
	var count=0
	for id in selected:
		if id!=3: count+=1
	return count

func _build_coin_icon()->void:
	var pixels=["00033330000","00344443000","03455554300","34542245430","35422224530","35424224530","35422224530","34542245430","03455554300","00344443000","00033330000"]
	var colors=[Color(0,0,0,0),Color(0,0,0,0),Color("b7792c"),Color("68472b"),Color("d4a143"),Color("ffe08a")]
	var img=Image.create(11,11,false,Image.FORMAT_RGBA8)
	for y in range(11):
		for x in range(11): img.set_pixel(x,y,colors[int(pixels[y][x])])
	coin_texture=ImageTexture.create_from_image(img)

func add_money_icon(parent:Node,pos:Vector2,edge:float=20)->TextureRect:
	var icon=TextureRect.new()
	icon.texture=coin_texture
	icon.position=pos
	icon.size=Vector2(edge,edge)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon
