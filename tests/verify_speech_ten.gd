extends SceneTree
var game
var checks=[]
var failed=false
const OUT="user://qa_verify_speech_ten"
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"passed":ok,"name":label});print("SPEECH10_", "PASS " if ok else "FAIL ",checks.size()," ",label)
	if not ok:failed=true
func glyph_bottom(label:Label)->float:
	var bottom=0.0
	for i in range(label.text.length()):
		bottom=maxf(bottom,label.get_character_bounds(i).end.y)
	return label.position.y+bottom
func verify_text(label:Label,panel:Panel)->bool:
	return glyph_bottom(label)+8<=panel.size.y and label.get_visible_line_count()==label.get_line_count()
func snap(name:String):
	if DisplayServer.get_name()=="headless":return
	await create_timer(.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+name+".png")
# 输入位置均为 1280×800 画布坐标；true 避免无头窗口再次缩放。
func click(point:Vector2):
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;game.get_viewport().push_input(motion,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;game.get_viewport().push_input(event,true)
		await create_timer(.06).timeout
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	load("res://scripts/main.gd").new_game_requested=true
	game=load("res://main.tscn").instantiate();game.save_path="user://qa_verify_speech_ten_save.json";root.add_child(game)
	game.qa_mode=true;game.set_process(false);game.title_screen.hide();game.v5.cancel_transition();game.auto_time=false;game.auto_weather=false;game.elapsed=3
	game.time_button.text="09:00 · 晨"
	game.v4.refresh();game.tutorial.active=true;game.tutorial.completed=false;game.tutorial.step=0;game.tutorial.tick(0)
	await process_frame
	game.tutorial._render_lesson()
	var lesson=game.tutorial
	check(lesson.words.get_line_count()>=4,"WELCOME uses the actual four or more wrapped lines")
	check(verify_text(lesson.words,lesson.bubble),"WELCOME displays every shaped line")
	check(glyph_bottom(lesson.words)+12<=lesson.next_button.position.y,"WELCOME final glyph stays above its button with breathing room")
	check(glyph_bottom(lesson.step_label)+8<=lesson.bubble.size.y,"WELCOME footer stays inside the bubble")
	check(lesson.overlay.visible and not game.service.guide_panel.visible,"WELCOME has only one robot speech bubble")
	await snap("08_欢迎教学末行与按钮留白")
	await click(lesson.next_button.get_global_rect().get_center())
	lesson.tick(0);await process_frame;lesson._render_lesson()
	check(lesson.step==1,"Actual welcome button advances to ORDER")
	check(verify_text(lesson.words,lesson.bubble),"ORDER displays every shaped line")
	check(glyph_bottom(lesson.words)+12<=lesson.next_button.position.y,"ORDER text stays above its action button")
	check(glyph_bottom(lesson.step_label)+8<=lesson.bubble.size.y,"ORDER footer stays inside the bubble")
	check(lesson.overlay.visible and not game.service.guide_panel.visible,"ORDER has only one robot speech bubble")
	await snap("09_读订单教学按钮留白")
	var all_fit=true
	var one_bubble=true
	for value in range(16):
		lesson.step=value;lesson._render_lesson();await process_frame;lesson._render_lesson()
		all_fit=all_fit and verify_text(lesson.words,lesson.bubble)
		if lesson.next_button.visible:all_fit=all_fit and glyph_bottom(lesson.words)+12<=lesson.next_button.position.y
		all_fit=all_fit and glyph_bottom(lesson.step_label)+8<=lesson.bubble.size.y
		one_bubble=one_bubble and lesson.overlay.visible and not game.service.guide_panel.visible
	check(all_fit,"All 16 lesson steps keep text, optional button and footer separated")
	check(one_bubble,"All lesson step layouts reuse the same single robot bubble")
	lesson.overlay.hide();lesson.active=false
	game.v5.guide_override="路再长，也先好好吃饭。";game.v4.guide_seconds=20;game.v4.refresh();await process_frame;game.v4.refresh()
	var short=game.service.guide_panel.size.y
	check(short<95 and verify_text(game.service.guide,game.service.guide_panel),"A short assistant line remains compact and fully visible")
	game.v5.guide_override="我是小满，车上的小助手。\n今天先一起做一碗热面。\n客人会等你；下锅后，记得照看每样食材的火候。";game.v4.refresh();await process_frame;game.v4.refresh()
	check(game.service.guide_panel.size.y>short and verify_text(game.service.guide,game.service.guide_panel),"Long assistant text uses its own wrapped Label height")
	game.v5.guide_override="好，开摊。";game.v4.refresh();await process_frame;game.v4.refresh()
	check(game.service.guide_panel.size.y<=short,"Short text shrinks after a longer line")
	var result=FileAccess.open(OUT+"/教学气泡补充验收.json",FileAccess.WRITE)
	result.store_string(JSON.stringify({"passed":not failed,"count":checks.size(),"checks":checks},"  "));result.close()
	print("SPEECH_TEN_COMPLETE ",checks.size()," checks; failures=",failed)
	if failed:
		game.audio.shutdown();quit(1)
	else:game._shutdown()
