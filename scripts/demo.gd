extends RefCounted
var game
func pause(seconds: float) -> void:
	await game.get_tree().create_timer(seconds).timeout
func run(owner_game) -> void:
	game=owner_game
	var pointer=load("res://scripts/verify.gd").new()
	pointer.game=game
	game.auto_time=false
	game.auto_weather=false
	game.hour=17
	game._set_weather(1)
	game._apply_lighting(10)
	game._notice("窗外下雨，屋檐下面，慢慢做一碗热面。")
	await pause(1.5)
	pointer.drag(Vector2(894,546),Vector2(678,596))
	game._notice("整块牛肉拖到砧板。听见刀刃落在木头上。")
	await pause(.7)
	for i in range(3):
		pointer.click(Vector2(680+i*16,595))
		await pause(.9)
	pointer.drag(Vector2(720,600),Vector2(442,526))
	await pause(.5)
	pointer.click(Vector2(960,650))
	await pause(1.0)
	pointer.click(Vector2(1008,546))
	game._cook()
	game._notice("加水，等锅里的气泡慢慢冒起来。")
	await pause(4.1)
	game._cook()
	game._notice("先撕开包装，再点一次，面饼和调料自动下锅。")
	await pause(2.0)
	game._cook()
	await pause(5.7)
	game._cook()
	game._notice("面熟后自动保温，客人一直等你，不会催。")
	await pause(1.3)
	game._serve()
	await pause(1.4)
	game._next_customer()
	game.prep.harvest_plant(1)
	game._notice("右侧四层培养皿，分别种不同的蔬菜。")
	await pause(.8)
	game.prep.water(1)
	await pause(1.7)
	game.prep.water(1)
	await pause(1.7)
	game._reset_bowl()
	game.economy.open_menu()
	game.economy.tab="shop"
	game.economy.redraw()
	await pause(1.8)
	game.economy.tab="job"
	game.economy.redraw()
	await pause(1.8)
	game.economy.panel.hide()
	game.economy.travel(1)
	await pause(1.2)
	game.economy.travel(2)
	game.hour=22
	game._apply_lighting(10)
	game._notice("一路开摊，一路送热饭。雨留在客人身后的公路上。")
	await pause(2.4)
	await game._shutdown()
