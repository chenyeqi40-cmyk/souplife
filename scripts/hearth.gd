extends Node

const TABLE_TARGET=Rect2(562,422,371,53)
const OUTER_BOWL_CENTER=Vector2(704,427)
const OUTER_SCALE=.57
var game
var guest_identity=""
var barter_accepted=false
var has_water=false
var seasoned=false
var boil_intensity=0.0 # Public 0..1 level for the continuous cooking sound.
var dialogue_open=false
var farewell_done=false
var review_line=0
var total_tips=0
var meal_age=0.0
var meal_tween:Tween
var bite_count=0
var guide_seconds=0.0
var guide_key=""
var pot:MeshInstance3D
var vessel:MeshInstance3D
var noodle_float:MeshInstance3D
var pot_material:ShaderMaterial
var floats:Array=[]
var eggs:Array=[]
var jar:MeshInstance3D
var jar_origin:Vector3
var jar_bounce=0.0
var coin_flights:Array=[]
var day_screen:Label
var tip_label:Label
var conversation_close:Button
var next_guest:Button
var dialogue_panel:Panel
var robot_layer:Control
var room_layer:Control
var prop_meshes:Array=[]

func setup(g)->void:
	game=g
	make_scene()
	make_ui()
	new_guest()
	speak_guide(8.0)

func prop(node_name:String,cell:int,rect:Rect2,inner:Rect2=Rect2(0,0,1,1),depth:float=1.5)->MeshInstance3D:
	var m=game.prep._sprite(node_name,"service_props.png",cell,2,rect,depth,inner)
	m.material_override.set_shader_parameter("magenta_key",true)
	prop_meshes.append(m)
	return m

func make_scene()->void:
	# The original counter geometry and appliance coordinates are never moved.
	# The small dining shelf is entirely on the exterior side of the window.
	var old_table=prop("OutsideDiningTable",1,Rect2(560,394,370,53),Rect2(.0,.255,1,.58),-.40)
	old_table.hide()
	jar=prop("GlassTipJar",0,Rect2(883,404,54,65),Rect2(.115,.045,.65,.86),1.28)
	jar.material_override.set_shader_parameter("glass_key",true)
	jar_origin=jar.position
	game.service.trash.hide()
	prop("LargePerspectiveWasteBin",5,Rect2(1157,619,129,143),Rect2(.115,.0,.78,.95),2.1)
	# Recessed in-bin appearances use only the top opening of the prop atlas.
	# The larger drag sprites and meat-cutting assets stay independent.
	prop("BeefInsideExistingBin",3,Rect2(875,533,44,28),Rect2(.135,.13,.70,.405),1.28)
	prop("SpamInsideExistingBin",4,Rect2(935,533,44,28),Rect2(.135,.13,.70,.405),1.28)
	prop("RecessedTwoRowEggHolder",2,Rect2(899,638,179,32),Rect2(.075,.29,.84,.32),1.29)
	for i in range(8):
		var row=int(i/4)
		var egg=game.prep._sprite("SeatedRawEgg"+str(i),"prep_atlas.png",2,2,Rect2(904+i%4*38+row*3,628+row*18,29,29),1.32+row*.01,Rect2(.23,.17,.57,.69))
		eggs.append(egg)
	pot_material=ShaderMaterial.new()
	pot_material.shader=load("res://shaders/pot_surface.gdshader")
	# Only the old vessel footprint is patched; the supplied cabin remains intact.
	var clean_rect=Rect2(346,478,198,168)
	var clean_stove=game.prep.reference_piece("CleanStoveBehindReplacementPot",clean_rect,Rect2(346.0/1280,478.0/714,198.0/1280,168.0/714),1.15)
	clean_stove.material_override.set_shader_parameter("art",load("res://assets/clean_stove_reference.png"))
	var old_pot=game.world.find_child("Pot_Front",true,false)
	if old_pot: old_pot.hide()
	var vessel_mat=game._paper_material("level_pot.png")
	vessel_mat.set_shader_parameter("magenta_key",true)
	vessel_mat.set_shader_parameter("frame_override",true)
	vessel=game._quad("LevelSymmetricCookingPot",Rect2(337*1.2265625,450*1.2265625,216*1.2265625,213*1.2265625),1.38,vessel_mat)
	pot=game._quad("EmptyWaterSoupSurface",Rect2(370*1.2265625,505*1.2265625,149*1.2265625,49*1.2265625),1.41,pot_material)
	noodle_float=game.prep._sprite("SimmeringNoodleCake","farm_packet.png",6,3,Rect2(400,512,82,42),1.44)
	noodle_float.hide()
	for i in range(game.INGREDIENTS.size()):
		var file="ingredients.png"
		var cell=i
		var rows=2
		if i==12:file="regional_food.png";cell=1;rows=1
		elif i in [10,13]:file="wildlife.png";cell=4;rows=2
		elif i>=8: file="regional_food.png";cell=i-8;rows=1
		elif i>=6: file="farm_packet.png";cell=0 if i==6 else 2;rows=3
		var m:MeshInstance3D
		if i in game.prep.FARM_IDS:m=game.prep.leaf_sprite("SimmerIngredient"+str(i),i,Rect2(0,0,68,37),1.47+i*.001)
		elif i in [11,14,15,16]:m=game.prep.cut_meat_sprite("SimmerIngredient"+str(i),i,Rect2(0,0,68,37),1.47+i*.001)
		else:m=game.prep._sprite("SimmerIngredient"+str(i),file,cell,rows,Rect2(0,0,68,37),1.47+i*.001)
		m.material_override.set_shader_parameter("magenta_key",i>=8 or i in game.prep.FARM_IDS)
		m.hide()
		floats.append(m)
	# The pot's rim remains foreground; floating pieces stay inside its ellipse.
	room_layer=load("res://scripts/hearth_effects.gd").new()
	room_layer.hearth=self
	room_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	room_layer.size=Vector2(1280,714)
	game.add_child(room_layer)
	game.move_child(room_layer,game.ui.get_index())

