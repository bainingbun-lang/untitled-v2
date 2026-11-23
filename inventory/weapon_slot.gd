class_name WeaponSlot
extends Node

## One hand: holds a weapon, fires it with that hand's trigger, reloads when a hand touches the magazine.

signal fired(slot: WeaponSlot)
signal reloaded(slot: WeaponSlot)

const MAG_TOUCH_RADIUS := 0.12

@export var fire_action := "grab"
@export var reload_action := "ax_button"

var controller: XRController3D
var partner: WeaponSlot
var weapon: Node3D
var id := ""
var blocked := false


func _ready() -> void:
	if controller:
		controller.button_pressed.connect(_on_button)


func hold(weapon_id: String, node: Node3D) -> void:
	id = weapon_id
	weapon = node
	if _is_xr_weapon():
		# Arma xr-tools: se agarra con el FunctionPickup de su mando.
		var pk := _xr_pickup()
		if pk != null:
			weapon.call("pick_up", pk)
	elif weapon.has_method("pick_up"):
		weapon.call("pick_up", controller, controller)


func _is_xr_weapon() -> bool:
	return is_instance_valid(weapon) and weapon.has_method("try_fire")


func _xr_pickup() -> Node:
	return controller.get_node_or_null("XRPickup") if controller else null


func release() -> String:
	var old := id
	if is_instance_valid(weapon):
		if _is_xr_weapon():
			var pk := _xr_pickup()
			if pk != null and weapon.has_method("let_go"):
				weapon.call("let_go", pk, Vector3.ZERO, Vector3.ZERO)
		elif weapon.has_method("let_go"):
			weapon.call("let_go")
		weapon.queue_free()
	weapon = null
	id = ""
	return old


func magazine_position() -> Vector3:
	var mag := weapon.get_node_or_null("Pivot/Magazine") as Node3D
	return mag.global_position if mag else weapon.global_position


func touches_magazine(hand: XRController3D) -> bool:
	return is_instance_valid(weapon) and is_instance_valid(hand) \
		and hand.global_position.distance_to(magazine_position()) < MAG_TOUCH_RADIUS


func reload() -> bool:
	if not is_instance_valid(weapon) or not weapon.has_method("insert_magazine"):
		return false
	weapon.call("eject_magazine")
	weapon.call("insert_magazine")
	if not weapon.call("is_chambered"):
		weapon.call("rack_slide")
	reloaded.emit(self)
	return true


func _on_button(action: String) -> void:
	if blocked:
		return
	if action == fire_action:
		# This hand on the other weapon's magazine reloads it instead of firing.
		if partner and partner.touches_magazine(controller):
			partner.reload()
		elif is_instance_valid(weapon):
			weapon.call("action")
			fired.emit(self)
	elif action == reload_action and is_instance_valid(weapon):
		reload()
