extends Node
# One shared timeline. Ingredients acquire cooking time only after insertion.
const TARGETS=[5,4,2,0,3,1,1,2,2,4,2,5,3,4,5,4,3]
const SECONDS_PER_CELL=4.0
const CYCLE_CELLS=5
const CYCLE_SECONDS=CYCLE_CELLS*SECONDS_PER_CELL
var game
var portions={}
var perfect=false
var elapsed=0.0
var started=false
var finished=false
var planned_cells=5
var panel:Panel
var cells=[]
var summary:Label
var hover_panel:Panel
var hover_title:Label
var hover_text:Label
var hover_cells=[]
var hovered_id=-1
var pointer=Vector2.ZERO
var rows=[] # Old saves/tests can still inspect this; no per-ingredient controls exist.

func setup(g):
	game=g
	panel=game._panel(game.ui,Rect2(348,657,214,52),Color("dedbc8"));panel.z_index=45
	summary=game._label(panel,"",Rect2(7,3,201,19),11)
	for i in range(5):
		var button=game._button(panel,"",Rect2(8+i*39,25,36,20),set_plan.bind(i+1),Color("48534f"),11)
		var fill=ColorRect.new();fill.position=Vector2(2,2);fill.size=Vector2(0,16);fill.color=Color("78b3ba");fill.mouse_filter=2;button.add_child(fill);button.move_child(fill,0)
		var number=game._label(button,str(i+1),Rect2(0,-1,36,20),11,Color("fff2d0"));number.horizontal_alignment=1
		button.disabled=true
		button.tooltip_text="固定五格：面饼和调料入锅就计时，走完自动关火盛面。"
		cells.append({"button":button,"fill":fill})
	hover_panel=game._panel(game.ui,Rect2(857,415,250,108),Color("dedbc8"));hover_panel.z_index=100;hover_panel.mouse_filter=2
	hover_title=game._label(hover_panel,"",Rect2(10,6,230,24),14)
	for i in range(5):
		var cell=game._panel(hover_panel,Rect2(11+i*44,37,39,19),Color("48534f"));cell.mouse_filter=2;hover_cells.append(cell)
		var label=game._label(cell,str(i+1),Rect2(0,-1,39,19),11,Color("f5ecd5"));label.horizontal_alignment=1
	hover_text=game._label(hover_panel,"",Rect2(10,64,232,36),11)
	hover_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	reset();hover_panel.hide()

func _input(event):
	if event is InputEventMouseMotion:pointer=event.position

func set_plan(_value:int):
	# Kept for old callers; the new stove always runs a fixed five cells.
	planned_cells=CYCLE_CELLS;refresh()

func start_cycle()->bool:
	if started or finished:return false
	if game.stage!=3 or game.prep.packet_stage!=2:return false
	elapsed=0.0;started=true;finished=false;perfect=false;planned_cells=CYCLE_CELLS
	for id in game.selected:track(int(id))
	refresh()
	return true

func target(id:int)->int:
	return TARGETS[id] if id>=0 and id<TARGETS.size() else 0

func global_units()->float:return elapsed/SECONDS_PER_CELL

func insert_at(id:int)->float:
	return maxf(0.0,float(planned_cells-target(id)))

func track(id:int):
	if id==3 or id<0 or id>=TARGETS.size() or portions.has(id):return
	if game.stage not in [3,4] or not started or finished:return
	portions[id]={"time":0.0,"added_at":elapsed,"quality":"生","lifted":false}

func units(id:int)->float:
	return float(portions.get(id,{}).get("time",0.0))/SECONDS_PER_CELL

func quality(id:int)->String:
	if not portions.has(id):return "未下锅"
	var amount=units(id);var goal=float(target(id))
	if amount<goal-.35:return "未到最佳"
	if amount<=goal+.65:return "最佳"
	return "过熟"

func tick(delta:float):
	for id in portions.keys():
		if not game.selected.has(id):portions.erase(id)
	for id in game.selected:track(int(id))
	if started and not finished and game.stage in [3,4] and not cooking_paused():
		elapsed=minf(CYCLE_SECONDS,elapsed+delta)
		for id in portions:portions[id].time=maxf(0,elapsed-float(portions[id].added_at))
		if elapsed>=CYCLE_SECONDS:game._finish_cooking_automatically()
	refresh()

func cooking_paused()->bool:
	return game.help_panel.visible or game.economy.panel.visible or game.backpack.panel.visible or game.show_layers or (game.fieldlife and game.fieldlife.modal_open()) or (game.title_screen and game.title_screen.visible)

func finalize():
	if not started or elapsed<CYCLE_SECONDS or finished:return
	finished=true
	for id in portions:
		portions[id].quality=quality(id);portions[id].lifted=true
	perfect=not portions.is_empty() and game.prep.packet_stage==2
	for id in portions:
		if portions[id].quality!="最佳":perfect=false
	if perfect:
		game.v5.guide_override="投料的时机，刚刚好！\n每样都在最佳熟度，完美出锅。";game.v5.aside_age=7;game.v4.guide_seconds=7
	refresh()

func penalty()->int:
	var result=0
	for id in portions:
		if portions[id].quality!="最佳":result+=18 if portions[id].quality=="过熟" else 25
	return result