func make_ui()->void:
	dialogue_panel=game.order_label.get_parent()
	dialogue_panel.position=Vector2(324,164)
	dialogue_panel.size=Vector2(245,226)
	game.customer_label.position=Vector2(13,9)
	game.customer_label.size=Vector2(220,27)
	game.customer_label.add_theme_font_size_override("font_size",17)
	dialogue_panel.get_child(1).text=""
	game.order_label.position=Vector2(13,47)
	game.order_label.size=Vector2(220,112)
	game.order_label.add_theme_font_size_override("font_size",16)
	game.talk_button.position=Vector2(13,174)
	game.talk_button.size=Vector2(147,36)
	game.talk_button.pressed.disconnect(game._talk)
	game.talk_button.pressed.connect(dialogue_action)
	conversation_close=game._button(dialogue_panel,"收起",Rect2(168,174,65,36),secondary_dialogue_action,game.PAPER,14)
	game.service.story_button.position=Vector2(324,398)
	game.service.story_button.size=Vector2(245,31)
	game.backpack.alternate.position=Vector2(324,433)
	game.backpack.alternate.size=Vector2(245,31)
	game.chapter_label.get_parent().hide()
	day_screen=game._label(game.ui,"",Rect2(134,217,124,33),18,Color("cee997"))
	day_screen.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	day_screen.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	tip_label=game._label(game.ui,"",Rect2(873,467,74,20),12,Color("fff0bc"))
	tip_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	tip_label.add_theme_color_override("font_shadow_color",Color("292631"))
	tip_label.add_theme_constant_override("shadow_outline_size",3)
	next_guest=game._button(game.ui,"招呼下一位",Rect2(354,307,168,36),game._next_customer,game.PAPER,15)
	next_guest.hide()
	# Remove the permanent banner and the original decorative patience ticket.
	for c in game.ui.get_children():
		if c is Panel and (c.position==Vector2(18,14) or c.position==Vector2(876,435)): c.hide()
		if c is Label and c.position==Vector2(1140,695): c.hide()
	game.coins_label.get_parent().position=Vector2(21,22)
	game.coins_label.position=Vector2(34,1)
	game.coins_label.size=Vector2(58,28)
	game.add_money_icon(game.coins_label.get_parent(),Vector2(7,5),19)
	game.add_money_icon(game.ui,Vector2(875,470),13)
	game.economy.nav_button.position=Vector2(30,442)
	game.economy.nav_button.size=Vector2(238,34)
	game.service.guide_panel.position=Vector2(28,277)
	game.service.guide_panel.size=Vector2(243,147)
	game.service.guide_panel.speech_tip=true
	game.service.guide_panel.get_child(0).hide()
	game.service.guide.position=Vector2(13,13)
	game.service.guide.size=Vector2(218,122)
	game.service.guide.add_theme_font_size_override("font_size",14)
	# Cream frames with charcoal inventory wells and a simple tan header.
	for panel in [dialogue_panel,game.economy.panel,game.help_panel]:
		panel.add_theme_stylebox_override("panel",game._style(Color("dedbc8"),Color("282b30"),3))
		var header=ColorRect.new()
		header.color=Color("bba77a")
		header.position=Vector2(4,4)
		header.size=Vector2(panel.size.x-8,31)
		header.mouse_filter=Control.MOUSE_FILTER_IGNORE
		panel.add_child(header)
		panel.move_child(header,0)
	for c in game.backpack.cells:
		c.button.add_theme_stylebox_override("normal",game._style(Color("34383e"),Color("989584"),2))
		c.label.add_theme_color_override("font_color",Color("e9e4cf"))
	game.backpack.description.add_theme_font_size_override("font_size",14)
	refresh()

