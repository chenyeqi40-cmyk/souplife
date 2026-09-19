@tool
extends EditorScript

func _run() -> void:
	var core=load("res://scripts/blender_sync_core.gd").new()
	core.sync_meshes()
