extends Node

# The lesson follows actual kitchen state. It never consumes ingredients,
# changes the order, advances cooking time, or grants a reward for the player.
enum Lesson { WELCOME, ORDER, MEAT, CUT, ADD_MEAT, SIDES, FIRE, WATER, TEAR, DROP, DONENESS, FINISH, SERVE, EAT, REVIEW, COMPLETE }
const ROBOT=Rect2(116,102,164,156)
const POT=Rect2(345,475,211,188)
const BOARD=Rect2(570,537,251,127)
const PACKET=Rect2(214,541,113,126)
const COUNTER_BOWL=Rect2(568,484,259,184)
const GUEST=Rect2(568,173,373,303)
var game
var active=true
var completed=false
var step=Lesson.WELCOME
var lesson_age=0.0
var initial_served=0
var recipe:Array=[]
var order_name=""
var meat_id=-1
var overlay:Control
var curtain:FocusCurtain
var bubble:Panel
var speaker:Label
var words:Label
var step_label:Label
var next_button:Button
var skip_button:Button
var action_panel:Panel
var action_label:Label
var last_step=-1

class FocusCurtain extends Control:
	var focus=Rect2(116,102,164,156)
	var accent=Rect2()
	var pulse=0.0
	var robot=Rect2(116,102,164,156)
	func _draw()->void:
		# Partition the screen around both holes: the chosen prop and the robot
		# keep the scene's original light instead of being repainted brighter.
		var holes=[focus,robot]
		if accent.size.x>0:holes.append(accent)
		var xs=[0.0,1280.0]
		var ys=[0.0,800.0]
		for hole in holes:
			xs.append(clampf(hole.position.x,0,1280));xs.append(clampf(hole.end.x,0,1280))
			ys.append(clampf(hole.position.y,0,800));ys.append(clampf(hole.end.y,0,800))
		xs.sort();ys.sort()
		for x in range(xs.size()-1):
			for y in range(ys.size()-1):
				var rect=Rect2(xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y])
				var is_hole=false
				for hole in holes:
					if hole.has_point(rect.get_center()):is_hole=true
				if not is_hole:draw_rect(rect,Color(.06,.09,.10,.66))
		var color=Color("eadba2");color.a=.75+.2*sin(pulse*3)
		draw_rect(focus.grow(3),color,false,2)
		# Corner marks read cleanly at the game's nearest-neighbour scale.
		for corner in [focus.position,Vector2(focus.end.x,focus.position.y),focus.end,Vector2(focus.position.x,focus.end.y)]:
			draw_rect(Rect2(corner-Vector2(3,3),Vector2(6,6)),Color("efe8c9"))
		if accent.size.x>0:draw_rect(accent.grow(2),Color("bde39b"),false,3)

func setup(g)->void:
	game=g
	active=not game.qa_mode
	completed=game.qa_mode
	initial_served=game.total_served
	overlay=Control.new();overlay.name="RobotFirstMealLesson"
	overlay.size=Vector2(1280,800);overlay.z_index=120
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.ui.add_child(overlay)
	curtain=FocusCurtain.new();curtain.size=overlay.size
	curtain.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(curtain)
	bubble=game._panel(overlay,Rect2(28,277,270,260),game.PAPER)
	bubble.set("speech_tip",true)
	bubble.mouse_filter=Control.MOUSE_FILTER_IGNORE
	speaker=game._label(bubble,"小满 / 今天我陪你开摊",Rect2(13,6,244,25),15)
	words=game._label(bubble,"",Rect2(13,41,244,132),15)
	words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	step_label=game._label(bubble,"",Rect2(13,224,244,18),11,Color("626a59"))
	next_button=game._button(bubble,"好，开摊",Rect2(13,183,244,31),advance_text,game.TEAL,14)
	skip_button=game._button(overlay,"跳过教学",Rect2(1120,22,133,34),skip,game.PAPER,14)
	skip_button.tooltip_text="保留当前这一碗和所有物品；可在帮助中重新教学。"
	action_panel=game._panel(overlay,Rect2(588,465,286,40),Color("e4dfc8"))
	action_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	action_label=game._label(action_panel,"",Rect2(9,6,268,27),13)
	action_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	overlay.hide()

func _capture_order()->void:
	recipe=game.service.order().need.duplicate()
	order_name=str(game.service.order().name)
	meat_id=-1
	for id in recipe:
		if int(id) in [0,4,11,14]:meat_id=int(id);break

