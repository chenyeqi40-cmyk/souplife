extends Node
# Contextual guidance and an untimed service loop, shared by native and Web.
const CAST = [
	{"name":"老乔","role":"巡路人","texture":"cast_road.png","row":0,"need":[0,1,3],"avoid":[],"order":"牛肉面，加个蛋，要辣。\n我坐一会儿，你慢慢来。","story":"这是断电的第七年。\n我每天绕一遍旧公路，\n把还亮着灯的地方记下来。","thanks":"这一口辣汤，暖到心里了。\n我会在路标上，画一只面碗。"},
	{"name":"禾苗","role":"种子保管员","texture":"cast_road.png","row":1,"need":[1,2,8],"avoid":[3],"order":"鸡蛋、卷心菜，再放嫩掌片。\n不要辣，我还要尝种子的味道。","story":"罐头总有吃完的那天。\n我背包里留着四包种子，\n春天到哪儿，就种到哪儿。","thanks":"这口青菜还有日晒的香气。\n吃完这一碗，又有力气照顾苗了。"},
	{"name":"阿岚","role":"补给商人","texture":"cast_rail.png","row":0,"need":[4,2],"avoid":[3],"order":"午餐肉面，加卷心菜。\n不放辣，借屋檐歇歇脚。","story":"列车停运了，生意还得做。\n哨站用旧电池换罐头，\n多出来的那节，留给广播。","thanks":"这汤真暖。留一份价目单，\n下趟商队替你捎些补给。"},
	{"name":"阿灯","role":"广播修理员","texture":"cast_rail.png","row":1,"need":[1,5,9],"avoid":[3],"order":"一个蛋，小葱，再加哨站菌菇。\n清淡些，今晚还要试麦克风。","story":"今天收到的不是求救信号，\n是渡口报来的天气预报。\n我想把它播给每个人听。","thanks":"「旧公路营地，明日晴。」\n下一条广播，替你报开摊。"},
	{"name":"小夏","role":"随船护士","texture":"cast_ferry.png","row":0,"need":[1,7],"avoid":[3],"order":"鸡蛋菠菜面，别放辣。\n我值完夜班，想吃点热的。","story":"诊所搬到了渡船上。\n水位退到哪里，船就开到哪里。\n今晚终于能坐下来吃饭了。","thanks":"吃饱就又有力气了。\n给下一位夜班人，也留盏灯。"},
	{"name":"温叔","role":"老摆渡人","texture":"cast_ferry.png","row":1,"need":[4,5,10],"avoid":[],"order":"午餐肉、小葱，加渡口的鱼干。\n盐湖的风，吹得骨头都冷了。","story":"鱼群跟着泉口慢慢回来了。\n我开始摆渡人，也送热饭。\n保温箱绑在船头，很稳当。","thanks":"你做好面，我送到对岸。\n这条水路，总会再热闹起来。"}
]
const BARTER_GUEST={"name":"拾风","role":"沿路流浪的旅人","texture":"cast_barter.png","row":0,"need":[1,5],"avoid":[3],"barter":true,"order":"今天没找到能换钱的东西。\n能用这只铜鸟哨，换一碗鸡蛋葱花面吗？\n不放辣就好。","story":"以前我在旧车站送报，\n这一声哨，是末班车的信号。\n听说阿灯又开始广播，我想去听听。","thanks":"好久没听见有人说，先吃饭。\n吃饱了，脚下的路也好走些。"}
const EXTRA_GUESTS=[
	{"name":"阿砾","role":"修井学徒","texture":"cast_road_extra.png","row":0,"need":[4,1],"avoid":[3],"order":"午餐肉面，加个蛋，不放辣。\n今天拧了一整天阀门，手还发酸。","story":"井站教我先听水声，再动扳手。\n你车上的净水滤芯，是师傅上一班修的。\n他说，能煮饭的水比好听的承诺踏实。","thanks":"明天轮到我检修那台旧泵。\n我会再听仔细一点。\n让开早摊的人，都有水用。"},
	{"name":"白禾","role":"夜班测绘员","texture":"cast_road_extra.png","row":1,"need":[1,7,8],"avoid":[3],"order":"鸡蛋、菠菜，再加嫩掌片。\n清淡些，夜里还要认路上的灯。","story":"老乔记亮灯的地方，我把它们连成路。\n阿灯报天气，小夏把停船的位置寄过来。\n我的地图上，能吃饭的地方用小碗标。","thanks":"今晚会给这里补一只小碗。\n走夜路的人看见它，就知道\n前面有人在等一锅水开。"}
]
const EMPTY_GUEST={"name":"","role":"","texture":"cast_road.png","row":0,"need":[],"avoid":[],"order":"","story":"","thanks":""}
const BOWL_AREA=Rect2(556,487,270,180)
const CUSTOMER_AREA=Rect2(562,419,374,57)
const TRASH_AREA=Rect2(1153,620,127,94)
const PACK_AREA=Rect2(220,548,99,113)
var game
var guide_panel: Panel
var guide: Label
var guide_visible=true
var trash: MeshInstance3D
var vegetable: MeshInstance3D
var drag_kind=""
var farm_index=-1
var pressed_position=Vector2.ZERO
var drag_active=false
var original_positions: Array=[]
var eating=false
var meal_time=0.0
var satisfaction=100
var last_tip=0
var last_frame=-1
var discarded=0
var reward_pending=false
var meal_gift=""
var special_meshes: Array=[]
var special_labels: Array=[]
var slot_icons: Array=[]
var journal={"message":false,"battery":false,"radio":false,"seeds":false,"clinic":false,"warm_route":false}
var story_button: Button
var cabinet: MeshInstance3D
var cabinet_amount=0.0
var cabinet_label: Label
var web_clock=0.0

