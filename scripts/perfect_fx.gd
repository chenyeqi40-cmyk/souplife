extends Control
var game
var age=2.0
var active=false
var trigger_count=0
const DURATION=1.95
func setup(g):
	game=g;mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(1280,714);z_index=54
func trigger():
	age=0;active=true;trigger_count+=1;queue_redraw()
func stop():
	if active and game.stage==5:game.service.restore_bowl()
	active=false;age=DURATION;queue_redraw()
func tick(delta:float):
	if not active:return
	if game.stage!=5 or game.v5.kind=="bowl":active=false;queue_redraw();return
	age+=delta
	if age>=DURATION:stop();return
	var lift=absf(sin(clampf(age/1.35,0,1)*PI*2.0))*exp(-age*1.15)*.78
	var meshes=[game.bowl]+game.toppings
	for i in range(meshes.size()):
		meshes[i].position=game.service.original_positions[i]+Vector3(0,lift,0)
	queue_redraw()
func _draw():
	if not active:return
	var alpha=clampf((DURATION-age)/.45,0,1)
	var centers=[Vector2(587,559),Vector2(820,550),Vector2(758,491),Vector2(627,493),Vector2(831,601),Vector2(690,470),Vector2(576,610),Vector2(779,616),Vector2(643,619)]
	for i in range(centers.size()):
		var local_age=age-float(i)*.08
		if local_age<0:continue
		var radius=(13+float(i%3)*6)*sin(clampf(local_age/.95,0,1)*PI)*alpha
		if radius<.5:continue
		var p=centers[i]+Vector2(0,-local_age*15)
		var points=PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius*.25,-radius*.25),p+Vector2(radius,0),p+Vector2(radius*.25,radius*.25),p+Vector2(0,radius),p+Vector2(-radius*.25,radius*.25),p+Vector2(-radius,0),p+Vector2(-radius*.25,-radius*.25)])
		draw_colored_polygon(points,Color(1,.87,.40,alpha))
		draw_rect(Rect2(p-Vector2(2,2),Vector2(4,4)),Color(1,1,.90,alpha))
