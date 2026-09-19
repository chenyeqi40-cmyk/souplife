extends Control
var hearth

func _draw()->void:
	if not hearth or hearth.game.show_layers: return
	var g=hearth.game
	# Change only pixels inside the original screen; keep the reference casing.
	var blink=fposmod(g.elapsed,5.4)<.17 or (fposmod(g.elapsed,13.7)>.31 and fposmod(g.elapsed,13.7)<.43)
	var surprise=g.simmer and g.simmer.perfect and g.stage==5 and hearth.guide_seconds>0
	for x in [145,216]:
		draw_rect(Rect2(x,145,30,23),Color("241f29"))
		if blink and not surprise:draw_rect(Rect2(x+2,157,25,2),Color("c1e68e"))
		elif surprise:
			draw_rect(Rect2(x+5,146,18,19),Color("d7f49b"));draw_rect(Rect2(x+10,151,8,9),Color("241f29"))
		else:
			draw_rect(Rect2(x+5,150,17,12),Color("c1e68e"));draw_rect(Rect2(x+7,148,13,16),Color("c1e68e"))
	draw_rect(Rect2(189,171,15,15),Color("241f29"))
	if surprise:
		draw_rect(Rect2(192,174,9,10),Color("d7f49b"));draw_rect(Rect2(195,177,3,4),Color("241f29"))
	else:draw_rect(Rect2(192,175,7,3),Color("c1e68e"))
	# Tiny deposits are readable through the glass and grow with saved tip income.
	for i in range(mini(hearth.total_tips,12)):
		var p=Vector2(892+i%4*9,454-int(i/4)*4)
		draw_rect(Rect2(p,Vector2(7,3)),Color("bb813c"))
		draw_rect(Rect2(p,Vector2(6,1)),Color("f4d67b"))
	for coin in hearth.coin_flights:
		if coin.age<0: continue
		var t=clampf(coin.age/coin.duration,0,1)
		var p=coin.from.lerp(Vector2(911,412),t)+Vector2(0,-sin(t*PI)*42)
		p=p.snapped(Vector2(2,2))
		draw_texture_rect(g.coin_texture,Rect2(p,Vector2(14,14)),false)
	# Smooth material light pools supply the room light without a hard overlay edge.
