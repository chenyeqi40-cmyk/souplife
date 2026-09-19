extends Control
var field

func _draw():
	if not field or not field.armed:return
	if not field.scope_active:_draw_mechanism()
	for casing in field.casings:
		draw_set_transform(casing.position,casing.age*11)
		draw_rect(Rect2(-5,-2,10,4),Color("b18141"))
		draw_rect(Rect2(-5,-2,2,4),Color("f3d28b"))
		draw_rect(Rect2(-3,-2,7,1),Color("e8bb67"))
		draw_set_transform(Vector2.ZERO)
	for impact in field.impact_marks:
		var p=field.world_to_lens(impact.point)
		var opacity=maxf(0,1-impact.age/.28)
		var radius=13+impact.age*64
		for direction in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
			draw_line(p+direction*radius*.38,p+direction*radius,Color(1,.87,.53,opacity),3)
	_draw_down_eyes()
	if field.scope_active:
		_draw_scope()
	elif field.ARENA.has_point(field.pointer):
		var p=field.pointer
		draw_arc(p,14,0,TAU,24,Color("e8ca9c"),2)
		draw_line(p+Vector2(-20,0),p+Vector2(-9,0),Color("e8ca9c"),2)
		draw_line(p+Vector2(9,0),p+Vector2(20,0),Color("e8ca9c"),2)
		var tip=Vector2(clampf(p.x+20,60,1040),clampf(p.y-18,150,590))
		draw_string(field.game.font,tip,"右键开镜",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff0c8"))
	_draw_bag()

func _draw_down_eyes():
	# The down frame already contains X eyes. Reinforce the same expression
	# after minification so that the tiny remote face remains readable in scope.
	for target in field.targets:
		if target.fall_age<.36 or target.pic.modulate.a<.05:continue
		var rect=target.pic.get_global_rect()
		var texture_size=target.pic.texture.get_size()
		var fit=minf(rect.size.x/texture_size.x,rect.size.y/texture_size.y)
		var displayed=texture_size*fit
		var u=.86 if target.get("region",0)==0 else .82 if target.get("region",0)==1 else .77
		var v=.71 if target.get("region",0)==0 else .77 if target.get("region",0)==1 else .65
		var eye=rect.position+(rect.size-displayed)*.5+displayed*Vector2(1.0-u if target.pic.flip_h else u,v)
		eye=field.world_to_lens(eye)
		if field.scope_active and eye.distance_to(field.WINDOW.get_center())>field.SCOPE_RADIUS-10:continue
		var edge=5.0 if field.scope_active else 1.8
		var color=Color(.11,.12,.08,target.pic.modulate.a)
		draw_line(eye-Vector2(edge,edge),eye+Vector2(edge,edge),color,3 if field.scope_active else 1)
		draw_line(eye+Vector2(edge,-edge),eye+Vector2(-edge,edge),color,3 if field.scope_active else 1)

func _draw_scope():
	var center=field.WINDOW.get_center()
	var radius=field.SCOPE_RADIUS
	draw_arc(center,radius+8,0,TAU,96,Color("1d2525"),14)
	draw_arc(center,radius+4,0,TAU,96,Color("616967"),3)
	draw_arc(center,radius-2,0,TAU,96,Color("151d1d"),4)
	var ink=Color("2e3029")
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		draw_line(center+direction*10,center+direction*(radius-6),ink,2)
		for distance in [54,108,162]:
			var side=Vector2(-direction.y,direction.x)*5
			var p=center+direction*distance
			draw_line(p-side,p+side,ink,2)
	var ready=field.cooldown<=0 and field.bolt_age<0 and field.ammo>0
	var red=Color("e25e4e") if ready else Color("d7b47c")
	draw_arc(center,7,0,TAU,16,red,2)
	draw_rect(Rect2(center-Vector2(1,1),Vector2(3,3)),red)
	draw_string(field.game.font,center+Vector2(-36,radius-28),"3.2 ×",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d6dfc5"))
	if field.muzzle_time>0:draw_arc(center,radius-7,PI*.1,PI*.88,36,Color(1,.77,.39,.8),5)
	if field.bolt_age>=0:
		draw_string(field.game.font,Vector2(1080,667),"上膛中",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e2cda4"))

func _draw_mechanism():
	# The gun, bolt, recoil, reload and shell ejection use no hands or arms.
	var breech=field.rifle_point(Vector2(.57,.38))
	var action=sin(clampf((field.bolt_age-.08)/.35,0,1)*PI) if field.bolt_age>=0 else 0.0
	if field.reload_remaining>0:action=sin((1-field.reload_remaining/field.RELOAD_SECONDS)*PI)
	if action>.01:
		draw_set_transform(breech,field.rifle.rotation+.40)
		draw_rect(Rect2(-18,-7,40,14),Color("293130"))
		draw_rect(Rect2(-16+action*16,-6,23,10),Color("96978b"))
		draw_rect(Rect2(-15+action*16,-6,21,3),Color("d1cfc0"))
		draw_rect(Rect2(2+action*16,3,7,10),Color("444b47"))
		draw_set_transform(Vector2.ZERO)
	if field.muzzle_time>0:
		var muzzle=field.rifle_point(Vector2(.14,.075))
		var flame=PackedVector2Array([muzzle+Vector2(-35,-20),muzzle+Vector2(-8,-16),muzzle+Vector2(-11,-27),muzzle+Vector2(3,-7),muzzle+Vector2(16,3),muzzle+Vector2(-7,3),muzzle+Vector2(-19,11),muzzle+Vector2(-16,-4)])
		draw_colored_polygon(flame,Color("f5cf83"))
		draw_rect(Rect2(muzzle-Vector2(8,7),Vector2(10,7)),Color("fff0bc"))

func _draw_bag():
	var icon=["00003333300000","00034444430000","00334444433000","03444444444300","03443333344300","03435555534300","33435555534330","34433333333443","34444444444443","34443333334443","34435555553443","34435555553443","03433333333430","00333333333300"]
	var palette={"3":Color("394038"),"4":Color("b5a272"),"5":Color("ded4ac")}
	var scale=3.0+field.bag_bounce*.35
	var origin=field.LOOT_BAG-Vector2(21,21)-Vector2(0,field.bag_bounce*4)
	for y in range(icon.size()):
		for x in range(icon[y].length()):
			var key=icon[y][x]
			if palette.has(key):draw_rect(Rect2(origin+Vector2(x,y)*scale,Vector2.ONE*scale),palette[key])
	for toast in field.loot_toasts:
		var fade=1.0-clampf((toast.age-1.0)/.7,0,1)
		var pos=field.LOOT_BAG+Vector2(-234,-30-toast.row*24-toast.age*16)
		var color=Color(1.0,.66,.46,fade) if toast.get("rare",false) else Color(.91,.91,.72,fade)
		draw_string(field.game.font,pos,toast.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,color)
