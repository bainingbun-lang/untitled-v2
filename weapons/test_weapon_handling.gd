extends SceneTree

var _checks := 0
var _failures: Array = []


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _initialize() -> void:
	await process_frame
	_expect(load("res://weapons/vr_two_handed.gd").can_instantiate(), "vr_two_handed.gd compila")
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var ak = load("res://weapons/ak47.tscn").instantiate()
	scene.add_child(ak)
	for _i in 3:
		await physics_frame  # el arma marca physics_ready en su primer frame de física
	var actions: Array = []
	ak.weapon_action.connect(func(a): actions.append(a))
	ak.draw()

	_case_loaded(ak)
	_case_fire(ak, actions)
	_case_reload(ak, actions)
	_case_zones()

	scene.free()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for f in _failures:
			print("FAIL: " + f)
		quit(1)


func _case_loaded(ak) -> void:
	_expect(ak.reload.total_rounds() == 30, "AK cargado: 29 + 1 en recamara")
	var shot := ak.get_node_or_null("ShotSound") as AudioStreamPlayer3D
	_expect(shot != null and shot.stream != null, "ShotSound con stream")
	_expect(shot.stream.resource_path == "res://weapons/ak47/ak47_shot.wav", "usa ak47_shot.wav")
	var muzzle: Vector3 = ak.get_node("Pivot/Smoke_spawn_point").position
	_expect(muzzle.z < -0.4, "boca del canon en -Z")


func _case_fire(ak, actions: Array) -> void:
	ak._next_fire_ms = 0
	ak.action()
	_expect(actions.has("Fire"), "dispara")
	_expect(ak.get_node("ShotSound").playing, "suena al disparar")
	_expect(ak.reload.total_rounds() == 29, "gasta una bala")
	actions.clear()
	ak.action()
	_expect(not actions.has("Fire"), "cadencia limita disparo inmediato")


func _case_reload(ak, actions: Array) -> void:
	var h: WeaponHandling = ak.get_node("Handling")
	var mag: Vector3 = ak.get_node("Pivot/Magazine").position
	var handle: Vector3 = ak.get_node("Pivot/ChargingHandle").position
	_expect(h.step(mag, true) == "eject_magazine", "grip en cargador lo expulsa")
	h.step(mag, false)
	_expect(not ak.reload.magazine_in, "sin cargador")
	_expect(h.step(mag, true) == "insert_magazine", "segundo grip inserta cargador")
	h.step(mag, false)
	_expect(ak.reload.magazine_in and ak.reload.magazine_rounds == 30, "cargador lleno")
	ak.reload.chambered = false
	_expect(h.step(handle, true) == "", "agarrar manija no recarga aun")
	_expect(h.step(handle + Vector3(0, 0, 0.03), true) == "", "medio recorrido no recarga")
	_expect(h.step(handle + Vector3(0, 0, 0.08), true) == "rack_slide", "tirar atras recarga")
	_expect(h.step(handle + Vector3(0, 0, 0.09), true) == "", "una sola recarga por tiron")
	h.step(handle, false)
	_expect(ak.is_chambered() and ak.reload.magazine_rounds == 29, "bala en recamara")
	ak.spare_magazines = 0
	ak.eject_magazine()
	_expect(not ak.insert_magazine(), "sin cargadores de repuesto no inserta")


func _case_zones() -> void:
	var m := Vector3(0, -0.08, -0.125)
	var c := Vector3(0.03, 0.04, -0.12)
	_expect(WeaponHandling.zone_for(m, m, c, 0.07) == "magazine", "zona cargador")
	_expect(WeaponHandling.zone_for(c, m, c, 0.07) == "handle", "zona manija")
	_expect(WeaponHandling.zone_for(Vector3(0, 0, -0.28), m, c, 0.07) == "", "foregrip fuera de zonas")
	_expect(is_equal_approx(WeaponHandling.rack_progress(Vector3.ZERO, Vector3(0, 0, 0.035), 0.07), 0.5), "progreso 50%")
