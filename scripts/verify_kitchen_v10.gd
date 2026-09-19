extends SceneTree
var game
var checks=[]
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"passed":ok,"description":label})
	if ok:print("KITCHEN10_PASS ",checks.size(),": ",label)
	else:failures+=1;push_error("KITCHEN10_FAIL "+label)
func shot(name:String):
	game.v4.guide_seconds=0;game.service.guide_panel.hide();game.simmer.pointer=Vector2(640,200);game._refresh();game.simmer.refresh();game.v4.update_pot()
	if DisplayServer.get_name()!="headless":await game._capture(name)
func reset():
	game._reset_bowl();game.v5.cancel_transition();game.v4.close_conversation();game.fieldlife.close_fridge();game.fieldlife.closeup.hide()
	for id in game.prep.staged_food.duplicate():game.prep.return_prepared(id)
	game.service.eating=false;game.stage=0;game._refresh()
func start():
	game.stage=3;game.prep.packet_stage=2;game.v4.has_water=true;game.v4.seasoned=true;game.simmer.start_cycle();game._refresh()
func advance(dt:float):
	game.elapsed+=dt;game.prep.tick(dt);game.simmer.tick(dt);game.v4.update_pot()
func click(p:Vector2):game._click_for_qa(p)
func atlas(mesh,file:String,column:int)->bool:
	if not mesh.material_override.get_shader_parameter("art").resource_path.ends_with(file):return false
	for uv in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
		if uv.x<float(column)*.5-.001 or uv.x>float(column+1)*.5+.001:return false
	return true
