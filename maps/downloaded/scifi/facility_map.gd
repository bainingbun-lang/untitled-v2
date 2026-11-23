extends Node3D

## Instalacion sci-fi armada por codigo con piezas modulares CC0 (Quaternius, ver CREDITS.md).
## Rejilla de celdas de 4 m: corredor central y 5 salas unidas por puertas. Las piezas se cargan
## con GLTFDocument desde bytes (funciona dentro del PCK) y se cachean; si una falla, se usa una caja.
const NpcSpawner = preload("res://npc/npc_spawner.gd")
const NpcReactions = preload("res://npc/npc_reactions.gd")
const PACK := "res://assets/packs/scifi_pieces.zip"
## Las piezas viven en un ZIP (sin importar) y se descomprimen una vez en user:// al abrir el mapa.
const PIECES := "user://scifi_pieces/"
const CELL := 4.0
const WALL_H := 3.05
## Letra = zona ('.' vacio, 'c' corredor). Filas = z, columnas = x.
const GRID := [
	"AAAABBBBCCCC",
	"AAAABBBBCCCC",
	"AAAABBBBCCCC",
	"cccccccccccc",
	"DDDDDDEEEEEE",
	"DDDDDDEEEEEE",
	"DDDDDDEEEEEE",
]
const FLOOR_PIECE := {"A": "Platform_Metal", "B": "Platform_Squares", "C": "Platform_Metal2", "D": "Platform_Simple", "E": "Platform_Metal", "c": "Platform_DarkPlates"}
const TINT := {"A": Color(0.55, 0.62, 0.7), "B": Color(0.62, 0.55, 0.5), "C": Color(0.5, 0.64, 0.58), "D": Color(0.6, 0.6, 0.66), "E": Color(0.66, 0.58, 0.6), "c": Color(0.35, 0.38, 0.43)}
## Puertas: [celda x, celda z, lado] ; el lado es N/S/E/O de esa celda.
const DOORS := [[1, 2, "S"], [5, 2, "S"], [10, 2, "S"], [1, 4, "N"], [8, 4, "N"], [3, 3, "S"]]
## Props: [pieza, x, z, desplazamiento x, desplazamiento z, giro en grados]
const PROPS := [
	["Prop_Crate3", 0, 0, -1.0, -1.0, 10], ["Prop_Crate4", 0, 0, 0.2, -1.4, 40], ["Prop_Barrel_Large", 3, 1, 1.2, 0.8, 0],
	["Prop_Computer", 4, 0, -1.2, -1.6, 0], ["Prop_Computer", 6, 0, 0.0, -1.6, 0], ["Prop_Chest", 7, 2, 0.0, 1.5, 0],
	["Prop_Crate4", 8, 0, 0.0, 0.0, 20], ["Prop_Barrel_Large", 11, 0, 1.3, -1.3, 0], ["Prop_Barrel_Large", 11, 0, 0.5, -1.5, 0],
	["Prop_Computer", 9, 0, 0.0, -1.6, 0], ["Prop_Crate3", 11, 2, -1.0, 0.8, 30], ["Prop_Crate3", 0, 4, -1.0, 1.2, 0],
	["Prop_Chest", 3, 6, 0.0, 1.5, 0], ["Prop_Computer", 2, 6, 0.0, 1.6, 180], ["Prop_Barrel_Large", 5, 5, 1.0, 1.0, 0],
	["Prop_Crate4", 7, 6, 0.5, 0.5, 15], ["Prop_Computer", 9, 6, 0.0, 1.6, 180], ["Prop_Barrel_Large", 11, 5, 1.2, 1.2, 0],
	["Prop_Crate3", 10, 4, 0.0, 0.0, 0],
	["Column_Round", 4, 3, -2.0, 0.0, 0], ["Column_Pipes", 8, 3, -2.0, 0.0, 0], ["Column_Simple", 6, 3, 0.0, -1.9, 0],
	["Prop_Vent_Big", 5, 3, 0.0, -1.95, 0], ["Prop_AccessPoint", 2, 3, 0.0, 1.95, 0],
]
const CEIL_LIGHTS := [[1.5, 1.5], [5.5, 1.5], [9.5, 1.5], [2.5, 5.5], [8.0, 5.5], [2.0, 3.0], [6.0, 3.0], [10.0, 3.0]]

var _cache := {}
var _soft := {}
var _mats := {}
var _floors: Array = []


