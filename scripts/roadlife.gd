extends Node
const MAP_TEXTURES=["road_region.png","rail_region.png","lake_region.png"]
const SPECIAL_NAMES=["去刺仙人掌","哨站菌菇","盐鳍鱼干"]
const SPECIAL_DESC=["耐旱菜圃种的嫩掌片，只有公路营地出售。","旧车厢的阴凉菌床出产，只在铁轨哨站补货。","盐湖养殖塘的晒干盐鳍鱼，只有渡口能买到。"]
const MAPS = [
	{"name":"旧公路营地","sub":"第七个断电年 · 公路仍有人守着","radio":"北边的信号塔恢复了。巡路人约好，把消息和热汤一起送出去。","job":"守塔人的晚饭","recipient":"守塔人","need":[0,1,8],"destination":1,"reward":32},
	{"name":"铁轨哨站","sub":"废弃铁路 · 用旧电池点亮屋檐","radio":"哨站把停运的车厢改成了客房。今晚，一位修船匠还没吃饭。","job":"渡口的夜班","recipient":"修船匠","need":[4,7,9],"destination":2,"reward":34},
	{"name":"盐湖渡口","sub":"退潮盐湖 · 温室和渔船共用一盏灯","radio":"渡船终于修好了。船长想把第一份热饭，带回救过他的营地。","job":"给营地报平安","recipient":"营地护士","need":[1,2,10],"destination":0,"reward":36}
]
const GOODS = [
	[{"id":"beef","name":"整块牛肉 × 3","price":12,"food":0,"qty":3,"desc":"公路商队带来的罐封牛肉，开罐后整块备料。"},{"id":"eggs","name":"生鸡蛋 × 6","price":8,"food":1,"qty":6,"desc":"营地鸡舍的新鲜鸡蛋，放入最长的食材格。"},{"id":"oil","name":"辣油 × 5","price":7,"food":3,"qty":5,"desc":"一点红油，把冷夜煮热。"},{"id":"box","name":"保温外卖箱","price":24,"scrap":1,"desc":"每次完成外卖额外获得 6 枚铜片。"}],
	[{"id":"cold_mushroom","name":"霜苔茸 × 2","price":9,"food":12,"qty":2,"desc":"在车厢背阴处采收，采下后只存冷藏箱。"},{"id":"spam","name":"整块午餐肉 × 4","price":10,"food":4,"qty":4,"desc":"哨站仓库的存货，先切片再下锅。"},{"id":"eggs","name":"生鸡蛋 × 4","price":7,"food":1,"qty":4,"desc":"沿铁路运来的小批补给。"},{"id":"lamp","name":"回收育苗灯","price":22,"scrap":1,"desc":"浇满水后，蔬菜的再生时间从 30 秒缩短至 16 秒。"}],
	[{"id":"cold_fish","name":"盐鳍鲜鱼 × 2","price":10,"food":13,"qty":2,"desc":"鱼鳍排盐，清甜的鱼肉只放冰箱冷藏。"},{"id":"beef","name":"船队牛肉 × 2","price":9,"food":0,"qty":2,"desc":"渡船送来的密封补给。"},{"id":"spam","name":"午餐肉 × 2","price":6,"food":4,"qty":2,"desc":"渔民换来的罐头。"},{"id":"oil","name":"盐湖辣油 × 8","price":9,"food":3,"qty":8,"desc":"盐湖集市的独家大瓶装。"},{"id":"collector","name":"屋顶集雨器","price":20,"scrap":1,"desc":"下雨时每 15 秒收集一份可浇灌的净水。"}]
]
var game
var map_index=0
var scrap=0
var upgrades: Array = []
var job: Dictionary = {}
var delivery_mode=false
var deliveries=0
var rain_clock=0.0
var autosave_clock=0.0
var panel: Panel
var content: Control
var nav_button: Button
var job_label: Label
var map_view=0
var tab="route"
var status=""
var exterior: MeshInstance3D
var exterior_original: Mesh
var exterior_original_material: Material
var package: MeshInstance3D
var shop_scroll:ScrollContainer

