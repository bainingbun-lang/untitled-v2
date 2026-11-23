class_name AmmoReserve
extends RefCounted

## Adaptado de godot_weapon_manager (MIT, Copyright (c) 2023 Colormatic), resources/weapons/ammo/ammo_reserve.gd; sin EventBus.

var ammo_reserve: Dictionary = {}


func ensure(type: String, current: int, maximum: int) -> void:
	if not ammo_reserve.has(type):
		ammo_reserve[type] = [current, maximum]


func add_ammo_to_reserve(type: String, amount: int) -> int:
	var amount_to_add := mini(ammo_reserve[type][1] - ammo_reserve[type][0], amount)
	ammo_reserve[type][0] += amount_to_add
	return amount - amount_to_add


func take_ammo_from_reserve(type: String, amount: int) -> int:
	var amount_to_return := mini(ammo_reserve[type][0], amount)
	ammo_reserve[type][0] -= amount_to_return
	return amount_to_return


func fill_ammo_reserve(type: String) -> void:
	ammo_reserve[type][0] = ammo_reserve[type][1]


func get_ammo_amount(type: String) -> int:
	return ammo_reserve[type][0] if ammo_reserve.has(type) else 0
