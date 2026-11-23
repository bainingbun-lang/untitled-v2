extends SceneTree

var fails := 0


func _expect(ok: bool, msg: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + msg)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	GameConfig.right_pocket = "machete"
	var root := Node3D.new()
	get_root().add_child(root)
	var player := (load("res://player/xr_player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	for i in 10:
		await process_frame
	var obj = player.holster_right.picked_up_object
	_expect(obj != null and obj.name == "XR_machete", "funda derecha tiene el machete")
	var m: Node3D = obj
	var dummy := Node3D.new()
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar hp := 100.0\nfunc take_damage(a, _p = Vector3.ZERO, _s = null, _z = \"\"):\n\thp -= a\n"
	s.reload()
	dummy.set_script(s)
	root.add_child(dummy)
	var slow: Dictionary = m.cut(dummy, Vector3(0, 1, 0), Vector3(0.5, 0, 0))
	_expect(slow.is_empty() and dummy.hp == 100.0, "golpe lento no corta")
	var fast: Dictionary = m.cut(dummy, Vector3(0, 1, 0), Vector3(6, 0, 0))
	_expect(not fast.is_empty() and dummy.hp < 100.0, "golpe rapido corta y daña (hp %.1f)" % dummy.hp)
	print("RESULTADO: ", "OK" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails else 0)
