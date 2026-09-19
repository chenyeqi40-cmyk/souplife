extends SceneTree
var game
var checks=[]
var failed=false
const OUT="user://qa_verify_ui_ten"

func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"passed":ok,"name":label});print("UI10_", "PASS " if ok else "FAIL ",checks.size()," ",label)
	if not ok:failed=true;write_result();game.audio.shutdown();quit(1)
func write_result():
	var file=FileAccess.open(OUT+"/界面商店验收.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"suite":"separate navigation and live business shop","passed":not failed,"count":checks.size(),"checks":checks},"  "))
# 输入位置均为 1280×800 画布坐标；true 避免无头窗口再次缩放。
func click_button(button:Button):
	await process_frame
	await click_at(button.get_global_rect().get_center())
func click_at(point:Vector2):
	move(point);await create_timer(.08).timeout
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;game.get_viewport().push_input(event,true)
		await create_timer(.08).timeout
func move(point:Vector2):
	var event=InputEventMouseMotion.new();event.position=point;event.global_position=point;game.get_viewport().push_input(event,true)
func scroll_shop():
	move(Vector2(1000,480));await create_timer(.12).timeout
	for i in range(8):
		var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;wheel.position=Vector2(1000,480);wheel.global_position=wheel.position;game.get_viewport().push_input(wheel,true)
		var release=wheel.duplicate();release.pressed=false;game.get_viewport().push_input(release,true)
	await create_timer(.12).timeout
func snap(name:String):
	await create_timer(.12).timeout
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"/"+name+".png")
func button_named(parent:Node,text:String)->Button:
	for child in parent.get_children():
		if child is Button and child.text.contains(text):return child
		var result=button_named(child,text)
		if result:return result
	return null
