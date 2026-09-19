extends Node
const GIFTS=[
 {"owner":"老乔","name":"旧黄铜罗盘","cell":0,"story":"指针有一点偏，却陪老乔走了七年。\n「以后不只守着公路，我也该去看一看。」"},
 {"owner":"阿岚","name":"末班车铜牌","cell":1,"story":"阿岚离开故乡时留下的最后一张车票。\n他说，真正值得留住的东西，从来不在货架上。"},
 {"owner":"阿灯","name":"旧广播徽章","cell":2,"story":"值班员制服上拆下的小徽章。\n七年后，阿灯终于又播了一条不是求救的消息。"},
 {"owner":"禾苗","name":"种子木签","cell":3,"story":"母亲刻下的嫩芽，被禾苗摸得很光滑。\n半袋种子可以给出去，春天也就有了第二个去处。"},
 {"owner":"小夏","name":"蓝花布章","cell":4,"story":"老诊所窗帘上的一朵小花，缝成了布章。\n「先让来的人吃口热的，再问来处。」"},
 {"owner":"温叔","name":"小渡船挂坠","cell":5,"story":"用修船剩下的木料刻成。\n热饭船上没有头等舱，只有每个人的一份晚饭。"}
]
const OPEN_RECT=Rect2(280,0,495,94)
const REPLIES={
 "老乔":[["那台收音机是她留下的。\n别人听见杂音，我总觉得里面\n还有一句没说完的话。","补给啊……前面那个站还有。\n只是今天，我不太想算这些。"],["好。告诉阿岚，老乔还在路上。\n你肯替我带话，就已经很好了。","我知道你是好意。\n可要是不等了，我还真不知道\n该往哪个方向走。"]],
 "阿岚":[["他还记得我？那年车陷在沙里，\n是他一铲一铲挖出来的。\n这份人情，我一直记着。","罐头能便宜一点。\n不过有些事，我不按价钱算。"],["阿灯在哨站北边，门口有天线。\n要是广播能再响起来，\n老乔也许就不用一个人等了。","那我们就先聊价钱吧。\n有些话，等想说的时候再说。"]],
 "阿灯":[["我想播：明天有雨，回家路上\n记得收衣服。越平常越好。\n别再只有失踪者的名字了。","赚不到多少。\n但信号那头要是有人应一声，\n我这晚就没白熬。"],["天气和归途……好。\n有人知道何时下雨，就敢播种；\n知道船几点来，就敢等。","广告我会留一点时间。\n可还有人等着听亲人的消息，\n不能把整晚都卖出去。"]],
 "禾苗":[["她把种子缝在外套里，\n说饿的时候也别全吃掉。\n我现在才明白那句话。","够换一阵子的罐头吧。\n可吃完以后呢？\n我想给以后留一点东西。"],["诊所要是真长出一排新芽，\n你替我摸摸第一片叶子。\n像替母亲看看。","我舍不得。\n不是舍不得价钱，\n是怕以后再没有种子了。"]],
 "小夏":[["那朵蓝花是老乔的妻子绣的。\n她说，来看病的人抬头时，\n得有点好看的东西。","有钱给一点，没钱也先看。\n人已经够难受了，\n总得有个能坐下的地方。"],["那我替夜班的大家记下了。\n忙完有热饭等着，\n连走回来的路都没那么冷。","那我恐怕得替几个病人\n先把钱垫上。\n他们也一样会饿。"]],
 "温叔":[["小夏搬诊所时带来的。\n我答应找土，拖到现在。\n人老了，承诺可不能也旧了。","夜里风大，确实多收一点。\n可送病人的那趟，我没收过。"],["说定了。你把面煮热，\n我把船开稳。\n沿岸的灯就是我们的站牌。","你的货我会送。\n但那条船上，总得给别人\n也留一点位置。"]],
 "阿砾":[["最怕把刚修好的水泵再弄坏。\n师傅说，手抖就先吃饭。\n这话听着简单，真管用。","光看账本，我一天像是\n只换了三个垫圈。\n可那后面有半条街的早饭。"],["那我明早来听你烧水。\n水声平稳，说明我没白修。\n就当是师傅之外的第二次验收。","新的当然好。\n可在下一批零件到来前，\n旧泵也得有人照顾。"]],
 "白禾":[["地图太满，看起来像一切都好了。\n我把没确认的路留白，\n好让走夜路的人知道要小心。","有人会买，但我更想让\n诊所的船和送粮的车\n拿到同一版。省得彼此等错地方。"],["一只小碗，记下了。\n老乔明天经过时会看懂。\n有人能坐下吃饭，路才算通了。","画得热闹不难。\n难的是让图上的那盏灯\n今晚真的亮着。"]]
}
var game
var panel:Panel
var description:Label
var cells=[]
var gifts:Array=[]
var pinned=false
var conversation_step=0
var conversation_ok=true
var conversation_complete=false
var alternate:Button
var guest_key=""
var awarded_this_meal=""
var pointer=Vector2(-100,-100)
var suppressed=false

