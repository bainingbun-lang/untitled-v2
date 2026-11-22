class_name BulletImpact
extends RefCounted

const EXIT_MAX_THICKNESS := 0.45
const EXIT_WOUND_SIZE := 0.07

## Entry point for any hitscan weapon: damages the collider and adds a bullet wound on NPCs/props.
static func apply(collider: Object, point: Vector3, normal: Vector3, damage: float, source: Node = null) -> void:
	if collider == null:
		return
	if collider.has_method("take_damage"):
		collider.take_damage(damage, point, source)
	elif collider.has_method("hit"):
		collider.hit(point)
	if collider is Node and ((collider as Node).is_in_group("damageable") or collider is RigidBody3D):
		GoreSystem.create_bullet_wound(collider, point, normal)
		GoreSystem.blood_spray(collider, point, normal)
		GoreSystem.blood_drip(collider, point)
		if collider.has_method("take_damage"):
			_try_exit_wound(collider as Node, point, normal)


## One exit wound max: cast back from behind the body; a hit on the same collider within EXIT_MAX_THICKNESS means the bullet went through.
static func _try_exit_wound(npc: Node, point: Vector3, normal: Vector3) -> Dictionary:
	if not npc is CollisionObject3D or not npc.is_inside_tree() or normal.length_squared() < 0.0001:
		return {}
	var n := normal.normalized()
	var space := (npc as CollisionObject3D).get_world_3d().direct_space_state
	var from := point - n * (EXIT_MAX_THICKNESS + 0.01)
	var query := PhysicsRayQueryParameters3D.create(from, point - n * 0.005)
	var hit := space.intersect_ray(query)
	if hit.is_empty() or hit.get("collider") != npc:
		return {}
	var exit_normal: Vector3 = hit.get("normal", -n)
	GoreSystem.blood_spray(npc, hit["position"], exit_normal)
	return WoundDecals.create_wound(npc, hit["position"], exit_normal, EXIT_WOUND_SIZE, 2, "exit")