func run():
	game=load("res://main.tscn").instantiate();game.new_game_requested=true;game.save_path="user://qa_verify_kitchen_v10_save.json";root.add_child(game)
	game.set_process(false);game.qa_mode=true;game.title_screen.hide();game.tutorial.active=false;game.tutorial.overlay.hide();game.auto_time=false;game.auto_weather=false;game.hour=10;game.weather=0;game.v5.cancel_transition();game.v4.close_conversation()
	game.screenshot_dir="user://qa_verify_kitchen_v10"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(game.screenshot_dir));await process_frame
	check(game.prep.stock.size()==17 and game.simmer.target(15)==4 and game.simmer.target(16)==3,"Seventeen ingredients include four-cell rock rabbit and three-cell marsh duck")
	for flavor in range(3):
		reset();click(Vector2(242+flavor*38,692));check(game.prep.flavor==flavor,"Flavor button selects soup %d"%flavor)
		game._cook();game.cook_remaining=0;game.stage=2;game.prep.packet_stage=1
		game.prep.drop_noodles();await create_timer(.45).timeout
		check(not game.simmer.started,"Flavor %d does not start cooking before noodle and seasoning landing"%flavor)
		await create_timer(.55).timeout;game.v4.update_pot()
		check(game.simmer.started and game.simmer.elapsed==0 and game.simmer.planned_cells==5,"Flavor %d starts the same fixed five cells on real landing"%flavor)
		check(game.v4.pot_material.get_shader_parameter("flavor")==flavor,"Soup material receives selected flavor %d"%flavor)
		var first=game.v4.boil_intensity;advance(16)
		check(game.v4.boil_intensity>first and game.v4.boil_intensity>.8,"Visible bubbling intensifies through flavor %d cooking"%flavor)
		await shot("01_汤底"+str(flavor)+"与沸腾.png")
		game.prep.choose_flavor((flavor+1)%3);check(game.prep.flavor==flavor,"A running bowl cannot change flavor midway")
		advance(4);check(game.stage==5 and game.v4.boil_intensity==0,"Fixed end switches off bubbles and automatically plates flavor %d"%flavor)
		check(game.bowl.material_override.get_shader_parameter("broth_flavor")==flavor,"Plated broth retains flavor %d"%flavor)
	reset();game.prep.choose_flavor(1);var saved=game.prep.to_save().duplicate(true);game.prep.flavor=0;game.prep.restore(saved)
	check(game.prep.flavor==1,"Selected flavor persists through save and restore")
	saved.erase("flavor");game.prep.restore(saved);check(game.prep.flavor==0,"Older saves default to original beef flavor")
	game.prep.stock[0]=4;game.v5.put_meat_on_board(0);game.prep.chop();await create_timer(.10).timeout
	check(game.prep.cuts==0 and game.prep.slices[0].visible==false,"Meat remains whole while the raised blade descends")
	await create_timer(.10).timeout
	check(game.prep.cuts==1 and game.prep.slices[0].visible and game.prep.board_meat.scale==Vector3.ONE and game.prep.board_meat.material_override.get_shader_parameter("meat_cuts")==1,"Blade contact removes a strip and separates the first slice without squashing the whole meat")
	await shot("02_刀接触切出肉片.png");game.prep.tick(.6)
	for i in range(2):game.prep.chop();await create_timer(.20).timeout;game.prep.tick(.6)
	check(game.prep.cuts==3 and not game.prep.board_meat.visible and game.prep.slices[2].visible,"Three contacts produce three separate pieces and exhaust the whole block")
	game.prep.commit_board();game.prep.stock[1]=5;game._select(1);game.prep.stock[2]=5;game._select(2,true);game.prep.tick(.5);start();game.prep.put_ready_in_pot(0);advance(3.18)
	var stock_before=game.prep.stock[1];click(game.prep.ready_rect(1).get_center())
	check(game.prep.egg_pending() and game.prep.stock[1]==stock_before and not game.simmer.portions.has(1),"Clicking prepared egg begins flight without stock charge or doneness")
	game.v5.make_food_ghost(1,true)
	var egg_uv=game.v5.ghost.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	check(egg_uv[0].x>=2.0/3.0-.001 and egg_uv[0].y<=.501,"Dragging a prepared egg still shows the whole raw egg, not a meat slice")
	game.v5.ghost.queue_free();game.v5.ghost=null
	check(not game._select(1,true),"Repeated egg input cannot create another flight")
	advance(.32);check(not game.prep.cooking_fx.egg_mesh.visible and game.prep.cooking_fx.shells[0].visible,"Whole egg strikes the rim and opens into two shell pieces")
	check(not game.prep.ready_meshes[1].visible,"The egg leaves the prep board visually during its single flight")
	advance(.28);await shot("03_鸡蛋裂壳蛋液流入.png")
	check(not game.selected.has(1),"An egg still in the air does not count as an ingredient in the soup")
	advance(.22)
	check(game.selected.has(1) and game.prep.stock[1]==stock_before-1 and is_equal_approx(game.simmer.portions[1].added_at,4.0),"Egg liquid arrival charges one stock and records the exact landing timestamp")
	advance(.4);check(game.prep.cooking_fx.landed_count==1 and not game.prep.cooking_fx.egg_active,"Shell animation finishes without a second charge")
	advance(7.6);game.prep.put_ready_in_pot(2);advance(8)
	check(game.stage==5 and game.simmer.perfect,"Immediate beef, egg liquid at cell one and late greens still produce perfect noodles")
	var original=game.service.original_positions[0];game.perfect_fx.tick(.30)
	check(game.bowl.position.y-original.y>.45 and game.perfect_fx.DURATION>1.8,"Perfect bowl makes a larger elastic jump with an extended star burst")
	check(game.toppings[0].get_meta("large_bowl_portion",0)>1.25 and game.toppings[2].get_meta("large_bowl_portion",0)>1.25,"Every plated portion uses the enlarged ingredient geometry")
	await shot("04_大配料完美面星光.png");game.perfect_fx.stop()
	reset();game.prep.stock[1]=5;game._select(1);start();game._select(1,true);advance(.3);game._reset_bowl();advance(1)
	check(game.prep.stock[1]==5 and not game.selected.has(1) and not game.prep.egg_pending(),"Reset during egg flight cancels cleanly with no inventory loss")
	reset();game.prep.stock[1]=5;game._select(1);start();game._select(1,true);game.prep.return_prepared(1);advance(1)
	check(game.prep.stock[1]==5 and not game.selected.has(1),"Returning the prepared egg cancels its pending flight")
	reset();start();advance(19.3);check(not game._select(1,true) and game.prep.stock[1]==5,"An egg that cannot land before the fixed finish stays in inventory")
	reset();game.prep.stock[1]=5;game._select(1);start();game._select(1,true);advance(.2)
	var pending_save=game.prep.to_save().duplicate(true);game.prep.restore(pending_save)
	check(not game.prep.egg_pending() and game.prep.stock[1]==5 and game.prep.staged_food.has(1),"Reloading during an egg flight restores the uncharged prepared egg safely")
	reset();start();game.prep.stock[0]=2;game.prep.stock[2]=2;game.prep.stock[4]=2;game.prep.stock[5]=2
	game._select(0,true);game._select(2,true);game._select(4,true);game._select(1,true)
	check(not game._select(5,true) and game.food_count()==3,"An egg in flight reserves the fourth slot against a fifth ingredient")
	var before_pause=game.prep.cooking_fx.egg_age;game.help_panel.show();advance(1);game.help_panel.hide()
	check(game.prep.cooking_fx.egg_age==before_pause and game.simmer.elapsed==0,"Opening help pauses both egg flight and cooking clock together")
	advance(.82);check(game.food_count()==4 and game.prep.stock[1]==4,"The reserved egg lands as precisely the fourth ingredient")
	reset();game.fieldlife.cold.show()
	for i in range(game.fieldlife.cold_slots.size()):
		game.simmer.pointer=game.fieldlife.cold_slots[i].get_global_rect().get_center();game.simmer.refresh()
		check(game.simmer.hovered_id==game.fieldlife.COLD_IDS[i],"Refrigerator slot %d exposes the right ingredient's doneness"%i)
	game.fieldlife.close_fridge()
	for id in [15,16]:
		reset();game.prep.stock[id]=3;game.v5.put_meat_on_board(id)
		check(game.prep.board_item==id and game.prep.board_meat.material_override.get_shader_parameter("art").resource_path.ends_with("hunt_regional_meat.png"),"New regional meat %d uses its own whole atlas"%id)
		for i in range(3):game.prep.chop();await create_timer(.20).timeout;game.prep.tick(.6)
		game.prep.commit_board();game.v5.make_food_ghost(id,true)
		check(atlas(game.v5.ghost,"hunt_regional_meat.png",id-15),"New regional cut meat %d keeps its atlas column when dragged"%id)
		game.v5.ghost.queue_free();game.v5.ghost=null
		start();advance(game.simmer.insert_at(id)*4);game.prep.put_ready_in_pot(id);advance(game.simmer.target(id)*4)
		check(game.stage==5 and game.simmer.perfect and atlas(game.toppings[id],"hunt_regional_meat.png",id-15),"New meat %d reaches its own perfect target and plates with matching art"%id)
		await shot("05_区域肉成品"+str(id)+".png")
	var result={"suite":"kitchen_v10","runtime":"Godot Windows native OpenGL","passed":checks.size()-failures,"failed":failures,"checks":checks}
	var f=FileAccess.open("user://qa_verify_kitchen_v10_result.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	print("KITCHEN10_COMPLETE ",checks.size()," checks; failures=",failures);game._shutdown()