func setup(g)->void:
 game=g
 game.service.cabinet_label.hide()
 panel=Panel.new();panel.position=Vector2(282,90);panel.size=Vector2(492,259)
 panel.add_theme_stylebox_override("panel",game._style(game.PAPER,game.INK,3));game.ui.add_child(panel)
 panel.z_index=40
 for i in range(12):
  var b=game._button(panel,"",Rect2(17+i%4*117,12+int(i/4)*80,107,70),show_item.bind(i),Color("d5c5a6"),12)
  var pic=TextureRect.new();pic.position=Vector2(31,3);pic.size=Vector2(44,44)
  pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  pic.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;pic.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var mat=ShaderMaterial.new();mat.shader=load("res://shaders/icon_key.gdshader");pic.material=mat
  b.add_child(pic)
  var label=game._label(b,"空格",Rect2(3,49,101,18),11);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  cells.append({"button":b,"pic":pic,"label":label})
 description=game._label(panel,"",Rect2(0,0,0,0),13);description.hide()
 panel.hide()
 var hot=game._button(game.ui,"",OPEN_RECT,func():pinned=not pinned,Color(0,0,0,0),12)
 hot.z_index=41
 for state in ["normal","hover","pressed","disabled","focus"]: hot.add_theme_stylebox_override(state,StyleBoxEmpty.new())
 hot.tooltip_text="随车背包：移入展开，点击固定"
 alternate=game._button(game.ui,"",Rect2(331,435,229,27),choose.bind(false),Color("dbceb2"),12)
 alternate.hide()
 game.scene_overlays.append(alternate)
 game.service.story_button.pressed.disconnect(game.service.story_action)
 game.service.story_button.pressed.connect(choose.bind(true))

func wants_open()->bool:
 if game.help_panel.visible or game.economy.panel.visible or game.show_layers: return false
 if game.get("fieldlife") and game.fieldlife.modal_open(): return false
 if suppressed:
  if OPEN_RECT.has_point(pointer) or panel.get_global_rect().has_point(pointer): return false
  suppressed=false
 return pinned or OPEN_RECT.has_point(pointer) or (panel.visible and panel.get_global_rect().has_point(pointer))

func _input(event:InputEvent)->void:
 if event is InputEventMouseMotion: pointer=event.position

func tick()->void:
 panel.visible=wants_open() and game.service.cabinet_amount>.72
 if panel.visible: refresh_items()
 var key=str(game.get("day"))+":"+str(game.economy.map_index)+":"+str(game.order_index)+":"+str(game.total_served)
 if key!=guest_key and game.stage<6:
  guest_key=key;conversation_step=0;conversation_ok=true;conversation_complete=false
 refresh_choices()

