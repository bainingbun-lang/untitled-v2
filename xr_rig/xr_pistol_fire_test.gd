extends SceneTree

## Prueba: la derringer agarrada y el gatillo disparan un impacto contra un NPC.
const BulletImpact = preload("res://gore/bullet_impact.gd")
var _fails := 0


func _init() -> void:
	await process_frame
	var pickable_script = load("res://addons/godot-xr-tools/objects/pickable.gd")
	var grab_script = load("res://addons/godot-xr-tools/objects/grab_points/grab_point.gd")
	var trigger_script = load("res://weapons/firearm/firearm_trigger.gd")
	var shooter_script = load("res://weapons/firearm/derringer_xr.gd")
	var sb = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(sb)
	for i in 60:
		await process_frame
	var npc: Node3D = null
	for n in sb.find_children("*", "CharacterBody3D", true, false):
		if n.has_method("take_damage") and npc == null:
			npc = n
	var pistol = pickable_script.new()
	pistol.name = "Derringer"
	pistol.add_child((load("res://weapons/pistol_cc0/derringer.glb") as PackedScene).instantiate())
	var grip = grab_script.new()
	grip.name = "GripPoint"
	pistol.add_child(grip)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0, -0.1)
	pistol.add_child(muzzle)
	var trig = trigger_script.new()
	trig.name = "FirearmTrigger"
	pistol.add_child(trig)
	var shooter = shooter_script.new()
	shooter.name = "Shooter"
	pistol.add_child(shooter)
	sb.add_child(pistol)
	for i in 3:
		await process_frame
	var target: Vector3 = npc.global_position + Vector3(0, 1.0, 0)
	pistol.global_position = target + Vector3(0, 0, 2.0)
	pistol.look_at(target, Vector3.UP)
	for i in 3:
		await physics_frame
	var hp0: float = npc.health
	trig.fired.emit()
	for i in 10:
		await physics_frame
	_expect(hp0 - npc.health >= 59.0, "el disparo de la derringer hace 60 de daño (bajó %.0f)" % (hp0 - npc.health))
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)


func _expect(cond: bool, label: String) -> void:
	print(("PASS: " if cond else "FAIL: ") + label)
	if not cond:
		_fails += 1
