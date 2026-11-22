## VR Weapon Rifle
## Copyright (c) 2019 Bastiaan Olij
## MIT License - see LICENSE file

class_name VrWeaponRifle
extends VrWeaponBase

@export var bullet_scene: PackedScene = null
@export var initial_bullet_speed: float = 300.0

@onready var twohanded: VrTwoHanded = $TwoHandedAnchor/TwoHanded
var can_shoot: bool = true

func pick_up(by: Node, with_controller: XRController3D) -> void:
	super.pick_up(by, with_controller)
	twohanded.enabled = true
	
	with_controller.connect("button_pressed", Callable(self, "button_pressed"))
	
	if has_node("Scope"):
		$Scope.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func let_go(starting_linear_velocity: Vector3 = Vector3.ZERO) -> void:
	twohanded.enabled = false
	if picked_up_by:
		picked_up_by.disconnect("button_pressed", Callable(self, "button_pressed"))
	
	super.let_go(starting_linear_velocity)
	
	if has_node("Scope"):
		$Scope.render_target_update_mode = SubViewport.UPDATE_DISABLED

func button_pressed(action: String) -> void:
	if action == "ax_button":
		if has_node("Scope/Camera"):
			$Scope/Camera.fov = clamp($Scope/Camera.fov + 1, 1, 6)
	if action == "by_button":
		if has_node("Scope/Camera"):
			$Scope/Camera.fov = clamp($Scope/Camera.fov - 1, 1, 6)
	
	if has_node("Scope/ScopeUI"):
		$Scope/ScopeUI.set_scope($Scope/Camera.fov)

func action() -> void:
	if can_shoot and bullet_scene:
		## Shoot our bullet
		var new_bullet = bullet_scene.instantiate()
		get_node("/root/Main/Viewport-VR/Spawns").add_child(new_bullet)
		
		var new_transform: Transform3D = $Pivot/Muzzle.global_transform
		new_bullet.linear_velocity = -new_transform.basis.z * initial_bullet_speed
		new_bullet.set_start_transform(new_transform)
		
		## Play our gunshot sound
		if has_node("AudioStreamPlayer3D"):
			$AudioStreamPlayer3D.play()
		
		## Start cooldown
		can_shoot = false
		if has_node("cooldown"):
			$cooldown.start()

func _process(delta: float) -> void:
	if twohanded.is_picked_up():
		if has_node("Pivot/GunHand"):
			$Pivot/GunHand.visible = true
		var target: Vector3 = twohanded.global_transform.origin + (global_transform.basis.y * $TwoHandedAnchor/Target.transform.origin.y)
		$Pivot.look_at(target, global_transform.basis.y)
	else:
		if has_node("Pivot/GunHand"):
			$Pivot/GunHand.visible = false
		$Pivot.transform.basis = Basis.IDENTITY

func _on_cooldown_timeout() -> void:
	can_shoot = true