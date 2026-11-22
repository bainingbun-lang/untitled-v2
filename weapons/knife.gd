## Held knife: the blade Area3D cuts NPCs when it moves fast enough; a fast hit on an arm or leg dismembers.
## Speed/cooldown/damage-by-speed logic adapted from UNTITLED core/game/vr_knife.gd.
class_name VrKnife
extends VrWeaponBase

const LIMB_WORDS := ["arm", "hand", "leg", "thigh", "calf", "shin", "knee", "foot", "elbow"]

@export var min_cut_speed: float = 1.5
@export var dismember_speed: float = 4.0
@export var max_cut_speed: float = 10.0
@export var base_damage: float = 25.0
@export var cut_cooldown: float = 0.35

@onready var blade: Area3D = $Blade

var _blade_velocity := Vector3.ZERO
var _last_blade_pos := Vector3.ZERO
var _cooldowns: Dictionary = {}


func _ready() -> void:
	super._ready()
	_last_blade_pos = blade.global_position
	blade.body_entered.connect(_on_blade_body_entered)


func _physics_process(delta: float) -> void:
	var pos := blade.global_position
	_blade_velocity = (pos - _last_blade_pos) / maxf(delta, 0.0001)
	_last_blade_pos = pos
	for body in _cooldowns.keys():
		_cooldowns[body] -= delta
		if _cooldowns[body] <= 0.0 or not is_instance_valid(body):
			_cooldowns.erase(body)


func _on_blade_body_entered(body: Node3D) -> void:
	if body == self or _cooldowns.has(body) or body == picked_up_by:
		return
	cut(body, blade.global_position, _blade_velocity)


## Applies one cut. Returns what happened, for tests: {"damage", "dismembered", "sliced"}.
func cut(body: Node3D, point: Vector3, velocity: Vector3) -> Dictionary:
	var speed := velocity.length()
	if speed < min_cut_speed or not (body.has_method("take_damage") or body.is_in_group("sliceable")):
		return {}
	_cooldowns[body] = cut_cooldown
	var dir := velocity / speed
	var t := clampf((speed - min_cut_speed) / (max_cut_speed - min_cut_speed), 0.0, 1.0)
	var damage := base_damage * lerpf(0.5, 1.5, t)
	BulletImpact.apply(body, point, -dir, damage, self)
	var result := {"damage": damage, "dismembered": false, "sliced": false}
	if speed >= dismember_speed:
		var skeleton := _find_skeleton(body)
		var bone := pick_limb_bone(skeleton, point)
		if bone >= 0:
			result["dismembered"] = not GoreSystem.dismember_limb(body, bone, skeleton, point, -dir).is_empty()
		if body.is_in_group("sliceable"):
			# Cut plane holds the edge (+X of the knife mesh) and the swing direction.
			var normal := global_basis.x.cross(dir)
			for mi in body.find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).skin == null and GoreSystem.slice_mesh_instance(mi, point, normal) != null:
					result["sliced"] = true
	if by_controller:
		by_controller.trigger_haptic_pulse("haptic", 0.0, lerpf(0.3, 1.0, t), 0.08, 0.0)
	return result


## Nearest arm/leg bone to point, or -1.
static func pick_limb_bone(skeleton: Skeleton3D, point: Vector3) -> int:
	if skeleton == null:
		return -1
	var best := -1
	var best_d := INF
	for i in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(i).to_lower()
		if not LIMB_WORDS.any(func(w): return bone_name.contains(w)):
			continue
		var d := skeleton.to_global(skeleton.get_bone_global_pose(i).origin).distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = i
	return best


static func _find_skeleton(body: Node) -> Skeleton3D:
	var found := body.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null