func setup(owner_game) -> void:
	game=owner_game
	exterior=game.world.find_child("Exterior_Skyline",true,false)
	exterior_original=exterior.mesh
	exterior_original_material=exterior.material_override
	panel=game._panel(game.ui,Rect2(281,103,778,562),game.PAPER)
	panel.z_index=30
	panel.hide()
	nav_button=game._button(game.ui,"路线 · 商店 · 外卖",Rect2(32,444,235,41),open_menu,Color("cbb88c"),16)
	job_label=game._label(game.ui,"",Rect2(32,491,232,124),14,Color("f8ebcc"))
	job_label.add_theme_color_override("font_shadow_color",Color("294442"))
	job_label.add_theme_constant_override("shadow_outline_size",5)
	package=game.prep._sprite("PackedDelivery","farm_packet.png",5,3,Rect2(185,471,90,106),1.45)
	package.hide()
	refresh_status()

func tick(delta: float) -> void:
	if upgrades.has("collector") and game.weather==1:
		rain_clock+=delta
		if rain_clock>=15:
			var gained=int(rain_clock/15)
			rain_clock=fmod(rain_clock,15)
			game.prep.water_store=mini(20,game.prep.water_store+gained)
			game.prep.refresh()
	else: rain_clock=0
	autosave_clock+=delta
	if autosave_clock>=10:
		autosave_clock=0
		game._save()

func refresh_status() -> void:
	if not job_label: return
	nav_button.text="商店"
	nav_button.tooltip_text="营业中也可以购买补给"
	game.chapter_label.text="第 %02d 天 / %s" % [game.day,MAPS[map_index].name]
	job_label.text="公路广播\n"+MAPS[map_index].radio
	if not job.is_empty():
		job_label.text="外卖："+job.title+"\n送往 "+MAPS[int(job.destination)].name+"\n"+("已打包 · 随时可出发" if job.packed else ("正在备餐 · 不限时" if delivery_mode else "已接单 · 等你开始"))
	package.visible=not job.is_empty() and bool(job.packed)
	game.serve_button.text="打包外卖" if delivery_mode else "出餐"

func open_menu() -> void:
	open_mode("shop")

func open_mode(mode:String) -> void:
	if mode not in ["route","shop","job","audio"]:return
	if mode in ["route","job"] and not _resources_available():return
	tab=mode;status=""
	map_view=map_index
	if game.get("day_cycle"):game.day_cycle.dismiss_management()
	if game.get("fieldlife"):game.fieldlife.close_fridge()
	if game.get("backpack"):game.backpack.pinned=false;game.backpack.suppressed=true;game.backpack.panel.hide()
	panel.show()
	redraw()

func redraw() -> void:
	if content:
		panel.remove_child(content)
		content.queue_free()
	content=Control.new()
	content.size=panel.size
	panel.add_child(content)
	game._label(content,{"route":"地图","shop":"商店","job":"外卖","audio":"声音设置"}.get(tab,"商店"),Rect2(24,7,340,30),23)
	game._label(content,"%d     零件 %d     外卖完成 %d" % [game.coins,scrap,deliveries],Rect2(398,10,302,26),15)
	game._button(content,"×",Rect2(728,15,33,32),func():panel.hide(),game.PAPER,19)
	game.add_money_icon(content,Vector2(373,15),17)
	game._label(content,"营业中也能补给，窗前的客人会等你。" if tab=="shop" else "收摊后的时间，按自己的节奏安排。",Rect2(25,69,727,28),15)
	if tab=="route": draw_route()
	elif tab=="shop": draw_shop()
	elif tab=="job": draw_job()
	else: draw_audio()
	game._label(content,status,Rect2(24,517,730,34),15,Color("835331"))

func draw_route() -> void:
	for i in range(3):
		game._button(content,MAPS[i].name+(" · 当前" if map_index==i else ""),Rect2(24+i*245,119,232,43),func():map_view=i;redraw(),Color("a9c2b4") if i==map_view else game.PAPER,16)
	var m=MAPS[map_view]
	var pic=TextureRect.new()
	pic.position=Vector2(25,180)
	pic.size=Vector2(370,170)
	pic.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture=load("res://assets/"+MAP_TEXTURES[map_view])
	content.add_child(pic)
	game._label(content,m.sub+"\n特产："+SPECIAL_NAMES[map_view],Rect2(419,181,333,60),17)
	game._label(content,m.radio,Rect2(419,241,326,100),17)
	game._label(content,"每处营地有不同的商店、客人和食材。\n接待完当日名单并收摊后，可以开车前往下一处。\n旅行到站不会自动翻到下一天。",Rect2(26,368,710,79),17)
	game._button(content,"已在这里" if map_view==map_index else "收好摊位 · 前往这里",Rect2(26,462,358,40),travel.bind(map_view),game.AMBER,17).disabled=map_view==map_index