func new_guest()->void:
	game.service.reward_pending=false;game.service.meal_gift=""
	game.backpack.awarded_this_meal=""
	barter_accepted=false
	dialogue_open=false
	farewell_done=false
	review_line=0
	meal_age=0
	bite_reset()
	has_water=false
	seasoned=false
	game.chatting=false
	if meal_tween and meal_tween.is_valid(): meal_tween.kill()
	refresh()

func bite_reset()->void:
	bite_count=0

func speak_guide(duration:float=7.0)->void:
	if game.v5: game.v5.guide_override="";game.v5.aside_age=0
	guide_seconds=duration
	game.service.guide_visible=true
	game.service.guide.text=game.service.guide_text()
	load("res://scripts/speech_layout.gd").fit(game.service.guide_panel,game.service.guide,13,218)

func open_conversation()->void:
	if game.get("day_cycle") and not game.day_cycle.has_customer():return
	if game.v5 and game.v5.busy(): return
	if game.service.eating: return
	if game.stage==6:
		if farewell_done: return
		dialogue_open=true
		refresh()
		return
	dialogue_open=true
	game.chatting=false
	game.order_label.text=game.service.order().order
	game.order_label.add_theme_font_size_override("font_size",16)
	refresh()

func dialogue_action()->void:
	if game.get("day_cycle") and not game.day_cycle.has_customer():return
	if is_barter() and not barter_accepted and game.stage<6:
		barter_accepted=true
		game._notice("请他先坐下，吃一碗热面。")
		game.order_label.text="真的可以吗？谢谢你。\n我在这里坐一会儿，不催你。\n已经好久没闻到这样的汤香了。"
		refresh()
		game._save()
		return
	if game.stage==6:
		advance_review()
		return
	game.chatting=not game.chatting
	game.order_label.text=game.service.order().story if game.chatting else game.service.order().order
	game.order_label.add_theme_font_size_override("font_size",14 if game.chatting else 16)
	game._refresh()

func close_conversation()->void:
	dialogue_open=false
	game.chatting=false
	game.backpack.refresh_choices()
	refresh()

func advance_review()->void:
	if game.stage!=6 or game.service.eating or farewell_done: return
	if review_line==0:
		review_line=1
		game.service.claim_review_reward()
		game.service.customer_frame(0)
	else:
		farewell_done=true
		close_conversation()
		if game.v5: game.v5.begin_departure()
	game._refresh()
	game._save()

