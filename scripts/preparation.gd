extends Node
# Screen positions are converted to independent, lit 3D paper meshes.
const FARM_IDS = [6,2,7,5]
const FARM_NAMES = ["香菜","卷心菜","菠菜","小葱"]
const BOARD = Rect2(574,542,243,111)
const POT = Rect2(357,483,183,157)
const BIN_RECTS = [Rect2(870,531,53,34),Rect2(927,531,52,34),Rect2(985,532,52,34),Rect2(889,626,195,50)]
const BIN_IDS = [0,4,3,1]
const MEAT_IDS=[0,4,11,14,15,16]
const FLAVORS=["牛肉","海鲜","蔬菜"]
var game
var cooking_fx
var flavor=0
var flavor_buttons=[]
var flavor_panel:Control
var authored_meshes = {}
var stock = [4,8,0,8,4,0,0,0,2,0,0,0,0,0,0,0,0]
var farm_water = [1,1,1,1]
var farm_growth = [1.0,1.0,1.0,1.0]
var water_store = 8
var board_item = -1
var cuts = 0
var dragging = -1
var drag_from_board = false
var board_pressed = false
var down_position = Vector2.ZERO
var knife_time = 0.0
var knife_base_y = 0.0
var packet_stage = 0 # 0 sealed, 1 open, 2 empty
var packet_busy = false
var animation_token = 0
var board_meat: MeshInstance3D
var knife: MeshInstance3D
var ghost: MeshInstance3D
var slices: Array = []
var bin_meshes: Array = []
var plant_meshes: Array = []
var plant_buttons: Array = []
var harvest_buttons: Array = []
var bin_labels: Array = []
var prep_label: Label
var add_button: Button
var packet: MeshInstance3D
var packet_top: MeshInstance3D
var noodle: MeshInstance3D
var seasoning: MeshInstance3D
var water_label: Label
var action_mark: Label
var tweens: Array = []
var water_fx = [0.0,0.0,0.0,0.0]
var staged_food:Array = []
var ready_meshes:Dictionary = {}
var ready_rects:Dictionary = {}
var ready_points:Dictionary = {}
var ready_flights:Dictionary = {}
const READY_SIZE=Vector2(74,58)

# Prepared portions are reserved visually, but stock is charged only when
# main._select actually puts them in the pot. A bowl reset preserves them.
func prepare_food(id:int,prepared:bool=false,quiet:bool=false)->bool:
	if id<0 or id>=stock.size() or game.stage>4:return false
	if staged_food.has(id):game._notice("这份已经在砧板备好了；开锅后再按时放入。");return false
	if game.selected.has(id):game._notice("锅里已经有这种食材了。");return false
	if stock[id]<=0:game._notice("这种食材用完了，先去采收或补货。");return false
	if id in MEAT_IDS and not prepared:
		game._notice("整块肉先放上砧板，切三刀再备好。");return false
	if staged_food.size()>=6:game._notice("砧板边已备好六份，先用掉一些再备料。");return false
	staged_food.append(id)
	var rect=Rect2(Vector2.ZERO,READY_SIZE)
	var mesh:MeshInstance3D
	if id in FARM_IDS:
		mesh=leaf_sprite("PreparedVegetable"+str(id),id,rect,1.78)
	elif id in [11,14,15,16]:
		mesh=cut_meat_sprite("PreparedFood"+str(id),id,rect,1.78)
	elif id in [0,4,1]:
		mesh=_sprite("PreparedFood"+str(id),"prep_atlas.png",2 if id==1 else 4 if id==4 else 3,2,rect,1.78)
	elif id in [10,12,13]:
		mesh=_sprite("PreparedFood"+str(id),"regional_food.png" if id==12 else "wildlife.png",1 if id==12 else 4,1 if id==12 else 2,rect,1.78)
		mesh.material_override.set_shader_parameter("magenta_key",true)
	elif id>=8:
		mesh=_sprite("PreparedFood"+str(id),"regional_food.png",id-8,1,rect,1.78)
		mesh.material_override.set_shader_parameter("magenta_key",true)
	else:mesh=_sprite("PreparedFood"+str(id),"ingredients.png",id,2,rect,1.78)
	ready_meshes[id]=mesh
	ready_points[id]=ready_destination(staged_food.size()-1)
	refresh_ready(true)
	if not quiet:
		game._notice(game.INGREDIENTS[id]+"备好了。悬停看最佳熟度，开锅后再投料。")
		game._save()
	return true

func ready_destination(index:int)->Vector2:
	# Cutting meat clears the centre of the board. Prepared food slides onto
	# its rear edge and comes back when the knife is put away.
	if board_item>=0:return Vector2(586+index*42,518)
	return Vector2(614+(index%3)*79,569+int(index/3)*54)

