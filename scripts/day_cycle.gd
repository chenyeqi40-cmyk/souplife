extends Node

enum Phase { OPEN, SERVING, CLOSED }
const REGION_GUESTS=[["老乔","禾苗","拾风","阿砾","白禾"],["阿岚","阿灯"],["小夏","温叔"]]
var game
var phase=Phase.OPEN
var visited_today:Dictionary={}
var current_guest_id=""
var day_region=0
var day_roster:Array=[]
var panel:Panel
var headline:Label
var description:Label
var primary:Button
var secondary:Button
var show_management=false
var initialized=false

func setup(g)->void:
	game=g
	panel=game._panel(game.ui,Rect2(321,171,478,230),game.PAPER);panel.z_index=32;panel.hide()
	headline=game._label(panel,"",Rect2(18,12,444,31),21)
	description=game._label(panel,"",Rect2(18,53,441,103),16)
	primary=game._button(panel,"",Rect2(18,172,213,40),_primary,game.TEAL,16)
	secondary=game._button(panel,"",Rect2(245,172,214,40),_secondary,game.PAPER,16)
	var manage=game._button(game.ui,"",Rect2(128,210,137,44),toggle_management,Color(0,0,0,0),12)
	manage.z_index=42
	for state in ["normal","hover","pressed","disabled","focus"]:manage.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	manage.tooltip_text="今天的接待进度；名单结束后收摊，休息后再开始下一天"
	initialized=true;_new_roster();_assign_guest(str(day_roster[0]))

func _new_roster()->void:
	day_region=game.economy.map_index
	day_roster=REGION_GUESTS[day_region].duplicate()

func has_customer()->bool:return initialized and phase==Phase.SERVING and current_guest_id!=""
func is_closed()->bool:return phase==Phase.CLOSED
func is_roster_complete()->bool:return not has_customer() and remaining().is_empty()
func can_manage_resources()->bool:return is_closed() and is_roster_complete()
func can_hunt()->bool:return can_manage_resources()
func can_delivery()->bool:return can_manage_resources()

func remaining(region:int=-1)->Array:
	var roster=day_roster if region<0 else REGION_GUESTS[clampi(region,0,2)]
	var result=[]
	for who in roster:
		if not visited_today.has(who):result.append(who)
	return result

func _assign_guest(who:String)->void:
	current_guest_id=who;phase=Phase.SERVING;visited_today[who]=true
	game.order_index=REGION_GUESTS[day_region].find(who)
	show_management=false

func show_next_customer(animate:bool=true)->bool:
	if is_closed() or has_customer() or (game.v5 and game.v5.busy()):return false
	if _kitchen_busy():return false
	var waiting=remaining()
	if waiting.is_empty():show_management=true;refresh();return false
	_assign_guest(str(waiting[0]))
	if game.simmer:game.simmer.reset()
	game.v4.new_guest();game._set_customer();game._refresh()
	if animate:game.v5.begin_arrival()
	game._save();return true

func finish_customer()->void:
	if not has_customer():return
	visited_today[current_guest_id]=true;current_guest_id="";phase=Phase.OPEN
	game.character.hide();game.v4.close_conversation();game.prep.clear_board()
	game.hour=minf(23.5,game.hour+1.4)
	if not remaining().is_empty():
		show_management=false
		show_next_customer(true)
	else:
		show_management=true
		game._set_customer()
		game._notice("今天似乎不会再有人来了。收拾好这一锅，就结束营业吧。")
	refresh();game._save()

func end_today()->bool:
	if is_closed():return false
	if has_customer() or not is_roster_complete() or game.service.eating or (game.v5 and game.v5.busy()):
		game._notice("先接待完今天这个区域的所有客人，再整理物资或出门。")
		return false
	if _kitchen_busy():game._notice("先收好正在做的这一碗，再收摊。");return false
	phase=Phase.CLOSED;current_guest_id="";dismiss_management()
	game.prep.clear_board();game.prep.reset_packet();game.service.restore_bowl()
	game.v4.new_guest();game.character.hide();game._set_customer();game._refresh()
	game._notice("今天营业结束了。现在可以直接去猎场、送外卖或整理物资。")
	game._save();return true

