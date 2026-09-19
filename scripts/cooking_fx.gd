extends Control
# Egg stock is charged only at the moment the liquid reaches the soup.
const EGG_LAND=.82
var game
var egg_age=0.0
var egg_active=false
var egg_landed=false
var egg_origin=Vector2.ZERO
var egg_mesh:MeshInstance3D
var shells=[]
var landed_count=0
var crack_point=Vector2(386,491)
func setup(g):
	game=g;mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(1280,714);z_index=49
	egg_mesh=game.prep._sprite("EggToPotRim","prep_atlas.png",2,2,Rect2(0,0,57,71),2.95)
	for i in range(2):
		var m=game.prep._sprite("CrackedEggShell"+str(i),"prep_atlas.png",2,2,Rect2(0,0,29,62),2.96,Rect2(.12+i*.38,.10,.38,.83))
		shells.append(m)
	cancel_egg()
func begin_egg()->bool:
	if egg_active or game.stage!=3 or game.selected.has(1):return false
	if not game.simmer.started or game.simmer.finished:return false
	if game.simmer.elapsed+EGG_LAND>=20:
		game._notice("这锅快出锅了，鸡蛋留给下一碗。")
		return false
	egg_origin=game.prep.ready_rect(1).get_center() if game.prep.staged_food.has(1) else Vector2(973,650)
	egg_age=0;egg_active=true;egg_landed=false;egg_mesh.show()
	game.prep._place(egg_mesh,egg_origin,2.95);queue_redraw()
	return true
func cancel_egg():
	egg_active=false;egg_landed=false
	if egg_mesh:egg_mesh.hide();egg_mesh.rotation.z=0
	for m in shells:m.hide();m.rotation.z=0
	queue_redraw()
func tick(delta:float):
	if not egg_active:return
	if game.stage!=3 or not game.v4.has_water:cancel_egg();return
	if game.simmer.cooking_paused():return
	var previous=egg_age;egg_age+=delta
	var flight=clampf(egg_age/.32,0,1)
	game.prep._place(egg_mesh,egg_origin.lerp(crack_point,flight)+Vector2(0,-sin(flight*PI)*70),2.95)
	egg_mesh.rotation.z=-.4*flight
	if egg_age>=.32:
		egg_mesh.hide()
		if previous<.32:game.audio.play_at("egg",-.35,-9)
		var split=clampf((egg_age-.32)/.28,0,1)
		for i in range(2):
			shells[i].show();shells[i].rotation.z=(-1 if i==0 else 1)*split*.5
			game.prep._place(shells[i],crack_point+Vector2((-1 if i==0 else 1)*(7+split*19),-split*8),2.96)
	if not egg_landed and egg_age>=EGG_LAND:
		var landing_time=game.simmer.elapsed+clampf(EGG_LAND-previous,0,delta)
		if landing_time>=20:cancel_egg();return
		egg_landed=true
		if game._select(1,true,true):
			game.simmer.portions[1].added_at=landing_time
			landed_count+=1;game._save()
		else:cancel_egg();return
	if egg_age>=1.12:cancel_egg()
	queue_redraw()
func _draw():
	if not egg_active or egg_age<.32 or egg_age>1.04:return
	if game.simmer.cooking_paused():return
	var open=clampf((egg_age-.32)/.24,0,1)
	var end=crack_point.lerp(Vector2(424,530),clampf((egg_age-.43)/.39,0,1))
	if egg_age>.43:
		var points=PackedVector2Array([crack_point+Vector2(-4*open,10),crack_point+Vector2(4*open,10),end+Vector2(7,0),end+Vector2(-7,0)])
		draw_colored_polygon(points,Color("f4ead0"))
		var yolk=crack_point.lerp(Vector2(424,530),clampf((egg_age-.50)/.32,0,1)).snapped(Vector2(2,2))
		draw_rect(Rect2(yolk-Vector2(7,6),Vector2(14,12)),Color("efa73d"))
		draw_rect(Rect2(yolk-Vector2(4,5),Vector2(6,3)),Color("ffe28a"))
	# Jagged shell split accompanies the two real atlas halves.
	if egg_age<.48:draw_polyline(PackedVector2Array([crack_point+Vector2(-9,-7),crack_point+Vector2(-3,-3),crack_point+Vector2(-7,2),crack_point+Vector2(2,5),crack_point+Vector2(-1,11)]),Color("785946"),2,false)
