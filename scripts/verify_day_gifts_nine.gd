extends SceneTree
const OUT="user://qa_verify_day_gifts_nine"
var game
var rows=[]
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	rows.append({"passed":ok,"label":label});print("DAY_GIFT ",rows.size()," ","PASS " if ok else "FAIL ",label)
	if not ok:failures+=1;write_result();push_error(label);quit(1);assert(ok,label)
func write_result():
	var f=FileAccess.open(OUT+"/verify_day_gifts_nine.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"suite":"fixed daily roster and earned gift review","count":rows.size(),"passed":failures==0,"checks":rows},"  "))
func capture(name:String):
	if DisplayServer.get_name()!="headless":game.screenshot_dir=OUT;await game._capture(name)
	else:await process_frame;await process_frame
func move(p:Vector2):
	var ev=InputEventMouseMotion.new();ev.position=p;ev.global_position=p;game.get_viewport().push_input(ev)
func reset_guest(region:int,who:String):
	game.fieldlife.closeup.hide();game.fieldlife.close_fridge();game.fieldlife.pointer=Vector2(700,680)
	game.economy.panel.hide();game.backpack.panel.hide();game.backpack.pinned=false
	game.stage=0;game.selected.clear();game.prep.clear_board();game.prep.reset_packet();game.v5.cancel_transition()
	game.service.eating=false;game.economy.delivery_mode=false;game.economy.job.clear()
	game.day+=1;game.economy.map_index=region;game.economy.apply_map()
	game.day_cycle.restore({"version":2,"phase":1,"current_guest_id":who,"day_region":region,"visited_today":{who:true}})
	game.v4.new_guest();game._set_customer();game.simmer.reset();game.backpack.tick();game._refresh()
func talk_right():
	game.v4.open_conversation();game.v4.dialogue_action();game.backpack.choose(true);game.backpack.choose(true)
func plate(perfect:bool=true,foods:Array=[]):
	game.selected=game.service.order().need.duplicate() if foods.is_empty() else foods.duplicate()
	game.stage=3;game.prep.packet_stage=2;game.simmer.reset();game.simmer.started=true;game.simmer.elapsed=20.0
	var first=true
	for item in game.selected:
		var id=int(item)
		if id==3:continue
		var t=game.simmer.target(id)*4.0
		if not perfect and first:t=maxf(0,t-3);first=false
		game.simmer.portions[id]={"time":t,"added_at":20.0-t,"quality":"生","lifted":false}
	game._finish_cooking_automatically()
func eat():
	game._serve();game.v4.tick(3.0)
func goodbye():
	game.fieldlife.closeup.hide()
	if game.v4.review_line==0:game.v4.advance_review()
	game.fieldlife.closeup.hide();game.v4.advance_review();game.v5.tick(.9)
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	load("res://scripts/main.gd").new_game_requested=true
	game=load("res://main.tscn").instantiate();game.save_path=OUT+"/qa_day_gifts_save.json";root.add_child(game)
	game.qa_mode=true;game.set_process(false);game.title_screen.hide();game.tutorial.active=false;game.tutorial.overlay.hide()
	game.v5.cancel_transition();game.auto_time=false;game.auto_weather=false;game.fieldlife.pointer=Vector2(700,680)
	await process_frame
	check(game.day_cycle.day_roster.size()==5 and game.day_cycle.current_guest_id=="老乔","Current desert day has five fixed guests")
	check(not game.day_cycle.end_today() and not game.day_cycle.can_hunt() and not game.day_cycle.can_manage_resources(),"First guest cannot be skipped by early closing or outside activity")
	game.economy.open_menu();var coins=game.coins
	check(not game.economy.panel.visible and not game.economy.buy(0) and game.coins==coins and not game.economy.travel(1),"Resource menu, buying and travel are gated during daily roster")
	check(game.service.guide_panel.speech_tip and not game.service.guide_panel.get_child(0).visible,"Assistant uses top-tail speech bubble without title label")
	talk_right();plate(false);check(not game.simmer.perfect,"Normal-cooked fixture is not a perfect bowl")
	eat();check(game.order_label.text.contains("好吃") and game.service.last_frame==2,"Normal matching ramen receives warm good-taste reaction")
	check(not game.fieldlife.closeup.visible and not game.backpack.gifts.has("老乔"),"Normal meal never grants or opens a gift")
	await capture("nine_day_01_普通面评价.png")
	game.v4.advance_review();check(not game.order_label.text.contains("纪念品") and not game.order_label.text.contains("罗盘") and not game.service.journal.message,"Normal follow-up neither promises a keepsake nor advances perfect-meal story")
	goodbye();check(game.day_cycle.current_guest_id=="禾苗" and game.v5.transition=="arriving" and not game.day_cycle.panel.visible,"Farewell automatically starts next guest without an early-closing choice")
	game.v5.tick(.9);check(game.v4.dialogue_open,"Automatic next guest arrives and speaks")
	for who in ["禾苗","拾风","阿砾","白禾"]:
		check(game.day_cycle.current_guest_id==who,"Daily sequence continues with "+who)
		if who=="拾风":game.v4.dialogue_action()
		plate(false);eat();goodbye()
		if who!="白禾":game.v5.tick(.9)
	check(game.day_cycle.is_roster_complete() and not game.character.visible and game.day_cycle.current_guest_id=="","Final farewell leaves an empty window without looping")
	check(game.day_cycle.headline.text=="今天似乎不会再有人来了" and not game.day_cycle.can_manage_resources(),"Full roster prompts end of business before resource time")
	await capture("nine_day_02_今日名单结束.png")
	game._click_for_qa(game.day_cycle.primary.get_global_rect().get_center())
	check(game.day_cycle.is_closed() and game.day_cycle.can_hunt() and not game.day_cycle.panel.visible,"End-business button unlocks hunting and dismisses blocking management panel")
	game.fieldlife.tick(.05);game._click_for_qa(game.fieldlife.hunt_button.get_global_rect().get_center())
	check(game.fieldlife.hunt.visible,"Actual hunting entrance click succeeds immediately after business ends")
	game.fieldlife.leave_hunt();game.day_cycle.finish_customer()
	check(game.day_cycle.is_closed(),"Late departure callback cannot reopen closed day")
	game.economy.open_menu();check(game.economy.panel.visible,"After-hours resource menu opens")
	game.economy.panel.hide();game.save_path=OUT+"/qa_day_gifts_save.json";game.qa_save_enabled=true;game._save()
	game.day_cycle.visited_today.clear();game.day_cycle.phase=0;game._load_save();game._set_customer();game._refresh()
	check(game.day_cycle.is_closed() and game.day_cycle.day_roster.size()==5 and game.day_cycle.remaining().is_empty(),"Closed v2 roster save restores without losing completion")
	check(game.economy.travel(1) and game.day_cycle.day_region==0 and game.day_cycle.is_closed(),"After-hours travel does not replace already completed daily roster")
	check(game.day_cycle.start_next_day() and game.day_cycle.day_region==1 and game.day_cycle.day_roster.size()==2,"Explicit next day uses the newly visited region's complete roster")
	game.v5.cancel_transition();game.stage=0;game.selected.clear();game.day_cycle.restore({"version":1,"phase":2,"visited_today":{"阿岚":true}})
	check(game.day_cycle.is_closed() and game.day_cycle.remaining().is_empty() and game.day_cycle.can_hunt(),"Earlier early-closed saves stay usable and grandfather the old finished day")
	game.day_cycle.restore({"version":1,"phase":0,"visited_today":{"阿岚":true}})
	check(game.day_cycle.current_guest_id=="阿灯" and not game.day_cycle.can_manage_resources(),"Earlier between-guest save resumes the next unvisited guest automatically")
	reset_guest(0,"老乔");talk_right();plate(true);eat()
	check(game.simmer.perfect and game.order_label.text.contains("等一下") and not game.backpack.gifts.has("老乔") and not game.fieldlife.closeup.visible,"Perfect tasting reaction occurs first, before the gift is issued")
	await capture("nine_day_03_完美面先赞叹.png")
	game._save();game.service.reward_pending=false;game._load_save();game._set_customer();game._refresh()
	check(game.service.reward_pending and game.v4.review_line==0,"Saving between tasting and gift preserves pending review without issuing it early")
	game.v4.advance_review()
	check(game.backpack.gifts.has("老乔") and game.service.journal.message and game.order_label.text.contains("罗盘") and game.order_label.text.contains("送给你"),"Second review line actively offers named compass after correct dialogue and perfect matching food")
	check(game.fieldlife.closeup.visible and game.fieldlife.title.text=="旧黄铜罗盘","Gift moment opens full artwork closeup")
	await capture("nine_day_04_主动赠礼特写.png")
	game.fieldlife.closeup.hide();game._save();game._load_save();game._set_customer();game._refresh()
	await capture("nine_day_05_客人具体赠礼对白.png")
	var gifts=game.backpack.gifts.size();game.service.claim_review_reward()
	check(game.backpack.gifts.size()==gifts and game.service.meal_gift=="旧黄铜罗盘","Claim and save restore never duplicate a keepsake")
	game.backpack.show_item(0);check(game.fieldlife.closeup.visible,"Earned keepsake can be inspected again in cabinet")
	reset_guest(0,"老乔");game.backpack.gifts.clear();talk_right();plate(true,[0]);eat();game.v4.advance_review()
	check(game.simmer.perfect and not game.service.recipe_matches() and not game.backpack.gifts.has("老乔"),"Perfect ingredient doneness with wrong order does not qualify for a gift")
	reset_guest(0,"老乔");plate(true);eat();game.v4.advance_review()
	check(not game.backpack.gifts.has("老乔") and not game.fieldlife.closeup.visible,"Perfect food without correct dialogue does not grant keepsake")
	reset_guest(0,"老乔");plate(true,[2]);eat()
	check(game.service.satisfaction<40 and game.service.last_frame==3 and game.order_label.text.contains("不太对"),"Only seriously mismatched meal uses disappointed reaction")
	reset_guest(1,"阿岚");game.service.journal.message=true
	game.v4.open_conversation();game.v4.dialogue_action();game._refresh()
	check(game.service.story_button.text==game.backpack.topics()[0],"Immediate UI refresh keeps ordinary dialogue choices, never a premature collect-gift button")
	game.backpack.choose(true);game.backpack.choose(true)
	check(not game.order_label.text.contains("交给你") and not game.order_label.text.contains("送给你") and not game.service.journal.battery,"Ordinary pre-meal conversation does not promise or issue battery")
	plate(true);eat();game.v4.advance_review()
	check(game.service.journal.battery and game.service.meal_gift=="旧电池" and game.fieldlife.closeup.visible,"Perfect meal unlocks named consumable battery offer and closeup")
	reset_guest(1,"阿灯");talk_right();plate(true);eat();game.v4.advance_review()
	check(not game.service.journal.battery and game.service.journal.radio and game.backpack.gifts.has("阿灯"),"Next linked customer consumes battery and issues broadcast badge exactly after perfect review")
	reset_guest(0,"禾苗");talk_right();plate(true);eat();game.v4.advance_review()
	check(game.service.journal.seeds and game.service.meal_gift=="半袋种子","Seeds remain a linked consumable reward")
	reset_guest(2,"小夏");talk_right();plate(true);eat();game.v4.advance_review()
	check(game.service.journal.clinic and game.service.meal_gift=="" and not game.fieldlife.closeup.visible,"Clinic consumes story seeds without inventing a fixed reward for every NPC")
	reset_guest(0,"拾风");game.v4.open_conversation();game.v4.dialogue_action();plate(false);eat();game.v4.advance_review()
	check(not game.order_label.text.contains("下次") and not game.order_label.text.contains("哨") and not game.backpack.gifts.has("拾风"),"Ordinary barter meal thanks the player without promising a future whistle")
	reset_guest(0,"拾风");game.v4.open_conversation();game.v4.dialogue_action();plate(true);eat();game.v4.advance_review()
	check(game.backpack.gifts.has("拾风") and game.service.meal_gift=="旧站铜鸟哨" and game.fieldlife.closeup.visible,"Perfect accepted barter meal grants and shows named whistle")
	check(game.v4.floats.size()==15 and game.v4.floats[14]!=null,"New rare red-lizard meat has a pot artwork slot")
	for id in game.prep.FARM_IDS:check(str(game.v4.floats[id].material_override.get_shader_parameter("art").resource_path).ends_with("harvest_leaves.png"),"Pot reuses the new extracted leaf sprite for "+game.INGREDIENTS[id])
	game.qa_save_enabled=false;write_result();print("DAY_GIFTS_NINE_COMPLETE ",rows.size()," failures=",failures)
	if failures>0:game.audio.shutdown();quit(1)
	else:game._shutdown()