func setup(owner_game) -> void:
	game=owner_game
	for item in game.materials:
		if item.has("mesh") and item.group=="interior":
			var tex=item.mat.get_shader_parameter("art")
			if tex and tex.resource_path.ends_with("rv_atlas.png"): item.mat.set_shader_parameter("art",load("res://assets/rv_atlas_v3.png"))
	# Existing original screenshot is sampled by UV; no cabin or robot repaint.
	guide_panel=game._panel(game.ui,Rect2(32,276,235,153),Color("e7d9b9"))
	game._label(guide_panel,"小满 / 随车助手",Rect2(12,7,210,27),17)
	guide=game._label(guide_panel,"",Rect2(12,40,210,105),15)
	var robot=game._button(game.ui,"",Rect2(115,112,163,150),func():game.v4.speak_guide(),Color(0,0,0,0),12)
	for state in ["normal","hover","pressed","disabled","focus"]: robot.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	robot.tooltip_text="小满：显示 / 收起步骤指引"
	game.scene_overlays.append(guide_panel)
	game.scene_overlays.append(robot)
	game.receipt.position=Vector2(32,490)
	game.receipt.size=Vector2(235,170)
	game.receipt.get_child(0).position=Vector2(12,6)
	game.receipt.get_child(0).add_theme_font_size_override("font_size",17)
	game.receipt_text.position=Vector2(12,34)
	game.receipt_text.size=Vector2(211,84)
	game.receipt_text.add_theme_font_size_override("font_size",14)
	game.next_button.position=Vector2(12,127)
	game.next_button.size=Vector2(211,34)
	var mat=game._paper_material("trashcan.png")
	trash=game._quad("DiscardBin",Rect2(1400,759,161,116),1.85,mat,Rect2(0,0,.5,1))
	game._label(game.ui,"拖到这里丢弃",Rect2(1140,695,131,18),10,game.PAPER).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for i in range(3):
		var m=game.prep._sprite("RegionSpecial"+str(i),"regional_food.png",i,1,Rect2(879+i*59,568,48,42),1.35)
		m.material_override.set_shader_parameter("magenta_key",true)
		special_meshes.append(m)
		var label=game._label(game.ui,"",Rect2(875+i*59,607,60,17),10,game.PAPER)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		special_labels.append(label)
		var topping=game.prep._sprite("SpecialTopping"+str(i),"regional_food.png",i,1,Rect2(643+i*36,570,58,48),1.96)
		topping.material_override.set_shader_parameter("magenta_key",true)
		topping.hide()
		game.toppings.append(topping)
	for button in game.slots:
		var pic=TextureRect.new()
		pic.position=Vector2(5,3)
		pic.size=Vector2(33,26)
		pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var mat_icon=ShaderMaterial.new()
		mat_icon.shader=load("res://shaders/icon_key.gdshader")
		pic.material=mat_icon
		button.add_child(pic)
		slot_icons.append(pic)
	for m in [game.bowl]+game.toppings: original_positions.append(m.position)
	var actor_mesh=game._quad("StandardPortraitMesh",Rect2(685,183,360,360),-1.5,game.character_material)
	game.character.mesh=actor_mesh.mesh;actor_mesh.queue_free()
	game.economy.apply_map()
	story_button=game._button(game.ui,"",Rect2(331,402,229,29),story_action,game.TEAL,13)
	story_button.hide()
	game.scene_overlays.append(story_button)
	# The top cupboard is an actual hinged paper door sampled from the same art.
	var dark=StandardMaterial3D.new()
	dark.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.cull_mode=BaseMaterial3D.CULL_DISABLED
	dark.albedo_color=Color("354842")
	game._quad("WarehouseInterior",Rect2(344,0,606,113),.10,dark)
	var shelf=StandardMaterial3D.new()
	shelf.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	shelf.cull_mode=BaseMaterial3D.CULL_DISABLED
	shelf.albedo_color=Color("b3ad89")
	for y in [40,80]: game._quad("WarehouseShelf"+str(y),Rect2(353,y,587,4),.15,shelf)
	cabinet=game.prep.reference_piece("OriginalCabinetDoor",Rect2(280,0,495,92),Rect2(280.0/1280,0,495.0/1280,92.0/714),.35)
	# Shift local vertices down so rotation happens at the top hinge.
	var shifted=game._quad("CabinetHingeMesh",Rect2(785-495*1.2265625/2,437.5,495*1.2265625,92*1.2265625),0,cabinet.material_override)
	cabinet.mesh=shifted.mesh;shifted.queue_free()
	game.prep._place(cabinet,Vector2(527.5,0),.35)
	cabinet_label=game._label(game.ui,"",Rect2(296,8,463,69),14,Color("e6dbc0"))
	cabinet_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.coins_label.get_parent().position=Vector2(19,80)
	game.coins_label.get_parent().size=Vector2(96,28)
	game.coins_label.position=Vector2(8,1)
	game.coins_label.add_theme_font_size_override("font_size",17)
	game.chapter_label.get_parent().position=Vector2(465,107)
	game.chapter_label.get_parent().size=Vector2(296,25)
	game.chapter_label.position=Vector2(7,0)