func travel(destination: int) -> bool:
	if not _resources_available():return false
	if game.get("day_cycle") and game.day_cycle.has_customer():
		status="先接待完窗口的这位客人，再开车出发。";redraw();return false
	if game.v5 and (game.v5.busy() or game.stage==6):
		status="先和这位客人说声再见，等他离开窗口再出发。"
		redraw()
		return false
	if destination<0 or destination>=3 or destination==map_index: return false
	if game.stage not in [0,6] or (game.stage==0 and not game.selected.is_empty()) or game.prep.board_item>=0 or game.prep.packet_busy:
		status="先把当前一碗做好，或点击「重新做」收回配料。"
		redraw()
		return false
	if game.stage==6: game._next_customer()
	if game.service.eating: return false
	game.order_index=0
	map_index=destination
	map_view=destination
	game.hour=fposmod(game.hour+1.5,24)
	apply_map()
	if game.get("day_cycle"):game.day_cycle.on_region_changed()
	game._set_customer()
	game._refresh()
	game._notice("房车停靠"+MAPS[map_index].name+"，窗外又有了新的故事。")
	panel.hide()
	if game.v5 and (not game.get("day_cycle") or game.day_cycle.has_customer()):game.v5.begin_arrival()
	game._save()
	return true

func apply_map() -> void:
	var temp=game._quad("MapTransferMesh",Rect2(340,135,965,420),-4.5,exterior_original_material,Rect2(0,0,1,1))
	exterior.mesh=temp.mesh
	temp.queue_free()
	exterior.material_override=exterior_original_material
	exterior.material_override.set_shader_parameter("art",load("res://assets/"+MAP_TEXTURES[map_index]))
	exterior.material_override.set_shader_parameter("background_band",0.0)
	refresh_status()

func draw_shop() -> void:
	game._label(content,MAPS[map_index].name+" · 本地货架",Rect2(26,111,442,28),20)
	game._button(content,"水井 · 免费补水",Rect2(513,107,238,34),refill,game.PAPER,15)
	shop_scroll=ScrollContainer.new();shop_scroll.position=Vector2(24,151);shop_scroll.size=Vector2(729,354)
	shop_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(shop_scroll)
	var goods=local_goods()
	var shelves=Control.new();shelves.custom_minimum_size=Vector2(708,goods.size()*65);shop_scroll.add_child(shelves)
	for i in range(goods.size()):
		var g=goods[i]
		var row=game._panel(shelves,Rect2(0,i*65,704,61),Color("dfd3b8"))
		if g.has("food") and game.get("fieldlife"):
			game.fieldlife.make_icon(row,shop_food_icon(int(g.food)),Rect2(6,5,48,49))
		game._label(row,g.name,Rect2(60,4,412,25),16)
		game._label(row,g.desc,Rect2(60,29,412,28),12)
		var owned=upgrades.has(g.id)
		var locked=g.has("requires") and not upgrades.has(g.requires)
		var caption="已安装" if owned else ("需先安装 8 发弹仓" if locked else "%d 铜片%s · 买入" % [g.price," +1零件" if g.has("scrap") else ""])
		game._button(row,caption,Rect2(491,10,199,40),buy.bind(i),game.TEAL,14).disabled=owned or locked

func shop_food_icon(id:int)->Texture2D:
	if id in [0,4,1]:
		var art=AtlasTexture.new();art.atlas=load("res://assets/prep_atlas.png")
		var cell=Vector2(art.atlas.get_width()/3.0,art.atlas.get_height()/2.0)
		art.region=Rect2(Vector2(([0,4,1].find(id))*cell.x,0),cell)
		return art
	return game.fieldlife.food_icon(id)

func local_goods() -> Array:
	var result=GOODS[map_index].duplicate(true)
	result.append({"id":"special"+str(map_index),"name":SPECIAL_NAMES[map_index]+" × 4 · 当地特产","price":6+map_index*2,"food":8+map_index,"qty":4,"desc":SPECIAL_DESC[map_index]})
	result.append({"id":"magazine_8","name":"8 发弹仓","price":70,"desc":"容量从 6 发提升到 8 发，所有猎场通用。"})
	result.append({"id":"magazine_10","name":"10 发弹仓","price":120,"requires":"magazine_8","desc":"先装好 8 发弹仓，再升级至 10 发。"})
	return result