func _ready() -> void:
	var _vg := Node.new()
	_vg.set_script(load("res://player/void_guard.gd"))
	add_child(_vg)
	ensure_pieces()
	_setup_environment()
	var rows: int = GRID.size()
	var cols: int = (GRID[0] as String).length()
	for z in rows:
		for x in cols:
			var ch := _at(x, z)
			if ch == ".":
				continue
			var c := Vector3((x + 0.5) * CELL, 0, (z + 0.5) * CELL)
			_place_floor(ch, c)
			_place_walls(x, z, ch, c)
	for p in PROPS:
		var d: Array = p
		_place_prop(d)
	for l in CEIL_LIGHTS:
		_add_light(Vector3(l[0] * CELL, WALL_H - 0.5, l[1] * CELL))
	var player := get_node_or_null("XRPlayer") as Node3D
	if player:
		player.global_position = Vector3(2.0, 0.1, 3.5 * CELL)
	_spawn_npcs(cols, rows)


func _at(x: int, z: int) -> String:
	if z < 0 or z >= GRID.size() or x < 0 or x >= (GRID[z] as String).length():
		return "."
	return (GRID[z] as String)[x]


func _is_door(x: int, z: int, side: String) -> bool:
	return DOORS.any(func(d): return d[0] == x and d[1] == z and d[2] == side)


## Descomprime el ZIP de piezas en user:// si aun no esta (o si cambio de tamano).
static func ensure_pieces() -> bool:
	var zr := ZIPReader.new()
	if zr.open(PACK) != OK:
		return false
	var stamp := PIECES + ".stamp"
	var size := str(FileAccess.get_file_as_bytes(PACK).size()) + "-v3"
	if FileAccess.file_exists(stamp) and FileAccess.get_file_as_string(stamp) == size:
		zr.close()
		return true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PIECES))
	for old in DirAccess.get_files_at(PIECES):
		if old.ends_with(".import"):
			DirAccess.remove_absolute(PIECES + old)
	for f in zr.get_files():
		if f.ends_with(".import"):
			continue
		if f.ends_with(".png"):
			var img := Image.new()
			if img.load_png_from_buffer(zr.read_file(f)) == OK:
				if img.get_width() > 1024:
					img.resize(1024, 1024, Image.INTERPOLATE_BILINEAR)
				img.save_png(PIECES + f.get_file())
				continue
		var fa := FileAccess.open(PIECES + f.get_file(), FileAccess.WRITE)
		if fa != null:
			fa.store_buffer(zr.read_file(f))
			fa.close()
	zr.close()
	var st := FileAccess.open(stamp, FileAccess.WRITE)
	if st != null:
		st.store_string(size)
		st.close()
	return true


## Obtiene una copia de la pieza (cacheada). Respaldo: caja gris con aviso.
func _piece(name: String) -> Node3D:
	if not _cache.has(name):
		var n: Node3D = null
		var bytes := FileAccess.get_file_as_bytes(PIECES + name + ".gltf")
		if not bytes.is_empty():
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_buffer(bytes, PIECES, st) == OK:
				n = doc.generate_scene(st) as Node3D
		if n == null:
			push_warning("Instalacion: no carga la pieza " + name + "; se usa una caja")
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1, 1, 1)
			mi.mesh = bm
			mi.position.y = 0.5
			n = Node3D.new()
			n.add_child(mi)
		_cache[name] = n
	return (_cache[name] as Node3D).duplicate() as Node3D


func _meshes(n: Node) -> Array:
	var out: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		out.append(n)
	return out


func _tint(n: Node3D, color: Color) -> void:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = 0.3
		m.roughness = 0.6
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	for mi in _meshes(n):
		(mi as MeshInstance3D).material_override = _mats[key]


## Las texturas del pack son muy metalicas y sin reflejos se ven negras: se baja el metal y se
## sube la rugosidad para que la luz de ambiente las ilumine.
func _soften_metal(n: Node3D, v := 0) -> void:
	for mi in _meshes(n):
		var inst := mi as MeshInstance3D
		if inst.mesh == null:
			continue
		for i in inst.mesh.get_surface_count():
			var m := inst.mesh.surface_get_material(i) as StandardMaterial3D
			if m == null:
				continue
			var key := m.get_instance_id()
			if not _soft.has(key):
				var c := m.duplicate() as StandardMaterial3D
				c.metallic = minf(c.metallic, 0.2)
				c.roughness = maxf(c.roughness, 0.55)
				_soft[key] = c
			inst.set_surface_override_material(i, _soft[key])