func refresh_ready(snap:bool=false)->void:
	for i in range(staged_food.size()):
		var id=int(staged_food[i]);var mesh=ready_meshes.get(id)
		if not is_instance_valid(mesh):continue
		var scale_value=.68 if board_item>=0 else 1.0
		mesh.scale=Vector3(scale_value,scale_value,1)
		if snap and not ready_flights.has(id):ready_points[id]=ready_destination(i)
		var point=ready_points.get(id,ready_destination(i))
		_place(mesh,point,1.78)
		ready_rects[id]=Rect2(point-READY_SIZE*scale_value*.5,READY_SIZE*scale_value)
		mesh.visible=game.stage<=4 and not (id==1 and egg_pending())

func ready_item_at(point:Vector2)->int:
	for id in staged_food:
		if ready_rects.has(id) and ready_rects[id].has_point(point):return int(id)
	return -1

func ready_rect(id:int)->Rect2:
	return ready_rects.get(id,Rect2())

func put_ready_in_pot(id:int)->bool:
	if not staged_food.has(id):return false
	if game.stage not in [3,4]:
		game._notice("先点火烧水、拆面下锅，再按时间放入备好的食材。");return false
	return game._select(id,true)

func source_rect(id:int)->Rect2:
	if id in BIN_IDS:return BIN_RECTS[BIN_IDS.find(id)]
	if id in FARM_IDS:return Rect2(1104,207+FARM_IDS.find(id)*106,157,98)
	if id>=11:return Rect2(12,488,212,174)
	if id>=8:return Rect2(875+(id-8)*59,570,56,42)
	return Rect2()

func return_prepared(id:int)->void:
	if not staged_food.has(id):return
	if id==1 and cooking_fx:cooking_fx.cancel_egg()
	on_added_to_pot(id)
	game._notice(game.INGREDIENTS[id]+"收回库存了，数量没有减少。")
	refresh();game._save()

func on_added_to_pot(id:int)->void:
	staged_food.erase(id)
	if ready_meshes.has(id):
		ready_meshes[id].queue_free();ready_meshes.erase(id)
	ready_rects.erase(id);ready_points.erase(id);ready_flights.erase(id)
	refresh_ready()

