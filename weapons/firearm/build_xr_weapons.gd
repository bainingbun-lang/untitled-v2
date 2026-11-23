extends SceneTree

## Genera las escenas weapons/xr_*.tscn (armas XRToolsPickable con cargador, corredera y gatillo).
## Regenerar tras cambiar WEAPONS: godot --headless --path . --script res://weapons/firearm/build_xr_weapons.gd
## Espacio del arma: cañón hacia -Z, gatillo cerca del origen.
const XRA := "res://addons/godot-xr-tools/"
const HAND_R := XRA + "objects/grab_points/grab_point_hand_right.tscn"
const HAND_L := XRA + "objects/grab_points/grab_point_hand_left.tscn"
const SNAP := XRA + "objects/snap_zone.tscn"
const HANDLE := XRA + "interactables/interactable_handle.tscn"
const SLIDER_ORIGIN := XRA + "interactables/interactable_slider_origin.gd"
const SLIDER := XRA + "interactables/interactable_slider.gd"

const WEAPONS := [
	{"id": "pistol", "model": "res://weapons/models/quaternius/Pistol_1.glb", "rot_y": 90.0, "scale": 0.1,
		"body": [Vector3(0.0, -0.022, 0.0), Vector3(0.02, 0.07, 0.12)],
		"mag": [Vector3(0, -0.04, 0.035), Vector3(0.014, 0.045, 0.022)],
		"grip": Vector3(0, -0.035, 0.035), "support": [], "muzzle_y": 0.0,
		"slide": [Vector3(0, 0.014, 0.0), Vector3(0.012, 0.01, 0.06), 0.03],
		"stats": {"damage": 45.0, "fire_interval": 0.2, "magazine_size": 7, "recoil_back": 0.03, "recoil_up_deg": 10.0},
		"sound": "res://weapons/ak47/ak47_shot.wav"},
	{"id": "ak47", "model": "res://weapons/ak47/ak47.glb", "rot_y": 90.0, "scale": 1.0,
		"mag_mesh": "akmagazine_low", "grip": Vector3(0, -0.05, 0.04),
		"support": [Vector3(0, -0.01, -0.22), Vector3(0, -0.02, 0.2)], "muzzle_y": 0.01,
		"slide": [Vector3(0.015, 0.02, -0.05), Vector3(0.01, 0.015, 0.05), 0.07],
		"stats": {"damage": 35.0, "fire_interval": 0.1, "automatic": true, "magazine_size": 30, "recoil_back": 0.02, "recoil_up_deg": 3.0},
		"sound": "res://weapons/ak47/ak47_shot.wav"},
	{"id": "sniper", "model": "res://weapons/models/sniper_cc0/sniper_rifle.glb", "rot_y": 180.0, "scale": 1.0,
		"mag_mesh": "SniperRifle/Magazine", "grip": Vector3(0, -0.05, 0.06),
		"support": [Vector3(0, -0.02, -0.2), Vector3(0, 0.0, 0.4)], "muzzle_y": -0.02,
		"slide": [Vector3(0.03, 0.0, 0.03), Vector3(0.012, 0.012, 0.04), 0.08],
		"stats": {"damage": 150.0, "fire_interval": 1.0, "magazine_size": 5, "max_range": 300.0, "recoil_back": 0.06, "recoil_up_deg": 8.0},
		"sound": "res://weapons/ak47/ak47_shot.wav"},
	{"id": "barrett", "model": "res://weapons/models/sniper_cc0/sniper_rifle.glb", "rot_y": 180.0, "scale": 1.2,
		"mag_mesh": "SniperRifle/Magazine", "grip": Vector3(0, -0.06, 0.07),
		"support": [Vector3(0, -0.02, -0.24), Vector3(0, 0.0, 0.48)], "muzzle_y": -0.024,
		"slide": [Vector3(0.036, 0.0, 0.036), Vector3(0.014, 0.014, 0.05), 0.1],
		"stats": {"damage": 400.0, "fire_interval": 0.8, "magazine_size": 10, "max_range": 400.0, "recoil_back": 0.08, "recoil_up_deg": 12.0},
		"sound": "res://weapons/ak47/ak47_shot.wav"},
	{"id": "shotgun", "model": "res://weapons/shotgun_mit/shotgun.tscn", "rot_y": 180.0, "scale": 0.55, "body": [Vector3(0, 0, -0.15), Vector3(0.05, 0.08, 0.9)],
		"mag": [Vector3(0, -0.08, -0.02), Vector3(0.03, 0.1, 0.06)],
		"grip": Vector3(0, -0.06, 0.1), "support": [Vector3(0, -0.05, -0.35), Vector3(0, -0.02, 0.25)], "muzzle_y": 0.02,
		"slide": [Vector3(0, -0.055, -0.32), Vector3(0.06, 0.05, 0.16), 0.1],
		"stats": {"damage": 160.0, "pellets": 8, "spread_deg": 4.0, "fire_interval": 0.6, "magazine_size": 6, "max_range": 40.0, "recoil_back": 0.06, "recoil_up_deg": 12.0},
		"sound": "res://weapons/shotgun/shotgun_shot.wav"},
	{"id": "smg", "model": "res://weapons/models/quaternius/Bullpup_2.glb", "rot_y": 90.0, "scale": 0.146, "body": [Vector3(0, 0, -0.08), Vector3(0.05, 0.1, 0.4)],
		"mag": [Vector3(0, -0.11, -0.06), Vector3(0.025, 0.14, 0.035)],
		"grip": Vector3(0, -0.07, 0.06), "support": [Vector3(0, -0.03, -0.2)], "muzzle_y": 0.02,
		"slide": [Vector3(0, 0.055, 0.0), Vector3(0.012, 0.012, 0.03), 0.04],
		"stats": {"damage": 22.0, "fire_interval": 0.07, "automatic": true, "magazine_size": 30, "recoil_back": 0.012, "recoil_up_deg": 2.0},
		"sound": "res://weapons/ak47/ak47_shot.wav"},
]

