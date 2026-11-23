extends XRToolsPickable

const NECK_CUTS := 4

@export var min_cut_speed := 1.5
@export var dismember_speed := 4.0
@export var max_cut_speed := 10.0
@export var base_damage := 25.0
@export var cut_cooldown := 0.35
@export var hit_sound: AudioStream

@onready var blade: Area3D = $Model/Blade

var _blade_velocity := Vector3.ZERO
var _last_blade_pos := Vector3.ZERO
var _cooldowns: Dictionary = {}
var _neck_progress: Dictionary = {}
var _player: AudioStreamPlayer3D


func _ready() -> void:
	super()
	add_to_group("holsterable")
	_last_blade_pos = blade.global_position
	blade.body_entered.connect(_on_blade_body_entered)
	if hit_sound != null:
		_player = AudioStreamPlayer3D.new()
		_player.stream = hit_sound
		blade.add_child(_player)


func _physics_process(delta: float) -> void:
	var pos := blade.global_position
	_blade_velocity = (pos - _last_blade_pos) / maxf(delta, 0.0001)
	_last_blade_pos = pos
	for body in _cooldowns.keys():
		_cooldowns[body] -= delta
		if _cooldowns[body] <= 0.0 or not is_instance_valid(body):
			_cooldowns.erase(body)


func _on_blade_body_entered(body: Node3D) -> void:
	if _cooldowns.has(body) or get_picked_up_by_controller() == null:
		return
	cut(body, blade.global_position, _blade_velocity)


func cut(body: Node3D, point: Vector3, velocity: Vector3) -> Dictionary:
	var speed := velocity.length()
	if speed < min_cut_speed or not (body.has_method("take_damage") or body.is_in_group("sliceable")):
		return {}
	_cooldowns[body] = cut_cooldown
	var dir := velocity / speed
	var t := clampf((speed - min_cut_speed) / (max_cut_speed - min_cut_speed), 0.0, 1.0)
	var damage := base_damage * lerpf(0.5, 1.5, t)
	var ctrl := get_picked_up_by_controller()
	BulletImpact.apply(body, point, -dir, damage, ctrl)
	var result := {"damage": damage, "dismembered": false, "sliced": false}
	if _player != null:
		_player.pitch_scale = randf_range(0.92, 1.08)
		_player.play()
	if ctrl != null:
		ctrl.trigger_haptic_pulse("haptic", 0.0, lerpf(0.3, 1.0, t), 0.08, 0.0)
	if body.has_method("take_damage") and point.y > body.global_position.y + 1.35:
		var cuts: int = int(_neck_progress.get(body, 0)) + 1
		_neck_progress[body] = cuts
		if cuts >= NECK_CUTS:
			result["decapitated"] = _decapitate(body, point, -dir)
			return result
	if speed >= dismember_speed:
		var skeleton := VrKnife._find_skeleton(body)
		var bone := VrKnife.pick_limb_bone(skeleton, point)
		if bone >= 0:
			result["dismembered"] = not GoreSystem.dismember_limb(body, bone, skeleton, point, -dir).is_empty()
		if body.is_in_group("sliceable"):
			var normal := blade.global_basis.x.cross(dir)
			for mi in body.find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).skin == null and GoreSystem.slice_mesh_instance(mi, point, normal) != null:
					result["sliced"] = true
	return result


func _decapitate(body: Node3D, point: Vector3, normal: Vector3) -> bool:
	var skeleton := VrKnife._find_skeleton(body)
	var head := -1
	if skeleton != null:
		for i in skeleton.get_bone_count():
			var bn := skeleton.get_bone_name(i).to_lower()
			if bn.contains("head") or bn.contains("neck"):
				head = i
				break
	if skeleton != null and head >= 0:
		GoreSystem.dismember_limb(body, head, skeleton, point, normal, "clean")
		GoreSystem.create_puddle(body, Vector3(point.x, 0.53, point.z), Vector3.UP, 0.3)
	body.take_damage(100000.0, point, get_picked_up_by_controller(), "head")
	GoreSystem.blood_spray(body, point, normal)
	GoreSystem.blood_drip(body, point)
	GoreSystem.create_blood_trail(body, point, point + Vector3.DOWN * 1.2)
	return true
