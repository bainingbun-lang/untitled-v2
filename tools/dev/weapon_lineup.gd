extends SceneTree

func _init() -> void:
	await process_frame
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	root3d.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	root3d.add_child(light)
	var ids := ["pistol", "smg", "ak47", "shotgun", "sniper", "barrett"]
	for i in ids.size():
		var w := (load("res://weapons/xr_%s.tscn" % ids[i]) as PackedScene).instantiate()
		root3d.add_child(w)
		(w as Node3D).position = Vector3(0, -i * 0.5 + 1.2, 0)
		if w is RigidBody3D:
			(w as RigidBody3D).freeze = true
		var l := Label3D.new()
		l.text = ids[i]
		l.pixel_size = 0.003
		l.position = Vector3(0, -i * 0.5 + 1.2 + 0.18, 0.55)
		root3d.add_child(l)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.position = Vector3(3.2, -0.2, 0)
	cam.look_at(Vector3(0, -0.2, 0))
	cam.fov = 38
	get_root().size = Vector2i(1000, 1100)
	for i in 6:
		await process_frame
	get_root().get_texture().get_image().save_png("/data/data/com.termux/files/usr/tmp/vrsim/lineup.png")
	quit()
