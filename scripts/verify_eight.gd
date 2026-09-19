extends RefCounted
# Cross-module acceptance. All mutation is restricted to the QA scene; it never
# reads/writes the player's save. Module-specific edge cases have separate suites.
var game
var checks=[]
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:
		game.get_tree().quit(1)
		assert(ok,label)
func capture(name:String):
	if DisplayServer.get_name()!="headless":await game._capture(name)
func click(point:Vector2,button:int=MOUSE_BUTTON_LEFT):
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=down
		game.get_viewport().push_input(event)
func move(point:Vector2):
	var event=InputEventMouseMotion.new();event.position=point;event.global_position=point;game.get_viewport().push_input(event)
func field_time(seconds:float):
	for i in range(int(seconds/.02)):
		game.elapsed+=.02;game.fieldlife.tick(.02)
func run(g):
	game=g
	await game.get_tree().create_timer(.12).timeout
	game.set_process(false);game.auto_time=false;game.auto_weather=false
	game.sound_off=true;game.audio.tick(1)
	game.v5.cancel_transition();game.v5.customer_offset=0
	game.fieldlife.close_fridge();game.fieldlife.pointer=Vector2(640,680)
	game.screenshot_dir="user://qa_verify_eight"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(game.screenshot_dir))
	check(game.qa_mode and not game.qa_save_enabled,"QA uses isolated in-memory progress")
	check(game.title_screen.background.material.shader.resource_path.ends_with("title_pixel.gdshader"),"Title keeps the supplied image and uses pixel sampling")
	check(game._style(game.PAPER,game.INK,2) is StyleBoxTexture,"Window and button frames use pixel nine-slice artwork")
	check(game.font.antialiasing==TextServer.FONT_ANTIALIASING_NONE,"Chinese UI font has hard pixel edges")
	game.title_screen.show();await capture("00_原图像素开始界面.png");game.title_screen.hide()
	game._refresh();game.simmer.refresh()
	check(game.simmer.panel.visible and game.simmer.cells.size()==5 and game.simmer.rows.is_empty(),"One five-cell clock is visible before heating")
	move(Vector2(895,548));game.simmer.refresh()
	check(game.simmer.hover_panel.visible and game.simmer.hover_title.text.contains("5 格"),"Tray hover previews beef cooking requirement")
	await capture("01_食材熟度提示.png")
	game.v4.open_conversation();game.v4.dialogue_action();game.backpack.choose(true);game.backpack.choose(true);game.v4.close_conversation()
	check(game.backpack.conversation_complete,"Customer conversation condition is recorded before cooking")
	click(Vector2(895,548))
	check(game.prep.board_item==0,"Whole beef click reaches the cutting board")
	for i in range(3):
		click(Vector2(690,587));await game.get_tree().create_timer(.15).timeout;game.prep.tick(.4)
	click(Vector2(690,587));click(Vector2(973,652));click(Vector2(1005,546))
	game.prep.tick(1)
	check(game.prep.staged_food.has(0) and game.prep.staged_food.has(1) and game.prep.staged_food.has(3) and game.selected.is_empty(),"Prepared meat egg and spice stay on worktop before heating")
	move(Vector2(690,680));game.simmer.refresh();await capture("02_备好食材再开火.png")
	click(Vector2(445,561));check(game.stage==1 and game.v4.has_water and not game.v4.seasoned,"Pot starts with clear water")
	game.stage=2;game._refresh()
	click(Vector2(270,610));await game.get_tree().create_timer(1.7).timeout
	check(game.prep.packet_stage==1,"First packet click tears the desk packet")
	click(Vector2(585,533));await game.get_tree().create_timer(1.1).timeout
	check(game.stage==3 and game.prep.packet_stage==2 and game.v4.seasoned and not game.simmer.started,"Noodles and seasoning enter before ingredient timer starts")
	game.prep.tick(1)
	click(game.prep.ready_rect(0).get_center());game.simmer.tick(4)
	click(game.prep.ready_rect(1).get_center());click(game.prep.ready_rect(3).get_center())
	game.simmer.tick(16.1);game.v4.update_pot();game._refresh()
	check(game.stage==4 and game.simmer.quality(0)=="最佳" and game.simmer.quality(1)=="最佳","Staggered addition makes beef and egg optimal on the shared clock")
	await capture("03_同一时间条完成烹饪.png")
	click(Vector2(445,561))
	check(game.stage==5 and game.simmer.perfect and not game.service.eating,"Shared finish creates perfect bowl on own worktop")
	check(game.v5.guide_override.contains("刚刚好"),"Perfect bowl triggers robot praise")
	await capture("04_完美面留在台面.png")
	click(Vector2(704,572));check(game.stage==6 and game.service.eating,"Manual bowl click serves the customer")
	game.v4.tick(3)
	check(game.v4.bite_count==1 and not game.service.eating,"Customer completes one bite before review")
	check(game.backpack.gifts.has("老乔") and game.fieldlife.closeup.visible,"Perfect meal plus dialogue grants the matching closeup gift")
	await capture("05_纪念品像素窗口.png")
	game.fieldlife.closeup.hide();game.v4.advance_review();game.v4.advance_review();game.v5.tick(1.0)
	check(game.stage==0 and not game.day_cycle.has_customer() and not game.character.visible,"Farewell leaves the window empty for business choice")
	check(game.day_cycle.visited_today.has("老乔") and not game.day_cycle.remaining().has("老乔"),"The served guest cannot return on this day")
	check(game.day_cycle.end_today(),"Business can close after completed service")
	await capture("06_结束营业后安排资源.png")
	game.day_cycle.show_management=false;game.day_cycle.refresh();game.fieldlife.open_hunt()
	check(game.fieldlife.phase=="driving" and not game.fieldlife.armed,"Hunt begins with driving while input is locked")
	field_time(3.1);check(game.fieldlife.phase=="approaching","Driving transitions to camera push-in")
	field_time(1.2);check(game.fieldlife.phase=="hunting" and game.fieldlife.targets.size()==3,"Camera stops before the hunt unlocks")
	game.audio.tick(.1);check(game.audio.music_track=="hunt_dunes","Closing and hunting switch to exploration BGM")
	await capture("07_房车窗口远景猎场.png")
	var target=game.fieldlife.targets[1]
	var point=target.pic.get_global_rect().position+target.pic.size*Vector2(.57,.66)
	var before=game.prep.stock[11]
	click(point);check(game.fieldlife.shots==0,"Unscoped click cannot fire or hit")
	move(point);click(point,MOUSE_BUTTON_RIGHT)
	check(game.fieldlife.scope_active,"Right mouse button enters magnified scope")
	await capture("08_瞄准镜中的同一猎物.png")
	click(point);check(game.fieldlife.hit_count==1 and game.prep.stock[11]==before,"Hit animation precedes any inventory award")
	field_time(.48);await capture("09_倒地叉眼.png")
	field_time(.30);await capture("10_食材弹出.png")
	field_time(1.0)
	check(game.prep.stock[11]==before+1 and game.fieldlife.loot_toasts.size()==2,"Loot flies to backpack and reports exact additions")
	game.fieldlife.leave_hunt();game.fieldlife.tick(.1)
	check(game.prep.stock[11]==before+1 and game.day_cycle.is_closed() and not game.character.visible,"Return keeps business closed and does not duplicate loot")
	game.audio.tick(.1);check(game.audio.music_track!="hunt_dunes","Returning restores camp BGM")
	var old_day=game.day
	check(game.day_cycle.start_next_day() and game.day==old_day+1,"Next day begins only by explicit action")
	game.v5.tick(1.1)
	check(game.day_cycle.has_customer() and game.day_cycle.current_guest_id=="老乔" and game.day_cycle.visited_today.size()==1,"Next-day arrival restarts a fresh finite guest list")
	var data={"version":"2026-09-13 pixel business","checks":checks,"passed":checks.size(),"result":"passed","save_isolation":true}
	var file=FileAccess.open("user://qa_verify_eight_result.json",FileAccess.WRITE);file.store_string(JSON.stringify(data,"  "));file.close()
	print("EIGHT_ALL_PASSED ",checks.size())
	game.get_tree().quit()
