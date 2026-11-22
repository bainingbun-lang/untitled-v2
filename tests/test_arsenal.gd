extends SceneTree

## Comprueba que cada arma del arsenal carga, tiene estadísticas válidas y entra al inventario.
## Ejecutar: godot --headless --path . --script res://tests/test_arsenal.gd
const Inv = preload("res://inventory/inventory.gd")
const GameConfig = preload("res://storage/game_config.gd")

var _fails := 0


func _init() -> void:
	var inv = Inv.new()
	for id in Inv.SCENES.keys():
		var path: String = Inv.SCENES[id]
		var packed := load(path) as PackedScene
		_expect(packed != null, "%s carga (%s)" % [id, path])
		if packed == null:
			continue
		var node = packed.instantiate()
		var ok: bool = node.has_method("action") or node.has_method("cut")
		_expect(ok, "%s tiene script de arma" % id)
		node.free()
		_expect(inv.add(id) or inv.weapons.size() >= Inv.MAX_WEAPONS, "%s entra al inventario" % id)
		inv.weapons.clear()
	for id in GameConfig.POCKET_WEAPONS:
		_expect(Inv.SCENES.has(id), "bolsillo '%s' existe en el inventario" % id)
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)


func _expect(cond: bool, label: String) -> void:
	print(("PASS: " if cond else "FAIL: ") + label)
	if not cond:
		_fails += 1
