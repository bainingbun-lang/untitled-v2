class_name PropFactory
extends RefCounted

## Props primitivos agarrables (estilo GMod): cajas, esfera, barril, tablón y ladrillo. Sin archivos externos.
const DEFS := {
	"caja": {"shape": "box", "size": Vector3(0.4, 0.4, 0.4), "mass": 5.0, "color": Color(0.55, 0.38, 0.2)},
	"caja_grande": {"shape": "box", "size": Vector3(0.8, 0.8, 0.8), "mass": 20.0, "color": Color(0.48, 0.33, 0.18)},
	"esfera": {"shape": "sphere", "size": Vector3(0.25, 0.25, 0.25), "mass": 3.0, "color": Color(0.8, 0.2, 0.2), "surface": "soft"},
	"barril": {"shape": "cylinder", "size": Vector3(0.3, 0.9, 0.3), "mass": 15.0, "color": Color(0.2, 0.35, 0.6), "surface": "metal"},
	"tablon": {"shape": "box", "size": Vector3(1.5, 0.1, 0.25), "mass": 4.0, "color": Color(0.6, 0.45, 0.25)},
	"ladrillo": {"shape": "box", "size": Vector3(0.22, 0.07, 0.1), "mass": 2.0, "color": Color(0.6, 0.25, 0.18)},
}


## Modelos del pack sci-fi (se descomprime en user:// al primer uso, igual que en el mapa de la instalación).
const PACK := "res://assets/packs/scifi_pieces.zip"
const PIECES := "user://scifi_pieces/"
const PIECE_DEFS := {
	"sf_barril": {"piece": "Prop_Barrel_Large", "mass": 18.0},
	"sf_cofre": {"piece": "Prop_Chest", "mass": 12.0},
	"sf_ordenador": {"piece": "Prop_Computer", "mass": 8.0},
	"sf_caja3": {"piece": "Prop_Crate3", "mass": 10.0},
	"sf_caja4": {"piece": "Prop_Crate4", "mass": 14.0},
	"sf_acceso": {"piece": "Prop_AccessPoint", "mass": 6.0},
}


static func ids() -> Array:
	var out: Array = DEFS.keys()
	if ResourceLoader.exists(PACK) or FileAccess.file_exists(PACK):
		out.append_array(PIECE_DEFS.keys())
	return out


static func _ensure_pieces() -> bool:
	var zr := ZIPReader.new()
	if zr.open(PACK) != OK:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PIECES))
	for f in zr.get_files():
		if f.begins_with("Prop_") and not f.ends_with(".import") and not FileAccess.file_exists(PIECES + f):
			var out := FileAccess.open(PIECES + f, FileAccess.WRITE)
			if out != null:
				out.store_buffer(zr.read_file(f))
	zr.close()
	return true


static func _make_piece(id: String) -> RigidBody3D:
	var d: Dictionary = PIECE_DEFS[id]
	if not _ensure_pieces():
		return null
	var bytes := FileAccess.get_file_as_bytes(PIECES + str(d["piece"]) + ".gltf")
	if bytes.is_empty():
		return null
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_buffer(bytes, PIECES, st) != OK:
		return null
	var model := doc.generate_scene(st) as Node3D
	if model == null:
		return null
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var rel := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != model:
			rel = (n as Node3D).transform * rel
			n = n.get_parent()
		var a := rel * m.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		model.free()
		return null
	var body := PropBody.new()
	body.name = "Prop_" + id
	body.mass = d["mass"]
	body.prop_id = id
	body.surface = "metal"
	body.add_to_group("prop")
	body.add_child(model)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	cs.shape = bs
	cs.position = box.get_center()
	body.add_child(cs)
	return body


static func make(id: String) -> RigidBody3D:
	if PIECE_DEFS.has(id):
		return _make_piece(id)
	var d: Dictionary = DEFS.get(id, {})
	if d.is_empty():
		return null
	var size: Vector3 = d["size"]
	var mesh: Mesh
	var shape: Shape3D
	match d["shape"]:
		"sphere":
			var m := SphereMesh.new()
			m.radius = size.x
			m.height = size.x * 2.0
			mesh = m
			var s := SphereShape3D.new()
			s.radius = size.x
			shape = s
		"cylinder":
			var m := CylinderMesh.new()
			m.top_radius = size.x
			m.bottom_radius = size.x
			m.height = size.y
			mesh = m
			var s := CylinderShape3D.new()
			s.radius = size.x
			s.height = size.y
			shape = s
		_:
			var m := BoxMesh.new()
			m.size = size
			mesh = m
			var s := BoxShape3D.new()
			s.size = size
			shape = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = d["color"]
	mat.roughness = 0.8
	mesh.surface_set_material(0, mat)
	var body := PropBody.new()
	body.name = "Prop_" + id
	body.mass = d["mass"]
	body.prop_id = id
	body.surface = str(d.get("surface", "wood"))
	body.add_to_group("prop")
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body


## Alterna fijar/soltar un prop agarrado: al soltarlo se queda quieto en el aire (true) o cae (false).
static func toggle_pin(prop: XRToolsPickable) -> bool:
	prop.restore_freeze = not prop.restore_freeze
	return prop.restore_freeze