func order() -> Dictionary:
	var c:Dictionary
	if game.get("day_cycle") and game.day_cycle.initialized:
		if game.economy.delivery_mode and not game.economy.job.is_empty():
			c=EMPTY_GUEST.duplicate(true);c.name=game.economy.job.recipient;c.need=game.economy.job.need.duplicate();return c
		if not game.day_cycle.has_customer():return EMPTY_GUEST.duplicate(true)
		c=customer_data(game.day_cycle.current_guest_id)
	else:
		c=(BARTER_GUEST if game.economy.map_index==0 and game.order_index==2 else CAST[game.economy.map_index*2+game.order_index%2]).duplicate(true)
	match c.name:
		"老乔":
			c.story="断电那晚，妻子留在盐湖诊所。\n我守这条公路七年，等她的呼号。\n阿岚有电池，阿灯会修广播。" if not journal.radio else "广播修好了。小夏说，旧诊所\n的值班册还在，里面有妻子的字。\n这次我想去渡口，不只守着路。"
			if journal.radio: c.thanks="收音机终于响了。谢谢你\n替我把一句话，带过这么远。"
		"阿岚":
			c.story="罐头可以标价，有些东西不能。\n这节电池是老乔当年救我时留下的。\n我一直没舍得卖。" if journal.message else "货架空了，我就往下一个站走。\n老乔救过我的车。我留了一节\n电池，却一直没等到他开口。"
			if journal.radio: c.thanks="哨站的广播我听见了。\n人情这东西，终于有了回声。"
		"阿灯":
			c.story="停电前我念列车时刻表，\n停电后，我开始念失踪者的名字。\n只缺一节电池，今晚就能再播。" if not journal.radio else "第一次播天气预报，我手在抖。\n禾苗说，知道哪天下雨，就敢播种。\n小夏说，她终于知道渡船几时来。"
		"禾苗":
			c.story="这些种子，是母亲最后一季留下的。\n我不敢全种下去，怕再没有春天。\n听到阿灯报雨，我想分一半给诊所。" if journal.radio else "母亲把最后一把种子交给我，\n说别拿它们换罐头。可没有预报，\n我不知道这一场雨能下多久。"
		"小夏":
			c.story="老乔的妻子教过我包扎。\n她的值班册里，每页都写着：\n先让来的人吃口热的，再问来处。"
			if journal.clinic: c.thanks="禾苗的种子已经放进育苗盘。\n我们给第一排贴了老诊所的名字。"
		"温叔":
			c.story="以前一张船票，只管送到对岸。\n现在船上有药、有种子，还有你的面。\n我想每周留一个晚班，专送这些。" if journal.clinic else "诊所搬上渡船那天，小夏没哭。\n她只是问，还能不能给窗台留块地。\n我答应了，到现在却只找来空花盆。"
			if journal.warm_route: c.thanks="明晚第一班「热饭船」启航。\n广播会报站，诊所的灯会等着。"
	return c

