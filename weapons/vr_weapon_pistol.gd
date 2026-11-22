## VR Weapon Pistol
## Copyright (c) 2019 Bastiaan Olij
## MIT License - see LICENSE file

class_name VrWeaponPistol
extends VrWeaponBase

@export var casing_scene: PackedScene = null
@export var smoke_scene: PackedScene = null
@export var initial_casing_velocity: float = 5.0
@export var magazine_size: int = 12
@export var ammunition: int = 12
@export var damage: float = 34.0

@export var rumble: float = 0.0:
	set = set_rumble, get = get_rumble

func set_rumble(new_value: float) -> void:
	if by_controller:
		by_controller.rumble = new_value

func get_rumble() -> float:
	if by_controller:
		return by_controller.rumble
	else:
		return 0.0

func set_ammunition(new_value: int) -> void:
	if ammunition != new_value:
		ammunition = new_value
		if has_node("Ammo_count_viewport/Ammo_count"):
			get_node("Ammo_count_viewport/Ammo_count").text = str(ammunition)
			get_node("Ammo_count_viewport").render_target_update_mode = SubViewport.UPDATE_ONCE

func action() -> void:
	if not has_node("AnimationPlayer") or $AnimationPlayer.is_playing():
		return
	if ammunition > 0:
		set_ammunition(ammunition - 1)
		_play_anim("Fire")
		_emit_smoke()

		if has_node("Aim") and $Aim.is_colliding():
			BulletImpact.apply($Aim.get_collider(), $Aim.get_collision_point(), $Aim.get_collision_normal(), damage, self)
	else:
		_play_anim("EmptyClick")

## Scene may not ship these animations yet; skip missing ones instead of erroring.
func _play_anim(anim: String) -> void:
	if has_node("AnimationPlayer") and $AnimationPlayer.has_animation(anim):
		$AnimationPlayer.play(anim)

func _process(delta: float) -> void:
	if has_node("Aim") and $Aim.is_colliding():
		$Aim/Target_dot.global_transform.origin = $Aim.get_collision_point()
		$Aim/Target_dot.visible = true
	else:
		if has_node("Aim/Target_dot"):
			$Aim/Target_dot.visible = false

func _emit_casing() -> void:
	if casing_scene:
		var new_casing = casing_scene.instantiate()
		new_casing.transform = $Pivot/Casing_spawn_point.global_transform
		new_casing.linear_velocity = new_casing.transform.basis.x * initial_casing_velocity

		get_node("/root/Main/Viewport-VR/Spawns").add_child(new_casing)

func _emit_smoke() -> void:
	if smoke_scene:
		var new_smoke = smoke_scene.instantiate()
		new_smoke.transform = $Pivot/Smoke_spawn_point.global_transform

		get_node("/root/Main/Viewport-VR/Spawns").add_child(new_smoke)

func _on_Gun_load_point_body_entered(body: Node3D) -> void:
	## Our ammo is loaded, so we can destroy our magazine
	body.call("drop_and_free")

	## And reload
	set_ammunition(magazine_size)

	## And finally play reload animation
	_play_anim("Load")