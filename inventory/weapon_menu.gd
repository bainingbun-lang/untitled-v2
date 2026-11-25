class_name WeaponMenu
extends Node

const RemoteLog = preload("res://debug/remote_log.gd")
const IDS :=["pistol", "ak47", "shotgun", "smg", "sniper", "barrett", "machete"]
const BUTTON := "by_button"
const CYCLE := "trigger_click"
const HOLD_SEC := 0.5

const PROP := "prop:"
const NPC := "npc:"
const NPC_KINDS := {
	"civil": {"role": "civilian"},
	"hostil": {"role": "hostile"},
	"armado": {"role": "hostile", "armed": true},
	"guardia": {"role": "defender", "armed": true},
	"zombi": {"role": "zombie"},
}
const CLEAR := "(borrar todos los props)"
const CLEAR_HELD := "(borrar el de la mano)"
const CLEAR_NPC := "(borrar NPC)"
const SAVE := "(guardar escena)"
const LOAD := "(cargar escena)"
const CAR := "coche"
const ENTER_CAR := "(subirse o bajarse del coche)"
const PAGE_NAMES := ["Armas", "Props", "NPC"]
const PIN := "ax_button"
const VISIBLE_LINES := 9

var entries: Array = []
var pages: Array = []
var page := 0
var cursor := 0
var open_side := ""

var _hands := {}
var _hold := {}
var _spawned := {}
var _panel: Label3D
var _scene: Node
var _player: XRPlayer


func setup(player: XRPlayer) -> void:
	_player = player
	_scene = player.get_parent()
	_hands = {"left": player.left_controller, "right": player.right_controller}
	var guns: Array = ["(manos libres)"]
	for id in IDS:
		if ResourceLoader.exists("res://weapons/xr_%s.tscn" % id):
			guns.append(id)
	var props: Array = ["(manos libres)"]
	for pid in PropFactory.ids():
		props.append(PROP + str(pid))
	props.append(CAR)
	props.append(ENTER_CAR)
	props.append(CLEAR_HELD)
	props.append(CLEAR)
	props.append(SAVE)
	props.append(LOAD)
	var npcs: Array = ["(manos libres)"]
	for k in NPC_KINDS:
		npcs.append(NPC + str(k))
	npcs.append(CLEAR_NPC)
	pages = [guns, props, npcs]
	entries = guns
	_panel = Label3D.new()
	_panel.pixel_size = 0.0007
	_panel.font_size = 48
	_panel.outline_size = 16
	_panel.outline_modulate = Color(0, 0, 0, 0.95)
	_panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_panel.no_depth_test = true
	_panel.position = Vector3(0.0, 0.25, -0.05)
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
	if action == PIN:
		_toggle_pin(side)
	if action == BUTTON and is_open() and side != open_side:
		_set_page((page + 1) % pages.size())
		_pulse(open_side, 0.4)
	elif action == BUTTON:
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


func _set_page(i: int) -> void:
	page = i
	entries = pages[i]
	cursor = 0
	_refresh()


func _open(side: String) -> void:
	open_side = side
	page = 0
	entries = pages[0]
	cursor = 0
	var c: XRController3D = _hands[side]
	if _panel.get_parent() != null:
		_panel.get_parent().remove_child(_panel)
	_scene.add_child(_panel)
	var fwd := -_player.camera.global_basis.z
	fwd.y = 0.0
	_panel.global_position = c.global_position + Vector3(0.0, 0.2, 0.0) + fwd.normalized() * 0.15
	_refresh()
	_pulse(side, 0.6)


func _refresh() -> void:
	var lines: Array = ["[ %s ]  (B/Y otra mano: cambiar página)" % PAGE_NAMES[page]]
	var first := clampi(cursor - VISIBLE_LINES / 2, 0, maxi(entries.size() - VISIBLE_LINES, 0))
	for i in range(first, mini(first + VISIBLE_LINES, entries.size())):
		lines.append(("> " if i == cursor else "   ") + str(entries[i]).trim_prefix(PROP).trim_prefix(NPC))
	_panel.text = "\n".join(lines)


func _confirm() -> void:
	var side := open_side
	open_side = ""
	if _panel.get_parent() != null:
		_panel.get_parent().remove_child(_panel)
	var chosen := "" if cursor == 0 else str(entries[cursor])
	if chosen == CLEAR:
		for p in get_tree().get_nodes_in_group("prop"):
			p.queue_free()
		return
	if chosen == CLEAR_HELD:
		_delete_held(side)
		return
	if chosen == SAVE:
		_status_haptic(side, SceneStore.save(get_tree()) == OK)
		return
	if chosen == LOAD:
		_status_haptic(side, SceneStore.load_into(_scene as Node3D, NPC_KINDS) >= 0)
		return
	if chosen == CAR:
		_spawn_car()
		return
	if chosen == ENTER_CAR:
		_toggle_car()
		return
	if chosen == CLEAR_NPC:
		for n in get_tree().get_nodes_in_group("basic_npc"):
			n.queue_free()
		return
	if chosen.begins_with(NPC):
		_spawn_npc(chosen.trim_prefix(NPC))
		return
	give(side, chosen)


