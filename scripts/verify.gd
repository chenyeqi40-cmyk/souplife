extends RefCounted
var game
var checks: Array = []

func check(value: bool, label: String) -> void:
	if not value:
		push_error("QA_FAILED: "+label)
		game.get_tree().quit(1)
		assert(value,label)
	checks.append(label)
	print("PASS: "+label)

func click(point: Vector2) -> void:
	game._click_for_qa(point)

func drag(start: Vector2, end: Vector2) -> void:
	var down=InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT
	down.position=start
	down.pressed=true
	game.get_viewport().push_input(down)
	var motion=InputEventMouseMotion.new()
	motion.position=end
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	game.get_viewport().push_input(motion)
	var up=InputEventMouseButton.new()
	up.button_index=MOUSE_BUTTON_LEFT
	up.position=end
	up.pressed=false
	game.get_viewport().push_input(up)

func wait(seconds: float) -> void:
	await game.get_tree().create_timer(seconds).timeout

func cut_meat(id: int) -> void:
	drag(Vector2(894 if id==0 else 952,546),Vector2(678,596))
	check(game.prep.board_item==id,"Whole meat drag reaches chopping board: "+str(id))
	for i in range(3):
		click(Vector2(680+i*16,595))
		await wait(.4)
	check(game.prep.cuts==3,"Three individual clicks produce three slices")
	drag(Vector2(720,600),Vector2(442,526))
	check(game.selected.has(id) and game.prep.board_item==-1,"Cut slices drag to pot; reservation consumed once")

func finish_cooking() -> void:
	game._cook()
	game._process(4)
	check(game.stage==2,"Water boils before packet opening")
	game._cook()
	game._cook()
	await wait(1.5)
	check(game.stage==2 and game.prep.packet_stage==1,"First click only tears packet; repeated busy click ignored")
	game._cook()
	await wait(1.1)
	check(game.stage==3,"Second click drops noodle brick and seasoning then starts cooking")
	game._process(5)
	game._process(3600)
	check(game.stage==4,"Finished noodles stay warm without timeout")
	game._cook()
	check(game.stage==5,"Noodles can be plated")

