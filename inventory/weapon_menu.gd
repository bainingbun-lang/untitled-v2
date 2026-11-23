class_name WeaponMenu
extends Node

const RemoteLog = preload("res://debug/remote_log.gd")
const IDS :=["pistol", "ak47", "shotgun", "smg", "sniper", "barrett", "machete"]
const BUTTON := "by_button"
const CYCLE := "trigger_click"
const HOLD_SEC := 0.5

var entries: Array = ["(manos libres)"]
var cursor := 0
var open_side := ""

var _hands := {}
var _hold := {}
var _spawned := {}
var _panel: Label3D
var _scene: Node


func setup(player: XRPlayer) -> void:
	_scene = player.get_parent()
	_hands = {"left": player.left_controller, "right": player.right_controller}
	for id in IDS:
		if ResourceLoader.exists("res://weapons/xr_%s.tscn" % id):
			entries.append(id)
	_panel = Label3D.new()
	_panel.pixel_size = 0.0008
	_panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_panel.no_depth_test = true
	_panel.position = Vector3(0.0, 0.14, -0.05)
	for side in _hands:
		var c: XRController3D = _hands[side]
		c.button_pressed.connect(_on_pressed.bind(side))
		c.button_released.connect(_on_released.bind(side))


func is_open() -> bool:
	return open_side != ""


func _process(delta: float) -> void:
	for side in _hold.keys():
		_hold[side] += delta
		if _hold[side] >= HOLD_SEC and not is_open():
			_open(side)


func _on_pressed(action: String, side: String) -> void:
	if action == "grip_click":
		_log_grip(side)
	if action == BUTTON:
		_hold[side] = 0.0
	elif action == CYCLE and is_open() and side != open_side:
		cursor = (cursor + 1) % entries.size()
		_refresh()
		_pulse(open_side, 0.3)


func _on_released(action: String, side: String) -> void:
	if action != BUTTON:
		return
	_hold.erase(side)
	if open_side == side:
		_confirm()


func _open(side: String) -> void:
	open_side = side
	cursor = 0
	var c: XRController3D = _hands[side]
	if _panel.get_parent() != null:
		_panel.get_parent().remove_child(_panel)
	c.add_child(_panel)
	_refresh()
	_pulse(side, 0.6)


func _refresh() -> void:
	var lines: Array = []
	for i in entries.size():
		lines.append(("> " if i == cursor else "   ") + str(entries[i]))
	_panel.text = "\n".join(lines)


func _confirm() -> void:
	var side := open_side
	open_side = ""
	if _panel.get_parent() != null:
		_panel.get_parent().remove_child(_panel)
	give(side, "" if cursor == 0 else str(entries[cursor]))


func give(side: String, id: String) -> Node3D:
	var pickup = (_hands[side] as Node).find_child("FunctionPickup", true, false)
	if pickup == null:
		return null
	var old = _spawned.get(side)
	if is_instance_valid(old):
		if pickup.picked_up_object == old:
			pickup.drop_object()
		old.queue_free()
	_spawned.erase(side)
	if id == "":
		return null
	var w := (load("res://weapons/xr_%s.tscn" % id) as PackedScene).instantiate() as Node3D
	_scene.add_child(w)
	w.global_position = (_hands[side] as Node3D).global_position
	pickup._pick_up_object(w)
	_spawned[side] = w
	return w


func _log_grip(side: String) -> void:
	var c: XRController3D = _hands[side]
	var pickup = c.find_child("FunctionPickup", true, false)
	var tracker := XRServer.get_tracker(c.tracker) as XRPositionalTracker
	var near = pickup.closest_object if pickup != null else null
	RemoteLog.crumb("GRIP %s: grip=%.2f tracker=%s hand=%s cerca=%s sostiene=%s" % [side, c.get_float("grip"), c.tracker, str(tracker.hand) if tracker else "SIN-TRACKER", str(near.name) if near else "nada", str(pickup.picked_up_object.name) if pickup != null and pickup.picked_up_object else "nada"])


func _pulse(side: String, amp: float) -> void:
	(_hands[side] as XRController3D).trigger_haptic_pulse("haptic", 0.0, amp, 0.08, 0.0)