func refresh_items()->void:
 for i in range(12):
  cells[i].pic.texture=null
  cells[i].label.text="空格"
  if i<6 and gifts.has(GIFTS[i].owner):
   var a=AtlasTexture.new();a.atlas=load("res://assets/souvenirs.png")
   a.region=Rect2(GIFTS[i].cell%3*a.atlas.get_width()/3.0,int(GIFTS[i].cell/3)*a.atlas.get_height()/2.0,a.atlas.get_width()/3.0,a.atlas.get_height()/2.0)
   cells[i].pic.texture=a;cells[i].label.text=GIFTS[i].name
  if i==6:
   cells[i].label.text="旧电池" if game.service.journal.battery else "电池已转交" if game.service.journal.radio else "空格"
   if game.service.journal.battery and game.get("fieldlife"):
    cells[i].pic.texture=game.fieldlife.atlas(5,Rect2(0,0,.40,.65))
  if i==8 and gifts.has("拾风"):
   var a=AtlasTexture.new();a.atlas=load("res://assets/cast_barter.png")
   a.region=Rect2(0,a.atlas.get_height()/2.0,a.atlas.get_width()/4.0,a.atlas.get_height()/2.0)
   cells[i].pic.texture=a;cells[i].label.text="旧站铜鸟哨"
  if i==7:
   cells[i].label.text="半袋种子" if game.service.journal.seeds and not game.service.journal.clinic else "种子已种下" if game.service.journal.clinic else "空格"
   if game.service.journal.seeds and not game.service.journal.clinic and game.get("fieldlife"):
    cells[i].pic.texture=game.fieldlife.atlas(5,Rect2(.40,0,.6,.58))
  cells[i].button.tooltip_text=cells[i].label.text

func show_item(i:int)->void:
 if i<0 or i>=cells.size(): return
 refresh_items()
 var item_name=""
 var item_story=""
 if i<6 and gifts.has(GIFTS[i].owner):
  item_name=GIFTS[i].name
  item_story=GIFTS[i].owner+"留下的纪念\n"+GIFTS[i].story
 elif i==6:
  if game.service.journal.battery:
   item_name="旧电池"
   item_story="阿岚交给你的口信物品\n带给铁轨哨站的阿灯，让老乔重新听见广播。\n转交后会从背包中取出，用来修复广播。"
  elif game.service.journal.radio:
   description.text="旧电池已交给阿灯。\n它现在守着哨站的一盏信号灯，不再占用背包。"
  else: description.text="旧电池的位置。\n先替老乔捎句话，再为阿岚做一碗完美泡面。"
 elif i==7:
  if game.service.journal.seeds and not game.service.journal.clinic:
   item_name="半袋种子"
   item_story="禾苗托你保管\n听见天气预报后，她终于舍得把一半春天送出去。\n带给盐湖渡口的小夏；种下后，这袋种子就用完了。"
  elif game.service.journal.clinic:
   description.text="种子已交给小夏。\n诊所窗台有了第一排新芽，空袋也留在那里了。"
  else: description.text="种子的空格。\n有人在等下一场能播种的雨。"
 elif i==8 and gifts.has("拾风"):
  item_name="旧站铜鸟哨"
  item_story="拾风用它换了一碗热面\n停运前，它是车站末班车的信号。\n听说阿灯重新广播，他决定再走一趟旧站。"
 else: description.text="这里还没有纪念品。\n认真听完故事，让每样食材都煮到最佳熟度。\n有的人会留下物件，有的人会留下下一次见面的约定。"
 if item_name!="":
  description.text=item_name+"\n"+item_story
  if game.get("fieldlife"):
   game.fieldlife.show_closeup(item_name,cells[i].pic.texture,item_story)