func refresh()->void:
	if not is_instance_valid(day_screen): return
	day_screen.text="第 %02d 天" % game.day
	game.chapter_label.get_parent().hide()
	tip_label.text="%d" % total_tips
	game.receipt.hide()
	for c in game.ui.get_children():
		if c is Panel and (c.position==Vector2(18,14) or c.position==Vector2(876,435)): c.hide()
	var customer_present=not game.get("day_cycle") or game.day_cycle.has_customer()
	dialogue_panel.visible=customer_present and dialogue_open and not game.show_layers and not game.service.eating and not farewell_done
	if not customer_present:game.character.hide()
	next_guest.visible=false
	conversation_close.visible=game.stage<6
	if game.stage<6:
		game.talk_button.text="回到点单" if game.chatting else "聊一会儿"
	else:
		game.talk_button.size=Vector2(219,36)
		game.talk_button.text="嗯，听你说" if review_line==0 else "谢谢，下次见"
		game.order_label.text=game.service.review_text(review_line)
		game.order_label.add_theme_font_size_override("font_size",15)
	if game.stage<6: game.talk_button.size=Vector2(147,36)
	if is_barter() and not barter_accepted and game.stage<6:
		game.talk_button.text="接受换餐"
		conversation_close.text="拒绝"
	else: conversation_close.text="收起"
	game.service.guide_panel.visible=guide_seconds>0 and not game.show_layers and not game.economy.panel.visible
	game.service.guide.text=game.v5.guide_override if game.v5 and game.v5.guide_override!="" else game.service.guide_text()
	load("res://scripts/speech_layout.gd").fit(game.service.guide_panel,game.service.guide,13,218)
	game.economy.job_label.visible=false
	game.serve_button.text="打包外卖" if game.economy.delivery_mode else "端到窗口长板"
	game.serve_button.add_theme_font_size_override("font_size",16)
	for m in game.prep.bin_meshes: m.hide()
	# Preserve the original chili oil icon in its original bin.
	game.prep.bin_meshes[2].visible=game.prep.stock[3]>0
	for i in range(8): eggs[i].visible=game.prep.stock[1]>i
	prop_meshes[3].visible=game.prep.stock[0]>0
	prop_meshes[4].visible=game.prep.stock[4]>0
	if game.stage==6: place_outer_bowl(1.0)
	update_pot()

func update_pot()->void:
	boil_intensity=0.0
	if has_water and game.stage in [1,2,3,4]:
		boil_intensity=lerpf(.06,.3,clampf(1.0-game.cook_remaining/3.5,0,1)) if game.stage==1 else .4 if game.stage==2 else lerpf(.42,1.0,clampf(game.simmer.global_units()/5.0,0,1))
	var liquid=2 if has_water and seasoned else (1 if has_water else 0)
	vessel.material_override.set_shader_parameter("frame_rect",Vector4(liquid/3.0,0,1.0/3.0,1))
	noodle_float.visible=game.prep.packet_stage==2 and has_water
	pot_material.set_shader_parameter("water_state",2 if has_water and seasoned else (1 if has_water else 0))
	pot_material.set_shader_parameter("elapsed",game.elapsed)
	pot_material.set_shader_parameter("simmer",game.stage in [1,2,3,4])
	pot_material.set_shader_parameter("night",game.light_night)
	pot_material.set_shader_parameter("sunset",game.sunset_amount)
	pot_material.set_shader_parameter("overcast",game.rain_amount)
	pot_material.set_shader_parameter("noodles",game.prep.packet_stage==2 and has_water)
	pot_material.set_shader_parameter("boil_intensity",boil_intensity)
	pot_material.set_shader_parameter("flavor",game.prep.flavor)
	var n=0
	for i in range(game.INGREDIENTS.size()):
		var m=floats[i]
		m.visible=game.stage<=4 and game.selected.has(i) and not (game.simmer and game.simmer.portions.get(i,{}).get("lifted",false))
		if not m.visible: continue
		if i==3:
			m.visible=has_water and seasoned
			game.prep._place(m,Vector2(444,536),1.485)
			m.scale=Vector3(.38,.35,1)
		else:
			var p=Vector2(410+n%2*64,514+int(n/2)*25)
			if has_water: p+=Vector2(sin(game.elapsed*.9+n)*1.5,cos(game.elapsed*1.1+n)*1.0)
			game.prep._place(m,p,1.475+n*.002)
			n+=1