func setup(owner_game) -> void:
	game = owner_game
	if ResourceLoader.exists("res://assets/prep_layers.glb"):
		var source=load("res://assets/prep_layers.glb").instantiate()
		for node in source.find_children("*","MeshInstance3D",true,false):
			var mesh=node.mesh.duplicate()
			for surface in range(mesh.get_surface_count()): mesh.surface_set_material(surface,null)
			authored_meshes[str(node.name)]=mesh
		source.free()
	# Reuse four complete drawers from the new reference via source UV rectangles.
	for i in range(4):
		var y=211+i*106
		var plant=reference_piece("OriginalGrowingDrawer"+str(i),Rect2(1096,y-4,169,106),farm_source(i),1.12)
		plant.material_override.set_shader_parameter("plant",true)
		plant_meshes.append(plant)
		var b=game._button(game.ui,"",Rect2(1108,y+76,144,21),plant_action.bind(i),Color("b3d1b9"),10)
		plant_buttons.append(b)
		game.scene_overlays.append(b)
	for i in range(4):
		var rect = BIN_RECTS[i]
		var id = BIN_IDS[i]
		if id == 1:
			for n in range(4): bin_meshes.append(_sprite("RawEgg"+str(n),"prep_atlas.png",2,2,Rect2(rect.position.x+6+n*40,rect.position.y-2,42,40),1.25))
		else:
			bin_meshes.append(_sprite("TrayFood"+str(id),"ingredients.png" if id==3 else "prep_atlas.png",3 if id==3 else (0 if id==0 else 1),2,Rect2(rect.position.x-2,rect.position.y-7,59,43),1.25))
		var label = game._label(game.ui,"",Rect2(rect.position.x-3,rect.end.y+1,rect.size.x+6,17),10,Color("f9e7c8"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_shadow_color",Color("273633"))
		label.add_theme_constant_override("shadow_outline_size",4)
		bin_labels.append(label)
		game.scene_overlays.append(label)
	board_meat = _sprite("CuttingBoardWholeMeat","prep_atlas.png",0,2,Rect2(595,550,166,94),1.4)
	board_meat.hide()
	for i in range(3):
		var piece = _sprite("CutSlice"+str(i),"prep_atlas.png",3,2,Rect2(714+i*19,566+i*10,74,65),1.46+i*.01)
		piece.hide()
		slices.append(piece)
	knife = _sprite("WorkingCleaver","prep_atlas.png",5,2,Rect2(650,495,147,132),1.7)
	knife.hide()
	ghost = _sprite("DraggedWholeMeat","prep_atlas.png",0,2,Rect2(0,0,152,100),2.7)
	ghost.hide()
	packet=reference_piece("OriginalPacketBody",Rect2(220,556,98,105),Rect2(220.0/1280,556.0/714,98.0/1280,105.0/714),1.8)
	packet.material_override.set_shader_parameter("packet",true)
	packet_top=reference_piece("OriginalPacketSeam",Rect2(220,552,98,15),Rect2(220.0/1280,552.0/714,98.0/1280,15.0/714),1.9)
	noodle = _sprite("FallingNoodleBrick","farm_packet.png",6,3,Rect2(340,392,116,101),2.0)
	seasoning = _sprite("FallingSeasoningSachet","farm_packet.png",7,3,Rect2(394,417,61,72),2.05)
	for m in [packet,packet_top,noodle,seasoning]: m.hide()
	prep_label = game._label(game.ui,"整块肉 → 拖到砧板 → 点击切三刀",Rect2(244,724,515,26),17,game.PAPER)
	add_button = game._button(game.ui,"",Rect2(244,755,255,31),commit_board,game.TEAL,14)
	water_label = game._label(game.ui,"",Rect2(514,758,246,28),13,Color("bfceb9"))
	action_mark = game._label(game.ui,"",Rect2(581,506,235,32),14,Color("fff1cd"))
	action_mark.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	action_mark.add_theme_color_override("font_shadow_color",Color("293832"))
	action_mark.add_theme_constant_override("shadow_outline_size",5)
	game.scene_overlays.append(action_mark)
	cooking_fx=load("res://scripts/cooking_fx.gd").new();game.ui.add_child(cooking_fx);cooking_fx.setup(game)
	flavor_panel=Control.new();flavor_panel.position=Vector2(224,658);flavor_panel.size=Vector2(115,47);game.ui.add_child(flavor_panel)
	game._label(flavor_panel,"汤底",Rect2(0,0,115,19),11,game.PAPER)
	for i in range(3):
		var b=game._button(flavor_panel,FLAVORS[i],Rect2(i*38,22,37,24),choose_flavor.bind(i),game.PAPER,11)
		b.tooltip_text=["浓香牛肉汤","奶白海鲜汤","橙色蔬菜汤"][i];flavor_buttons.append(b)
	refresh()

func choose_flavor(value:int)->void:
	if packet_stage==2 or packet_busy or game.stage>=3:return
	flavor=clampi(value,0,2);refresh();game._save()
	game._notice(FLAVORS[flavor]+"口味，面和调料下锅后汤底会变色。")

func egg_pending()->bool:
	return cooking_fx and cooking_fx.egg_active and not cooking_fx.egg_landed

func _sprite(node_name: String, file: String, cell: int, rows: int, rect: Rect2, depth: float, inner: Rect2=Rect2(0,0,1,1)) -> MeshInstance3D:
	var mat = game._paper_material(file)
	mat.set_shader_parameter("alpha_cut",.65)
	var local = Rect2(785-rect.size.x*1.2265625/2,437.5-rect.size.y*1.2265625/2,rect.size.x*1.2265625,rect.size.y*1.2265625)
	var uv = Rect2((cell%3+inner.position.x)/3.0,(int(cell/3)+inner.position.y)/float(rows),inner.size.x/3.0,inner.size.y/float(rows))
	var m = game._quad(node_name,local,0,mat,uv)
	if authored_meshes.has(node_name): m.mesh=authored_meshes[node_name]
	_place(m,rect.get_center(),depth)
	return m

func leaf_sprite(node_name:String,id:int,rect:Rect2,depth:float)->MeshInstance3D:
	var index=FARM_IDS.find(id)
	if index<0:index=0
	var mat=game._paper_material("harvest_leaves.png")
	mat.set_shader_parameter("magenta_key",true)
	mat.set_shader_parameter("alpha_cut",.65)
	var local=Rect2(785-rect.size.x*1.2265625/2,437.5-rect.size.y*1.2265625/2,rect.size.x*1.2265625,rect.size.y*1.2265625)
	var mesh=game._quad(node_name,local,0,mat,Rect2(float(index)/4.0,0,.25,1))
	_place(mesh,rect.get_center(),depth)
	return mesh

func whole_lizard_sprite(node_name:String,id:int,rect:Rect2,depth:float)->MeshInstance3D:
	var mat=game._paper_material("lizard_meat.png")
	mat.set_shader_parameter("magenta_key",true)
	var local=Rect2(785-rect.size.x*1.2265625/2,437.5-rect.size.y*1.2265625/2,rect.size.x*1.2265625,rect.size.y*1.2265625)
	var mesh=game._quad(node_name,local,0,mat,Rect2(.5 if id in [14,16] else 0.0,0,.5,1))
	_place(mesh,rect.get_center(),depth)
	return mesh

func apply_leaf_art(mesh:MeshInstance3D,id:int)->void:
	# Authored bowl vertices already contain the correct perspective and position.
	# Replace only their UVs, including the older six-topping authored scene.
	var index=FARM_IDS.find(id)
	if index<0:return
	var remapped=ArrayMesh.new()
	for surface in range(mesh.mesh.get_surface_count()):
		var arrays=mesh.mesh.surface_get_arrays(surface).duplicate(true)
		var uvs=arrays[Mesh.ARRAY_TEX_UV]
		var lo=Vector2(INF,INF);var hi=Vector2(-INF,-INF)
		for uv in uvs:lo=lo.min(uv);hi=hi.max(uv)
		var span=hi-lo
		for i in range(uvs.size()):
			var local=(uvs[i]-lo)/span
			uvs[i]=Vector2((float(index)+local.x)/4.0,local.y)
		arrays[Mesh.ARRAY_TEX_UV]=uvs
		remapped.add_surface_from_arrays(mesh.mesh.surface_get_primitive_type(surface),arrays)
	mesh.mesh=remapped
	var mat=mesh.material_override
	mat.set_shader_parameter("art",load("res://assets/harvest_leaves.png"))
	mat.set_shader_parameter("magenta_key",true)
	mat.set_shader_parameter("tile_override",false)
	mat.set_shader_parameter("frame_override",false)

func enlarge_bowl_toppings()->void:
	for mesh in game.toppings:
		if mesh.has_meta("large_bowl_portion"):continue
		var old_bounds=mesh.mesh.get_aabb();var center=old_bounds.get_center()
		var size=old_bounds.size*1.32
		var world_center=center+mesh.position
		var pixel_center=Vector2((world_center.x*100+785)/1.2265625,(437.5-world_center.y*100)/1.2265625)
		var half=Vector2(size.x,size.y)*100/1.2265625*.5
		var fitted=Vector2(clampf(pixel_center.x,593+half.x,794-half.x),clampf(pixel_center.y,519+half.y,611-half.y))
		var offset=Vector3((fitted.x-pixel_center.x)*.012265625,-(fitted.y-pixel_center.y)*.012265625,0)
		var enlarged=ArrayMesh.new()
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays=mesh.mesh.surface_get_arrays(surface).duplicate(true)
			var vertices=arrays[Mesh.ARRAY_VERTEX]
			for i in range(vertices.size()):vertices[i]=center+(vertices[i]-center)*Vector3(1.32,1.32,1)+offset
			arrays[Mesh.ARRAY_VERTEX]=vertices
			enlarged.add_surface_from_arrays(mesh.mesh.surface_get_primitive_type(surface),arrays)
		mesh.mesh=enlarged;mesh.set_meta("large_bowl_portion",1.32)

func cut_lizard_sprite(node_name:String,id:int,rect:Rect2,depth:float)->MeshInstance3D:
	var mesh=whole_lizard_sprite(node_name,id,rect,depth)
	set_lizard_portions(mesh,id,3)
	return mesh

func meat_atlas(id:int)->String:return "hunt_regional_meat.png" if id in [15,16] else "lizard_meat.png"
func meat_column(id:int)->int:return 1 if id in [14,16] else 0
func cut_meat_sprite(node_name:String,id:int,rect:Rect2,depth:float)->MeshInstance3D:
	var mesh=whole_meat_sprite(node_name,id,rect,depth)
	set_lizard_portions(mesh,id,3)
	return mesh
func whole_meat_sprite(node_name:String,id:int,rect:Rect2,depth:float)->MeshInstance3D:
	var mesh=whole_lizard_sprite(node_name,id,rect,depth)
	if ResourceLoader.exists("res://assets/"+meat_atlas(id)):mesh.material_override.set_shader_parameter("art",load("res://assets/"+meat_atlas(id)))
	return mesh

func set_lizard_portions(mesh:MeshInstance3D,id:int,count:int=3)->void:
	# Preserve the serving footprint while arranging small, flattened portions.
	# Both flesh AND skin come from the correct half of the existing raw atlas.
	var bounds=mesh.mesh.get_aabb()
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var source=Rect2(float(meat_column(id))*.5+.23*.5,.20,.60*.5,.64)
	var layouts=[Rect2(.27,.03,.71,.51),Rect2(.14,.25,.71,.51),Rect2(.01,.47,.71,.51)] if count>1 else [Rect2(.06,.20,.88,.60)]
	for p in range(layouts.size()):
		var area=layouts[p]
		var left=bounds.position.x+area.position.x*bounds.size.x
		var right=bounds.position.x+area.end.x*bounds.size.x
		var top=bounds.end.y-area.position.y*bounds.size.y
		var bottom=bounds.end.y-area.end.y*bounds.size.y
		var z=bounds.position.z+float(p)*.002
		var points=[Vector3(left,top,z),Vector3(right,top,z),Vector3(right,bottom,z),Vector3(left,bottom,z)]
		var coords=[source.position,Vector2(source.end.x,source.position.y),source.end,Vector2(source.position.x,source.end.y)]
		for corner in [0,2,1,0,3,2]:
			st.set_normal(Vector3(0,0,1));st.set_uv(coords[corner]);st.add_vertex(points[corner])
	mesh.mesh=st.commit()
	mesh.set_meta("lizard_portions",count)
	mesh.set_meta("lizard_atlas_column",meat_column(id))
	var mat=mesh.material_override
	mat.set_shader_parameter("art",load("res://assets/"+meat_atlas(id)) if ResourceLoader.exists("res://assets/"+meat_atlas(id)) else load("res://assets/lizard_meat.png"))
	mat.set_shader_parameter("magenta_key",true)
	mat.set_shader_parameter("tile_override",false)
	mat.set_shader_parameter("frame_override",false)

func set_cut_art(mesh:MeshInstance3D,id:int)->void:
	# Board slice meshes are reused after each order: restore their full footprint
	# before swapping either species back to ordinary beef or luncheon meat.
	if not mesh.has_meta("uncut_quad"):mesh.set_meta("uncut_quad",mesh.mesh)
	mesh.mesh=mesh.get_meta("uncut_quad")
	if id in [11,14,15,16]:set_lizard_portions(mesh,id,1)
	else:
		mesh.material_override.set_shader_parameter("art",load("res://assets/prep_atlas.png"))
		mesh.material_override.set_shader_parameter("magenta_key",false)
		_tile(mesh,3 if id==0 else 4,2)

func set_board_art(id:int)->void:
	board_meat.material_override.set_shader_parameter("meat_cuts",float(cuts))
	if id in [11,14,15,16]:
		board_meat.material_override.set_shader_parameter("art",load("res://assets/"+meat_atlas(id)) if ResourceLoader.exists("res://assets/"+meat_atlas(id)) else load("res://assets/lizard_meat.png"))
		board_meat.material_override.set_shader_parameter("magenta_key",true)
		board_meat.material_override.set_shader_parameter("tile_override",true)
		board_meat.material_override.set_shader_parameter("tile_rows",2)
		board_meat.material_override.set_shader_parameter("tile_rect",Vector4(float(meat_column(id))*.5,0,.5,1))
	else:
		board_meat.material_override.set_shader_parameter("art",load("res://assets/prep_atlas.png"))
		board_meat.material_override.set_shader_parameter("magenta_key",false)
		_tile(board_meat,0 if id==0 else 1,2)

func _place(m: MeshInstance3D, point: Vector2, depth: float = 1.5) -> void:
	m.position = Vector3((point.x*1.2265625-785)/100,(437.5-point.y*1.2265625)/100,depth)

func _tile(m: MeshInstance3D, cell: int, rows: int) -> void:
	# Re-map atlas tile in the shader; vertices and texel sharpness stay unchanged.
	m.material_override.set_shader_parameter("tile_override",true)
	m.material_override.set_shader_parameter("tile_rect",Vector4(float(cell%3)/3,float(int(cell/3))/rows,1.0/3,1.0/rows))
	m.material_override.set_shader_parameter("tile_rows",rows)

func input_allowed() -> bool:
	if game.fieldlife and game.fieldlife.modal_open(): return false
	if game.simmer and game.simmer.panel.visible and game.simmer.panel.get_global_rect().has_point(game.get_global_mouse_position()):return false
	if game.title_screen and game.title_screen.visible: return false
	if game.v5 and game.v5.busy(): return false
	return not game.help_panel.visible and not game.show_layers and not game.economy.panel.visible and not (game.backpack and game.backpack.panel.visible)

func _input(event: InputEvent) -> void:
	if game and game.v5: return
	if not game or not game.economy or not input_allowed(): return
	if event is InputEventMouseMotion:
		if board_pressed and event.position.distance_to(down_position)>10 and cuts==3:
			dragging=board_item
			drag_from_board=true
			board_pressed=false
			_tile(ghost,3 if dragging==0 else 4,2)
			ghost.show()
		if dragging>=0: _place(ghost,event.position,2.7)
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT: return
	var pos: Vector2 = event.position
	if event.pressed and game.stage<=4:
		for i in range(4):
			if BIN_RECTS[i].has_point(pos):
				var id = BIN_IDS[i]
				if id in [0,4]:
					if board_item>=0: game._notice("先把砧板上的肉切好，放入锅中。")
					elif stock[id]<=0: game._notice("这格用完了，可以去商店补货。")
					elif game.selected.has(id) or game.food_count()>=4: game._notice("本碗已经选过，或四种食材已经放满。")
					else:
						dragging=id
						drag_from_board=false
						_tile(ghost,0 if id==0 else 1,2)
						_place(ghost,pos,2.7)
						ghost.show()
				else: game._select(id)
				get_viewport().set_input_as_handled()
				return
		if BOARD.has_point(pos) and board_item>=0:
			board_pressed=true
			down_position=pos
			get_viewport().set_input_as_handled()
	if not event.pressed:
		if dragging>=0:
			if drag_from_board:
				if POT.has_point(pos): commit_board()
			elif BOARD.has_point(pos) and board_item<0:
				board_item=dragging
				cuts=0
				set_board_art(board_item)
				board_meat.show()
				game._sound("tap")
			dragging=-1
			ghost.hide()
			refresh()
			game._save()
			get_viewport().set_input_as_handled()
		elif board_pressed:
			board_pressed=false
			if BOARD.has_point(pos):
				if cuts<3: chop()
				else: commit_board()
			get_viewport().set_input_as_handled()

func chop() -> void:
	if board_item<0 or cuts>=3 or knife_time>0 or game.stage>4: return
	knife_time=.50
	knife.show()
	# The lower-left blade edge meets the right edge of the remaining meat.
	_place(knife,Vector2(737-cuts*35,564),1.7)
	knife_base_y=knife.position.y
	knife.position.y+=.75
	var swing=create_tween();tweens.append(swing)
	swing.tween_property(knife,"position:y",knife_base_y,.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	swing.tween_property(knife,"position:y",knife_base_y+.66,.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var token = animation_token
	await get_tree().create_timer(.18).timeout
	if token!=animation_token: return
	game.audio.play_at("chop"+str(cuts+1),.13,-7)
	cuts+=1
	set_cut_art(slices[cuts-1],board_item)
	slices[cuts-1].show()
	board_meat.material_override.set_shader_parameter("meat_cuts",float(cuts))
	var piece=slices[cuts-1]
	_place(piece,Vector2(738+(cuts-1)*20,594+(cuts-1)*12),1.46+cuts*.01)
	var slide=create_tween();tweens.append(slide)
	slide.tween_property(piece,"position:x",piece.position.x+.12,.17).set_trans(Tween.TRANS_QUAD)
	if cuts==3: board_meat.hide()
	refresh()
	game._save()

func commit_board() -> void:
	if board_item<0 or cuts<3 or game.stage>4: return
	var id = board_item
	if game._select(id,true):
		clear_board()
		game._notice("切好的"+game.INGREDIENTS[id]+("已备妥，开锅后再投料。" if game.stage<3 else "已放入锅里。"))

func clear_board() -> void:
	animation_token+=1
	board_item=-1
	cuts=0
	knife_time=0
	board_meat.hide()
	board_meat.scale=Vector3.ONE
	board_meat.material_override.set_shader_parameter("meat_cuts",-1.0)
	knife.hide()
	for piece in slices: piece.hide()
	refresh()

func harvest_plant(index: int) -> void:
	if index<0 or index>=FARM_IDS.size():return
	var id = FARM_IDS[index]
	if game.stage>4: game._notice("已经盛出来了，下一碗再采。");return
	if staged_food.has(id) or game.selected.has(id):game._notice("这种菜已经备好或入锅了，先用完这一份。");return
	if staged_food.size()>=6:game._notice("砧板边已经备好六份，先用掉一些再采。");return
	if stock[id]<=0 and farm_growth[index]>=1.0:
		farm_growth[index]=0.0
		farm_water[index]=0
		stock[id]+=1
	if stock[id]>0 and prepare_food(id,true):
		var origin=Vector2(1180,244+index*106)
		ready_points[id]=origin
		ready_flights[id]={"age":0.0,"from":origin}
		refresh_ready()
		game._notice(FARM_NAMES[index]+"先放砧板备好；浇一次水就能再长一茬。")
	refresh()
	game._save()

func water(index: int) -> void:
	if game.irrigation:
		game.irrigation.start(index)
		return
	if farm_growth[index]>=1.0: game._notice("已经长成，点击蔬菜采收。")
	elif farm_water[index]>=1: game._notice("水够了，根系正在慢慢长。")
	elif water_store<=0: game._notice("水壶空了。打开路线，在营地水井免费取水。")
	else:
		water_store-=1
		farm_water[index]=1
		water_fx[index]=1.6
		game.audio.play_at("water",.70,-12)
		game._notice("水浇好了，根系开始再生。")
	refresh()
	game._save()

func plant_action(index:int)->void:
	# The physical drawer follows its roots, not the previously harvested
	# portion waiting on our board. Empty roots must always remain waterable.
	if farm_growth[index]>=1.0:harvest_plant(index)
	else:water(index)

func tick(delta: float) -> void:
	if cooking_fx:cooking_fx.tick(delta)
	var changed = false
	for i in range(staged_food.size()):
		var id=int(staged_food[i]);var destination=ready_destination(i)
		if ready_flights.has(id):
			ready_flights[id].age+=delta
			var t=clampf(float(ready_flights[id].age)/.72,0,1)
			ready_points[id]=Vector2(ready_flights[id].from).lerp(destination,t)+Vector2(0,-sin(t*PI)*80)
			if t>=1:ready_flights.erase(id)
		else:ready_points[id]=Vector2(ready_points.get(id,destination)).move_toward(destination,delta*600)
	refresh_ready()
	for i in range(4):
		water_fx[i]=maxf(0,water_fx[i]-delta)
		if farm_water[i]>=1 and farm_growth[i]<1.0:
			farm_growth[i]=minf(1.0,farm_growth[i]+delta/(16.0 if game.economy.upgrades.has("lamp") else 30.0))
			changed=true
	if knife_time>0:
		knife_time=maxf(0,knife_time-delta)
		if knife_time==0: knife.hide()
	if changed: refresh()

func tear_packet() -> void:
	if packet_busy or packet_stage!=0: return
	packet_busy=true
	var token=animation_token
	packet.show()
	packet_top.show()
	packet.material_override.set_shader_parameter("torn",0)
	_place(packet,Vector2(269,608),1.8)
	_place(packet_top,Vector2(269,559),1.9)
	packet.rotation.z=0
	packet_top.rotation.z=0
	game.audio.play_at("tear",-.28,-6)
	var tw=create_tween()
	tweens.append(tw)
	tw.tween_property(packet,"position",Vector3(-.67,-2.04,1.8),.45)
	tw.parallel().tween_property(packet_top,"position",Vector3(-.67,-1.43,1.9),.45)
	tw.tween_property(packet,"rotation:z",-.08,.15)
	tw.tween_property(packet,"rotation:z",.04,.35)
	tw.tween_callback(func(): packet.material_override.set_shader_parameter("torn",1))
	tw.tween_property(packet_top,"position",Vector3(.73,-1.58,1.9),.55).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(packet_top,"rotation:z",-.7,.55)
	await tw.finished
	if token!=animation_token: return
	packet_top.hide()
	packet_stage=1
	packet_busy=false
	game._notice("包装撕开了。再点「面饼和调料下锅」。")
	game._refresh()
	game._save()

func drop_noodles() -> void:
	if packet_busy or packet_stage!=1: return
	packet_busy=true
	var token=animation_token
	noodle.show()
	seasoning.show()
	_place(noodle,Vector2(581,475),2.0)
	_place(seasoning,Vector2(619,498),2.05)
	noodle.scale=Vector3.ONE
	seasoning.scale=Vector3.ONE
	game.audio.play_at("rustle",-.25,-10)
	var target=Vector3((445*1.2265625-785)/100,(437.5-522*1.2265625)/100,2.0)
	var tw=create_tween()
	tweens.append(tw)
	tw.tween_property(noodle,"position",target,.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(noodle,"scale",Vector3(.55,.33,1),.65)
	tw.parallel().tween_property(seasoning,"position",target,.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(seasoning,"scale",Vector3(.3,.3,1),.9)
	tw.tween_callback(func(): game.audio.play_at("splash",-.30,-10))
	await tw.finished
	if token!=animation_token: return
	for m in [packet,noodle,seasoning]: m.hide()
	packet_stage=2
	packet_busy=false
	if game.v4: game.v4.seasoned=true
	game.stage=3
	game.cook_remaining=0.0
	if game.simmer:game.simmer.start_cycle()
	game._refresh()
	game._save()

func reset_packet() -> void:
	if cooking_fx:cooking_fx.cancel_egg()
	if game.v4: game.v4.seasoned=false
	animation_token+=1
	for tw in tweens:
		if tw and tw.is_valid(): tw.kill()
	tweens.clear()
	packet_stage=0
	packet_busy=false
	for m in [packet,packet_top,noodle,seasoning]: m.hide()

func refresh() -> void:
	if not is_instance_valid(prep_label): return
	if flavor_panel:
		flavor_panel.visible=game.stage<3 and not (game.fieldlife and game.fieldlife.modal_open()) and not (game.title_screen and game.title_screen.visible)
		for i in range(flavor_buttons.size()):
			flavor_buttons[i].disabled=packet_busy
			flavor_buttons[i].add_theme_stylebox_override("normal",game._style(Color("a8bb83") if i==flavor else game.PAPER))
	refresh_ready()
	for i in range(4):
		plant_meshes[i].material_override.set_shader_parameter("growth",farm_growth[i])
		plant_buttons[i].text=FARM_NAMES[i]+(" · 可采收" if farm_growth[i]>=1 else (" · 浇水即可再生" if farm_water[i]<1 else " · 生长 %d%%" % int(farm_growth[i]*100)))
		if farm_growth[i]>=1 and stock[FARM_IDS[i]]>0: plant_buttons[i].text=FARM_NAMES[i]+" · 已采 ×"+str(stock[FARM_IDS[i]])
		bin_labels[i].text=game.INGREDIENTS[BIN_IDS[i]]+" ×"+str(stock[BIN_IDS[i]])
	for i in range(3): bin_meshes[i].visible=stock[BIN_IDS[i]]>0
	for i in range(4): bin_meshes[i+3].visible=stock[1]>i
	prep_label.text="先备料 → 看最佳熟度 → 按时投料 → 一起出锅" if board_item<0 else "%s · %d / 3 刀 · 已备食材挪到砧板后沿" % [game.INGREDIENTS[board_item],cuts]
	add_button.text="切三刀后备妥" if cuts<3 else "备好肉片" if game.stage<3 else "肉片下锅 / 拖到锅里"
	add_button.disabled=cuts<3 or game.stage>4
	water_label.text="净水 %d  /  可去营地取水" % water_store
	action_mark.text=("已备 %d 份 · 悬停看最佳熟度"%staged_food.size() if not staged_food.is_empty() else "") if board_item<0 else ("点击砧板落刀 · %d / 3" % cuts if cuts<3 else "肉切好了 · 再点一下备妥" if game.stage<3 else "肉切好了 · 点击下锅")

func to_save() -> Dictionary:
	return {"stock":stock,"water":farm_water,"growth":farm_growth,"water_store":water_store,"board":board_item,"cuts":cuts,"packet":packet_stage,"staged_food":staged_food,"flavor":flavor}

func restore(data: Dictionary) -> void:
	for mesh in ready_meshes.values():
		if is_instance_valid(mesh):mesh.queue_free()
	staged_food.clear();ready_meshes.clear();ready_rects.clear();ready_points.clear();ready_flights.clear()
	clear_board()
	reset_packet()
	flavor=clampi(int(data.get("flavor",0)),0,2)
	for i in range(mini(stock.size(),data.get("stock",stock).size())): stock[i]=maxi(0,int(data.get("stock",stock)[i]))
	for i in range(4):
		farm_water[i]=clampi(int(data.get("water",farm_water)[i]),0,1)
		farm_growth[i]=clampf(float(data.get("growth",farm_growth)[i]),0,1)
	water_store=maxi(0,int(data.get("water_store",8)))
	board_item=int(data.get("board",-1))
	if board_item not in [-1,0,4,11,14,15,16]: board_item=-1
	cuts=clampi(int(data.get("cuts",0)),0,3)
	if board_item>=0:
		set_board_art(board_item)
		board_meat.visible=cuts<3
		board_meat.scale=Vector3.ONE
		for i in range(3):
			set_cut_art(slices[i],board_item)
			slices[i].visible=i<cuts
	packet_stage=clampi(int(data.get("packet",0)),0,2)
	packet.visible=packet_stage==1 and game.stage==2
	if packet.visible:
		packet.material_override.set_shader_parameter("torn",1)
		_place(packet,Vector2(585,548),1.8)
	var restored_stage=game.stage
	game.stage=mini(game.stage,4)
	for id in data.get("staged_food",[]):prepare_food(int(id),true,true)
	game.stage=restored_stage
	refresh()

func farm_source(index: int) -> Rect2:
	return Rect2(1096.0/1280,(207.0+index*106)/714.0,169.0/1280,106.0/714)

func reference_piece(node_name: String, rect: Rect2, source: Rect2, depth: float) -> MeshInstance3D:
	var mat=ShaderMaterial.new()
	mat.shader=load("res://shaders/reference_crop.gdshader")
	mat.set_shader_parameter("art",load("res://assets/rv_atlas_v3.png"))
	mat.set_shader_parameter("source_rect",Vector4(source.position.x,source.position.y,source.size.x,source.size.y))
	game.materials.append({"mat":mat,"group":"interior"})
	var local=Rect2(785-rect.size.x*1.2265625/2,437.5-rect.size.y*1.2265625/2,rect.size.x*1.2265625,rect.size.y*1.2265625)
	var mesh=game._quad(node_name,local,0,mat)
	_place(mesh,rect.get_center(),depth)
	return mesh
