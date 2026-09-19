extends SceneTree
var checks=[]
var game
var field
var output="user://qa_verify_hunt_v10"
func check(name:String,condition:bool):
	checks.append({"name":name,"passed":condition});print(("PASS " if condition else "FAIL ")+name)
func tick_for(seconds:float):
	for i in range(int(seconds/.02)):game.elapsed+=.02;field.tick(.02)
func snapshot(name:String):
	field.hunt_paint.queue_redraw();await process_frame;await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/"+name+".png")
func aim_at(target:Dictionary)->Vector2:
	var rect=target.pic.get_global_rect()
	for fy in [.62,.72,.55,.82,.45]:
		for fx in [.52,.62,.43,.72,.33]:
			var point=rect.position+rect.size*Vector2(fx,fy);field.pointer=point
			if field.scope_aim().is_equal_approx(point) and field._target_hit(target,point):return point
	return rect.get_center()
func close_day():
	game.day_cycle.phase=game.day_cycle.Phase.CLOSED;game.day_cycle.current_guest_id=""
	for who in game.day_cycle.day_roster:game.day_cycle.visited_today[who]=true
	game.day_cycle.dismiss_management();game.day_cycle.refresh();game.character.hide()
func verify_fresh_instance():
	var before=game.prep.stock[11]
	field.active_region=0;field._spawn_drop(11,Vector2(500,490));game._save()
	var fresh=load("res://main.tscn").instantiate();fresh.save_path=game.save_path;root.add_child(fresh)
	fresh.set_process(false)
	check("全新实例读档不会在恢复中覆盖待结算猎获",fresh.fieldlife.drops.size()>0 and JSON.parse_string(FileAccess.get_file_as_string(game.save_path)).fieldlife.pending.size()>0)
	fresh.fieldlife.tick(.02)
	check("全新实例恢复旧猎场及待结算库存",fresh.prep.stock[11]==before+1 and fresh.fieldlife.capacity()==10 and not fresh.fieldlife.encounters.is_empty())
	fresh.audio.shutdown();await create_timer(.10).timeout;fresh.queue_free();fresh=null;await process_frame