func food_under_pointer()->int:
	if game.fieldlife and game.fieldlife.cold.visible:
		for i in range(game.fieldlife.cold_slots.size()):
			if game.fieldlife.cold_slots[i].get_global_rect().has_point(pointer):return game.fieldlife.COLD_IDS[i]
		if game.fieldlife.cold.get_global_rect().has_point(pointer):return -1
	if game.prep:
		var ready_id=game.prep.ready_item_at(pointer)
		if ready_id>=0:return ready_id
		for i in range(game.prep.BIN_IDS.size()):
			if game.prep.BIN_RECTS[i].has_point(pointer):return game.prep.BIN_IDS[i]
		for i in range(4):
			if Rect2(1104,207+i*106,157,98).has_point(pointer):return game.prep.FARM_IDS[i]
		for i in range(3):
			if Rect2(875+i*59,570,56,42).has_point(pointer):return 8+i
	return -1

func refresh():
	if not panel:return
	var blocked=game.economy.panel.visible or game.show_layers or (game.title_screen and game.title_screen.visible) or game.help_panel.visible
	panel.visible=game.stage<=4 and not blocked and not (game.fieldlife and game.fieldlife.modal_open())
	var u=global_units()
	summary.text="固定五格 · 面入锅后开始" if game.stage==0 else "烧水 / 拆面 · 计时尚未开始" if game.stage in [1,2] else "已走 %.1f / 5 格 · 自动出锅"%u
	for i in range(5):
		var cell=cells[i];var style=game._style(Color("48534f"),Color("b9dc8e") if i+1==planned_cells else Color("293d35"),3 if i+1==planned_cells else 1)
		cell.button.add_theme_stylebox_override("normal",style);cell.button.add_theme_stylebox_override("disabled",style)
		cell.button.disabled=true
		cell.fill.size.x=32*clampf(u-i,0,1)
		cell.fill.color=Color("c97963") if u>planned_cells+.65 else Color("b9dc8e") if u>=planned_cells-.18 else Color("78b3ba")
	if game.stage in [3,4]:game.hint.text="固定五格自动出锅；需要煮得久的先放，青菜晚放。"
	hovered_id=food_under_pointer()
	var hide_for_modal=game.fieldlife and (game.fieldlife.hunt.visible or game.fieldlife.closeup.visible)
	hover_panel.visible=hovered_id>=0 and game.stage<=4 and not blocked and not hide_for_modal and not game.backpack.panel.visible
	if not hover_panel.visible:return
	var id=hovered_id;var goal=target(id)
	hover_title.text=game.INGREDIENTS[id]+(" · 调味料" if id==3 else " · 最佳 %d 格"%goal)
	for i in range(5):
		hover_cells[i].visible=id!=3
		hover_cells[i].add_theme_stylebox_override("panel",game._style(Color("8ba764") if i+1==goal else Color("48534f"),Color("def0b5") if i+1==goal else Color("293d35"),2))
	hover_text.text="调味料不计熟度，也不占四种食材的位置。" if id==3 else "面下锅后立即放入，煮满五格最佳。\n绿色标出它需要在锅里煮的格数。" if goal==5 else "固定第 5 格出锅 → 第 %d 格下锅。\n绿色标出它需要在锅里煮的格数。"%int(insert_at(id))
	if game.prep.staged_food.has(id):hover_text.text+="\n右键可收回库存。"
	hover_text.size.y=52
	hover_panel.size.y=124 if game.prep.staged_food.has(id) else 108
	var source=game.prep.source_rect(id)
	if game.fieldlife.cold.visible and id>=11:
		var cold_index=game.fieldlife.COLD_IDS.find(id)
		if cold_index>=0:source=game.fieldlife.cold_slots[cold_index].get_global_rect()
	elif game.prep.staged_food.has(id):source=game.prep.ready_rect(id)
	var x=clampf(pointer.x-125,10,1020);var y=source.position.y-hover_panel.size.y-8
	if pointer.x>1090:x=825
	if y<115:y=source.end.y+8
	hover_panel.position=Vector2(x,clampf(y,110,585))

func reset():
	portions.clear();perfect=false;elapsed=0;started=false;finished=false
	planned_cells=CYCLE_CELLS
	refresh()

func to_save()->Dictionary:
	return {"version":3,"portions":portions,"perfect":perfect,"elapsed":elapsed,"started":started,"finished":finished,"planned":CYCLE_CELLS}

func restore(data:Dictionary):
	portions.clear();perfect=bool(data.get("perfect",false));elapsed=maxf(0,float(data.get("elapsed",0)))
	started=bool(data.get("started",game.stage in [3,4,5,6]));finished=bool(data.get("finished",game.stage>=5));planned_cells=CYCLE_CELLS
	if game.stage in [3,4] and game.prep.packet_stage==2:started=true;finished=false
	for key in data.get("portions",{}):
		var id=int(key)
		if id<0 or id>=TARGETS.size() or id==3:continue
		var old=data.portions[key]
		if int(data.get("version",0))<2:elapsed=maxf(elapsed,float(old.get("time",0)))
		portions[id]={"time":float(old.get("time",0)),"added_at":float(old.get("added_at",0)),"quality":str(old.get("quality","生")),"lifted":finished}
	if int(data.get("version",0))<2:
		for id in portions:portions[id].added_at=elapsed-float(portions[id].time)
		# Before the fire, previous versions stored ingredients in an unheated pot.
		# Put those portions on the prep board and restore their one reserved stock unit.
		if game.stage<3:
			var old_selected=game.selected.duplicate()
			game.selected.clear()
			for id in old_selected:
				game.prep.stock[int(id)]+=1;game.prep.prepare_food(int(id),true,true)
			portions.clear();elapsed=0;started=false
	elapsed=minf(CYCLE_SECONDS,elapsed)
	refresh()