func tick(delta:float)->void:
	guide_seconds=maxf(0,guide_seconds-delta)
	var key=str(game.stage)+":"+str(game.prep.packet_stage)+":"+str(game.prep.board_item)
	if key!=guide_key:
		guide_key=key
		if game.total_served<1 and not (game.simmer and game.simmer.perfect): speak_guide(5.5)
	if game.service.eating:
		meal_age+=delta
		# Bowl stops on the table before the one-hand bite begins.
		if meal_age>=.70 and bite_count==0:
			bite_count=1
			game.service.customer_frame(1)
		if meal_age>=2.05 and game.service.last_frame==1: game.service.customer_frame(0)
		if meal_age>=2.65: game.service.complete_meal()
	for coin in coin_flights: coin.age+=delta
	for i in range(coin_flights.size()-1,-1,-1):
		if coin_flights[i].age>=coin_flights[i].duration:
			coin_flights.remove_at(i)
			jar_bounce=.45
			game.audio.play_at("jar",.35,-17)
	jar_bounce=maxf(0,jar_bounce-delta)
	jar.position=jar_origin+Vector3(0,sin((.45-jar_bounce)*16)*jar_bounce*.14,0)
	jar.scale=Vector3(1+sin((.45-jar_bounce)*20)*jar_bounce*.14,1-sin((.45-jar_bounce)*20)*jar_bounce*.12,1)
	refresh()
	room_layer.queue_redraw()

func serve_to_table()->void:
	if game.stage!=5 or game.service.eating: return
	if game.get("day_cycle") and not game.day_cycle.has_customer():return
	game.service.eating=true
	game.service.satisfaction=game.service.score()
	game.stage=6
	meal_age=0
	bite_count=0
	farewell_done=false
	dialogue_open=false
	game.chatting=false
	game.backpack.refresh_choices()
	game.service.customer_frame(0)
	game.audio.play_at("bowl",.12,-13)
	game._refresh()
	game._save()

func place_outer_bowl(_amount:float)->void:
	var meshes=[game.bowl]+game.toppings
	var t=clampf(meal_age/.55,0,1) if game.service.eating else 1.0
	t=t*t*(3-2*t)
	var sc=lerpf(1.0,OUTER_SCALE,t)
	var source=Vector3(.625,-2.745,1.5)
	var target=Vector3((OUTER_BOWL_CENTER.x*1.2265625-785)/100,(437.5-OUTER_BOWL_CENTER.y*1.2265625)/100,1.15)
	for i in range(meshes.size()):
		var m=meshes[i]
		var origin=game.service.original_positions[i]
		m.scale=Vector3(sc,sc,sc)
		# Absolute-authored vertices and centered fresh sprites share one pivot transform.
		m.position=origin*sc+source*(1-sc)+(target-source)*t
		m.visible=(i==0 or game.selected.has(i-1)) and not farewell_done

func review_ready()->void:
	meal_age=3
	dialogue_open=true
	review_line=0
	total_tips+=game.service.last_tip
	for i in range(mini(game.service.last_tip,4)):
		coin_flights.append({"age":-i*.13,"duration":.70,"from":Vector2(729+i*5,347)})
	refresh()

func to_save()->Dictionary:
	return {"barter_accepted":barter_accepted,"water":has_water,"seasoned":seasoned,"tips":total_tips,"farewell":farewell_done,"review_line":review_line,"meal_age":meal_age,"bite_count":bite_count}

func restore(d:Dictionary)->void:
	barter_accepted=bool(d.get("barter_accepted",false))
	has_water=bool(d.get("water",false));seasoned=bool(d.get("seasoned",false))
	total_tips=maxi(0,int(d.get("tips",0)))
	farewell_done=bool(d.get("farewell",false))
	review_line=clampi(int(d.get("review_line",0)),0,1)
	meal_age=float(d.get("meal_age",0));bite_count=int(d.get("bite_count",0))
	dialogue_open=game.stage==6 and not farewell_done and not game.service.eating
	if game.stage==6 and not game.service.eating:game.service.customer_frame(0 if review_line==1 else game.service.review_frame())

func is_barter()->bool:
	if game.get("day_cycle") and not game.day_cycle.has_customer():return false
	return game.service.order().get("barter",false)

func secondary_dialogue_action()->void:
	if is_barter() and not barter_accepted and game.stage<6:
		decline_barter()
	else: close_conversation()

func decline_barter()->void:
	if not is_barter() or barter_accepted or game.stage!=0: return
	game.stage=6
	game.service.eating=false
	farewell_done=true
	game._next_customer()
	game._notice("他收好铜鸟哨，点了点头，走向下一处亮灯的地方。")
