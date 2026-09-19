extends SceneTree
var game
var checks=[]
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"index":checks.size()+1,"passed":ok,"description":label})
	if ok:print("FIXED5_PASS ",checks.size(),": ",label)
	else:failures+=1;push_error("FIXED5_FAIL %d: %s"%[checks.size(),label])
func move(p:Vector2):
	var event=InputEventMouseMotion.new();event.position=p;event.global_position=p;game.get_viewport().push_input(event)
func click(p:Vector2):game._click_for_qa(p)
func drag(from:Vector2,to:Vector2):
	move(from)
	var e=InputEventMouseButton.new();e.position=from;e.global_position=from;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;game.get_viewport().push_input(e)
	move(to)
	e=InputEventMouseButton.new();e.position=to;e.global_position=to;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false;game.get_viewport().push_input(e)
func capture(name:String):
	if DisplayServer.get_name()!="headless":await game._capture(name)
func clear_meal():
	game.stage=0;game.selected.clear();game.prep.clear_board();game.prep.reset_packet();game.simmer.reset()
	game.v5.cancel_transition();game.v4.close_conversation();game.fieldlife.closeup.hide();game.fieldlife.close_fridge();game.fieldlife.pointer=Vector2(640,680)
	game.service.eating=false
	if game.perfect_fx:game.perfect_fx.stop()
	game._refresh()
func fast_start():
	game.stage=3;game.prep.packet_stage=2;game.v4.has_water=true;game.v4.seasoned=true;game.simmer.start_cycle();game._refresh()

func atlas_is(mesh:MeshInstance3D,file:String,column:int,columns:int)->bool:
	if not is_instance_valid(mesh):return false
	var mat=mesh.material_override
	var art=mat.get_shader_parameter("art")
	if not art or not art.resource_path.ends_with(file):return false
	if mat.get_shader_parameter("tile_override") or mat.get_shader_parameter("frame_override"):return false
	for surface in range(mesh.mesh.get_surface_count()):
		for uv in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]:
			if uv.x<float(column)/columns-.0001 or uv.x>float(column+1)/columns+.0001:return false
	return true