func run(owner_game) -> void:
	game=owner_game
	game.screenshot_dir=ProjectSettings.globalize_path("user://qa_verify")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(game.screenshot_dir))
	game.auto_time=false
	game.auto_weather=false
	game.hour=10
	game._refresh()
	await wait(.8)
	var rain=game.world.find_child("WeatherOutsideWindow",true,false)
	check(rain.get_aabb().position.z+rain.position.z < game.character.get_aabb().position.z+game.character.position.z,"Weather plane is behind customer and before distant landscape")
	check(game.ingredient_buttons.is_empty() and game.prep.bin_meshes.size()==7,"Food is placed in right countertop bins; raw eggs occupy longest bin")
	await game._capture("01_食材格与四层种植.png")
	var original=game.prep.stock[0]
	game._select(0)
	check(game.selected.is_empty(),"Cannot add uncut whole beef directly")
	drag(Vector2(894,546),Vector2(200,600))
	check(game.prep.board_item==-1 and game.prep.stock[0]==original,"Invalid drag returns food without consuming inventory")
	drag(Vector2(894,546),Vector2(677,595))
	click(Vector2(682,595))
	await wait(.19)
	await game._capture("02_砧板逐刀切肉.png")
	await wait(.22)
	for i in range(2):
		click(Vector2(699+i*15,595))
		await wait(.4)
	check(game.prep.cuts==3,"Beef cuts are visible and count individual clicks")
	drag(Vector2(720,600),Vector2(444,523))
	check(game.selected==[0] and game.prep.stock[0]==original-1,"Beef commits exactly one portion after chopping")
	click(Vector2(960,651))
	click(Vector2(1008,546))
	check(game.selected==[0,1,3],"Raw egg and chili oil are selected from countertop compartments")
	game._cook()
	game._process(4)
	game._cook()
	await wait(.93)
	await game._capture("03_撕开泡面袋.png")
	await wait(.5)
	check(game.stage==2 and game.prep.packet_stage==1,"Torn packet waits for second click indefinitely")
	game._process(300)
	check(game.stage==2,"No automatic noodle drop while waiting")
	game._cook()
	await wait(.34)
	await game._capture("04_面饼调料下锅.png")
	await wait(.8)
	game._process(5)
	game._cook()
	await game._capture("05_热面出锅.png")
	game._serve()
	var earned=game.coins
	game._serve()
	check(earned>28 and earned==game.coins,"Local service earns payment exactly once")
	game._next_customer()
	await cut_meat(4)
	game.prep.harvest_plant(1)
	check(game.selected.has(2) and game.prep.farm_growth[1]==0,"Cabbage is sourced from second hydroponic drawer")
	game.prep.tick(90)
	check(game.prep.farm_growth[1]==0,"Harvested crop does not regrow without watering")
	game.prep.water(1)
	game.prep.tick(60)
	check(game.prep.farm_growth[1]==0,"One water dose is insufficient")
	await game._capture("06_采收后等待浇水.png")
	game.prep.water(1)
	game.prep.tick(15)
	check(game.prep.farm_growth[1]>.4 and game.prep.farm_growth[1]<1,"Two doses start gradual regrowth")
	game.prep.tick(16)
	check(game.prep.farm_growth[1]==1,"Crop becomes harvestable again")
	await finish_cooking()
	game._serve()
	game._next_customer()
	game._select(1)
	game.prep.harvest_plant(3)
	await finish_cooking()
	game._serve()
	game._next_customer()
	check(game.day==2 and game.order_index==0,"Three-customer story continues into next day")
	var saved_amount=game.prep.stock[1]
	game._select(1)
	game._reset_bowl()
	check(game.prep.stock[1]==saved_amount,"Reset refunds reserved ingredients")
	for id in [0,1,3,4]: game._select(id,true)
	game.prep.harvest_plant(0)
	game.prep.harvest_plant(2)
	check(game.selected.size()==5 and game.prep.farm_growth[2]==1,"Five ingredient slots prevent overfilling and accidental crop loss")
	game._reset_bowl()
	game.economy.open_menu()
	game.economy.tab="shop"
	game.economy.redraw()
	await game._capture("07_公路营地商店.png")
	var before_coins=game.coins
	var before_stock=game.prep.stock[0]
	check(game.economy.buy(0),"Shop purchase succeeds with enough currency")
	check(game.coins==before_coins-12 and game.prep.stock[0]==before_stock+3,"Shop deducts coins and adds exact quantity")
	game.coins=0
	check(not game.economy.buy(0),"Insufficient funds cannot buy or create negative balance")
	game.coins=before_coins
	game.economy.tab="job"
	game.economy.accept_job()
	game.economy.toggle_delivery()
	await cut_meat(0)
	game._select(1)
	await finish_cooking()
	game._serve()
	check(game.economy.job.packed and game.stage==0,"Correct delivery can be packed without paying out early")
	check(not game.economy.deliver(),"Delivery cannot complete at wrong destination")
	check(game.economy.travel(1),"Packed food can travel to railway checkpoint")
	game.economy.open_menu()
	game.economy.tab="job"
	game.economy.redraw()
	await game._capture("08_外卖到站交付.png")
	var before_delivery=game.coins
	check(game.economy.deliver(),"Correct destination accepts packed delivery")
	check(game.coins==before_delivery+32 and game.economy.scrap==1,"Delivery rewards coins and salvage part")
	check(not game.economy.deliver(),"Repeated delivery click cannot duplicate reward")
	check(game.economy.GOODS[0][0].id!=game.economy.GOODS[1][0].id,"Map shops carry different goods")
	check(game.economy.buy(2),"Railway shop sells functional grow-light upgrade")
	game.economy.panel.hide()
	await game._capture("09_铁轨哨站.png")
	check(game.economy.travel(2),"Can visit salt-lake ferry map")
	game._set_weather(1)
	game.hour=22
	game._apply_lighting(10)
	await wait(.4)
	await game._capture("10_雨夜客人身后下雨.png")
	for w in [0,2,3]:
		game._set_weather(w)
		game.hour=18
		game._apply_lighting(10)
		await wait(.2)
	check(game.weather==3 and game.dust_amount==1,"Daylight and all four weather modes still update")
	game.economy.upgrades.append("collector")
	game._set_weather(1)
	var water=game.prep.water_store
	game.economy.tick(15.1)
	check(game.prep.water_store==water+1,"Rain collector adds water during rain")
	game.prep.water_store=0
	game.economy.refill()
	check(game.prep.water_store==8,"Free well prevents farming resource deadlock")
	game.economy.open_menu()
	game.economy.tab="audio"
	game.economy.redraw()
	await game._capture("11_ASMR声音设置.png")
	for name in ["chop1","chop2","chop3","tear","rustle","egg","water","splash","bowl","boil","rain","tap"]:
		var stream=load("res://assets/asmr/"+name+".wav")
		check(stream!=null and stream.get_length()>.05,"Recorded Foley asset loads: "+name)
	game.audio.play_at("chop1",.15,-7)
	check(game.audio.boil.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and game.audio.rain.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Recorded boil and rain loops are configured for continuous playback")
	check(game.audio.voices[game.audio.next_voice-1].playing,"Foley plays through independent voice pool")
	game._toggle_sound()
	check(game.sound_off and not game.audio.voices[game.audio.next_voice-1].playing,"Mute immediately silences active effects")
	game._toggle_sound()
	game.economy.panel.hide()
	# A restart must preserve a torn packet, without dropping noodles on its own.
	game._cook()
	game._process(4)
	game._cook()
	await wait(1.5)
	var packet_save=game.prep.to_save().duplicate(true)
	game.prep.reset_packet()
	game.prep.restore(packet_save)
	check(game.prep.packet_stage==1 and game.prep.packet.visible and game.stage==2,"Open packet restores visibly and still needs a second click")
	game._reset_bowl()
	game.prep.farm_growth[2]=0
	game.prep.farm_water[2]=2
	game.prep.tick(16)
	check(game.prep.farm_growth[2]==1,"Purchased grow-light actually shortens regrowth to sixteen seconds")
	game._set_weather(0)
	game.hour=10
	game._apply_lighting(10)
	game._toggle_layers()
	await wait(1)
	await game._capture("12_真实3D食材片层.png")
	game._toggle_layers()
	game.qa_save_enabled=true
	game.save_path="user://qa_v2_roundtrip.json"
	game.economy.accept_job()
	game._select(1)
	game.prep.farm_growth[0]=0
	game.prep.farm_water[0]=1
	game.audio.foley_volume=.42
	game._save()
	var expected_coins=game.coins
	game.coins=0
	game.selected.clear()
	game._load_save()
	check(game.coins==expected_coins and game.selected==[1] and game.prep.farm_water[0]==1 and game.economy.map_index==2 and not game.economy.job.is_empty() and is_equal_approx(game.audio.foley_volume,.42),"Save restores inventory, crops, map, job and audio settings")
	game.qa_save_enabled=false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	var report={"version":2,"passed":checks.size(),"checks":checks,"godot":Engine.get_version_info().string,"audio":"12 recorded Foley clips with source and license provenance","maps":3,"weather_depth":-2.5,"customer_depth":-1.5}
	var file=FileAccess.open(ProjectSettings.globalize_path("user://qa_verify_result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("QA_PASS: "+str(checks.size())+" checks")
	await game._shutdown()
