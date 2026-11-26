extends SceneTree

var _fails := 0


func _expect(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fails += 1


func _init() -> void:
	await process_frame
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	root.add_child(mi)
	mi.global_position = Vector3(2, 0, 0)
	var uv := DamageUV.uv_at_point(mi, Vector3(2, 0, 0))
	_expect(uv != Vector2(-1, -1) and uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0, "uv en [0,1] (%s)" % str(uv))
	_expect(uv.distance_to(Vector2(0.5, 0.5)) < 0.01, "centro del quad = (0.5,0.5)")
	_expect(DamageUV.uv_at_point(MeshInstance3D.new(), Vector3.ZERO) == Vector2(-1, -1), "sin malla = (-1,-1)")
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)
