extends Node

const CUSTOMER_DROP=Rect2(566,183,371,295)
const COUNTER_BOWL=Rect2(574,491,247,171)
const PACKET=Rect2(220,548,101,113)
const OPEN_PACKET=Rect2(531,454,112,158)
var game
var kind=""
var food_id=-1
var farm_index=-1
var press=Vector2.ZERO
var moved=false
var ghost:MeshInstance3D
var transition=""
var transition_age=0.0
var customer_offset=0.0
var reaction_age=0.0
var quip_clock=43.0
var quip_index=0
var guide_override=""
var aside_age=0.0
var awning:MeshInstance3D

func setup(g)->void:
	game=g
	var mat=game._paper_material("awning_outward.png")
	mat.set_shader_parameter("magenta_key",true)
	# The near edge attaches above the serving hatch. The roof recedes
	# two metres toward the road; from the kitchen we see its underside.
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left=(308*1.2265625-785)/100.0
	var right=(1036*1.2265625-785)/100.0
	var near_y=(437.5-129*1.2265625)/100.0
	var far_y=(437.5-188*1.2265625)/100.0
	var vertices=[Vector3(left,near_y,-.35),Vector3(right,near_y,-.35),Vector3(right,far_y,-2.35),Vector3(left,far_y,-2.35)]
	var uvs=[Vector2(.02,.218),Vector2(.98,.218),Vector2(.98,.675),Vector2(.02,.675)]
	for i in [0,2,1,0,3,2]:
		st.set_normal(Vector3(0,-.94,.34))
		st.set_uv(uvs[i]);st.add_vertex(vertices[i])
	awning=MeshInstance3D.new()
	awning.name="OutwardRainAwning"
	awning.mesh=st.commit();awning.material_override=mat
	game.world.add_child(awning)

func busy()->bool:
	return transition!=""

func _input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and game.prep.input_allowed():
		var staged=game.prep.ready_item_at(event.position)
		if staged>=0:
			game.prep.return_prepared(staged);get_viewport().set_input_as_handled();return
	if event is InputEventMouseMotion and kind!="":
		if event.position.distance_to(press)>8: moved=true
		if moved:
			if kind=="bowl":
				var offset=event.position-press
				var meshes=[game.bowl]+game.toppings
				for i in range(meshes.size()): meshes[i].position=game.service.original_positions[i]+Vector3(offset.x*.012265625,-offset.y*.012265625,2)
			elif ghost:
				ghost.show();game.prep._place(ghost,event.position,3.2)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT: return
	if not event.pressed and kind!="":
		var selected_kind=kind
		var was_moved=moved
		kind=""
		if ghost: ghost.queue_free();ghost=null
		if game.prep.input_allowed(): finish_gesture(selected_kind,event.position,was_moved)
		elif selected_kind=="bowl": game.service.restore_bowl()
		moved=false
		get_viewport().set_input_as_handled()
		return
	if not event.pressed or not game.prep.input_allowed(): return
	var p=event.position
	if game.v4.dialogue_panel.visible and game.v4.dialogue_panel.get_global_rect().has_point(p): return
	press=p;moved=false
	if game.stage==5 and COUNTER_BOWL.has_point(p):
		kind="bowl"
	elif game.stage<=4:
		if PACKET.has_point(p) or (game.prep.packet_stage==1 and OPEN_PACKET.has_point(p)):
			kind="packet"
			ghost=game.prep.reference_piece("PacketPointer",Rect2(0,0,79,86),Rect2(220.0/1280,556.0/714,98.0/1280,105.0/714),3.2)
			ghost.material_override.set_shader_parameter("packet",true)
		elif game.prep.ready_item_at(p)>=0:
			food_id=game.prep.ready_item_at(p);kind="staged_food";make_food_ghost(food_id,true)
		elif game.prep.BOARD.has_point(p) and game.prep.board_item>=0:
			kind="board"
			if game.prep.cuts==3: make_food_ghost(game.prep.board_item,true)
		else:
			for i in range(4):
				if game.prep.BIN_RECTS[i].has_point(p):
					food_id=game.prep.BIN_IDS[i];kind="food";make_food_ghost(food_id);break
			if kind=="":
				for i in range(3):
					if Rect2(875+i*59,570,56,42).has_point(p):
						food_id=8+i;kind="food";make_food_ghost(food_id);break
			if kind=="":
				for i in range(4):
					if Rect2(1104,211+i*106,153,71).has_point(p):
						farm_index=i;kind="vegetable"
						ghost=game.prep.leaf_sprite("VegetablePointer",game.prep.FARM_IDS[i],Rect2(0,0,92,77),3.2)
						break
	if kind!="":
		if ghost: ghost.hide()
		get_viewport().set_input_as_handled()
	elif Rect2(883,404,54,65).has_point(p):
		game.v4.jar_bounce=.45
		game.audio.play_at("jar",.35,-19)
		game._notice("存钱罐里有 %d 枚小费。" % game.v4.total_tips)
		get_viewport().set_input_as_handled()

