extends RefCounted
var game
var checks=[]
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok});print(("PASS " if ok else "FAIL ")+label)
	if not ok:game.get_tree().quit(1);assert(ok,label)
func capture(name:String):
	if DisplayServer.get_name()!="headless":await game._capture(name)
func move(p:Vector2):
	var ev=InputEventMouseMotion.new();ev.position=p;ev.global_position=p;game.get_viewport().push_input(ev)
func mouse(p:Vector2,pressed:bool):
	var ev=InputEventMouseButton.new();ev.position=p;ev.global_position=p;ev.button_index=MOUSE_BUTTON_LEFT;ev.pressed=pressed;game.get_viewport().push_input(ev)
func run(g):
	game=g
	await game.get_tree().create_timer(.15).timeout
	game.set_process(false);game.auto_time=false;game.auto_weather=false;game.tutorial.active=false;game.tutorial.overlay.hide()
	game.v5.cancel_transition();game.title_screen.hide();game.help_panel.hide();game.fieldlife.close_fridge();game.fieldlife.pointer=Vector2(700,680)
	game.screenshot_dir="user://qa_verify_ten"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(game.screenshot_dir))
	check(game.qa_mode and not game.qa_save_enabled,"QA uses isolated progress and preserves player saves")
	check(game.audio.FOLEY_GAIN_DB>=10 and game.audio.music_volume>=.8,"Foley and music gains are raised substantially")
	var mix=AudioServer.get_bus_index("StallMix")
	check(mix>=0 and AudioServer.get_bus_effect(mix,0) is AudioEffectHardLimiter,"Shared audio mix has a peak limiter")
	check(AudioServer.get_bus_effect(mix,0).ceiling_db<0,"Output peak ceiling stays below digital clipping")
	game.sound_off=false;game.audio.play_at("egg",.5,-9)
	check(game.audio.voices[(game.audio.next_voice+7)%8].volume_db>=1,"Egg cracking sound is louder than previous -9dB trim")
	game.stage=1;game.v4.has_water=true;game.v4.boil_intensity=.1;game.audio.tick(2)
	var early=game.audio.boil.volume_db
	game.stage=3;game.v4.boil_intensity=1;game.audio.tick(2)
	check(game.audio.boil.volume_db>early+8 and game.audio.boil_strength>.99,"Gurgle grows with the same intensity as visible boiling")
	game.sound_off=true;game.audio.tick(1)
	check(game.audio.boil.volume_db<=-79 and game.audio.rain.volume_db<=-79,"Mute still silences all ambient cooking channels")
	game.stage=0;game.v4.has_water=false;game.v4.boil_intensity=0;game._refresh();game.cabin_details.tick(1)
	check(game.cabin_details.radio!=null and game.cabin_details.board!=null,"Grey radio and thin-board patches are installed")
	check(not game.world.find_child("LargePerspectiveWasteBin",true,false).visible and not game.service.trash.visible,"Both older damaged bin meshes are hidden")
	check(game.cabin_details.closed_bin.visible and not game.cabin_details.open_bin.visible,"Clean waste bin is closed at rest")
	move(Vector2(1210,680));game.cabin_details.tick(.2)
	check(not game.cabin_details.lid_open,"Hovering without a bowl never opens the bin")
	move(Vector2(700,680));game.cabin_details.tick(.2);await capture("00_音量与厨房细节更新.png")
	game.stage=5;game.selected=[0,1];game.service.restore_bowl();game._refresh()
	mouse(Vector2(704,563),true);move(Vector2(1210,674));game.cabin_details.tick(.2)
	check(game.v5.kind=="bowl" and game.cabin_details.lid_open,"Actual bowl drag opens the bin only at its drop target")
	await capture("01_拖面靠近才打开垃圾桶.png")
	move(Vector2(900,490));game.cabin_details.tick(.2)
	check(not game.cabin_details.lid_open,"Moving the bowl away closes the lid again")
	move(Vector2(1210,674));game.cabin_details.tick(.2);var before=game.service.discarded
	mouse(Vector2(1210,674),false);game.cabin_details.tick(.2)
	check(game.stage==0 and game.service.discarded==before+1 and not game.cabin_details.lid_open,"Dropping discards once and returns the bin to its closed state")
	game.v4.close_conversation();game._reset_bowl();game.prep.choose_flavor(1);game.prep.stock[1]=5;game._select(1)
	game.stage=3;game.prep.packet_stage=2;game.v4.has_water=true;game.v4.seasoned=true;game.simmer.start_cycle();game._select(1,true)
	var egg_age=game.prep.cooking_fx.egg_age
	var guest=game.day_cycle.current_guest_id
	game._click_for_qa(game.navigation.buttons.shop.get_global_rect().get_center())
	check(game.economy.panel.visible and game.economy.tab=="shop" and game.day_cycle.has_customer(),"Separate shop opens through its actual button during active service")
	game.prep.tick(1);game.simmer.tick(1)
	check(game.prep.cooking_fx.egg_age==egg_age and game.simmer.elapsed==0,"Shopping pauses an in-flight egg and the shared cooking clock together")
	game.coins=300
	var goods=game.economy.local_goods()
	var upgrade_index=-1
	for i in range(goods.size()):
		if goods[i].id=="magazine_8":upgrade_index=i
	check(upgrade_index>=0 and game.economy.buy(upgrade_index) and game.fieldlife.capacity()==8,"Purchase in the independent shop updates the hunting magazine capacity")
	check(game.day_cycle.current_guest_id==guest and not game.day_cycle.can_hunt(),"Shopping and upgrading preserve the guest and after-hours hunting gate")
	game.economy.panel.hide();game.prep.tick(.82);game.simmer.tick(.82);game.v4.update_pot()
	check(game.selected.has(1) and game.prep.stock[1]==4 and not game.prep.egg_pending(),"Closing the shop resumes egg landing with one inventory charge")
	check(game.v4.pot_material.get_shader_parameter("flavor")==1,"Selected seafood broth remains white through the shopping interruption")
	game._reset_bowl()
	game.fieldlife.cold_pinned=true;game.fieldlife.cold_suppressed=false;game.fieldlife.tick(.5)
	check(game.fieldlife.cold_slots.size()==6 and game.fieldlife.COLD_IDS.has(15) and game.fieldlife.COLD_IDS.has(16),"Fridge shelf UI includes both newly huntable regional meats")
	game.fieldlife.close_fridge()
	var f=FileAccess.open("user://qa_verify_ten_result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"version":"2026-09-13 playable update","checks":checks,"passed":checks.size(),"result":"passed"},"  "));f.close()
	print("TEN_ALL_PASSED ",checks.size());game._shutdown()
