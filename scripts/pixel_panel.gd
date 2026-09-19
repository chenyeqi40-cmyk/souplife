extends Panel
var paper_color=Color.WHITE
var speech_tip=false:
	set(value):
		speech_tip=value
		if value:add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		queue_redraw()
func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
func _draw():
	if speech_tip:
		var x=round(size.x*.48)
		var points=PackedVector2Array([Vector2(4,2),Vector2(x-13,2),Vector2(x-13,-4),Vector2(x-8,-4),Vector2(x-8,-10),Vector2(x,-18),Vector2(x+8,-10),Vector2(x+8,-4),Vector2(x+13,-4),Vector2(x+13,2),Vector2(size.x-4,2),Vector2(size.x-1,5),Vector2(size.x-1,size.y-4),Vector2(size.x-4,size.y-1),Vector2(4,size.y-1),Vector2(1,size.y-4),Vector2(1,5)])
		var shadow=PackedVector2Array()
		for p in points:shadow.append(p+Vector2(4,5))
		draw_colored_polygon(shadow,Color(.08,.09,.09,.45))
		draw_colored_polygon(points,Color("f3ead1"))
		points.append(points[0]);draw_polyline(points,Color("272928"),3.0,false)
		return
	if size.x<175 or size.y<120 or paper_color.a<.95 or paper_color.get_luminance()<.45:return
	var header_bottom=37.0
	for child in get_children():
		if child is Label and child.position.y>=0 and child.position.y<28:
			header_bottom=maxf(header_bottom,minf(64,child.position.y+child.size.y+2))
	draw_rect(Rect2(7,7,size.x-14,header_bottom-8),Color("b9ab80"))
	draw_line(Vector2(7,header_bottom),Vector2(size.x-7,header_bottom),Color("494a40"),1)
	# Small desktop-window grip, away from the text on the left.
	for y in range(4):
		for x in range(2):
			draw_rect(Rect2(size.x-15+x*3,13+y*4,2,2),Color("343630"))
