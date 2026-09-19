extends Node
# Local artwork patches leave all original counter footprints and interactions in place.
var game
var radio:MeshInstance3D
var board:MeshInstance3D
var closed_bin:MeshInstance3D
var open_bin:MeshInstance3D
var pointer=Vector2.ZERO
var lid_amount=0.0
var lid_open=false
func setup(g):
	game=g
	if ResourceLoader.exists("res://assets/cabin_details_v10.png"):
		radio=_patch("GreyRetroCabinetRadio",Rect2(779,0,133,87),1.04)
		board=_patch("ThinOriginalCuttingBoard",Rect2(565,535,257,123),1.18)
	var previous=game.world.find_child("LargePerspectiveWasteBin",true,false)
	if previous:previous.hide()
	game.service.trash.hide()
	if ResourceLoader.exists("res://assets/trash_clean.png"):
		closed_bin=_bin("CleanWasteBinClosed",Rect2(278.0/1774,114.0/887,409.0/1774,666.0/887))
		open_bin=_bin("CleanWasteBinOpen",Rect2(1092.0/1774,114.0/887,409.0/1774,666.0/887))
		open_bin.hide()
func _patch(label:String,r:Rect2,depth:float)->MeshInstance3D:
	var mesh=game.prep.reference_piece(label,r,Rect2(r.position/Vector2(1280,714),r.size/Vector2(1280,714)),depth)
	mesh.material_override.set_shader_parameter("art",load("res://assets/cabin_details_v10.png"))
	return mesh
func _bin(label:String,uv:Rect2)->MeshInstance3D:
	var mat=game._paper_material("trash_clean.png");mat.set_shader_parameter("magenta_key",true)
	return game._quad(label,Rect2(1155*1.2265625,575*1.2265625,132*1.2265625,220*1.2265625),2.15,mat,uv)
func _input(event):
	if event is InputEventMouseMotion or event is InputEventMouseButton:pointer=event.position
func tick(delta:float):
	if not open_bin:return
	var wanted=game.stage==5 and game.v5.kind=="bowl" and game.v5.moved and game.service.TRASH_AREA.has_point(pointer) and game.prep.input_allowed()
	lid_amount=move_toward(lid_amount,1.0 if wanted else 0.0,delta*9)
	var is_open=lid_amount>.35
	if is_open!=lid_open:
		lid_open=is_open;game.audio.play_at("tap",.85,-18)
	open_bin.visible=is_open;closed_bin.visible=not is_open