func give(side: String, id: String) -> Node3D:
	var pickup = (_hands[side] as Node).find_child("FunctionPickup", true, false)
	if pickup == null:
		return null
	var old = _spawned.get(side)
	if is_instance_valid(old):
		if pickup.picked_up_object == old:
			pickup.drop_object()
		old.hide()
		get_tree().create_timer(0.7).timeout.connect(func(): if is_instance_valid(old): old.queue_free()) # xr-tools quita sus excepciones de colision 0.5 s tras soltar
	_spawned.erase(side)
	if id == "":
		return null
	var w: Node3D
	if id.begins_with(PROP):
		w = PropFactory.make(id.trim_prefix(PROP))
		if w == null:
			return null
	else:
		w = (load("res://weapons/xr_%s.tscn" % id) as PackedScene).instantiate() as Node3D
	_scene.add_child(w)
	w.global_position = (_hands[side] as Node3D).global_position
	pickup._pick_up_object(w)
	if not id.begins_with(PROP):
		_spawned[side] = w
	return w


func _status_haptic(side: String, ok: bool) -> void:
	_pulse(side, 0.8 if ok else 0.2)


func _spawn_car() -> void:
	var fwd := -_player.camera.global_basis.z
	fwd.y = 0.0
	var car := Vehicle.new()
	_scene.add_child(car)
	car.global_position = _player.global_position + fwd.normalized() * 4.0 + Vector3(0, 0.3, 0)
	car.look_at(car.global_position + fwd, Vector3.UP)


func _toggle_car() -> void:
	for v in get_tree().get_nodes_in_group(Vehicle.GROUP):
		if v.driver == _player:
			v.exit()
			return
	var best: Vehicle = null
	for v in get_tree().get_nodes_in_group(Vehicle.GROUP):
		if v.global_position.distance_to(_player.global_position) < 6.0:
			best = v
	if best != null:
		best.enter(_player)


func _delete_held(side: String) -> void:
	var pickup = (_hands[side] as Node).find_child("FunctionPickup", true, false)
	var held = pickup.picked_up_object if pickup != null else null
	if held != null and held.is_in_group("prop"):
		pickup.drop_object()
		held.queue_free()


## Aparece a 2 m delante de la cabeza, a la altura del suelo del jugador.
func _spawn_npc(kind: String) -> void:
	var fwd := -_player.camera.global_basis.z
	fwd.y = 0.0
	var pos := _player.global_position + fwd.normalized() * 2.0
	var opts: Dictionary = (NPC_KINDS[kind] as Dictionary).duplicate()
	opts["id"] = "%s_menu" % kind
	var npc := BasicNpc.spawn(_scene as Node3D, pos, opts)
	if npc != null:
		npc.set_meta("menu_kind", kind)
		npc.set_target(_player.camera)


## A/X con un prop en la mano: al soltarlo queda fijo en el aire (otra pulsación lo deja caer). Con un arma, A/X sigue expulsando el cargador.
func _toggle_pin(side: String) -> void:
	var pickup = (_hands[side] as Node).find_child("FunctionPickup", true, false)
	var held = pickup.picked_up_object if pickup != null else null
	if held != null and held.is_in_group("prop"):
		PropFactory.toggle_pin(held)
		_pulse(side, 0.5)


func _log_grip(side: String) -> void:
	var c: XRController3D = _hands[side]
	var pickup = c.find_child("FunctionPickup", true, false)
	var tracker := XRServer.get_tracker(c.tracker) as XRPositionalTracker
	var near = pickup.closest_object if pickup != null else null
	RemoteLog.crumb("GRIP %s: grip=%.2f tracker=%s hand=%s cerca=%s sostiene=%s" % [side, c.get_float("grip"), c.tracker, str(tracker.hand) if tracker else "SIN-TRACKER", str(near.name) if near else "nada", str(pickup.picked_up_object.name) if pickup != null and pickup.picked_up_object else "nada"])


func _pulse(side: String, amp: float) -> void:
	(_hands[side] as XRController3D).trigger_haptic_pulse("haptic", 0.0, amp, 0.08, 0.0)
