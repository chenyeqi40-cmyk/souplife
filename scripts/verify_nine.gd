extends RefCounted
# Cross-module acceptance. This runs only with --qa-nine and never uses player saves.
var game
var checks=[]
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok});print(("PASS " if ok else "FAIL ")+label)
	if not ok:game.get_tree().quit(1);assert(ok,label)
func capture(name:String):
	if DisplayServer.get_name()!="headless":await game._capture(name)
func tick_hunt(seconds:float):
	for i in range(int(seconds/.02)):game.elapsed+=.02;game.fieldlife.tick(.02)
func run(g):
	game=g
	await game.get_tree().create_timer(.15).timeout
	game.set_process(false);game.auto_time=false;game.auto_weather=false
	game.sound_off=true;game.audio.tick(1);game.v5.cancel_transition();game.tutorial.active=false;game.tutorial.overlay.hide()
	game.fieldlife.close_fridge();game.fieldlife.pointer=Vector2(700,680)
	game.screenshot_dir="user://qa_verify_nine"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(game.screenshot_dir))
	check(game.qa_mode and not game.qa_save_enabled,"QA does not read or overwrite the player's save")
	check(game.font.antialiasing==TextServer.FONT_ANTIALIASING_GRAY,"Simplified Chinese uses ordinary readable antialiased text")
	check(game._style(game.PAPER,game.INK,2) is StyleBoxTexture,"Pixel window artwork remains intact")
	game.title_screen.show();await capture("00_保留原图开始界面.png");game.title_screen.hide()
	game._refresh();game.simmer.refresh()
	check(game.simmer.cells.size()==5 and game.simmer.panel.visible,"Fixed five-cell clock is visible before heating")
	game.simmer.set_plan(2);check(game.simmer.planned_cells==5,"Old plan API cannot shorten the five-cell cycle")
	check(game.service.guide_panel.speech_tip,"Robot keeps the same panel position with an upward bubble tail")
	game.v5.guide_override="慢慢来，每一片菜都有自己的好时候。";game.v4.speak_guide(5);game.v4.refresh()
	game.simmer.pointer=Vector2(895,548);game.simmer.refresh();await capture("01_气泡与食材熟度提示.png")
	game.simmer.pointer=Vector2(700,680);game.simmer.refresh()
	for id in game.prep.FARM_IDS:
		check(str(game.v4.floats[id].material_override.get_shader_parameter("art").resource_path).ends_with("harvest_leaves.png"),"Harvested and simmering greens use new stacked-leaf art: "+game.INGREDIENTS[id])
	game.v4.open_conversation();game.v4.dialogue_action();game.backpack.choose(true);game.backpack.choose(true);game.v4.close_conversation()
	game.prep.prepare_food(0,true,true);game.prep.prepare_food(1,true,true);game.prep.prepare_food(3,true,true)
	game._cook();check(game.stage==1 and not game.simmer.started and not game.v4.seasoned,"Heating starts clear water without starting the cooking clock")
	game.stage=2;game._refresh();game.prep.tear_packet();await game.get_tree().create_timer(1.7).timeout
	check(game.prep.packet_stage==1 and not game.simmer.started,"Tearing the desk packet does not start the clock")
	game.prep.drop_noodles();await game.get_tree().create_timer(.3).timeout
	check(not game.simmer.started,"Clock waits for actual noodle and seasoning landing")
	await game.get_tree().create_timer(.8).timeout
	check(game.stage==3 and game.simmer.started and game.simmer.elapsed==0 and game.v4.seasoned,"Noodle and seasoning landing starts the fixed cycle and colored broth")
	game._select(0,true);game.simmer.tick(4);game._select(1,true);game._select(3,true)
	game._cook();check(game.stage==3 and not game.simmer.finished,"Clicking the pot cannot plate early")
	game.simmer.tick(15.8);game.v4.update_pot();game._refresh()
	check(game.stage==3,"Bowl stays on stove until all five cells finish")
	await capture("02_五格即将完成.png")
	game.simmer.tick(1.0);game.v4.update_pot();game._refresh()
	check(game.simmer.elapsed==20 and game.stage==5 and game.simmer.perfect,"Clock clamps to twenty seconds and automatically plates a perfect bowl")
	check(game.perfect_fx.active and game.perfect_fx.trigger_count==1 and not game.service.eating,"Perfect sparkle triggers exactly once while the bowl remains on own worktop")
	var base=game.service.original_positions[0]
	game.perfect_fx.tick(.26);check(game.bowl.position.y>base.y,"Perfect bowl visibly bounces upward")
	await capture("03_完美泡面弹跳与星光.png")
	game._serve();check(game.stage==6 and game.service.eating and not game.perfect_fx.active,"Manual service stops the bounce before moving bowl to the window")
	game.v4.tick(3)
	check(game.v4.bite_count==1 and not game.service.eating,"Customer takes one bite before expression and review")
	check(not game.fieldlife.closeup.visible and not game.backpack.gifts.has("老乔"),"First perfect reaction precedes gift delivery")
	await capture("04_客人发现完美泡面.png")
	game.v4.advance_review()
	check(game.fieldlife.closeup.visible and game.backpack.gifts.has("老乔"),"Next line names the gift and opens its closeup at actual delivery")
	await capture("05_赠礼特写.png");game.fieldlife.closeup.hide();game.v4.advance_review();game.v5.tick(.9)
	check(game.day_cycle.current_guest_id=="禾苗" and not game.day_cycle.end_today(),"Farewell brings the next distinct customer and still blocks early closing")
	game.v5.cancel_transition();game.stage=0;game.selected.clear();game.prep.reset_packet();game.simmer.reset();game.v4.close_conversation()
	var served={}
	for who in game.day_cycle.day_roster:served[who]=true
	game.day_cycle.restore({"version":2,"phase":0,"day_region":0,"visited_today":served});game._set_customer();game._refresh()
	check(game.day_cycle.is_roster_complete() and game.day_cycle.end_today() and game.day_cycle.can_hunt(),"All completed guests unlock business closing and hunting")
	game.fieldlife.travel_seed=91743;game.fieldlife.open_hunt()
	check(game.fieldlife.phase=="driving" and game.fieldlife.drive_scene.scale==Vector2.ONE and game.fieldlife.drive_scene.texture==game.viewport3d.get_texture(),"Driving uses the original full live cabin without initial camera zoom")
	tick_hunt(1.5);await capture("06_原房车视角窗外行驶.png")
	tick_hunt(1.6);check(game.fieldlife.phase=="approaching","Camera approach starts only after the outside drive ends")
	tick_hunt(1.5);check(game.fieldlife.phase=="hunting" and game.fieldlife.targets.size() in [6,7],"Stopped hunt contains six or seven distant walking lizards")
	game.fieldlife.set_scoped(true);check(game.fieldlife.scope_active,"Hunting still supports optical scope mode")
	await capture("07_镜中远处猎物.png");game.fieldlife.leave_hunt()
	check(game.day_cycle.is_closed() and not game.character.visible,"Returning from hunt leaves business closed with no repeating guest")
	game.stage=3;game.selected=[0];var stock=game.prep.stock[0];game._reset_bowl()
	check(game.prep.stock[0]==stock and game.stage==0,"Discarding cooked food never refunds it as raw stock")
	var file=FileAccess.open("user://qa_verify_nine_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":"2026-09-13 perfect cooking","checks":checks,"passed":checks.size(),"result":"passed","save_isolation":true},"  "));file.close()
	print("NINE_ALL_PASSED ",checks.size());game._shutdown()
