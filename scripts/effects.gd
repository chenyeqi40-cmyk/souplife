extends Control

var game: Control

func _draw() -> void:
	if game == null or game.show_layers: return
	var t: float = game.elapsed
	var night: float = game.light_night
	# Warm light spill is restricted to the cabin; rain remains in the 3D opening.
	if night > .02:
		for i in range(8):
			var r = Rect2(402-i*10,111-i*2,480+i*20,17+i*4)
			draw_rect(r,Color(1,.71,.35,.010*night))
		for i in range(5):
			draw_rect(Rect2(1100-i*5,205,155+i*10,407),Color(.32,.83,.74,.005*night))
	# Visible simmer bubbles and steam, hand-placed on the pot surface.
	if game.stage in [1,2,3,4,5,6]:
		var strength = .45 if game.stage==1 else 1.0
		var center = Vector2(442,529)
		if game.stage >= 5: center = Vector2(690,551)
		if game.stage == 6: center = Vector2(704,409)
		for i in range(20):
			var life = fposmod(t*.22+float(i)*.071,1.0)
			var px = center.x+sin(float(i)*2.76)*43+sin(life*5+float(i))*10
			var py = center.y-life*96
			var sz = 3+floor(life*4)
			var a = sin(life*PI)*.19*strength
			draw_rect(Rect2(floor(px/2)*2,floor(py/2)*2,sz*2,sz),Color(.94,.91,.80,a))
		if game.stage in [1,2,3,4]:
			for i in range(11):
				var x = 392+fposmod(float(i)*27.1,88.0)
				var y = 517+sin(i*1.7)*15
				var phase = fposmod(t*(.8 if game.stage==1 else 1.5)+i*.21,1.0)
				var bubble=Color(1,.79,.40,(1-phase)*.40) if game.v4 and game.v4.seasoned else Color(.8,.9,.9,(1-phase)*.33)
				draw_rect(Rect2(x,y,2+phase*3,2),bubble)
	# All weather is behind the customer in the 3D world.
	if game.prep:
		for i in range(4):
			if game.prep.water_fx[i]>0:
				for j in range(12):
					var p=Vector2(1170+j%4*5,220+i*106+fposmod(t*82+j*13,62))
					draw_rect(Rect2(p,Vector2(2,5)),Color(.62,.88,.93,.8))
	# Radio activity after the first two encounters connects the miniature story.
	if game.order_index==2 or game.day>1:
		for i in range(5):
			var height = 2+abs(sin(t*3+i*2))*6
			draw_rect(Rect2(828+i*4,74-height,2,height),Color("a5e9a0"))
	if game.hydrated:
		draw_rect(Rect2(1240,625,7,4),Color("a3e57b"))
