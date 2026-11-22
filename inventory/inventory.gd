class_name Inventory
extends Node3D

## Stored weapons (max 4) plus one weapon per hand. Left menu button toggles a simple panel.
## While open: right trigger moves the cursor, left trigger puts the selected weapon in the left hand.

signal changed

const MAX_WEAPONS := 4
const SCENES := {
	"ak47": "res://weapons/ak47.tscn",
	"pistol": "res://weapons/pistol.tscn",
	"knife": "res://weapons/knife.tscn",
	"sniper": "res://weapons/sniper.tscn",
	"shotgun": "res://weapons/shotgun.tscn",
	"machete": "res://weapons/machete.tscn",
}

@export var menu_action := "menu_button"

var weapons: Array[String] = []
var right: WeaponSlot
var left: WeaponSlot
var panel: Label3D
var cursor := 0


func setup(right_controller: XRController3D, left_controller: XRController3D) -> void:
	right = _make_slot("RightSlot", right_controller)
	left = _make_slot("LeftSlot", left_controller)
	right.partner = left
	left.partner = right
	panel = Label3D.new()
	panel.name = "InventoryPanel"
	panel.pixel_size = 0.0008
	panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	panel.no_depth_test = true
	panel.position = Vector3(0.0, 0.08, -0.06)
	panel.visible = false
	left_controller.add_child(panel)
	left_controller.button_pressed.connect(_on_left_button)
	right_controller.button_pressed.connect(_on_right_button)


func _make_slot(n: String, c: XRController3D) -> WeaponSlot:
	var s := WeaponSlot.new()
	s.name = n
	s.controller = c
	add_child(s)
	return s


func add(id: String) -> bool:
	if weapons.size() >= MAX_WEAPONS or not SCENES.has(id):
		return false
	weapons.append(id)
	_refresh()
	return true


func remove(id: String) -> bool:
	var i := weapons.find(id)
	if i < 0:
		return false
	weapons.remove_at(i)
	cursor = clampi(cursor, 0, maxi(weapons.size() - 1, 0))
	_refresh()
	return true


func equip_right(id: String) -> bool:
	return _equip(right, id)


func equip_left(id: String) -> bool:
	return _equip(left, id)


## Registers a weapon node that already exists in the scene (e.g. the starting AK) as held by a slot.
func hold_existing(slot: WeaponSlot, id: String, node: Node3D) -> void:
	slot.hold(id, node)
	changed.emit()


func stow(slot: WeaponSlot) -> bool:
	if slot.id.is_empty() or weapons.size() >= MAX_WEAPONS:
		return false
	add(slot.release())
	return true


func is_open() -> bool:
	return panel != null and panel.visible


func toggle() -> void:
	panel.visible = not panel.visible
	right.blocked = panel.visible
	left.blocked = panel.visible
	_refresh()


func _equip(slot: WeaponSlot, id: String) -> bool:
	if not remove(id):
		return false
	if not slot.id.is_empty() and not stow(slot):
		add(id)
		return false
	var node := (load(SCENES[id]) as PackedScene).instantiate() as Node3D
	get_parent().add_child(node)
	node.global_transform = slot.controller.global_transform
	slot.hold(id, node)
	changed.emit()
	return true


func _on_left_button(action: String) -> void:
	if action == menu_action:
		toggle()
	elif is_open() and action == left.fire_action and not weapons.is_empty():
		equip_left(weapons[cursor])
		toggle()


func _on_right_button(action: String) -> void:
	if is_open() and action == right.fire_action and not weapons.is_empty():
		cursor = (cursor + 1) % weapons.size()
		_refresh()


func _refresh() -> void:
	changed.emit()
	if panel == null:
		return
	var lines := PackedStringArray(["INVENTARIO  D:%s  I:%s" % [right.id, left.id]])
	for i in weapons.size():
		lines.append(("> " if i == cursor else "  ") + weapons[i])
	if weapons.is_empty():
		lines.append("  (vacio)")
	panel.text = "\n".join(lines)
