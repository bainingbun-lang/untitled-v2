class_name NpcSpawner
extends RefCounted

## Genera NPC desde una lista declarativa de un mapa. Cada entrada:
##   {"id": "...", "role": "hostile|civilian|defender|zombie", "armed": bool, "count": int}
## Los NPC se reparten en los puntos de aparición en orden cíclico.
const BasicNpc = preload("res://npc/basic_npc.gd")


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
