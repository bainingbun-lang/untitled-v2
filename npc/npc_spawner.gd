class_name NpcSpawner
extends RefCounted

## Genera NPC desde una lista declarativa de un mapa. Cada entrada:
##   {"id": "...", "role": "hostile|civilian|defender|zombie", "armed": bool, "count": int}
## Los NPC se reparten en los puntos de aparición en orden cíclico.
const BasicNpc = preload("res://npc/basic_npc.gd")
const GameConfig = preload("res://storage/game_config.gd")


## Reparto por defecto para un total de NPC: ~40% armados hostiles, resto civiles; con zombis
## activados, la mitad de los civiles pasa a zombis.
static func default_spec(total: int) -> Array:
	var armed := int(round(total * 0.4))
	var civil := total - armed
	var zombie := 0
	if GameConfig.zombies:
		zombie = civil / 2
		civil -= zombie
	var spec: Array = [
		{"id": "armado", "role": "hostile", "armed": true, "count": armed},
		{"id": "civil", "role": "civilian", "count": civil},
	]
	if zombie > 0:
		spec.append({"id": "zombi", "role": "zombie", "count": zombie})
	return spec


## Cuántos NPC caben según el área de piso y el relleno elegido (mínimo 2, máximo 60).
static func count_for_area(area_m2: float) -> int:
	return clampi(int(round(area_m2 * GameConfig.density_per_m2())), 2, 60)


## Puntos de piso dentro de un rectángulo: muestreo aleatorio con raycast hacia abajo.
## Debe llamarse en un frame de física. Intenta hasta 40 veces por punto pedido.
static func floor_points(space: PhysicsDirectSpaceState3D, min_xz: Vector2, max_xz: Vector2, want: int, exclude: Array) -> Array:
	var out: Array = []
	var attempts := want * 40
	for _a in attempts:
		if out.size() >= want:
			break
		var x := randf_range(min_xz.x, max_xz.x)
		var z := randf_range(min_xz.y, max_xz.y)
		var p: Variant = _floor_at(space, x, z)
		if p != null and not _too_close(p, out) and not _too_close(p, exclude):
			out.append(p)
	return out


## Superficie de piso bajo (x, z): baja desde arriba saltando techos. null si no hay piso.
static func _floor_at(space: PhysicsDirectSpaceState3D, x: float, z: float):
	var p_top := Vector3(x, 12.0, z)
	for _step in 8:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p_top, Vector3(x, -2.0, z)))
		if hit.is_empty():
			return null
		if hit.normal.y > 0.7 and hit.position.y > -0.2 and hit.position.y < 1.0:
			return hit.position + Vector3.UP * 0.5
		p_top = hit.position - Vector3.UP * 0.05
	return null


static func _too_close(p: Vector3, others: Array) -> bool:
	for o in others:
		if p.distance_to(o) < 0.7:
			return true
	return false


static func spawn(parent: Node3D, spec: Array, points: Array, eye: Node3D = null) -> Array:
	var made: Array = []
	if points.is_empty():
		return made
	var i := 0
	for entry in spec:
		var count := int(entry.get("count", 1))
		for k in count:
			var pos: Vector3 = points[i % points.size()]
			var opts: Dictionary = entry.duplicate()
			opts.erase("count")
			opts["id"] = "%s_%d" % [str(entry.get("id", "npc")), k + 1]
			var npc: Node3D = BasicNpc.spawn(parent, pos, opts)
			if npc != null:
				if eye != null:
					npc.set_target(eye)
				made.append(npc)
			i += 1
	return made