func _put(name: String, pos: Vector3, yaw: float, color: Color, solid: bool, scl := Vector3.ONE, v := 0) -> Node3D:
	var n := _piece(name)
	n.position = pos
	n.rotation.y = yaw
	n.scale = scl
	if color.a < 0.0:
		_tint(n, color)  # solo si se pide un color explicito; por defecto se conservan las texturas
	_soften_metal(n, v)
	add_child(n)
	if solid:
		for mi in _meshes(n):
			(mi as MeshInstance3D).create_trimesh_collision()
	return n


func _place_floor(ch: String, c: Vector3) -> void:
	var h := _h(c)
	_put(FLOOR_PIECE[ch], c, 0.0, TINT[ch], false, Vector3.ONE, h)
	if h % 7 == 0:
		_put("Prop_Light_Floor", c + Vector3(1.6, 0.0, -1.7), PI / 2, TINT[ch], false)
	_put("Platform_Simple", c + Vector3(0, WALL_H, 0), 0.0, Color(0.3, 0.33, 0.38), false)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(CELL, 0.4, CELL)
	cs.shape = bs
	body.add_child(cs)
	body.position = c + Vector3(0, -0.2, 0)
	add_child(body)
	_floors.append(c)


## Lados: [dx, dz, nombre, giro]. La pieza de pared vive en su borde -x local y mira a +x.
func _h(p: Vector3) -> int:
	return int(absf(sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453)) % 16


func _place_walls(x: int, z: int, ch: String, c: Vector3) -> void:
	for s in [[-1, 0, "O", 0.0], [1, 0, "E", PI], [0, -1, "N", -PI / 2], [0, 1, "S", PI / 2]]:
		var nb := _at(x + s[0], z + s[1])
		if nb == ch:
			continue
		var door := _is_door(x, z, s[2]) or _is_door(x + s[0], z + s[1], {"O": "E", "E": "O", "N": "S", "S": "N"}[s[2]])
		var outer: bool = nb == "."
		if not outer and ch > nb:
			continue
		var edge := c + Vector3(s[0], 0, s[1]) * (CELL * 0.5)
		if door:
			_put("Door_Frame_Square", edge, s[3] + PI / 2, Color(0.75, 0.55, 0.2), true, Vector3(0.82, 0.6, 1.0))
			continue
		var piece := "WallAstra_Straight" if outer else "WallBand_Straight"
		if outer and (x + z) % 3 == 1:
			piece = "WallAstra_Straight_Divided"
		_put(piece, edge, s[3], TINT[ch] if not outer else Color(0.5, 0.54, 0.6), true)
		if not outer:
			_put("WallBand_Straight", edge, s[3] + PI, TINT[nb], false)


func _place_prop(d: Array) -> void:
	var c := Vector3((int(d[1]) + 0.5) * CELL + float(d[3]), 0, (int(d[2]) + 0.5) * CELL + float(d[4]))
	var nm := str(d[0])
	if nm.begins_with("Prop_Crate"):
		c.y = 0.5 if nm == "Prop_Crate3" else 0.56
	var solid := not (nm == "Prop_Vent_Big" or nm == "Prop_AccessPoint")
	_put(nm, c, deg_to_rad(float(d[5])), Color(0.8, 0.5, 0.2) if nm.contains("Crate") or nm.contains("Barrel") else Color(0.55, 0.6, 0.65), solid)


func _add_light(p: Vector3) -> void:
	var l := OmniLight3D.new()
	l.position = p
	l.omni_range = 12.0
	l.light_energy = 1.4
	l.light_color = Color(0.85, 0.92, 1.0)
	add_child(l)
	_put("Prop_Light_Wide", Vector3(p.x, WALL_H, p.z), 0.0, Color(0.9, 0.95, 1.0), false)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func npc_spec(total: int) -> Array:
	return NpcSpawner.default_spec(total)


func _spawn_npcs(cols: int, rows: int) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lo := Vector2(0, 0)
	var hi := Vector2(cols * CELL, rows * CELL)
	var total := mini(30, maxi(1, NpcSpawner.count_for_area(_floors.size() * CELL * CELL) / 2))
	var space := get_world_3d().direct_space_state
	var points := NpcSpawner.floor_points(space, lo, hi, total, [Vector3(2.0, 0, 3.5 * CELL)])
	var eye := get_node_or_null("XRPlayer/XRCamera3D") as Node3D
	var made: Array = NpcSpawner.spawn(self, npc_spec(points.size()), points, eye)
	var rx := NpcReactions.new()
	add_child(rx)
	rx.setup(self, eye, made)
	print("Instalacion: NPC pedidos %d, colocados %d" % [total, points.size()])