func customer_data(who:String)->Dictionary:
	if who==BARTER_GUEST.name:return BARTER_GUEST.duplicate(true)
	for record in CAST+EXTRA_GUESTS:
		if record.name==who:return record.duplicate(true)
	return EMPTY_GUEST.duplicate(true)

func customer_frame(frame: int) -> void:
	var c=order()
	if c.name=="" or (game.get("day_cycle") and not game.day_cycle.has_customer()):
		game.character.hide();return
	game.character.show()
	game.character_material.set_shader_parameter("art",load("res://assets/"+c.texture))
	game.character_material.set_shader_parameter("frame_override",true)
	game.character_material.set_shader_parameter("frame_rect",Vector4(frame*.25,c.row*.5,.25,.5))
	game.character_material.set_shader_parameter("magenta_key",true)
	game.character_material.set_shader_parameter("portrait",true)
	last_frame=frame

func refresh() -> void:
	for i in range(3):
		special_meshes[i].visible=game.prep.stock[8+i]>0
		special_labels[i].text=["嫩掌片","菌菇","鱼干"][i]+"×"+str(game.prep.stock[8+i])
	game.receipt.visible=false
	game.economy.job_label.visible=not game.economy.job.is_empty()
	game.next_button.disabled=eating
	if story_button:
		if game.backpack:game.backpack.refresh_choices()
		else:story_button.hide()