func verify_visual_chain():
	clear_meal()
	for id in game.prep.staged_food.duplicate():game.prep.return_prepared(id)
	for id in game.prep.FARM_IDS:
		game.prep.stock[id]=3;game.prep.prepare_food(id,true,true)
		var column=game.prep.FARM_IDS.find(id)
		check(atlas_is(game.prep.ready_meshes[id],"harvest_leaves.png",column,4),"Leaf %d uses its own atlas quarter while prepared"%id)
		game.v5.make_food_ghost(id,true)
		check(atlas_is(game.v5.ghost,"harvest_leaves.png",column,4),"Leaf %d drag uses the same leaf-only portion"%id)
		game.v5.ghost.queue_free();game.v5.ghost=null
		check(atlas_is(game.v4.floats[id],"harvest_leaves.png",column,4) and atlas_is(game.toppings[id],"harvest_leaves.png",column,4),"Leaf %d retains its identity both floating and on the plated bowl"%id)
		game.prep.return_prepared(id)
	var authored=load("res://房车场景.tscn").instantiate()
	var geometry_unchanged=true
	for id in [2,5]:
		var original=authored.find_child("Topping_"+str(id),true,false)
		geometry_unchanged=geometry_unchanged and original.mesh.get_aabb().is_equal_approx(game.toppings[id].mesh.get_aabb()) and original.position.is_equal_approx(game.toppings[id].position)
	authored.free()
	check(geometry_unchanged,"Replacing authored bowl leaves preserves original vertices, position and perspective")
	for id in [11,14]:
		game.prep.stock[id]=3;game.v5.put_meat_on_board(id)
		for i in range(3):click(Vector2(691,589));await create_timer(.15).timeout;game.prep.tick(.4)
		var column=1 if id==14 else 0
		var correct_slices=true
		for piece in game.prep.slices:correct_slices=correct_slices and atlas_is(piece,"lizard_meat.png",column,2) and piece.visible
		check(correct_slices,"Three actual cuts retain flesh and skin from lizard species %d"%id)
		var data=game.prep.to_save().duplicate(true);game.prep.restore(data)
		check(atlas_is(game.prep.slices[2],"lizard_meat.png",column,2),"Reloading a cut board preserves lizard species %d"%id)
		game.prep.commit_board();game.prep.tick(.5)
		check(atlas_is(game.prep.ready_meshes[id],"lizard_meat.png",column,2) and game.prep.ready_meshes[id].get_meta("lizard_portions",0)==3,"Prepared lizard %d is three small species-specific portions"%id)
		game.v5.make_food_ghost(id,true)
		check(atlas_is(game.v5.ghost,"lizard_meat.png",column,2) and game.v5.ghost.get_meta("lizard_portions",0)==3,"Dragging cut lizard %d never substitutes ordinary beef"%id)
		game.v5.ghost.queue_free();game.v5.ghost=null
		check(atlas_is(game.v4.floats[id],"lizard_meat.png",column,2),"Floating lizard %d uses its own real atlas half"%id)
		check(atlas_is(game.toppings[id],"lizard_meat.png",column,2),"Plated lizard %d keeps its species-specific skin and meat"%id)
	game.prep.stock[0]=3;game.v5.put_meat_on_board(0)
	click(Vector2(691,589));await create_timer(.15).timeout;game.prep.tick(.4)
	check(game.prep.slices[0].material_override.get_shader_parameter("art").resource_path.ends_with("prep_atlas.png") and not game.prep.slices[0].material_override.get_shader_parameter("magenta_key"),"A reused cutting board restores ordinary beef after cutting lizard meat")
	game.prep.clear_board()
	for id in game.prep.FARM_IDS:game.prep.prepare_food(id,true,true)
	game.prep.tick(1);game._refresh();game.v4.guide_seconds=0;move(Vector2(640,240));game.simmer.refresh()
	await capture("17_叶片与两种蜥肉备料.png")
	fast_start();game.prep.put_ready_in_pot(11);game.prep.put_ready_in_pot(14);game.simmer.tick(12);game.prep.put_ready_in_pot(2);game.prep.put_ready_in_pot(7)
	game.v4.update_pot();game._refresh()
	await capture("18_两种蜥肉与叶片入锅.png")
	game.simmer.tick(8);game.perfect_fx.stop();game.v4.guide_seconds=0;game._refresh()
	check(game.stage==5 and game.simmer.perfect and game.selected.has(11) and game.selected.has(14),"Both identifiable meat species still finish perfectly with correctly timed leaf portions")
	game.hour=20;game.weather=1;game._apply_lighting(3.0)
	var survives_light=true
	for id in [11,14]:
		var column=1 if id==14 else 0
		survives_light=survives_light and atlas_is(game.v4.floats[id],"lizard_meat.png",column,2) and atlas_is(game.toppings[id],"lizard_meat.png",column,2)
		# Identity comes from different atlas pixels, even with the common white tint.
		survives_light=survives_light and game.toppings[id].material_override.get_shader_parameter("tint")==Color.WHITE
	for id in game.prep.FARM_IDS:survives_light=survives_light and atlas_is(game.toppings[id],"harvest_leaves.png",game.prep.FARM_IDS.find(id),4)
	check(survives_light,"Day-to-night lighting preserves every leaf and both naturally coloured lizard atlas mappings without tint hacks")
	game.hour=10;game.weather=0;game._apply_lighting(20);game.v4.update_pot()
	await capture("19_叶片与两种蜥肉成品.png")
	clear_meal();game.tutorial.restart();game.tutorial.tick(.1);await process_frame
	check(game.tutorial.bubble.get("speech_tip")==true and game.tutorial.bubble.position==Vector2(28,277),"Tutorial uses an upward speech bubble in its existing position")
	var text_bottom=game.tutorial.words.position.y+game.tutorial.words.get_line_count()*game.tutorial.words.get_line_height()
	check(text_bottom+10<=game.tutorial.next_button.position.y and game.tutorial.words.get_rect().end.y+10<=game.tutorial.next_button.position.y,"All welcome lines and the text area clear the next button by at least ten pixels")
	check(game.tutorial.next_button.get_rect().end.y+10<=game.tutorial.step_label.position.y and game.tutorial.step_label.get_rect().end.y<=game.tutorial.bubble.size.y-6,"Tutorial button, step number and lower bubble border remain separated")
	await capture("20_机器人教学气泡留白.png")
	game.tutorial.skip()
