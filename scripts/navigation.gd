extends Control
var game
var buttons={}
const MODES=["route","shop","job","hunt"]
const NAMES=["地图","商店","外卖","打猎"]

class NavPicture extends Control:
	var kind="route"
	func _draw():
		var ink=Color("343c38")
		var paper=Color("eee4c8")
		var green=Color("7e9b79")
		if kind=="route":
			draw_colored_polygon(PackedVector2Array([Vector2(1,4),Vector2(8,1),Vector2(15,4),Vector2(22,1),Vector2(22,20),Vector2(15,23),Vector2(8,20),Vector2(1,23)]),paper)
			for x in [1,8,15,22]:draw_line(Vector2(x,4 if x in [1,15] else 1),Vector2(x,23 if x in [1,15] else 20),ink,2)
			draw_line(Vector2(4,17),Vector2(18,8),green,3)
			draw_rect(Rect2(15,6,5,5),Color("b85d49"))
		elif kind=="shop":
			draw_rect(Rect2(2,9,21,14),ink);draw_rect(Rect2(4,11,17,10),paper)
			draw_rect(Rect2(1,3,23,6),Color("af6650"))
			for x in [3,11,19]:draw_rect(Rect2(x,3,4,6),paper)
			draw_rect(Rect2(7,14,6,7),green);draw_rect(Rect2(16,13,3,4),ink)
		elif kind=="job":
			draw_rect(Rect2(2,10,21,12),ink);draw_rect(Rect2(4,12,17,8),Color("c5ab71"))
			draw_rect(Rect2(8,5,11,3),ink);draw_rect(Rect2(7,7,3,5),ink);draw_rect(Rect2(17,7,3,5),ink)
			draw_rect(Rect2(11,12,3,7),paper)
		else:
			draw_line(Vector2(3,20),Vector2(21,3),ink,4)
			draw_line(Vector2(2,20),Vector2(11,12),Color("9c6b43"),6)
			draw_rect(Rect2(13,5,7,3),ink);draw_rect(Rect2(12,8,3,4),ink)
			draw_rect(Rect2(10,15,3,5),ink)

func setup(g):
	game=g;name="SeparateNavigation";mouse_filter=Control.MOUSE_FILTER_IGNORE
	size=Vector2(1280,800);z_index=22
	for i in range(4):
		var key=MODES[i]
		var b=game._button(self,NAMES[i],Rect2(16,102+i*44,90,38),open_mode.bind(key),game.PAPER,14)
		b.alignment=HORIZONTAL_ALIGNMENT_RIGHT
		for state in ["normal","hover","pressed","disabled","focus"]:
			var style=b.get_theme_stylebox(state).duplicate();style.content_margin_right=8;b.add_theme_stylebox_override(state,style)
		b.add_theme_constant_override("outline_size",0)
		var icon=NavPicture.new();icon.kind=key;icon.position=Vector2(6,6);icon.size=Vector2(25,26);icon.mouse_filter=2;b.add_child(icon)
		buttons[key]=b
	game.economy.nav_button.hide();game.economy.job_label.hide()
	if game.fieldlife:game.fieldlife.hunt_button.hide()

func open_mode(mode:String):
	if mode=="hunt":game.fieldlife.open_hunt()
	else:game.economy.open_mode(mode)

func contains(point:Vector2)->bool:
	if not visible:return false
	for button in buttons.values():
		if button.get_global_rect().has_point(point):return true
	return false

func _process(_delta):
	if not game:return
	visible=not game.show_layers and not (game.title_screen and game.title_screen.visible) and not game.fieldlife.hunt.visible
	var closed=game.day_cycle and game.day_cycle.can_manage_resources()
	for key in buttons:
		buttons[key].tooltip_text="随时采购补给，不影响当天接待" if key=="shop" else ("点击打开" if closed else "接待完今天所有客人并收摊后开放")
