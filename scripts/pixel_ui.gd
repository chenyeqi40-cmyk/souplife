extends RefCounted
# Code-native nine-slice frames: square pixels, double ink outline, dry paper.
static var cached={}
static func frame(bg:Color,border:Color,width:int)->StyleBoxTexture:
	var key=bg.to_html()+border.to_html()+str(width)
	if cached.has(key):return cached[key]
	var svg='<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" shape-rendering="crispEdges"><path d="M4 0H28V2H30V4H32V28H30V30H28V32H4V30H2V28H0V4H2V2H4Z" fill="#%s"/><path d="M4 2H28V4H30V28H28V30H4V28H2V4H4Z" fill="#f3ecd1"/><path d="M5 4H27V5H28V27H27V28H5V27H4V5H5Z" fill="#%s"/><path d="M6 6H26V26H6Z" fill="#%s"/><path d="M5 27H27V28H5ZM27 5H28V27H27Z" fill="#777264"/></svg>'%[border.to_html(false),border.to_html(false),bg.to_html(false)]
	if bg.a<.1:
		svg='<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" shape-rendering="crispEdges"><path d="M3 1H29V3H31V29H29V31H3V29H1V3H3Z" fill="none" stroke="#%s" stroke-width="2"/></svg>'%border.to_html(false)
	if bg.a>=.1 and bg.a<.999:
		svg=svg.replace('fill="#%s"'%bg.to_html(false),'fill="#%s" fill-opacity="%.3f"'%[bg.to_html(false),bg.a])
	var im=Image.new();im.load_svg_from_string(svg)
	var s=StyleBoxTexture.new();s.texture=ImageTexture.create_from_image(im);s.set_texture_margin_all(7);s.set_content_margin_all(0)
	s.axis_stretch_horizontal=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH;s.axis_stretch_vertical=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	cached[key]=s;return s