func topics()->Array:
 match game.service.order().name:
  "老乔": return ["问起那台收音机","问路上的补给价格","答应给阿岚捎句话","劝他不必再等"]
  "阿岚": return ["先谈谈老乔的口信","先问罐头能便宜吗","问阿灯的修理铺怎么走","说自己只在意价格"]
  "阿灯": return ["问他最想播什么消息","问广播能赚多少铜片","请他先报天气和归途","请他只播商店广告"]
  "禾苗": return ["听她讲母亲留下的种子","问种子能换几罐肉","答应把春天带到诊所","劝她把种子全部卖掉"]
  "小夏": return ["问起老诊所窗台的花","问诊所收多少诊费","答应给夜班人留热饭","说只接待有钱的客人"]
  "温叔": return ["问渡船上的空花盆","先谈夜班船票价格","一起约定每周的热饭船","请他只送我的货"]
  "阿砾": return ["问第一次修井时怕什么","问今天换了多少零件","邀他明早听开水的声音","劝他只等一台新水泵"]
  "白禾": return ["问地图上为什么留白","问这张地图能卖多少","请她给餐车画一只面碗","请她把这里画得最热闹"]
 return []

func refresh_choices()->void:
 var visible=game.chatting and game.stage<6 and not game.v4.is_barter() and not game.economy.delivery_mode and not conversation_complete
 if game.get("day_cycle") and not game.day_cycle.has_customer():visible=false
 if not visible:
  game.service.story_button.hide();alternate.hide();return
 var t=topics()
 if t.size()<4:game.service.story_button.hide();alternate.hide();return
 game.service.story_button.show();alternate.show()
 game.service.story_button.text=t[conversation_step*2]
 alternate.text=t[conversation_step*2+1]

func choose(correct:bool)->void:
 if conversation_complete or not game.chatting or game.stage>=6: return
 var response=REPLIES.get(game.service.order().name,[["我听着呢。","没关系，慢慢聊。"],["谢谢你。","下回再聊吧。"]])[conversation_step][0 if correct else 1]
 if not correct: conversation_ok=false
 if conversation_step==0:
  conversation_step=1
 else:
  conversation_complete=true
  if conversation_ok:
   game._notice("你记住了他在意的事。你们又聊近了一点。")
  else: game._notice("话题停在了这里。下次见面，还可以慢慢了解。")
 game.order_label.text=response
 game.order_label.add_theme_font_size_override("font_size",14)
 if game.v5: game.v5.react(correct)
 refresh_choices()
 game._save()

func award_after_meal()->String:
 var who=game.service.order().name
 awarded_this_meal=""
 if game.service.satisfaction<100 or not conversation_complete or not conversation_ok: return ""
 if not game.get("simmer") or not game.simmer.perfect or not game.service.recipe_matches(): return ""
 # Dialogue only records the promise. A perfect meal completes this visit's exchange.
 # Story flags keep consumables and their transfers one-time, even on later visits.
 var battery_before=bool(game.service.journal.battery)
 var seeds_before=bool(game.service.journal.seeds)
 game.service.story_action()
 if who=="阿岚" and not battery_before and game.service.journal.battery:
  awarded_this_meal="旧电池"
  _receive(6,who,awarded_this_meal)
  return awarded_this_meal
 if who=="禾苗" and not seeds_before and game.service.journal.seeds:
  awarded_this_meal="半袋种子"
  _receive(7,who,awarded_this_meal)
  return awarded_this_meal
 if gifts.has(who): return ""
 if who not in ["老乔","阿灯","温叔"]: return ""
 if who=="阿灯" and not game.service.journal.radio: return ""
 if who=="温叔" and not game.service.journal.warm_route: return ""
 for i in range(GIFTS.size()):
  if GIFTS[i].owner==who:
   gifts.append(who)
   awarded_this_meal=GIFTS[i].name
   _receive(i,who,awarded_this_meal)
   return awarded_this_meal
 return ""

func _receive(slot:int,who:String,item_name:String)->void:
 game._notice(who+"留下「"+item_name+"」。已收进顶柜的随车背包。")
 show_item(slot)

func to_save()->Dictionary:
 return {"gifts":gifts,"step":conversation_step,"ok":conversation_ok,"complete":conversation_complete,"guest_key":guest_key}

func restore(data:Dictionary)->void:
 gifts=data.get("gifts",[])
 conversation_step=clampi(int(data.get("step",0)),0,1)
 conversation_ok=bool(data.get("ok",true));conversation_complete=bool(data.get("complete",false))
 guest_key=str(data.get("guest_key",""))
