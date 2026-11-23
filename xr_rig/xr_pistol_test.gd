extends SceneTree

## Prueba aislada del arma pickable de xr-tools con el modelo CC0 (derringer).
## Ejecutar: godot --headless --path . --script res://xr_rig/xr_pistol_test.gd
var _fails := 0


func _init() -> void:
	await process_frame
	var pickable_script = load("res://addons/godot-xr-tools/objects/pickable.gd")
	var grab_script = load("res://addons/godot-xr-tools/objects/grab_points/grab_point.gd")
	var pistol = pickable_script.new()
	pistol.name = "Derringer"
	var model := (load("res://weapons/pistol_cc0/derringer.glb") as PackedScene)
	_expect(model != null, "el modelo derringer.glb carga")
	if model != null:
		pistol.add_child(model.instantiate())
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.05, 0.12, 0.18)
	shape.shape = box
	pistol.add_child(shape)
	var grip = grab_script.new()
	grip.name = "GripPoint"
	grip.position = Vector3(0, -0.04, 0.02)
	pistol.add_child(grip)
	root.add_child(pistol)
	await process_frame

	var pickup_script = load("res://addons/godot-xr-tools/functions/function_pickup.gd")
	var hand = pickup_script.new()
	root.add_child(hand)
	pistol.pick_up(hand)
	await process_frame
	_expect(pistol.is_picked_up(), "el arma se puede agarrar (pick_up)")
	pistol.let_go(hand, Vector3.ZERO, Vector3.ZERO)
	await process_frame
	_expect(not pistol.is_picked_up(), "el arma se suelta (let_go)")
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)


func _expect(cond: bool, label: String) -> void:
	print(("PASS: " if cond else "FAIL: ") + label)
	if not cond:
		_fails += 1