func run():
	game=load("res://main.tscn").instantiate();game.new_game_requested=true;game.save_path="user://qa_verify_fixed_stove_save.json"
	root.add_child(game);game.set_process(false);game.qa_mode=true;game.title_screen.hide();game.tutorial.active=false;game.tutorial.overlay.hide()
	game.v4.guide_seconds=0;game.v4.close_conversation();game.v5.cancel_transition();game.auto_time=false;game.auto_weather=false;game.hour=10;game.weather=0
	game.screenshot_dir="user://qa_verify_fixed_stove"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(game.screenshot_dir))
	game._refresh();game.simmer.refresh();await process_frame
	check(game.prep.stock.size()==15 and game.simmer.target(14)==5,"Red cactus lizard meat has an inventory entry and five-cell doneness")
	check(game.simmer.panel.visible and game.simmer.cells.size()==5,"Fixed five-cell stove is visible before cooking")
	game.simmer.set_plan(2);click(game.simmer.cells[1].button.get_global_rect().get_center())
	check(game.simmer.planned_cells==5 and game.simmer.cells[1].button.disabled,"Neither old API nor clicking can change the fixed five-cell duration")
	move(Vector2(895,548));game.simmer.refresh()
	check(game.simmer.hovered_id==0 and game.simmer.hover_text.text.contains("立即"),"Beef hover explains immediate insertion after noodle drop")
	move(Vector2(1180,350));game.simmer.refresh()
	check(game.simmer.hovered_id==2 and game.simmer.hover_text.text.contains("第 3 格"),"Greens hover teaches cell-three insertion for the fixed cell-five finish")
	click(Vector2(1180,350));game.prep.tick(.3)
	check(game.prep.staged_food.has(2) and game.selected.is_empty() and game.prep.ready_flights.has(2),"Harvested leaves fly to the board without entering the pot")
	var leaves=game.prep.ready_meshes[2]
	check(leaves.material_override.get_shader_parameter("art").resource_path.ends_with("harvest_leaves.png"),"Harvest and board use the leaf-only atlas")
	var uv=leaves.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	check(is_equal_approx(uv[0].x,.25) or is_equal_approx(uv[1].x,.25),"Cabbage leaves use the second quarter of the four-column atlas")
	game.prep.tick(.5);click(Vector2(1180,350));game.irrigation.tick(2.5);game.prep.tick(2)
	check(game.prep.farm_water[1]==1 and game.prep.farm_growth[1]>0,"Clicking the harvested drawer still starts regeneration with one watering")
	click(Vector2(895,548));game.prep.tick(.4)
	check(game.prep.board_item==0 and game.prep.ready_rect(2).get_center().y<542,"Meat preparation moves waiting leaves off the centre of the board")
	for i in range(3):click(Vector2(691,589));await create_timer(.15).timeout;game.prep.tick(.4)
	click(Vector2(700,590));click(Vector2(973,652));click(Vector2(1005,546));game.prep.tick(.4)
	check(game.prep.staged_food.has(0) and game.prep.staged_food.has(1) and game.selected.is_empty(),"Meat and egg are prepared before the fixed cycle starts")
	move(game.prep.ready_rect(2).get_center());game.simmer.refresh();await capture("13_新叶片与固定五格.png")
	game.simmer.tick(50)
	check(game.simmer.elapsed==0 and not game.simmer.started,"Preparation and clear-water stages do not start the noodle clock")
	click(Vector2(445,561));game._process(3.6);check(game.stage==2,"Clear-water heating reaches the packet stage")
	click(Vector2(270,610));await create_timer(1.7).timeout
	check(game.prep.packet_stage==1 and not game.simmer.started,"Tearing the bag does not start the clock")
	click(Vector2(585,533));await create_timer(.4).timeout
	check(not game.simmer.started,"Clock waits until noodle and seasoning flight actually reaches the pot")
	await create_timer(.75).timeout
	check(game.stage==3 and game.prep.packet_stage==2 and game.simmer.started and game.selected.is_empty(),"Actual noodle and seasoning drop starts the fixed cycle with no toppings required")
	game.simmer.tick(.15)
	check(game.simmer.elapsed>.1 and game.simmer.portions.is_empty(),"The clock advances before the first topping is inserted")
	click(game.prep.ready_rect(0).get_center())
	check(is_equal_approx(game.simmer.portions[0].added_at,.15) and game.simmer.units(0)==0,"Beef starts its own cooking time only at its real insertion instant")
	game._cook();game._finish_cooking_automatically();game.simmer.finalize()
	check(game.stage==3 and not game.simmer.finished,"Clicking the pot and completion hooks cannot end the cycle early")
	game.simmer.tick(3.85)
	game.tutorial.restart();game.tutorial.advance_text();game.tutorial.advance_text();game.tutorial.tick(.1)
	move(Vector2(640,240));game.simmer.refresh();await capture("16_固定五格新手提示.png")
	game.tutorial.active=false;game.tutorial.overlay.hide()
	click(game.prep.ready_rect(1).get_center());click(game.prep.ready_rect(3).get_center())
	check(is_equal_approx(game.simmer.portions[1].added_at,4) and not game.simmer.portions.has(3),"Egg starts at cell one while spice has no doneness clock")
	var elapsed_before=game.simmer.elapsed;game.help_panel.show();game.simmer.tick(20);game.help_panel.hide()
	check(is_equal_approx(game.simmer.elapsed,elapsed_before),"Help pauses the running stove without resetting elapsed time")
	game.simmer.tick(8)
	drag(game.prep.ready_rect(2).get_center(),Vector2(445,545))
	check(game.selected.has(2) and game.simmer.units(2)==0 and is_equal_approx(game.simmer.portions[2].added_at,12),"Dragging leaf portions in at cell three starts their doneness at zero")
	game.v4.update_pot()
	check(game.v4.floats[2].material_override.get_shader_parameter("art").resource_path.ends_with("harvest_leaves.png"),"Floating cabbage uses the same leaf-only atlas")
	move(Vector2(640,240));game.simmer.refresh();await capture("14_固定五格顺序投料.png")
	var saved=game.simmer.to_save().duplicate(true);game.simmer.restore(saved)
	check(game.simmer.planned_cells==5 and is_equal_approx(game.simmer.portions[0].added_at,.15) and is_equal_approx(game.simmer.portions[2].added_at,12),"Saving and loading retains fixed duration and actual insertion timestamps")
	game.simmer.tick(7.9)
	check(game.stage==3 and not game.simmer.finished,"Stove does not stop before the end of the fifth cell")
	game.simmer.tick(.5)
	check(game.stage==5 and game.simmer.finished and is_equal_approx(game.simmer.elapsed,20) and not game.v4.has_water,"Crossing five cells clamps precisely to twenty seconds and automatically switches off and plates")
	check(game.simmer.perfect and game.simmer.quality(0)=="最佳" and game.simmer.quality(1)=="最佳" and game.simmer.quality(2)=="最佳","Immediate beef, cell-one egg and cell-three greens finish with perfect doneness")
	check(game.bowl.visible and not game.service.eating,"Automatically plated bowl stays on our own counter and does not feed the guest")
	check(game.perfect_fx.active and game.perfect_fx.trigger_count>0,"Automatic perfect finish triggers the celebratory bowl effect")
	game.perfect_fx.tick(.34)
	check(game.bowl.position.y>game.service.original_positions[0].y,"Perfect bowl makes a small lift while the star particles display")
	var stopped=game.simmer.elapsed;game.simmer.tick(100)
	check(game.simmer.elapsed==stopped,"Finished stove never accrues extra doneness after the fifth cell")
	await capture("15_自动出锅完美火候.png")
	clear_meal();game.prep.stock[2]+=2;fast_start();game.simmer.tick(12);game._select(2,true);game.simmer.tick(8)
	check(game.simmer.perfect and not game.selected.has(0) and not game.selected.has(1),"Pure perfect doneness does not require matching the guest's recipe")
	check(game.service.score()<100,"Missing ordered ingredients are assessed separately by customer satisfaction")
	clear_meal();game.prep.stock[2]+=2;fast_start();game._select(2,true);game.simmer.tick(20)
	check(game.stage==5 and game.simmer.quality(2)=="过熟" and not game.simmer.perfect,"Early greens produce ordinary overcooked noodles while still plating normally")
	click(Vector2(704,572));check(game.stage==6 and game.service.eating,"Ordinary non-perfect noodles can be served and eaten normally")
	game.v4.tick(3);check(not game.service.eating and game.v4.bite_count==1,"An ordinary bowl still reaches a single bite and customer review")
	clear_meal();fast_start();game.simmer.tick(20)
	check(game.stage==5 and not game.simmer.perfect,"An empty-topping noodle bowl still completes without getting a free perfect award")
	clear_meal();game.stage=3;game.prep.packet_stage=2
	game.simmer.restore({"version":2,"planned":2,"elapsed":8.0,"started":false,"finished":false,"portions":{}})
	check(game.simmer.planned_cells==5 and game.simmer.started and game.simmer.elapsed==8,"Older adjustable-duration save resumes on fixed five cells after noodles are in")
	game.simmer.tick(12)
	check(game.stage==5 and game.simmer.elapsed==20,"Older mid-cook save automatically plates at the fixed end without requiring a first topping")
	clear_meal();game.prep.stock[14]=1;game.v5.put_meat_on_board(14)
	check(game.prep.board_item==14 and game.prep.board_meat.material_override.get_shader_parameter("art").resource_path.ends_with("lizard_meat.png"),"Rare red lizard meat uses its raw-meat atlas on the board")
	check(is_equal_approx(game.prep.board_meat.material_override.get_shader_parameter("tile_rect").x,.5),"Rare raw meat uses the right atlas column")
	game.fieldlife.cold.show();game.simmer.pointer=Vector2(613,572);game.simmer.refresh()
	check(game.simmer.hovered_id==14 and game.simmer.hover_title.text.contains("5 格"),"Fourth refrigerated slot shows rare meat doneness above any food behind the panel")
	game.fieldlife.close_fridge()
	for i in range(3):click(Vector2(691,589));await create_timer(.15).timeout;game.prep.tick(.4)
	click(Vector2(700,590));game.prep.tick(.4)
	check(game.prep.staged_food.has(14) and game.prep.stock[14]==1,"Rare meat must be cut three times and waits prepared without consuming stock")
	game.v5.make_food_ghost(14,false)
	check(game.v5.ghost.material_override.get_shader_parameter("art").resource_path.ends_with("lizard_meat.png"),"Dragging raw rare meat uses its distinct atlas instead of cooked slices")
	game.v5.ghost.queue_free();game.v5.ghost=null
	fast_start();game.prep.put_ready_in_pot(14);game.simmer.tick(20)
	check(game.prep.stock[14]==0 and game.simmer.perfect and game.simmer.quality(14)=="最佳","Rare meat consumes one stock and has the same five-cell target as regular lizard meat")
	clear_meal();game.prep.stock[0]+=2;game.prep.stock[1]+=2;game._select(0,true);game._select(1);game.prep.tick(.4)
	game.tutorial.restart();game.tutorial.advance_text();game.tutorial.advance_text();game.stage=2;game.prep.packet_stage=1;game.tutorial.tick(.1)
	check(game.tutorial.words.text.contains("计时就开始") and game.tutorial.words.text.contains("马上"),"Tutorial warns before noodle drop that the clock starts and beef must follow immediately")
	game.stage=3;game.prep.packet_stage=2;game.simmer.start_cycle();game._select(0,true);game.simmer.tick(4);game.tutorial.tick(.1)
	check(game.tutorial.words.text.contains("鸡蛋") and not game.tutorial.words.text.contains("选择"),"Tutorial follows the fixed timer to egg insertion without adjustable-end instructions")
	game.tutorial.skip()
	await verify_visual_chain()
	var result={"suite":"fixed_five_stove","runtime":"Godot 4.7.2 Windows native OpenGL","passed":checks.size()-failures,"failed":failures,"checks":checks}
	var output=FileAccess.open("user://qa_verify_fixed_stove_result.json",FileAccess.WRITE)
	if output:output.store_string(JSON.stringify(result,"\t"));output.close()
	print("FIXED_FIVE_COMPLETE ",checks.size()," checks; failures=",failures)
	game._shutdown()
