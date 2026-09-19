@tool
extends RefCounted

func sync_meshes() -> void:
	var path="res://房车场景.tscn"
	var source: Node3D=load("res://assets/rv_layers.glb").instantiate()
	var target: Node3D=load(path).instantiate()
	var synced=0
	for source_mesh in source.find_children("*","MeshInstance3D",true,false):
		var destination=target.find_child(source_mesh.name,true,false)
		if destination is MeshInstance3D:
			destination.mesh=source_mesh.mesh.duplicate()
			for surface in range(destination.mesh.get_surface_count()): destination.mesh.surface_set_material(surface,null)
			destination.transform=source_mesh.transform
			synced+=1
	for node in target.find_children("*","",true,false): node.owner=target
	if synced==0:
		push_error("No matching paper meshes found. Keep the original Blender object names.")
	else:
		var backup=FileAccess.open(path+".bak",FileAccess.WRITE)
		backup.store_string(FileAccess.get_file_as_string(path))
		backup.close()
		var scene=PackedScene.new()
		if scene.pack(target)==OK:
			ResourceSaver.save(scene,path)
			print("Blender sync complete: ",synced," paper meshes. Reopen the scene to refresh the editor.")
	source.free()
	target.free()
