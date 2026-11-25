class_name SceneStore
extends RefCounted

## Guarda y recarga la escena armada (props y NPC del menú) en user://escena.json.
const PATH := "user://escena.json"


static func save(tree: SceneTree) -> int:
	var props := []
	for p in tree.get_nodes_in_group("prop"):
		if p is PropBody and p.is_inside_tree():
			props.append({"id": p.prop_id, "pos": _v(p.global_position), "rot": _v(p.global_rotation), "frozen": p.freeze})
	var npcs := []
	for n in tree.get_nodes_in_group("basic_npc"):
		if n.has_meta("menu_kind"):
			npcs.append({"kind": n.get_meta("menu_kind"), "pos": _v(n.global_position)})
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"props": props, "npcs": npcs}))
	return OK


## Devuelve cuántos elementos se crearon (-1 si no hay archivo o está dañado).
static func load_into(parent: Node3D, npc_kinds: Dictionary) -> int:
	if not FileAccess.file_exists(PATH):
		return -1
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return -1
	var made := 0
	for e in data.get("props", []):
		var b := PropFactory.make(str(e.get("id", "")))
		if b == null:
			continue
		parent.add_child(b)
		b.global_position = _unv(e.get("pos"))
		b.global_rotation = _unv(e.get("rot"))
		if bool(e.get("frozen", false)):
			b.freeze = true
		made += 1
	for e in data.get("npcs", []):
		var kind := str(e.get("kind", ""))
		if not npc_kinds.has(kind):
			continue
		var opts: Dictionary = (npc_kinds[kind] as Dictionary).duplicate()
		opts["id"] = kind + "_menu"
		var npc := BasicNpc.spawn(parent, _unv(e.get("pos")), opts)
		if npc != null:
			npc.set_meta("menu_kind", kind)
			made += 1
	return made


static func _v(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _unv(a: Variant) -> Vector3:
	if typeof(a) == TYPE_ARRAY and a.size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO
