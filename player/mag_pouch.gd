extends Node3D

const GameConfig = preload("res://storage/game_config.gd")
const AmmoReserve = preload("res://weapons/ammo_reserve.gd")
const START_MAGS := 3
const MAX_MAGS := 6
const GRAB_RADIUS := 0.16

var reserve := AmmoReserve.new()
var player: Node
var _area: Area3D
var _was := {}
var _caps := {}


func setup(p: Node) -> void:
	player = p
	name = "MagPouch"
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.1, 0.06)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.16, 0.1)
	mi.material_override = mat
	add_child(mi)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 0xFFFFF
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.12
	cs.shape = s
	_area.add_child(cs)
	add_child(_area)


func _controller(side: String) -> XRController3D:
	return player.left_controller if side == "left" else player.right_controller


func _pickup(side: String) -> Node:
	return _controller(side).find_child("FunctionPickup", true, false)


func _held(side: String) -> Node:
	var p := _pickup(side)
	return p.picked_up_object if p != null and is_instance_valid(p.picked_up_object) else null


func _process(_delta: float) -> void:
	if player == null:
		return
	for side in ["left", "right"]:
		var c := _controller(side)
		var g := c.is_button_pressed("grip_click")
		if g and not _was.get(side, false) and c.global_position.distance_to(global_position) < GRAB_RADIUS:
			dispense(side)
		_was[side] = g


func _physics_process(_delta: float) -> void:
	if _area == null:
		return
	for b in _area.get_overlapping_bodies():
		if b.has_method("is_picked_up") and b.get("rounds") != null and not b.is_picked_up():
			_return_mag(b)


func capacity(type: String) -> int:
	if not _caps.has(type):
		var path := "res://weapons/xr_%s.tscn" % type.trim_prefix("mag_")
		var cap := 0
		if ResourceLoader.exists(path):
			var inst := (load(path) as PackedScene).instantiate()
			var m := inst.get_node_or_null("Magazine")
			cap = int(m.get("rounds")) if m != null else 0
			inst.free()
		_caps[type] = cap
	return _caps[type]


func _mag_type(b: Node) -> String:
	for g in b.get_groups():
		if str(g).begins_with("mag_"):
			return str(g)
	return ""


func _ensure(type: String) -> void:
	var cap := capacity(type)
	reserve.ensure(type, START_MAGS * cap, MAX_MAGS * cap)


func dispense(side: String) -> Node:
	if _held(side) != null:
		return null
	var other := "right" if side == "left" else "left"
	var gun := _held(other)
	if gun == null or gun.scene_file_path == "":
		return null
	var well := gun.get_node_or_null("MagazineWell")
	if well == null:
		return null
	var type: String = well.snap_require
	var cap := capacity(type)
	if cap <= 0:
		return null
	var amount := cap
	if not GameConfig.infinite_mags:
		_ensure(type)
		amount = reserve.take_ammo_from_reserve(type, cap)
		if amount <= 0:
			_controller(side).trigger_haptic_pulse("haptic", 0.0, 0.5, 0.15, 0.0)
			return null
	var inst := (load(gun.scene_file_path) as PackedScene).instantiate()
	var mag := inst.get_node("Magazine")
	inst.remove_child(mag)
	inst.free()
	mag.name = "PouchMag"
	mag.set("rounds", amount)
	gun.get_parent().add_child(mag)
	mag.global_position = _controller(side).global_position
	_pickup(side)._pick_up_object(mag)
	return mag


func _return_mag(b: Node) -> void:
	var type := _mag_type(b)
	if GameConfig.infinite_mags:
		b.queue_free()
		return
	if type == "" or capacity(type) <= 0:
		return
	_ensure(type)
	var left := reserve.add_ammo_to_reserve(type, int(b.get("rounds")))
	if left == 0:
		b.queue_free()
	else:
		b.set("rounds", left)