func restart()->void:
	# Replaying explains the current bowl without resetting the player's meal.
	active=true;completed=false;step=Lesson.WELCOME;lesson_age=0;last_step=-1
	initial_served=game.total_served
	_capture_order()
	game._save()

func skip()->void:
	active=false;completed=true
	overlay.hide()
	game._notice("教学已收起，慢慢做就好。需要时可以在帮助里重新教学。")
	game._save()

func advance_text()->void:
	if not active:return
	if step==Lesson.WELCOME:
		_capture_order()
		if game.stage==0:game.v4.open_conversation()
		_enter(Lesson.ORDER)
	elif step==Lesson.ORDER:
		game.v4.close_conversation()
		_enter(Lesson.MEAT)
	elif step==Lesson.COMPLETE:
		active=false;completed=true;overlay.hide();game._save()

func _enter(value:int)->void:
	if step==value:return
	step=value;lesson_age=0;last_step=-1
	game._save()

func _suspended()->bool:
	if not active:return true
	if game.title_screen and game.title_screen.visible:return true
	if game.v5 and game.v5.busy():return true
	if game.fieldlife and game.fieldlife.modal_open():return true
	if game.economy.panel.visible or game.backpack.panel.visible or game.help_panel.visible or game.show_layers:return true
	# A received memento takes precedence over teaching; the module works with
	# the optional closeup service without requiring a particular node name.
	if game.backpack.has_method("closeup_open") and game.backpack.closeup_open():return true
	return false

func tick(delta:float)->void:
	if not overlay:return
	if _suspended():overlay.hide();return
	if recipe.is_empty():_capture_order()
	lesson_age+=delta
	_update_step()
	if not active:overlay.hide();return
	# During the perfect-bowl praise, leave the existing robot bubble fully
	# visible; resume the tutorial only when that short line finishes.
	if game.simmer and game.simmer.perfect and game.v4.guide_seconds>0 and game.stage==5:
		overlay.hide();return
	overlay.show()
	if game.service.guide_panel:game.service.guide_panel.hide()
	_render_lesson()
	curtain.pulse+=delta;curtain.queue_redraw()

func _update_step()->void:
	if step in [Lesson.WELCOME,Lesson.ORDER,Lesson.COMPLETE]:return
	if game.total_served>initial_served and game.stage!=6:
		_enter(Lesson.COMPLETE);return
	if game.stage==6:
		if game.v4.farewell_done:_enter(Lesson.COMPLETE)
		elif game.service.eating:_enter(Lesson.EAT)
		else:_enter(Lesson.REVIEW)
		return
	if game.stage==5:_enter(Lesson.SERVE);return
	if game.stage in [3,4]:
		_enter(Lesson.FINISH if game.stage==4 else Lesson.DONENESS)
		return
	if game.stage==2:
		_enter(Lesson.DROP if game.prep.packet_stage==1 else Lesson.TEAR);return
	if game.stage==1:_enter(Lesson.WATER);return
	# Recover coherently if the player resets or changes ingredients mid-lesson.
	if meat_id>=0 and not game.selected.has(meat_id) and not game.prep.staged_food.has(meat_id):
		if game.prep.board_item>=0:_enter(Lesson.ADD_MEAT if game.prep.cuts>=3 else Lesson.CUT)
		else:_enter(Lesson.MEAT)
		return
	var missing=_missing_side()
	if missing>=0:_enter(Lesson.SIDES)
	else:_enter(Lesson.FIRE)

func _missing_side()->int:
	for id in recipe:
		if int(id)!=meat_id and not game.selected.has(int(id)) and not game.prep.staged_food.has(int(id)):return int(id)
	return -1

func _food_rect(id:int)->Rect2:
	if game.prep.staged_food.has(id):return game.prep.ready_rect(id).grow(5)
	for i in range(game.prep.BIN_IDS.size()):
		if id==game.prep.BIN_IDS[i]:return game.prep.BIN_RECTS[i].grow(8)
	for i in range(game.prep.FARM_IDS.size()):
		if id==game.prep.FARM_IDS[i]:return Rect2(1099,202+i*106,163,88)
	if id>=11:return Rect2(18,450,210,251)
	if id>=8:return Rect2(872+(id-8)*59,568,61,48)
	return POT