func start_next_day()->bool:
	if not can_manage_resources():return false
	if _kitchen_busy() or game.economy.delivery_mode:
		game._notice("先完成手头的备餐，再开始下一天。备好的食材可以保留。")
		return false
	if game.fieldlife and game.fieldlife.modal_open():return false
	game.day+=1;game.hour=8.;game.hydrated=false
	visited_today.clear();current_guest_id="";phase=Phase.OPEN;show_management=false;_new_roster()
	game.stage=0;game.selected.clear();game.prep.reset_packet();game.v4.new_guest()
	if game.auto_weather:game._set_weather(0)
	game.economy.panel.hide()
	var result=show_next_customer()
	game._notice("第 %d 天，开摊。今天有 %d 位客人，慢慢招呼。"%[game.day,day_roster.size()])
	game._save();return result

func on_region_changed()->void:
	# After-hours travel changes tomorrow's region, never tonight's completed roster.
	if not is_closed():return
	current_guest_id="";dismiss_management()
	game.v4.new_guest();game._set_customer();refresh()

func _kitchen_busy()->bool:
	return game.stage!=0 or not game.selected.is_empty() or game.prep.board_item>=0 or game.prep.packet_busy

func dismiss_management()->void:
	show_management=false
	if panel:panel.hide()

func toggle_management()->void:
	show_management=not show_management;refresh()

func _primary()->void:
	if is_closed():start_next_day()
	elif is_roster_complete():end_today()
	else:dismiss_management()

func _secondary()->void:
	dismiss_management()

func refresh()->void:
	if not panel:return
	var blocked=game.help_panel.visible or game.show_layers or game.economy.panel.visible or game.backpack.panel.visible
	if game.fieldlife and game.fieldlife.modal_open():blocked=true
	if game.title_screen and game.title_screen.visible:blocked=true
	panel.visible=show_management and not blocked
	if is_closed():
		headline.text="第 %d 天 · 已收摊"%game.day
		description.text="今天的 %d 位客人都已接待完。\n可以直接点击猎场入口，也可以整理物资或送外卖。\n准备好了，再亲手开始下一天。"%day_roster.size()
		primary.text="开始下一天";primary.disabled=_kitchen_busy() or game.economy.delivery_mode;secondary.text="回到房车"
	elif not is_roster_complete():
		headline.text="第 %d 天 · 接待中"%game.day
		description.text="今天共 %d 位客人，%s\n道别后，下一位会自己来到窗口。\n全部接待完，才能整理物资、出门或开始下一天。"%[day_roster.size(),"正在接待"+current_guest_id+"。" if has_customer() else "下一位正在路上。"]
		primary.text="继续接待";primary.disabled=false;secondary.text="收起安排"
	else:
		headline.text="今天似乎不会再有人来了"
		description.text="今天这个区域的客人，都已经道别离开了。\n结束营业后，就能整理物资、去猎场或送一份外卖。\n今晚不会再有人来，明天仍由你亲手开始。"
		primary.text="结束今天营业";primary.disabled=_kitchen_busy();secondary.text="再坐一会儿"
	if not has_customer():game.character.hide()

func to_save()->Dictionary:
	return {"version":2,"phase":phase,"visited_today":visited_today,"current_guest_id":current_guest_id,"day_region":day_region,"day_roster":day_roster,"show_management":show_management}

func restore(data:Dictionary)->void:
	visited_today.clear();day_region=clampi(int(data.get("day_region",game.economy.map_index)),0,2)
	day_roster=REGION_GUESTS[day_region].duplicate()
	if data.is_empty():
		var index=clampi(game.order_index,0,day_roster.size()-1)
		for i in range(index+1):visited_today[day_roster[i]]=true
		current_guest_id=str(day_roster[index]);phase=Phase.SERVING
		if game.economy.delivery_mode or not game.economy.job.is_empty():phase=Phase.CLOSED;current_guest_id=""
	else:
		for who in data.get("visited_today",{}):
			for roster in REGION_GUESTS:
				if who in roster:visited_today[str(who)]=true
		phase=clampi(int(data.get("phase",Phase.OPEN)),Phase.OPEN,Phase.CLOSED)
		current_guest_id=str(data.get("current_guest_id",""))
	if is_closed():
		# Earlier versions allowed early closing. Preserve that completed old day;
		# tomorrow uses the complete current roster rather than trapping old saves.
		current_guest_id=""
		if int(data.get("version",0))<2:
			for who in day_roster:visited_today[who]=true
		if not remaining().is_empty():phase=Phase.OPEN
	if phase==Phase.SERVING and current_guest_id in day_roster:
		visited_today[current_guest_id]=true;game.order_index=day_roster.find(current_guest_id)
	else:
		current_guest_id=""
		if not is_closed():phase=Phase.OPEN
	if phase==Phase.OPEN and not remaining().is_empty():
		_assign_guest(str(remaining()[0]));game.v4.new_guest()
	show_management=phase==Phase.OPEN and is_roster_complete()