func make_food_ghost(id:int,cut:bool=false)->void:
	if id in game.prep.FARM_IDS:
		ghost=game.prep.leaf_sprite("VegetablePointer",id,Rect2(0,0,92,77),3.2);return
	if id in [11,14,15,16]:
		ghost=game.prep.cut_meat_sprite("LizardMeatPointer",id,Rect2(0,0,115,84),3.2) if cut else game.prep.whole_meat_sprite("LizardMeatPointer",id,Rect2(0,0,115,84),3.2)
		return
	if id in [10,12,13]:
		ghost=game.prep._sprite("ColdIngredientPointer","regional_food.png" if id==12 else "wildlife.png",1 if id==12 else 4,1 if id==12 else 2,Rect2(0,0,100,80),3.2)
		ghost.material_override.set_shader_parameter("magenta_key",true);return
	if id in [0,4,1]:
		var cell=2 if id==1 else ((3 if id==0 else 4) if cut else (0 if id==0 else 1))
		ghost=game.prep._sprite("IngredientPointer","prep_atlas.png",cell,2,Rect2(0,0,115,84),3.2)
	elif id>=8:
		ghost=game.prep._sprite("IngredientPointer","regional_food.png",id-8,1,Rect2(0,0,95,79),3.2)
		ghost.material_override.set_shader_parameter("magenta_key",true)
	else: ghost=game.prep._sprite("IngredientPointer","ingredients.png",id,2,Rect2(0,0,92,77),3.2)

func finish_gesture(which:String,p:Vector2,dragged:bool)->void:
	match which:
		"bowl":
			game.service.restore_bowl()
			if dragged and game.service.TRASH_AREA.has_point(p): game.service.discard_bowl()
			elif (not dragged and COUNTER_BOWL.has_point(p)) or (dragged and CUSTOMER_DROP.has_point(p)): game._serve()
		"food":
			if game.prep.staged_food.has(food_id):
				if not dragged or game.prep.POT.has_point(p):game.prep.put_ready_in_pot(food_id)
			elif food_id in game.prep.MEAT_IDS:
				if not dragged or game.prep.BOARD.has_point(p): put_meat_on_board(food_id)
				elif game.prep.POT.has_point(p): game._notice("整块肉先放砧板切好；也可以点击肉块把它放上砧板。")
			elif not dragged or game.prep.POT.has_point(p) or game.prep.BOARD.has_point(p): game._select(food_id)
		"staged_food":
			if not dragged or game.prep.POT.has_point(p):game.prep.put_ready_in_pot(food_id)
			elif game.prep.source_rect(food_id).grow(9).has_point(p):game.prep.return_prepared(food_id)
		"board":
			if game.prep.cuts<3:
				if game.prep.BOARD.has_point(p): game.prep.chop()
			elif (not dragged and game.prep.BOARD.has_point(p)) or (dragged and game.prep.POT.has_point(p)): game.prep.commit_board()
		"vegetable":
			if not dragged: game.prep.plant_action(farm_index)
			elif game.prep.POT.has_point(p) or game.prep.BOARD.has_point(p): game.prep.harvest_plant(farm_index)
		"packet":
			if game.stage!=2: game._notice("先把锅里的清水烧开，再拆面袋。")
			elif not dragged or game.prep.POT.has_point(p): game._cook()