var _root: Node


func _init() -> void:
	await process_frame
	var only := OS.get_environment("ONLY") # ONLY=shotgun regenera solo esa arma
	for cfg in WEAPONS:
		if only != "" and cfg.id != only:
			continue
		var path := "res://weapons/xr_%s.tscn" % cfg.id
		var packed := PackedScene.new()
		var node := _build(cfg)
		var err := packed.pack(node)
		if err == OK:
			err = ResourceSaver.save(packed, path)
		print("%s %s" % [path, "OK" if err == OK else "ERROR %d" % err])
		node.free()
	quit()


func _build(cfg: Dictionary) -> Node:
	var gun := RigidBody3D.new()
	gun.set_script(load("res://weapons/firearm/xr_firearm.gd"))
	gun.name = "XR_" + cfg.id
	gun.collision_layer = 4
	gun.collision_mask = 196615
	gun.second_hand_grab = 2 # SECOND: la otra mano sujeta guardamanos/culata
	for k in cfg.stats:
		gun.set(k, cfg.stats[k])
	gun.shot_sound = load(cfg.sound)
	_root = gun

	var model = _add(gun, Node3D.new(), "Model")
	var body_box: AABB
	var mag_box: AABB
	var mag_mesh: Mesh
	var mag_xf := Transform3D.IDENTITY
	if cfg.has("model"):
		var glb: Node3D = load(cfg.model).instantiate()
		glb.rotation_degrees.y = cfg.rot_y
		glb.scale = Vector3.ONE * cfg.scale
		_add(model, glb, "Mesh")
		var first := true
		for m: MeshInstance3D in glb.find_children("*", "MeshInstance3D", true, false):
			var a := _xf_to(m, model) * m.get_aabb()
			body_box = a if first else body_box.merge(a)
			first = false
		if cfg.has("mag_mesh"):
			var mi: MeshInstance3D = glb.find_child(cfg.mag_mesh.get_file(), true, false)
			mag_xf = _xf_to(mi, model)
			mag_mesh = mi.mesh
			mag_box = mag_xf * mi.get_aabb()
			gun.set("model_magazine", NodePath("Model/Mesh/" + str(glb.get_path_to(mi))))
	else:
		body_box = AABB(cfg.body[0] - cfg.body[1] / 2, cfg.body[1])
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = cfg.body[1]
		mi.mesh = bm
		mi.position = cfg.body[0]
		_add(model, mi, "Body")
	if cfg.has("body") and cfg.has("model"):
		body_box = AABB(cfg.body[0] - cfg.body[1] / 2, cfg.body[1])
	if cfg.has("mag"):
		mag_box = AABB(cfg.mag[0] - cfg.mag[1] / 2, cfg.mag[1])

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = body_box.size
	col.shape = shape
	col.position = body_box.get_center()
	_add(gun, col, "CollisionShape3D")

	var r = _add(gun, load(HAND_R).instantiate(), "GripR")
	r.position = cfg.grip
	r.handle = "Grip"
	var l = _add(gun, load(HAND_L).instantiate(), "GripL")
	l.position = cfg.grip
	l.handle = "Grip"
	var i := 0
	for p: Vector3 in cfg.support:
		for scene in [HAND_L, HAND_R]:
			var s = _add(gun, load(scene).instantiate(), "Support%d%s" % [i, "L" if scene == HAND_L else "R"])
			s.position = p
		i += 1

	var trig_mesh = _add(gun, MeshInstance3D.new(), "TriggerMesh")
	trig_mesh.position = Vector3(0, -0.015, 0)
	var trig := Node.new()
	trig.set_script(load("res://weapons/firearm/firearm_trigger.gd"))
	_add(gun, trig, "FirearmTrigger")
	trig.mesh_trigger = trig_mesh
	trig.value = 0.3

	var muzzle = _add(gun, Marker3D.new(), "Muzzle")
	muzzle.position = Vector3(0, cfg.muzzle_y, body_box.position.z - 0.01)

	# Cargador: top_level para que lo mueva la SnapZone/la mano y no el padre.
	var mag := RigidBody3D.new()
	mag.set_script(load("res://weapons/firearm/xr_magazine.gd"))
	mag.top_level = true
	mag.collision_layer = 4
	mag.collision_mask = 196615
	mag.rounds = gun.magazine_size
	_add(gun, mag, "Magazine")
	mag.add_to_group("mag_" + cfg.id, true)
	var mag_center := mag_box.get_center()
	var mmi := MeshInstance3D.new()
	if mag_mesh:
		mmi.mesh = mag_mesh
		mmi.transform = Transform3D(mag_xf.basis, mag_xf.origin - mag_center)
	else:
		var bm := BoxMesh.new()
		bm.size = mag_box.size
		mmi.mesh = bm
	_add(mag, mmi, "Mesh")
	var mcol := CollisionShape3D.new()
	var mshape := BoxShape3D.new()
	mshape.size = mag_box.size
	mcol.shape = mshape
	_add(mag, mcol, "CollisionShape3D")
	for scene in [HAND_L, HAND_R]:
		_add(mag, load(scene).instantiate(), "Grab" + ("L" if scene == HAND_L else "R"))

	var well = _add(gun, load(SNAP).instantiate(), "MagazineWell")
	well.set_script(load("res://weapons/firearm/magazine_well.gd"))
	well.position = mag_center
	well.grab_distance = 0.06
	well.snap_require = "mag_" + cfg.id
	well.initial_object = NodePath("../Magazine")
	# snap_zone.tscn ya trae estas conexiones; si no se quitan, pack() las duplica.
	for sig in [well.body_entered, well.body_exited]:
		for c in sig.get_connections():
			sig.disconnect(c.callable)

	# Corredera / cerrojo / bomba: el slider se mueve en +X local, girado para ir hacia atrás (+Z).
	var origin := Node3D.new()
	origin.set_script(load(SLIDER_ORIGIN))
	origin.rotation_degrees.y = -90.0
	origin.position = cfg.slide[0]
	_add(gun, origin, "SlideOrigin")
	origin.limit_minimum = 0.0
	origin.limit_maximum = cfg.slide[2]
	var slider := Node3D.new()
	slider.set_script(load(SLIDER))
	_add(origin, slider, "Slide")
	slider.default_on_release = true
	var smi := MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = Vector3(cfg.slide[1].z, cfg.slide[1].y, cfg.slide[1].x) # ejes girados
	smi.mesh = sbm
	_add(slider, smi, "SlideMesh")
	var horigin = _add(slider, Node3D.new(), "HandleOrigin")
	var handle = _add(horigin, load(HANDLE).instantiate(), "InteractableHandle")
	var hcol := CollisionShape3D.new()
	var hs := SphereShape3D.new()
	hs.radius = 0.035
	hcol.shape = hs
	_add(handle, hcol, "CollisionShape3D")
	return gun


func _add(parent: Node, child: Node, n: String) -> Node:
	child.name = n
	parent.add_child(child)
	child.owner = _root
	return child


# Transformación de `node` relativa a `ancestor` sin estar en el árbol.
func _xf_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != ancestor and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
