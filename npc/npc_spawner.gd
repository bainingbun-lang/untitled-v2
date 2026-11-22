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


## Puntos de piso dentro de un rectángulo, con raycast hacia abajo. Debe llamarse en un frame de física.
static func floor_points(space: PhysicsDirectSpaceState3D, min_xz: Vector2, max_xz: Vector2, want: int, exclude: Array) -> Array:
	var out: Array = []
	var side := maxf(0.6, sqrt(maxf(0.01, (max_xz.x - min_xz.x) * (max_xz.y - min_xz.y) / float(maxi(want, 1)))))
	var x := min_xz.x + side * 0.5
	var guard := 0
	while x < max_xz.x and out.size() < want and guard < 5000:
		var z := min_xz.y + side * 0.5
		while z < max_xz.y and out.size() < want and guard < 5000:
			guard += 1
			var p_top := Vector3(x, 12.0, z)
			# Desde arriba: si la primera superficie es un techo o un piso alto, se sigue bajando.
			for _step in 8:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p_top, Vector3(x, -2.0, z)))
				if hit.is_empty():
					break
				if hit.normal.y > 0.7 and hit.position.y > -0.2 and hit.position.y < 1.0:
					var p: Vector3 = hit.position + Vector3.UP * 0.5
					if not _too_close(p, exclude):
						out.append(p)
					break
				p_top = hit.position - Vector3.UP * 0.05
			z += side
		x += side
	return out


static func _too_close(p: Vector3, others: Array) -> bool:
	for o in others:
		if p.distance_to(o) < 0.8:
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
