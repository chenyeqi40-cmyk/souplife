extends CanvasLayer
var game
var resume_button:Button
var new_button:Button
var confirm:ConfirmationDialog
var background:TextureRect
var panel:Panel

func setup(g)->void:
	game=g
	layer=100
	var matte=ColorRect.new()
	matte.color=Color("242c2b")
	matte.size=Vector2(1280,800)
	add_child(matte)
	background=TextureRect.new()
	background.position=Vector2(0,40)
	background.size=Vector2(1280,720)
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var pixel=ShaderMaterial.new();pixel.shader=load("res://shaders/title_pixel.gdshader");background.material=pixel
	if ResourceLoader.exists("res://assets/title_interior.png"): background.texture=load("res://assets/title_interior.png")
	add_child(background)
	panel=game._panel(background,Rect2(38,276,286,313),Color("dedbc8"))
	var name_label=game._label(panel,"末日泡面摊",Rect2(21,8,245,30),24,Color("293b36"))
	name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var subtitle=game._label(panel,"荒路尽头，还亮着一盏灯。",Rect2(19,68,250,25),14,Color("666750"))
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	resume_button=game._button(panel,"继续旅程",Rect2(23,112,240,43),enter_game,game.TEAL,18)
	resume_button.disabled=not FileAccess.file_exists(game.save_path)
	new_button=game._button(panel,"开始新旅程",Rect2(23,170,240,43),start_new,game.PAPER,18)
	game._button(panel,"离开",Rect2(23,228,240,43),game._shutdown,game.PAPER,17)
	confirm=ConfirmationDialog.new()
	confirm.title="开始新旅程"
	confirm.dialog_text="重新开摊会覆盖当前进度。\n要开始新的旅程吗？"
	confirm.ok_button_text="重新开摊"
	confirm.cancel_button_text="继续原来的旅程"
	confirm.add_theme_font_override("font",game.font)
	var dialog_theme=Theme.new()
	dialog_theme.default_font=game.font
	dialog_theme.default_font_size=16
	for type in ["Window","PopupPanel","AcceptDialog"]:
		dialog_theme.set_stylebox("panel",type,game._style(game.PAPER,game.INK,2))
	dialog_theme.set_color("font_color","Label",game.INK)
	for state in ["normal","hover","pressed","focus"]:
		dialog_theme.set_stylebox(state,"Button",game._style(game.TEAL if state=="hover" else game.PAPER,game.INK,2))
	dialog_theme.set_color("font_color","Button",game.INK)
	confirm.theme=dialog_theme
	confirm.confirmed.connect(restart_game)
	add_child(confirm)
	game._label(background,"一碗热面，慢慢做。",Rect2(925,685,301,26),16,Color("f8ead1"))

func enter_game()->void:
	hide()
	if game.stage<6: game.v5.begin_arrival()
	game._refresh()

func start_new()->void:
	if FileAccess.file_exists(game.save_path): confirm.popup_centered(Vector2i(430,180))
	else: restart_game()

func restart_game()->void:
	game.new_game_requested=true
	game.skip_title_once=true
	game.get_tree().reload_current_scene()