func _next_portion()->int:
	var chosen=-1
	var largest=-1
	# Long-cooking food comes first because the noodle drop starts the clock.
	for key in recipe:
		var id=int(key)
		if game.selected.has(id):continue
		var target=game.simmer.target(id)
		if target>largest:largest=target;chosen=id
	return chosen

func _set_focus(rect:Rect2,caption:String,accent:Rect2=Rect2())->void:
	curtain.focus=rect;curtain.accent=accent
	action_panel.visible=caption!=""
	action_label.text=caption
	var width=286.0
	var x=clampf(rect.get_center().x-width*.5,310,964)
	var y=rect.end.y+11
	if y+48>708:y=rect.position.y-51
	if rect.position.x<310:x=rect.end.x+13;y=maxf(485,rect.position.y)
	action_panel.position=Vector2(x,clampf(y,20,736))
	action_panel.size=Vector2(width,40)

func _render_lesson()->void:
	bubble.position=Vector2(28,277)
	next_button.visible=step in [Lesson.WELCOME,Lesson.ORDER,Lesson.COMPLETE]
	step_label.text="第一碗 / %02d · 可随时跳过"%mini(step+1,16)
	match step:
		Lesson.WELCOME:
			words.text="我是小满，车上的小助手。\n今天先一起做一碗热面。\n客人会等你；下锅后，记得照看每样食材的火候。"
			next_button.text="好，开摊"
			_set_focus(ROBOT,"")
		Lesson.ORDER:
			words.text=order_name+"已经点好餐了。\n先读读他的要求，再准备食材。\n对话可以慢慢聊，没有耐心倒计时。"
			next_button.text="记住了，开始准备"
			_set_focus(Rect2(318,158,257,311),"先看点单；调味料不占四个食材位")
		Lesson.MEAT:
			var name=game.INGREDIENTS[meat_id] if meat_id>=0 else "食材"
			words.text="先取整块"+name+"。\n点击它，或按住拖到砧板。\n我们切好后再下锅。"
			_set_focus(_food_rect(meat_id),"点击肉块，或拖到中间砧板")
		Lesson.CUT:
			words.text="点砧板上的肉，切三刀。\n每一刀都会留下切开的变化。\n已经切了 %d / 3 刀。"%game.prep.cuts
			_set_focus(BOARD,"点击肉块切一刀 · %d / 3"%game.prep.cuts)
		Lesson.ADD_MEAT:
			words.text="肉已经切好了。\n再点一下，把肉片备妥。\n先留在砧板，等面下锅后再按时间投入。"
			_set_focus(BOARD,"再点切好的肉片 · 先备妥")
		Lesson.SIDES:
			var id=_missing_side()
			var name=game.INGREDIENTS[id] if id>=0 else "配料"
			words.text="接下来备好"+name+"。\n点击取用，或拖到砧板。\n先不下锅。悬停看它需要煮几格；辣油不计熟度。"
			if id in game.prep.FARM_IDS:words.text="接下来采"+name+"。\n点击培养皿，菜会飞到砧板。\n采完浇一次水就会再长。切肉时，菜会挪到旁边。"
			_set_focus(_food_rect(id),"取用"+name+" · 先放砧板备好")
		Lesson.FIRE:
			words.text="备料齐了。每锅固定煮五格。\n面饼和调料入锅就开始计时，走完自动关火盛面。\n先点锅烧水。"
			_set_focus(POT,"固定五格 · 不能改终点，也不需手动关火",Rect2(348,657,214,52))
		Lesson.WATER:
			words.text="听，水慢慢热起来了。\n等水开，再拆桌上的面袋。\n这会儿可以看一看锅里的清水。"
			_set_focus(POT,"等水烧开 · 不用连续点击")
		Lesson.TEAR:
			words.text="水开了。\n就用桌上这袋面，点一下撕开。\n先听包装袋沙沙响，再把面下锅。"
			_set_focus(PACKET,"点击桌上面袋，撕开封口")
		Lesson.DROP:
			var first=_next_portion()
			words.text="再点一次，面饼和调料落进锅里，五格计时就开始了。\n"+("面一下锅，马上放备好的"+game.INGREDIENTS[first]+"。" if first>=0 and game.simmer.target(first)==5 else "看好食材的投料时机，晚熟的先放。")+"\n不用等第一样配菜。"
			_set_focus(Rect2(520,446,130,170),"面与调料入锅即计时 · 备好后再点",_food_rect(first) if first>=0 else Rect2())
		Lesson.DONENESS:
			var id=_next_portion()
			var clock=Rect2(348,657,214,52)
			if id<0:
				words.text="食材都下锅了。\n它们在锅里待的时间不同，却能一起做好。\n五格走完会自动关火，把面留在我们台面上。"
				_set_focus(clock,"五格自动出锅 · 不用再点锅",POT)
			else:
				var name=game.INGREDIENTS[id]
				var at=game.simmer.insert_at(id)
				var now=game.simmer.global_units()
				if id==3:words.text="再放"+name+"。\n它是调味料，不占食材位，也不计熟度。\n本锅会照常走完五格。"
				elif now<at-.10:words.text="%s只需煮 %d 格，先别急。\n固定第 5 格出锅，所以等时间条到第 %d 格再放。\n现在已走 %.1f 格。"%[name,game.simmer.target(id),int(at),now]
				else:words.text="现在放%s。\n点击它，或拖进锅。\n配菜从入锅这一刻计算熟度，第五格会和面一起自动盛出。"%name
				_set_focus(_food_rect(id),"%s · 第 %d 格投入 · 最佳 %d 格"%[name,int(at),game.simmer.target(id)] if id!=3 else "点调味料下锅 · 不改变五格计时",clock)
			action_panel.position=Vector2(587,668)
		Lesson.FINISH:
			words.text="五格已经走完了。\n灶台会自动关火，把面盛好。\n每样配菜都达到最佳熟度，就会出现完美火候。"
			_set_focus(POT,"自动关火盛面 · 等成品放上台面")
		Lesson.SERVE:
			words.text="热面在我们自己的台面上。\n点击成品碗，或把它拖到客人面前。\n也能点下方「端到窗口长板」。"
			_set_focus(COUNTER_BOWL,"点击成品碗，或拖给客人")
		Lesson.EAT:
			words.text="让他先吃一口。\n碗放在窗口长板上，吃完才会说出感受。\n我也想尝尝……可惜我只有电源接口。"
			_set_focus(GUEST,"等客人吃完这一口")
		Lesson.REVIEW:
			words.text="听听他的评价，也听听他接下来想说的话。\n最后点「谢谢，下次见」，这段对话就结束了。"
			_set_focus(Rect2(318,158,257,311),"回应评价，再向客人道别")
		Lesson.COMPLETE:
			words.text="第一碗，完成。\n下次可以试试种菜、走访商店，或去猎场找新的食材。\n路再长，也先好好吃饭。"
			next_button.text="交给我吧"
			_set_focus(ROBOT,"")
	var bottom=load("res://scripts/speech_layout.gd").fit(bubble,words,41,244,65 if next_button.visible else 28)
	speaker.size.x=bubble.size.x-26
	next_button.position=Vector2(13,bottom+9);next_button.size.x=bubble.size.x-26
	step_label.position=Vector2(13,bottom+(49 if next_button.visible else 9));step_label.size.x=bubble.size.x-26
	last_step=step

func to_save()->Dictionary:
	return {"version":3,"active":active,"completed":completed,"step":step,"initial_served":initial_served,"recipe":recipe,"order_name":order_name,"meat_id":meat_id}

func restore(data:Dictionary)->void:
	# An older save has already been played. Avoid dropping a new tutorial
	# over an existing meal; the Help action can explicitly replay it.
	if data.is_empty():
		active=false;completed=true;step=Lesson.COMPLETE
		overlay.hide();return
	active=bool(data.get("active",false)) and not game.qa_mode
	completed=bool(data.get("completed",true)) or game.qa_mode
	step=clampi(int(data.get("step",0)),Lesson.WELCOME,Lesson.COMPLETE)
	initial_served=maxi(0,int(data.get("initial_served",game.total_served)))
	recipe=[]
	for id in data.get("recipe",[]):
		if int(id)>=0 and int(id)<game.INGREDIENTS.size():recipe.append(int(id))
	order_name=str(data.get("order_name",""))
	meat_id=int(data.get("meat_id",-1))
	if meat_id not in [-1,0,4,11,14]:meat_id=-1
	lesson_age=0;last_step=-1;overlay.hide()