func guide_text() -> String:
	if game.get("day_cycle") and not game.day_cycle.has_customer():
		if game.economy.delivery_mode:return "这份外卖是收摊后的约定。\n照着外卖单备料、煮面，再打包送出去。"
		return "今天收摊了。现在可以直接去猎场，或整理物资、送外卖。\n点下方日期屏开始明天。" if game.day_cycle.is_closed() else "今天似乎不会再有人来了。\n点「结束今天营业」，就能整理物资或出门啦。" if game.day_cycle.is_roster_complete() else "下一位客人正在路上。\n今天的名单还没接待完，我们再等一会儿。"
	if eating: return "客人在吃面啦。\n配料越合口味，小费越多。\n我们等他慢慢吃完。"
	if game.stage==6:return "听完评价，说声再见。\n下一位会自己走过来；\n今天的客人都见完，再收摊。"
	if game.stage==5: return "面在我们的台面上。\n点碗或拖给客人，就能送餐。\n做错了？拖到右下垃圾桶。"
	if game.stage==4: return "到计划终点了，点锅关火。\n继续煮，食材就会过熟哦。"
	if game.stage==3: return "看锅下的共同时间条。\n需要格数少的食材，晚一点下。"
	if game.stage==2: return "袋子撕开了，再点一次：\n面饼和调料会一起下锅。" if game.prep.packet_stage==1 else "水开了。点桌上红色泡面袋，\n听它的封口慢慢撕开。"
	if game.stage==1: return "水在加热，等它沸腾。\n这会儿可以看看备料的最佳格数。"
	if game.prep.board_item>=0: return "点砧板，切三刀。\n切好后先备在台面，开锅再投料。" if game.prep.cuts<3 else "肉切好啦。\n点肉片备好，再点锅烧水。"
	if game.selected.is_empty(): return "客人已经点单了。\n点整块肉或拖到砧板；\n生鸡蛋在最长格子里。"
	return "青菜从右侧培养皿采到砧板。\n先看熟度、备好料，再烧水。\n采过的菜浇一次水就能再长。"

func tick(delta: float) -> void:
	web_clock+=delta
	if OS.has_feature("web") and web_clock>.4:
		web_clock=0
		var state={"region":game.economy.MAPS[game.economy.map_index].name,"customer":order().name,"stage":game.PHASES[game.stage],"coins":game.coins,"gifts":game.backpack.gifts,"guide":guide_text()}
		JavaScriptBridge.eval("window.stallState="+JSON.stringify(state)+";",true)
		var command=JavaScriptBridge.eval("window.stallCommand || ''",true)
		if command=="backpack": game.backpack.pinned=true;JavaScriptBridge.eval("window.stallCommand='';",true)
	guide_panel.visible=guide_visible and not game.show_layers
	guide.text=guide_text()
	var hovering=Rect2(280,0,495,94).has_point(game.get_global_mouse_position()) and game.prep.input_allowed()
	if game.backpack: hovering=game.backpack.wants_open()
	cabinet_amount=move_toward(cabinet_amount,1.0 if hovering else 0.0,delta*4)
	cabinet.rotation.x=-cabinet_amount*1.47
	cabinet_label.visible=false
	var meat=game.prep.stock[0]+game.prep.stock[4]+game.prep.stock[11]
	if game.prep.stock.size()>14:meat+=game.prep.stock[14]
	cabinet_label.text="随车仓库  /  物资随车保留\n肉 %d   鸡蛋 %d   净水 %d\n特产：嫩掌片 %d · 菌菇 %d · 鱼干 %d" % [meat,game.prep.stock[1],game.prep.water_store,game.prep.stock[8],game.prep.stock[9],game.prep.stock[10]]
	var over=TRASH_AREA.has_point(game.get_global_mouse_position()) and drag_kind=="bowl"
	trash.material_override.set_shader_parameter("frame_override",true)
	trash.material_override.set_shader_parameter("frame_rect",Vector4(.5 if over else 0,0,.5,1))
	# Its underlying mesh carries half-atlas UVs; normalize them before framing.
	trash.material_override.set_shader_parameter("frame_source",Vector2(2,1))

func story_choice() -> String:
	match order().name:
		"老乔": return "替老乔给阿岚捎句话" if not journal.message else ""
		"阿岚": return "收下留给老乔的电池" if journal.message and not journal.battery and not journal.radio else ""
		"阿灯": return "把电池交给阿灯修广播" if journal.battery and not journal.radio else ""
		"禾苗": return "带一半种子去盐湖诊所" if journal.radio and not journal.seeds else ""
		"小夏": return "把禾苗的种子交给小夏" if journal.seeds and not journal.clinic else ""
		"温叔": return "约定每周的热饭船" if journal.clinic and game.economy.deliveries>0 and not journal.warm_route else ""
	return ""

