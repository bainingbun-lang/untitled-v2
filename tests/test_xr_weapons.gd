extends SceneTree

## Armas xr-tools (weapons/xr_*.tscn): carga, agarre, disparo por señal del gatillo, cadencia,
## retroceso que se recupera, sacar/meter cargador y correr la corredera.
## Ejecutar: godot --headless --path . --script res://tests/test_xr_weapons.gd
const IDS := ["pistol", "ak47", "sniper", "barrett", "shotgun", "smg"]
var _fails := 0


func _init() -> void:
	await process_frame
	var target := StaticBody3D.new()
	var tcol := CollisionShape3D.new()
	var tbox := BoxShape3D.new()
	tbox.size = Vector3(3, 3, 0.5)
	tcol.shape = tbox
	target.add_child(tcol)
	target.position = Vector3(0, 0, -3)
	root.add_child(target)
	var hand = load("res://addons/godot-xr-tools/functions/function_pickup.gd").new()
	root.add_child(hand)
	hand.set_process(false) # sin XRController3D en headless
	for id in IDS:
		await _check(id, hand, target)
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)


func _check(id: String, hand: Node3D, target: Node) -> void:
	var packed := load("res://weapons/xr_%s.tscn" % id) as PackedScene
	_expect(packed != null, "%s: la escena carga" % id)
	if packed == null:
		return
	var gun = packed.instantiate()
	gun.freeze = true
	root.add_child(gun)
	for i in 5:
		await physics_frame
	_expect(gun.is_xr_class("XRToolsPickable"), "%s: es XRToolsPickable" % id)
	_expect(gun.get_node("GripR").handle == "Grip", "%s: empuñadura con handle Grip" % id)
	var box: BoxShape3D = gun.get_node("CollisionShape3D").shape
	_expect(box.size.x > 0.0 and box.size.z > box.size.x, "%s: caja de colisión alineada (larga en Z)" % id)
	var well = gun.get_node("MagazineWell")
	var mag = gun.get_node("Magazine")
	var size: int = gun.magazine_size
	_expect(well.has_snapped_object() and gun.reload.magazine_in, "%s: cargador puesto al aparecer" % id)
	_expect(gun.reload.chambered, "%s: bala en recámara al aparecer" % id)

	gun.pick_up(hand)
	await physics_frame
	_expect(gun.is_picked_up(), "%s: se agarra" % id)
	var handle = gun.get_node("SlideOrigin/Slide/HandleOrigin/InteractableHandle")
	_expect(handle.enabled, "%s: mango de corredera activo al agarrar" % id)

	var hits: Array = []
	gun.shot.connect(func(h): hits.append(h))
	var rest: Transform3D = gun._model_rest
	gun.get_node("FirearmTrigger").fired.emit()
	await physics_frame
	_expect(hits.size() == gun.pellets, "%s: el gatillo dispara (%d impactos)" % [id, hits.size()])
	_expect(hits.size() > 0 and hits[0].get("collider") == target, "%s: el rayo da en el blanco" % id)
	_expect(not gun.get_node("Model").transform.is_equal_approx(rest), "%s: retroceso mueve el modelo" % id)
	gun.get_node("FirearmTrigger").fired.emit()
	await physics_frame
	_expect(hits.size() == gun.pellets, "%s: cadencia bloquea el segundo tiro inmediato" % id)
	for i in 60:
		await physics_frame
	_expect(gun.get_node("Model").transform.origin.distance_to(rest.origin) < 0.002, "%s: el retroceso se recupera" % id)

	well.drop_object()
	_expect(not gun.reload.magazine_in, "%s: sacar cargador (eject)" % id)
	_expect(mag.rounds == size - 2, "%s: el cargador fuera guarda sus balas (%d)" % [id, mag.rounds])
	well.pick_up_object(mag)
	_expect(gun.reload.magazine_in and gun.reload.magazine_rounds == size - 2, "%s: meter cargador (insert)" % id)

	gun.reload.chambered = false
	var slide = gun.get_node("SlideOrigin/Slide")
	var limit: float = gun.get_node("SlideOrigin").limit_maximum
	slide.move_slider(limit)
	_expect(not gun.reload.chambered, "%s: corredera atrás aún no carga" % id)
	slide.move_slider(0.0)
	_expect(gun.reload.chambered and gun.reload.magazine_rounds == size - 3, "%s: correr corredera mete bala (rack)" % id)

	gun.let_go(hand, Vector3.ZERO, Vector3.ZERO)
	await physics_frame
	_expect(not gun.is_picked_up() and not handle.enabled, "%s: se suelta y desactiva el mango" % id)
	gun.queue_free()
	await process_frame


func _expect(cond: bool, label: String) -> void:
	print(("PASS: " if cond else "FAIL: ") + label)
	if not cond:
		_fails += 1
