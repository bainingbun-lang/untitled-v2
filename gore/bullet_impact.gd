class_name BulletImpact
extends RefCounted

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