func story_action() -> void:
	if story_choice()=="": return
	match order().name:
		"老乔": journal.message=true;game._notice("记下口信：去铁轨哨站找阿岚。")
		"阿岚": journal.battery=true;game._notice("收到旧电池。阿灯就在铁轨哨站。")
		"阿灯": journal.battery=false;journal.radio=true;game._notice("广播修好了。禾苗终于能听到天气预报。")
		"禾苗": journal.seeds=true;game._notice("收到半袋种子，带给盐湖渡口的小夏。")
		"小夏": journal.clinic=true;game._notice("诊所种下了新的菜。温叔想和你聊聊夜班船。")
		"温叔": journal.warm_route=true;game._notice("约定了热饭船。广播、种子和一碗面，把三个营地连在一起。")
	game.order_label.text=order().story
	game.order_label.add_theme_font_size_override("font_size",13)
	# The review caller saves story flags and the associated gift atomically.
	game._refresh()

func score() -> int:
	var errors=0
	for id in order().need:
		if not game.selected.has(id): errors+=1
	for id in order().avoid:
		if game.selected.has(id): errors+=1
	return maxi(0,100-errors*30-(game.simmer.penalty() if game.simmer else 0))

func start_meal() -> void:
	if game.v4: game.v4.serve_to_table()

func complete_meal() -> void:
	if not eating: return
	if game.get("day_cycle") and not game.day_cycle.has_customer():eating=false;return
	eating=false
	last_tip=8 if satisfaction==100 else (4 if satisfaction>=70 else (1 if satisfaction>=40 else 0))
	if game.v4.is_barter(): last_tip=0
	else: game.coins+=12+last_tip
	game.total_served+=1
	var who=order().name
	game.visits[who]=int(game.visits.get(who,0))+1
	game.last_receipt="满意度  %d%%\n餐费  +12 铜片    小费  +%d 铜片\n%s" % [satisfaction,last_tip,"很合口味，谢谢这碗热面！" if satisfaction>=70 else "下次留意点单里的偏好。"]
	# First let the guest taste and react. Gifts are considered on the next line,
	# after the player has seen that reaction, never promised before this meal.
	reward_pending=true;meal_gift="";game.backpack.awarded_this_meal=""
	customer_frame(review_frame())
	if game.v4: game.v4.review_ready()
	game._refresh()
	game._save()

func recipe_matches()->bool:
	for id in order().need:
		if not game.selected.has(id):return false
	for id in order().avoid:
		if game.selected.has(id):return false
	return true

func review_frame()->int:
	return 2 if satisfaction>=70 else 0 if satisfaction>=40 else 3

func claim_review_reward()->String:
	if not reward_pending:return meal_gift
	reward_pending=false
	if game.v4.is_barter():
		if game.v4.barter_accepted and game.simmer.perfect and recipe_matches() and not game.backpack.gifts.has("拾风"):
			game.backpack.gifts.append("拾风");meal_gift="旧站铜鸟哨"
			game.backpack.awarded_this_meal=meal_gift
			game.backpack.show_item(8)
	else:meal_gift=game.backpack.award_after_meal()
	if meal_gift!="":game.last_receipt+="\n赠礼："+meal_gift
	return meal_gift

func review_text(line:int)->String:
	if line==0:
		if satisfaction<40:return "这碗吃着不太对。\n下次照顾一下点单和火候吧。"
		if game.simmer.perfect and recipe_matches():return "等一下……这口面！\n每样火候都刚刚好，太好吃了。\n我已经很久没吃到这样的味道了。"
		return "好吃，热汤和面都很暖。\n能在路上坐下来吃这一碗，真好。" if satisfaction>=70 else "吃着暖暖的。\n有些配料和我想的不太一样，\n不过能坐下来吃饭，总是好的。"
	if meal_gift!="":
		var offers={"老乔":"这只旧黄铜罗盘跟了我很多年。\n把它送给你，愿你往后的路\n也总能通向一盏亮灯。", "阿岚":"这节旧电池交给你。\n请带给阿灯，让老乔听见广播。\n这回，它终于有了该去的地方。", "阿灯":"这是我旧制服上的广播徽章。\n送给你吧。有人肯认真做饭，\n这条路就值得认真报一遍。", "禾苗":"我想好了，这半袋种子给你。\n替我带到诊所，好吗？\n春天不能只放在我的口袋里。", "温叔":"这只小渡船挂坠送给你。\n你把面煮热，我把船开稳。\n往后，每一盏灯都是我们的站牌。", "拾风":"好吃得让我想起旧站的灯。\n这只铜鸟哨归你了。\n谢谢你肯给我这一碗热饭。"}
		return offers.get(order().name,"把这份「"+meal_gift+"」送给你。\n谢谢这碗好面。")
	return "谢谢你让我在这儿坐了一会儿。\n吃饱了，接着上路。" if game.v4.is_barter() else order().thanks

