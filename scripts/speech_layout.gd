extends RefCounted

static func fit(panel:Panel,label:Label,top:float=13.0,max_width:float=244.0,footer:float=0.0)->float:
	var font=label.get_theme_font("font")
	var font_size=label.get_theme_font_size("font_size")
	var longest=0.0
	for line in label.text.split("\n"):
		longest=maxf(longest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
	var width=clampf(ceil(longest)+8.0,164.0,max_width)
	# Shape the actual Label at its final width. Font's generic multiline
	# measurement does not use this Label's smart wrapping or line spacing.
	label.size.x=width
	var lines=label.get_line_count()
	var text_height=0.0
	for line in range(lines):
		text_height+=label.get_line_height(line)
	var spacing=float(label.get_theme_constant("line_spacing"))
	var paragraph_spacing=float(label.get_theme_constant("paragraph_spacing"))
	if label.label_settings:
		spacing=label.label_settings.line_spacing
	text_height+=maxi(0,lines-1)*spacing
	text_height+=maxi(0,label.text.split(label.paragraph_separator).size()-1)*paragraph_spacing
	text_height=maxf(text_height,label.get_minimum_size().y)
	var height=maxf(24.0,ceil(text_height)+12.0)
	label.position=Vector2(13,top);label.size=Vector2(width,height)
	panel.size=Vector2(width+26,top+height+13.0+footer)
	return top+height
