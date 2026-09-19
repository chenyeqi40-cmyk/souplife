extends RefCounted
static var phase=0
const SENTINEL="user://qa_verify_title_flow_save.json"
var game
func check(ok:bool,label:String)->void:
	if not ok:
		push_error("TITLE_QA_FAILED: "+label)
		game.get_tree().quit(1)
		assert(ok,label)
	print("PASS: "+label)
func run(g)->void:
	game=g
	await game.get_tree().create_timer(.12).timeout
	if phase==0:
		check(game.title_screen.visible,"Normal launch shows the title first")
		game.save_path=SENTINEL
		var file=FileAccess.open(SENTINEL,FileAccess.WRITE)
		file.store_string("existing-progress");file.close()
		game.coins=43;game.selected=[1]
		game.title_screen.resume_button.disabled=false
		game._click_for_qa(game.title_screen.new_button.get_global_rect().get_center())
		await game.get_tree().create_timer(.12).timeout
		check(game.title_screen.confirm.visible and game.coins==43,"Starting over asks inside the game before replacing an existing journey")
		game.title_screen.confirm.hide()
		game.title_screen.enter_game()
		await game.get_tree().create_timer(.95).timeout
		check(not game.title_screen.visible and game.coins==43 and game.selected==[1],"Continue keeps the current journey")
		check(game.v4.dialogue_open,"Continue brings guest to window with an automatic greeting")
		phase=1
		game.title_screen.restart_game()
	else:
		check(not game.title_screen.visible and game.stage==0 and game.coins==28 and game.selected.is_empty(),"Confirmed new journey resets to a playable fresh stall")
		await game.get_tree().create_timer(.95).timeout
		check(game.v4.dialogue_open and not game.v5.busy(),"New journey enters gameplay and greets without another start click")
		check(FileAccess.get_file_as_string(SENTINEL)=="existing-progress","Menu checks never alter real player saves")
		print("TITLE_FLOW_QA_COMPLETE 7")
		game._shutdown()
