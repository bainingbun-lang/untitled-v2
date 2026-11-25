extends SceneTree

func _init() -> void:
	await process_frame
	var ok = await MapLoader.go(self, "res://maps/downloaded/school/school_map.tscn")
	print("PASS cargo" if ok else "FAIL cargo")
	var bad = await MapLoader.go(self, "res://no_existe.tscn")
	print("PASS rechaza inexistente" if not bad else "FAIL inexistente")
	for i in 5:
		await process_frame
	print("PASS escena actual: ", current_scene.name if current_scene else "ninguna")
	quit(0 if ok and not bad else 1)