func _initialize():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	game=load("res://main.tscn").instantiate();game.save_path="user://qa_hunt_v10_"+str(Time.get_ticks_usec())+".json";root.add_child(game)
	await process_frame
	game.qa_mode=true;game.qa_save_enabled=true;game.set_process(false);game.title_screen.hide();game.sound_off=true;game.audio.tick(1)
	game.auto_time=false;game.auto_weather=false;game.tutorial.active=false;game.tutorial.overlay.hide();game.v5.transition="";game.v5.customer_offset=0
	game.stage=0;game.selected.clear();game.prep.clear_board();game.economy.map_index=0
	field=game.fieldlife;game.economy.upgrades.erase("magazine_8");game.economy.upgrades.erase("magazine_10")
	check("新游戏弹夹默认6发",field.ammo==6 and field.capacity()==6)
	field.restore({"loot_version":3,"ammo":3});check("旧3发满弹夹迁移为6发满弹夹",field.ammo==6)
	field.restore({"loot_version":3,"ammo":1});check("旧部分弹药保留余弹",field.ammo==1)
	field.restore({"loot_version":3,"ammo":0});check("旧空弹夹不会凭空补弹",field.ammo==0)
	field.restore({});check("无旧数据时默认6发",field.ammo==6)
	field.open_hunt();check("营业期间仍拒绝猎场",not field.hunt.visible)
	close_day();field.travel_seed=18
	field.open_hunt();check("出发是完整原营业视角且锁定射击",field.drive_scene.scale==Vector2.ONE and field.drive_scene.position==Vector2.ZERO and field.phase=="driving" and not field.shoot(Vector2(500,400)))
	tick_for(1.5);await snapshot("01_六发猎枪出发仍保留房车")
	tick_for(1.6);check("停稳前推阶段也不能开镜或开枪",field.phase=="approaching" and not field.armed)
	field.set_scoped(true);check("镜头前推期间禁用开镜",not field.scope_active)
	tick_for(1.5);check("沙地仍有6至7只蜥蜴",field.targets.size() in [6,7] and field.targets.all(func(a):return a.region==0))
	var starting_total=field.targets.size();var point=aim_at(field.targets[0])
	var old_ammo=field.ammo;check("不开镜不消耗弹药",not field.shoot(point) and field.ammo==old_ammo)
	field.pointer=point;field.set_scoped(true)
	var first=field.targets[0];var old_stock=game.prep.stock[14 if first.rare else 11]
	check("开镜仍命中原蜥蜴并扣一发",field.shoot(point) and field.ammo==5)
	var accepted=0
	for i in range(50):
		if field.shoot(point):accepted+=1
	check("连续调用不能无限连发",accepted==0 and field.ammo==5 and field.shots==1)
	tick_for(.8);await snapshot("02_蜥蜴受击与6发余弹")
	tick_for(1.1);check("普通或稀有蜥肉仍自动到账",game.prep.stock[14 if first.rare else 11]==old_stock+1)
	# Isolate the magazine edge case while the original world continues running.
	field.ammo=1;field.cooldown=0;field.bolt_age=-1;field.pointer=Vector2(610,260);field.set_scoped(true)
	check("最后一发打空也扣弹保存",not field.shoot(Vector2(610,260)) and field.ammo==0 and JSON.parse_string(FileAccess.get_file_as_string(game.save_path)).fieldlife.ammo==0)
	check("上膛未完成时不能连开枪",not field.shoot(Vector2(610,260)) and field.reload_remaining==0)
	tick_for(.56);check("弹夹打空后自动换弹并收镜",field.reload_remaining>0 and not field.scope_active)
	var reload_age=field.reload_remaining;field.begin_reload();check("重复换弹不会重置换弹时长",field.reload_remaining==reload_age)
	await snapshot("03_打空自动换弹")
	field.set_scoped(true);check("换弹时禁止重新开镜和射击",not field.scope_active and not field.shoot(Vector2(610,260)))
	tick_for(1.10);check("自动装满6发且落盘",field.ammo==6 and field.reload_remaining==0 and JSON.parse_string(FileAccess.get_file_as_string(game.save_path)).fieldlife.ammo==6)
	field.ammo=4;check("R接口支持提前换弹",field.begin_reload());tick_for(1.10);check("提前换弹装至当前容量",field.ammo==6)
	game.economy.upgrades.append("magazine_8");check("8发升级正确读取商店状态",field.capacity()==8);field.begin_reload();tick_for(1.10);check("升级后换弹装满8发",field.ammo==8)
	game.economy.upgrades.append("magazine_10");check("10发升级优先于8发",field.capacity()==10);field.begin_reload();tick_for(1.10);check("升级后换弹装满10发",field.ammo==10)
	await snapshot("04_十发扩容与自动换弹")
	tick_for(25);check("蜥蜴全部离场后有明确空猎场提示",field.empty_announced and field.hunt_note.text.contains("暂时不会有蜥蜴来了"))
	check("空猎场不自动补新猎物",field.targets.size()==starting_total and field.targets.all(func(a):return not a.alive))
	await snapshot("05_蜥蜴猎场耗尽提示")
	field.leave_hunt();var stable_stock=game.prep.stock.duplicate();field.open_hunt();tick_for(4.6)
	check("同一天重复进出不会重刷蜥蜴",field.targets.is_empty() and field.empty_announced and game.prep.stock==stable_stock);field.leave_hunt()
	for region in [1,2]:
		game.economy.map_index=region;field.open_hunt();tick_for(1.5)
		check("区域%d行车采用独立野外背景"%region,field.active_region==region and field.drive_material.get_shader_parameter("terrain").resource_path.ends_with("hunt_regions.png") and is_equal_approx(field.drive_material.get_shader_parameter("terrain_rect").x,(region-1)*.5))
		await snapshot("06_岩坡行车" if region==1 else "10_盐湖湿地行车")
		tick_for(3.1)
		check("区域%d只刷本区动物且不乱加植物共生"%region,field.targets.size() in [6,7] and field.targets.all(func(a):return a.region==region and not a.rare))
		var target=field.targets[0];var rect=target.pic.get_global_rect();var initial_frame=target.last_frame;tick_for(.22)
		check("区域%d有行走位移与两帧姿态"%region,target.pic.get_global_rect().position!=rect.position and target.last_frame!=initial_frame)
		point=aim_at(target);field.pointer=point;field.set_scoped(true)
		await snapshot("07_响石岩兔开镜" if region==1 else "11_盐帆泽鸭开镜")
		var id=15 if region==1 else 16;var before=game.prep.stock.duplicate()
		check("区域%d猎物可以瞄准命中"%region,field.shoot(point))
		check("区域%d待结算肉类ID和归属保存正确"%region,field.drops.size()==1 and field.drops[0].id==id and field.drops[0].region==region and JSON.parse_string(FileAccess.get_file_as_string(game.save_path)).fieldlife.pending[0].region==region)
		tick_for(.36);check("区域%d命中切换叉眼倒地帧"%region,target.last_frame==3)
		await snapshot("08_岩兔倒地叉眼" if region==1 else "12_泽鸭倒地叉眼")
		tick_for(.44);await snapshot("09_岩兔肉自动收获" if region==1 else "13_泽鸭肉自动收获")
		tick_for(1.1)
		check("区域%d肉类自动入包不串旧食材"%region,game.prep.stock[id]==before[id]+1 and game.prep.stock[11]==before[11] and game.prep.stock[8]==before[8])
		var granted=game.prep.stock[id];field._grant_drop(field.drops[0]);check("区域%d掉落重复回调幂等"%region,game.prep.stock[id]==granted)
		field.leave_hunt();field.open_hunt();tick_for(4.6)
		check("区域%d重进不会复活已猎获目标"%region,field.targets.size()<6 or field.targets.size()==6 and field.encounters[field.active_encounter_key].size()==6)
		tick_for(.02)
		# Trigger a miss to make the surviving herd flee without manufacturing rewards.
		field.pointer=Vector2(610,250);field.set_scoped(true);field.shoot(Vector2(610,250));tick_for(25)
		check("区域%d耗尽提示使用本区动物名称"%region,field.empty_announced and field.hunt_note.text.contains("暂时不会有"+field.HUNT_REGIONS[region].plural+"来了"))
		field.leave_hunt()
	game._save();var populations=field.encounters.duplicate(true);var stocks=game.prep.stock.duplicate();game._load_save();field.tick(.02)
	var herd_saved=field.encounters.keys()==populations.keys()
	for key in populations:
		herd_saved=herd_saved and field.encounters[key].size()==populations[key].size()
		for i in range(populations[key].size()):
			var before=populations[key][i];var after=field.encounters[key][i]
			herd_saved=herd_saved and before.alive==after.alive and before.rare==after.rare and absf(before.x-after.x)<.01 and absf(before.y-after.y)<.01
	check("完整读档保存三地区猎群且不串库存",herd_saved and game.prep.stock==stocks and field.capacity()==10 and field.ammo<=10)
	var before15=game.prep.stock[15];var before16=game.prep.stock[16]
	field.active_region=1;field._spawn_drop(15,Vector2(500,500));field.active_region=2;field._spawn_drop(16,Vector2(600,500));game._save()
	game._load_save();field.tick(.02);game._load_save();field.tick(.02)
	check("跨地区未完成飞行读档各到账一次",game.prep.stock[15]==before15+1 and game.prep.stock[16]==before16+1)
	var old={"loot_version":3,"hunted":2,"ammo":3,"pending":[{"uid":"v9:rare","id":14,"x":500,"y":500}]}
	var rare_before=game.prep.stock[14];field.restore(old);field.tick(.02);field.restore(old);field.tick(.02)
	check("V9稀有掉落旧存档仍幂等迁移",game.prep.stock[14]==rare_before+1)
	game.day+=1;game.economy.map_index=0;close_day();field.open_hunt();tick_for(4.6)
	check("新一天刷新猎群而非场内自动再生",field.targets.size() in [6,7] and not field.empty_announced)
	field.leave_hunt()
	check("六种冷藏食材与新肉图真实接入",field.COLD_IDS.size()==6 and game.prep.stock.size()==17 and field.food_icon(15).atlas.resource_path.ends_with("hunt_regional_meat.png") and field.food_icon(16).region.position.x>0)
	await verify_fresh_instance()
	var passed=true
	for row in checks:passed=passed and row.passed
	var file=FileAccess.open(output+"/V10猎场验收.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"checks":checks},"  "));file.close()
	print("HUNT_V10_QA "+str(checks.size())+" checks / "+str(passed));call_deferred("finish",passed)
func finish(passed:bool):
	game.audio.shutdown();await create_timer(.10).timeout;game.queue_free();game=null;field=null
	await process_frame;await process_frame;quit(0 if passed else 1)
