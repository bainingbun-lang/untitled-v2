extends SceneTree

func _init() -> void:
	await process_frame
	var root := Node3D.new()
	get_root().add_child(root)
	var player := (load("res://player/xr_player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	for i in 10:
		await process_frame
	var fails := 0
	for z in [player.holster_right, player.holster_left]:
		var obj = z.picked_up_object
		print("funda ", z.name, " -> ", obj.name if obj else "VACIA")
		if obj == null:
			fails += 1
	print("RESULTADO: ", "OK, 0 fallos" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails else 0)