func buy(index: int) -> bool:
	if index<0 or index>=local_goods().size(): return false
	var g=local_goods()[index]
	if upgrades.has(g.id): return false
	if g.has("requires") and not upgrades.has(g.requires):
		status="先安装 8 发弹仓，才能继续升级。"
		if panel.visible:redraw()
		return false
	if game.coins<int(g.price) or scrap<int(g.get("scrap",0)):
		status="补给不够。接待客人赚铜片；完成外卖回收零件。"
		if panel.visible: redraw()
		return false
	game.coins-=int(g.price)
	scrap-=int(g.get("scrap",0))
	if g.has("food"): game.prep.stock[int(g.food)]+=int(g.qty)
	else: upgrades.append(g.id)
	game.audio.play_at("tap",0,-16)
	game._refresh()
	game._save()
	status="已补充："+g.name
	if panel.visible: redraw()
	return true

func refill() -> void:
	game.prep.water_store=maxi(8,game.prep.water_store)
	game.prep.refresh()
	game.audio.play_at("water",.5,-14)
	game._save()
	status="水壶装满了。屋顶集雨器可额外收集雨水，最多 20 份。"
	redraw()

func draw_job() -> void:
	var data=MAPS[map_index]
	if job.is_empty():
		game._label(content,"一碗面，也能把公路连起来。",Rect2(28,120,716,36),25)
		game._label(content,data.job,Rect2(28,184,704,34),24)
		game._label(content,"收餐人："+data.recipient+"\n目的地："+MAPS[int(data.destination)].name+"\n配料："+food_text(data.need)+"\n报酬：%d 枚铜片 + 1 个回收零件" % data.reward,Rect2(28,230,700,157),20)
		game._label(content,"收摊后：接受 → 备餐 → 打包 → 前往目的地 → 交付\n结束营业后，外卖才开放；路上没有倒计时。",Rect2(28,396,700,63),16)
		var available=not game.get("day_cycle") or game.day_cycle.can_delivery()
		game._button(content,"接下这份外卖" if available else "收摊后开放外卖",Rect2(28,466,719,40),accept_job,game.AMBER,18).disabled=not available
	else:
		game._label(content,job.title,Rect2(28,128,700,43),26)
		game._label(content,"送给："+job.recipient+"\n送往："+MAPS[int(job.destination)].name+"\n配料："+food_text(job.need)+"\n状态："+("已打包，热汤稳稳放好了" if job.packed else "等待备餐，不限时"),Rect2(28,203,700,161),21)
		game._label(content,"用完零件还能接新的委托。保温外卖箱每单额外 +6 铜片。",Rect2(28,389,704,58),16)
		if job.packed:
			game._button(content,"交付热面" if map_index==int(job.destination) else "打开地图，前往目的地",Rect2(28,465,720,42),deliver if map_index==int(job.destination) else func():open_mode("route");map_view=int(job.destination);redraw(),game.AMBER,17)
		else:
			game._button(content,"回到物资整理" if delivery_mode else "开始做这份外卖",Rect2(28,465,720,42),toggle_delivery,game.AMBER,17)

func food_text(items: Array) -> String:
	var names=PackedStringArray()
	for i in items: names.append(game.INGREDIENTS[int(i)])
	return "、".join(names)

func accept_job() -> void:
	if not _delivery_available():return
	if not job.is_empty(): return
	var m=MAPS[map_index]
	job={"title":m.job,"recipient":m.recipient,"need":m.need.duplicate(),"destination":m.destination,"reward":m.reward,"packed":false}
	game._save()
	refresh_status()
	redraw()

func toggle_delivery() -> void:
	if not _delivery_available() or job.is_empty() or job.get("packed",false):return
	if game.stage!=0 or not game.selected.is_empty() or game.prep.board_item>=0:
		status="先完成当前备餐，或点击「重新做」收回配料。"
		redraw()
		return
	delivery_mode=not delivery_mode
	game._set_customer()
	game._refresh()
	panel.hide()
	game._save()