func put_meat_on_board(id:int)->void:
	if game.v4.is_barter() and not game.v4.barter_accepted: game.v4.open_conversation();return
	if game.prep.board_item>=0: game._notice("砧板上还有肉，先切好并备妥。")
	elif game.prep.stock[id]<=0: game._notice("这格肉用完了，去商店补些货吧。")
	elif game.prep.staged_food.has(id):game._notice("这种肉已经切好，在砧板旁等着下锅。")
	elif game.selected.has(id): game._notice("本碗已经放过这种肉。")
	else:
		game.prep.board_item=id;game.prep.cuts=0
		game.prep.set_board_art(id)
		game.prep.board_meat.scale=Vector3.ONE;game.prep.board_meat.show()
		game._sound("tap");game.prep.refresh();game._save()

func begin_departure()->void:
	if busy() or game.stage!=6 or game.service.eating or not game.v4.farewell_done: return
	transition="leaving";transition_age=0;customer_offset=0
	game.v4.close_conversation()
	game.bowl.hide()
	for m in game.toppings: m.hide()

func cancel_transition()->void:
	transition="";transition_age=0;customer_offset=0

func begin_arrival()->void:
	if game.stage==6: return
	if game.get("day_cycle") and not game.day_cycle.has_customer():return
	transition="arriving";transition_age=0;customer_offset=-5.1
	game.v4.close_conversation()

func announce_guest()->void:
	if game.stage==6 or game.economy.delivery_mode: return
	if game.get("day_cycle") and not game.day_cycle.has_customer():return
	var greetings={"老乔":"老板，又闻到热汤味了。","禾苗":"你好，今天也有新长的菜吗？","阿岚":"借你的屋檐歇一会儿。","阿灯":"忙了一早上，总算坐下了。","小夏":"刚下夜班，想吃点暖的。","温叔":"船拴好了，来讨碗热面。","拾风":"老板，我想跟你商量件事。"}
	game.v4.open_conversation()
	greetings["阿砾"]="井站交班了，闻着汤味过来的。"
	greetings["白禾"]="赶在天黑前，来补一笔地图。"
	game.order_label.text=greetings.get(game.service.order().name,"你好，来一碗面。")+"\n"+game.service.order().order
	game.order_label.add_theme_font_size_override("font_size",14)

func tick(delta:float)->void:
	if transition=="" and game.stage==6 and game.v4.farewell_done: begin_departure()
	if busy():
		transition_age+=delta
		var t=clampf(transition_age/.85,0,1)
		var smooth=t*t*(3-2*t)
		customer_offset=5.1*smooth if transition=="leaving" else -5.1*(1-smooth)
		if t>=1:
			if transition=="leaving":
				cancel_transition()
				game._finish_next_customer()
			else:
				cancel_transition();game._refresh();announce_guest()
		if busy():
			game.cook_button.disabled=true;game.serve_button.disabled=true
			game.clear_button.disabled=true;game.v4.next_guest.hide()
	if game.stage==5 and kind!="bowl": game.service.restore_bowl()
	if reaction_age>0:
		reaction_age=maxf(0,reaction_age-delta)
		if reaction_age==0 and game.stage<6: game.service.customer_frame(0)
	aside_age=maxf(0,aside_age-delta)
	if aside_age==0: guide_override=""
	quip_clock-=delta
	if quip_clock<=0 and can_quip(): say_aside()

func react(correct:bool)->void:
	game.service.customer_frame(2 if correct else 3)
	reaction_age=2.4

func can_quip()->bool:
	return not busy() and kind=="" and game.prep.input_allowed() and not game.v4.dialogue_open and not game.service.eating and game.v4.guide_seconds<=0 and game.prep.knife_time<=0

func say_aside()->void:
	var lines=["我的末日生存指南第一条：\n没想好怎么办，就先烧水。","外面还没通电，锅先开了。\n我宣布，这是今天的小胜利。","人类需要热饭。\n我需要……别把汤溅进屏幕。","这辆房车的导航很准：\n哪里有人饿了，就往哪里开。"]
	if game.weather==1: lines=["棚子替客人挡雨，\n锅子替客人挡冷。分工合理。","雨点敲棚子的节奏不错。\n可惜它不会帮忙洗碗。"]
	elif game.stage==5: lines=["面在我们桌上等着呢。\n再香，也得亲手递过去才算数。"]
	elif game.prep.water_store<=1: lines=["水壶快空了。\n我能说冷笑话，不能变出热水。"]
	guide_override=lines[quip_index%lines.size()]
	quip_index+=1;aside_age=5.5;game.v4.guide_seconds=5.5
	quip_clock=45.0+fmod(quip_index*17,24)
	game.v4.refresh()
