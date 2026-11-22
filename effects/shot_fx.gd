class_name ShotFx
extends RefCounted

const SMOKE := preload("res://effects/Smoke.tscn")
const FLASH_MESH := preload("res://effects/muzzleflash.obj")
const FLASH_MAT := preload("res://effects/muzzle_flash_material.tres")
const FLASH_TIME := 0.05

## Call from the weapon on fire: ShotFx.fire($Pivot/Smoke_spawn_point)
static func fire(point: Node3D) -> void:
	if point == null or not point.is_inside_tree():
		return
	var parent: Node = point.get_tree().current_scene
	var smoke: Node3D = SMOKE.instantiate()
	parent.add_child(smoke)
	smoke.global_transform = point.global_transform
	point.get_tree().create_timer(3.0).timeout.connect(smoke.queue_free)
	var flash := MeshInstance3D.new()
	flash.mesh = FLASH_MESH
	flash.material_override = FLASH_MAT
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_transform = point.global_transform
	point.get_tree().create_timer(FLASH_TIME).timeout.connect(flash.queue_free)