func pack_delivery() -> bool:
	if not _delivery_available():return false
	if not delivery_mode or job.is_empty() or job.packed or game.stage!=5: return false
	for id in job.need:
		if not game.selected.has(int(id)):
			game._notice("外卖还缺 "+game.INGREDIENTS[int(id)]+"，重新备一碗，配料会取回。")
			return false
	job.packed=true
	delivery_mode=false
	game.stage=0
	game.selected.clear()
	if game.simmer:game.simmer.reset()
	game.prep.reset_packet()
	game.audio.play_at("rustle",-.3,-9)
	game._set_customer()
	game._refresh()
	game._save()
	game._notice("外卖已打包。打开路线，开往"+MAPS[int(job.destination)].name+"。")
	return true

func deliver() -> bool:
	if not _delivery_available():return false
	if job.is_empty() or not job.packed or map_index!=int(job.destination): return false
	var reward=int(job.reward)+(6 if upgrades.has("box") else 0)
	game.coins+=reward
	scrap+=1
	deliveries+=1
	job.clear()
	delivery_mode=false
	status="热面送到了。收到 %d 枚铜片和 1 个零件。公路又亮了一盏灯。" % reward
	game.audio.play_at("bowl",0,-12)
	game._refresh()
	game._save()
	if panel.visible: redraw()
	return true

func _delivery_available()->bool:
	if game.get("day_cycle") and not game.day_cycle.can_delivery():
		status="结束今天营业后，才可以出门送外卖。"
		game._notice(status)
		if panel.visible:redraw()
		return false
	return true

func _resources_available()->bool:
	if game.get("day_cycle") and not game.day_cycle.can_manage_resources():
		status="先接待完今天所有客人并收摊，再安排外出。商店现在就能使用。"
		panel.hide();game._notice(status);return false
	return true

func draw_audio() -> void:
	game._label(content,"贴近灶台，听见每一刀。",Rect2(27,122,712,42),25)
	game._label(content,"真实录音制作 · 撕袋 / 木砧板 / 蛋壳 / 热水 / 金属碗\n原创配乐《荒路留灯》；操作时音乐自动放轻。戴耳机听声场。",Rect2(27,181,710,69),17)
	for i in range(3):
		game._label(content,["操作音量","窗外环境","餐车音乐"][i],Rect2(29,260+i*61,160,32),18)
		var slider=HSlider.new()
		slider.position=Vector2(205,263+i*61)
		slider.size=Vector2(529,29)
		slider.min_value=0
		slider.max_value=1
		slider.step=.01
		slider.value=[game.audio.foley_volume,game.audio.ambience_volume,game.audio.music_volume][i]
		slider.value_changed.connect(func(value):
			if i==0: game.audio.foley_volume=value
			elif i==1: game.audio.ambience_volume=value
			else: game.audio.music_volume=value
			game._save())
		content.add_child(slider)
	game._button(content,"试听切肉",Rect2(28,465,230,42),func():game.audio.play_at("chop1",.12,-7),game.TEAL,16)
	game._button(content,"试听撕袋",Rect2(274,465,230,42),func():game.audio.play_at("tear",-.2,-6),game.TEAL,16)
	game._button(content,"试听浇水",Rect2(520,465,230,42),func():game.audio.play_at("water",.7,-12),game.TEAL,16)

func to_save() -> Dictionary:
	return {"map":map_index,"scrap":scrap,"upgrades":upgrades,"job":job,"delivery_mode":delivery_mode,"deliveries":deliveries,"foley":game.audio.foley_volume,"ambience":game.audio.ambience_volume,"music":game.audio.music_volume}

func restore(data: Dictionary) -> void:
	map_index=clampi(int(data.get("map",0)),0,2)
	scrap=maxi(0,int(data.get("scrap",0)))
	upgrades=data.get("upgrades",[])
	job=data.get("job",{})
	delivery_mode=bool(data.get("delivery_mode",false)) and not job.is_empty() and not bool(job.get("packed",false))
	deliveries=maxi(0,int(data.get("deliveries",0)))
	game.audio.foley_volume=clampf(float(data.get("foley",1.0)),0,1)
	game.audio.ambience_volume=clampf(float(data.get("ambience",.85)),0,1)
	game.audio.music_volume=clampf(float(data.get("music",.85)),0,1)
	apply_map()
