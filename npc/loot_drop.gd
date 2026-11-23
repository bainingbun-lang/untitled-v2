class_name LootDrop
extends RefCounted

const GUN := "res://weapons/xr_ak47.tscn"
const SPARE_ROUNDS := 30


static func spawn(npc: Node3D) -> void:
	var parent := npc.get_parent()
	if parent == null or not ResourceLoader.exists(GUN):
		return
	var gun := (load(GUN) as PackedScene).instantiate() as RigidBody3D
	gun.name = "Loot_ak47"
	gun.get_node("Magazine").set("rounds", randi_range(4, 20))
	parent.add_child(gun)
	gun.global_position = npc.global_position + Vector3(0.35, 1.0, -0.2)
	var spare := gun.get_node("Magazine").duplicate() as RigidBody3D
	spare.name = "Loot_mag_ak47"
	spare.set("rounds", SPARE_ROUNDS)
	parent.add_child(spare)
	spare.global_position = npc.global_position + Vector3(-0.3, 0.6, 0.15)
	var held := npc.get_node_or_null("Gun") as Node3D
	if held != null:
		held.visible = false