func prepare_closed():
	game.economy.panel.hide();game.v5.cancel_transition();game.stage=0;game.selected.clear();game.prep.clear_board()
	game.day_cycle.phase=2;game.day_cycle.current_guest_id="";game.day_cycle.show_management=false
	for who in game.day_cycle.day_roster:game.day_cycle.visited_today[who]=true
	game.character.hide();game.v4.close_conversation();game.day_cycle.refresh()
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	load("res://scripts/main.gd").new_game_requested=true
	game=load("res://main.tscn").instantiate();game.save_path="user://qa_verify_ui_ten_save.json";root.add_child(game)
	game.qa_mode=true;game.set_process(false);game.title_screen.hide();game.tutorial.active=false;game.tutorial.overlay.hide()
	game.v5.cancel_transition();game.auto_time=false;game.auto_weather=false;game.fieldlife.pointer=Vector2(700,680)
	game.elapsed=3;game.v4.refresh();await process_frame
	check(game.navigation.buttons.size()==4,"Four independent icon navigation buttons are present")
	var previous_y=-1.0
	for key in ["route","shop","job","hunt"]:
		var b=game.navigation.buttons[key]
		check(b.visible and b.get_child_count()==1 and b.position.y>previous_y,"Icon and vertical ordering for "+key);previous_y=b.position.y
	check(game.navigation.buttons.hunt.text=="打猎" and not game.fieldlife.hunt_button.visible and not game.economy.nav_button.visible,"Hunting says only 打猎 and old combined entries are hidden")
	game.v4.open_conversation();game.v4.dialogue_action();game.backpack.choose(true)
	var guest=game.day_cycle.current_guest_id;var step=game.backpack.conversation_step;var response=game.order_label.text
	await click_button(game.navigation.buttons.shop)
	check(game.economy.panel.visible and game.economy.tab=="shop","Actual shop click opens while a customer is being served")
	check(game.day_cycle.has_customer() and game.day_cycle.current_guest_id==guest and game.backpack.conversation_step==step,"Opening shop preserves guest and dialogue progress")
	check(button_named(game.economy.content,"前往这里")==null and button_named(game.economy.content,"外卖委托")==null,"Shop has no route or delivery tabs mixed into it")
	game.coins=400;var stock=game.prep.stock[0]
	await click_button(button_named(game.economy.content,"12 铜片"))
	check(game.prep.stock[0]==stock+3 and game.coins==388,"Buying a regional food by clicking works during service")
	game.prep.water_store=0;await click_button(button_named(game.economy.content,"免费补水"))
	check(game.prep.water_store==8 and game.day_cycle.current_guest_id==guest,"Water refill is available without advancing the day")
	var goods=game.economy.local_goods();var index8=-1;var index10=-1
	for i in range(goods.size()):
		if goods[i].id=="magazine_8":index8=i
		if goods[i].id=="magazine_10":index10=i
	check(index8>=0 and index10>=0 and goods[index8].price==70 and goods[index10].price==120,"Shop offers 8 and 10 round upgrades at the agreed prices")
	var coins=game.coins
	check(not game.economy.buy(index10) and game.coins==coins,"10-round upgrade requires 8-round upgrade with no charge on failure")
	await scroll_shop()
	check(game.economy.shop_scroll.scroll_vertical>0,"Mouse wheel reveals lower upgrade shelves")
	await click_button(button_named(game.economy.content,"70 铜片"))
	check(game.economy.upgrades.has("magazine_8") and game.coins==coins-70,"Clicking the 8-round upgrade buys and records it during service")
	await scroll_shop()
	await snap("02_营业购买弹仓升级")
	await click_button(button_named(game.economy.content,"120 铜片"))
	check(game.economy.upgrades.has("magazine_10") and game.coins==coins-190,"Clicking the 10-round upgrade consumes exactly its price")
	coins=game.coins;check(not game.economy.buy(index8) and game.coins==coins,"Already installed upgrade cannot be bought twice")
	game.economy.panel.hide();game.v4.refresh()
	check(game.day_cycle.current_guest_id==guest and game.backpack.conversation_step==step,"Shopping leaves the active conversation available to continue")
	await snap("01_四入口与营业中对话")
	for key in ["route","job","hunt"]:
		await click_button(game.navigation.buttons[key])
		check(not game.economy.panel.visible and not game.fieldlife.hunt.visible,"Business gate rejects the "+key+" entrance")
	check(not game.day_cycle.end_today(),"Shopping does not enable early closing")
	game.backpack.pinned=true;game.service.cabinet_amount=1;game.backpack.tick();await process_frame
	check(game.backpack.panel.visible and game.backpack.panel.size.y<300 and not game.backpack.description.visible and not game.service.cabinet_label.visible,"Cabinet contains a compact grid without the old explanation rows")
	game.backpack.gifts.append("老乔");game.backpack.refresh_items();await click_button(game.backpack.cells[0].button)
	check(game.fieldlife.closeup.visible and game.fieldlife.title.text=="旧黄铜罗盘","Clicking a cabinet gift still opens its large closeup")
	game.fieldlife.closeup.hide();game.backpack.pinned=false;game.backpack.suppressed=true;game.backpack.panel.hide()
	game.fieldlife.pointer=Vector2(700,680);game.fieldlife.tick(.01)
	for id in game.fieldlife.COLD_IDS:game.prep.stock[id]=2
	move(Vector2(130,512));await create_timer(.12).timeout;game.fieldlife.tick(.35);await create_timer(.12).timeout
	check(game.fieldlife.cold.visible and game.fieldlife.fridge_amount>.72,"Hovering the actual fridge opens the upper door and its interior")
	check(game.fieldlife.cold.size.x<=212 and game.fieldlife.cold.position.x<30,"Fridge content stays within the original upper fridge instead of a floating menu")
	check(game.fieldlife.cold_slots.size()==game.fieldlife.COLD_IDS.size(),"Every cold ingredient has an internal shelf position")
	for slot in game.fieldlife.cold_slots:check(Rect2(Vector2.ZERO,game.fieldlife.cold.size).encloses(Rect2(slot.position,slot.size)),"Shelf slot is inside the lining")
	await snap("03_上半冰箱内胆与食材")
	var chosen=game.fieldlife.COLD_IDS[0]
	await click_at(game.fieldlife.cold_slots[0].get_global_rect().get_center())
	check(game.prep.board_item==chosen and not game.fieldlife.cold.visible,"Actual shelf ingredient click takes whole meat to the chopping board")
	game.prep.clear_board();move(Vector2(700,680));game.fieldlife.tick(.4)
	game.v4.guide_seconds=5;game.v5.guide_override="真香。";game.v4.refresh();var short=game.service.guide_panel.size.y
	game.v5.guide_override="这口汤让人想起屋檐下的雨声。\n今天路上来了许多人，每个人都带着不同的故事。\n慢慢吃完，再去看看窗外的天色。";game.v4.refresh();await create_timer(.12).timeout;game.v4.refresh()
	check(game.service.guide_panel.size.y>short and game.service.guide_panel.size.y<240,"Assistant bubble grows for longer text and shrinks for a short line")
	print("UI10_LAYOUT ",game.service.guide.position," ",game.service.guide.size," panel ",game.service.guide_panel.size)
	check(game.service.guide.position.y+game.service.guide.size.y+10<=game.service.guide_panel.size.y,"Assistant text has bottom breathing room")
	await snap("04_随文字变化的助手气泡")
	game.tutorial.active=true;game.tutorial.completed=false;game.tutorial.step=game.tutorial.Lesson.WELCOME;game.tutorial._render_lesson();var welcome=game.tutorial.bubble.size.y
	game.tutorial.step=game.tutorial.Lesson.WATER;game.tutorial._render_lesson()
	check(game.tutorial.bubble.size.y!=welcome,"Tutorial bubble also adapts to text and button presence")
	check(game.tutorial.step_label.position.y+game.tutorial.step_label.size.y<game.tutorial.bubble.size.y,"Tutorial footer remains inside its adaptive bubble")
	game.tutorial.overlay.show();await snap("05_教学气泡自适应")
	game.tutorial.active=false;game.tutorial.overlay.hide();game.v5.guide_override="";game.simmer.perfect=true;game.stage=5;game.v4.guide_seconds=5;game.v4.refresh();game.v4.room_layer.queue_redraw();await snap("06_完美料理惊讶表情")
	game.simmer.reset();prepare_closed()
	await click_button(game.navigation.buttons.route)
	check(game.economy.panel.visible and game.economy.tab=="route" and button_named(game.economy.content,"免费补水")==null,"Closed-day map opens as a route-only mode")
	await snap("07_独立地图")
	await click_button(game.navigation.buttons.job)
	check(game.economy.panel.visible and game.economy.tab=="job" and button_named(game.economy.content,"买入")==null,"Closed-day delivery opens as its own mode")
	await click_button(game.navigation.buttons.hunt)
	check(game.fieldlife.hunt.visible and not game.economy.panel.visible,"Hunting opens directly after closing and clears the previous modal")
	game.fieldlife.leave_hunt();check(game.day_cycle.is_closed(),"Returning from hunting does not start a new day")
	game.qa_save_enabled=true
	var marker="{\"ui_test_marker\":true}";var file=FileAccess.open(game.save_path,FileAccess.WRITE);file.store_string(marker);file.close()
	var saved=game.economy.to_save().duplicate(true);game.economy.restore(saved)
	check(FileAccess.get_file_as_string(game.save_path)==marker,"Restoring economy does not rewrite a partly restored save")
	saved.erase("foley");saved.erase("ambience");saved.erase("music");game.economy.restore(saved)
	check(is_equal_approx(game.audio.foley_volume,1.0) and is_equal_approx(game.audio.ambience_volume,.85) and is_equal_approx(game.audio.music_volume,.85),"Missing audio fields use the new defaults")
	saved.foley=.3;saved.ambience=.2;saved.music=.1;game.economy.restore(saved)
	check(is_equal_approx(game.audio.foley_volume,.3) and is_equal_approx(game.audio.ambience_volume,.2) and is_equal_approx(game.audio.music_volume,.1),"Existing audio slider preferences remain unchanged")
	game.qa_save_enabled=false
	write_result();print("UI_TEN_COMPLETE ",checks.size()," checks; failures=",failed);game._shutdown()