func restore_bowl() -> void:
	var meshes=[game.bowl]+game.toppings
	for i in range(meshes.size()):
		meshes[i].position=original_positions[i]
		meshes[i].scale=Vector3.ONE

func discard_bowl() -> void:
	if game.stage!=5 or eating: return
	discarded+=1
	restore_bowl()
	game.stage=0
	if game.v4: game.v4.has_water=false
	game.selected.clear()
	if game.simmer:game.simmer.reset()
	game.prep.reset_packet()
	game.audio.play_at("bowl",.85,-12)
	game._notice("这碗已丢弃，食材不退回。重新给客人做好吃的吧。")
	game._refresh()
	game._save()

func _input(event: InputEvent) -> void:
	if game and game.v5: return
	if not game or not game.prep.input_allowed(): return
	if event is InputEventMouseMotion and drag_kind!="":
		if event.position.distance_to(pressed_position)>8: drag_active=true
		if drag_active:
			if drag_kind=="bowl":
				var offset=event.position-pressed_position
				var meshes=[game.bowl]+game.toppings
				for i in range(meshes.size()): meshes[i].position=original_positions[i]+Vector3(offset.x*.012265625,-offset.y*.012265625,2)
			else:
				vegetable.show()
				game.prep._place(vegetable,event.position,3.0)
		get_viewport().set_input_as_handled()
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT: return
	var pos=event.position
	if event.pressed:
		if game.stage<=4:
			for i in range(3):
				if Rect2(875+i*59,570,56,42).has_point(pos):
					game._select(8+i)
					get_viewport().set_input_as_handled()
					return
		if game.stage==2 and (PACK_AREA.has_point(pos) or (game.prep.packet_stage==1 and Rect2(531,454,112,158).has_point(pos))):
			game._cook()
			get_viewport().set_input_as_handled()
			return
		if game.stage==5 and BOWL_AREA.has_point(pos): drag_kind="bowl"
		elif game.stage<=4:
			for i in range(4):
				if Rect2(1104,211+i*106,153,71).has_point(pos):
					if game.prep.farm_growth[i]<1 and game.prep.stock[game.prep.FARM_IDS[i]]<=0:
						game._notice("菜还没长好。浇一次水，再等它慢慢长。")
						get_viewport().set_input_as_handled()
						return
					drag_kind="veg"
					farm_index=i
					if vegetable: vegetable.queue_free()
					vegetable=game.prep.reference_piece("DraggedOriginalVegetable",Rect2(0,0,123,102),game.prep.farm_source(i),3)
					vegetable.material_override.set_shader_parameter("plant",true)
					vegetable.material_override.set_shader_parameter("leaves_only",true)
					vegetable.hide()
					break
		if drag_kind!="":
			pressed_position=pos
			drag_active=false
			get_viewport().set_input_as_handled()
	elif drag_kind!="":
		var kind=drag_kind
		drag_kind=""
		if kind=="bowl":
			restore_bowl()
			if drag_active and TRASH_AREA.has_point(pos): discard_bowl()
			elif CUSTOMER_AREA.has_point(pos): game._serve()
		else:
			vegetable.hide()
			if game.prep.POT.has_point(pos) or not drag_active: game.prep.harvest_plant(farm_index)
		drag_active=false
		get_viewport().set_input_as_handled()
