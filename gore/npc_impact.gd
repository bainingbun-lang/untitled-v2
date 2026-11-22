class_name NpcImpact
extends RefCounted

## Golpe o estrellón contra un NPC (puño, cuerpo o NPC arrojado contra una superficie).
## La fuerza (m/s) decide el daño, la herida y el sangrado:
##   >= 4  : herida de impacto.
##   >= 10 : herida grande (la zona se abre), rociada y goteo.
const GoreSystem = preload("res://gore/gore_system.gd")
const WOUND_MIN_SPEED := 4.0
const Sfx = preload("res://audio/sfx.gd")
const OPEN_WOUND_SPEED := 10.0


static func apply(npc: Node, point: Vector3, normal: Vector3, speed: float, zone: String = "head") -> Dictionary:
	if npc == null or not npc.has_method("take_damage") or speed <= 0.0:
		return {}
	var damage := clampf(speed * 3.0, 0.0, 200.0)
	Sfx.play_at(npc, Sfx.impact(), point)
	npc.take_damage(damage, point, null, zone)
	var wounded := speed >= WOUND_MIN_SPEED
	if wounded:
		var depth := 0.9 if speed >= OPEN_WOUND_SPEED else 0.5
		GoreSystem.create_bullet_wound(npc, point, normal, false, zone, -1, Vector2(0.5, 0.5), depth)
	if speed >= OPEN_WOUND_SPEED:
		GoreSystem.blood_spray(npc, point, normal)
		GoreSystem.blood_drip(npc, point)
	return {"damage": damage, "wounded": wounded, "open": speed >= OPEN_WOUND_SPEED}
