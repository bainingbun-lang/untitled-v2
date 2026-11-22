class_name NpcReactions
extends Node

## Reacciones de los NPC de un mapa:
##  - Al recibir daño grita "¡REFUERZOS!" y llama un refuerzo armado (máximo REINFORCEMENTS por mapa).
##  - Si el jugador se acerca por detrás (menos de 3 m, fuera de su vista frontal), dice "¿Quién anda ahí?".
## El grito tiene sonido generado (audio/sfx.gd) y texto sobre la cabeza.

const NpcSpawner = preload("res://npc/npc_spawner.gd")
const REINFORCEMENTS := 3
const BEHIND_RANGE := 3.0
const SHOUT_TIME := 2.0
const GameConfig = preload("res://storage/game_config.gd")
const POLICE_UNITS := 2
const POLICE_CAP := 4
const BulletImpact = preload("res://gore/bullet_impact.gd")
const Sfx = preload("res://audio/sfx.gd")
## Tiempo tras aparecer en el que los daños (caídas al piso, choques) no provocan reacciones.
const GRACE_TIME := 3.0

var _map: Node3D
var _eye: Node3D
var _npcs: Array = []
var _budget := REINFORCEMENTS
var _check_time := 0.0
var _seen_shots := 0
var _police_at_ms := -1
var _police_sent := 0
var _born := {}


func setup(map: Node3D, eye: Node3D, npcs: Array) -> void:
	_map = map
	_eye = eye
	for npc in npcs:
		_watch(npc)


func _watch(npc: Node) -> void:
	if npc == null or _npcs.has(npc):
		return
	_npcs.append(npc)
	_born[npc] = Time.get_ticks_msec()
	if npc.has_signal("damaged"):
		npc.damaged.connect(_on_damaged.bind(npc))


func _on_damaged(_amount: float, _health: float, npc: Node) -> void:
	if Time.get_ticks_msec() - int(_born.get(npc, 0)) < GRACE_TIME * 1000.0:
		return
	# Reacción según la gravedad: golpe leve pide que pare, herida grave pide ayuda, y si queda poca vida se rinde.
	var text := "¡REFUERZOS!"
	if _health <= 25.0:
		text = "¡Basta, me rindo!"
	elif _amount < 10.0:
		text = "¡Oye, basta!"
	_shout(npc, text)
	if _health <= 25.0:
		return
	if _budget > 0 and is_instance_valid(_map):
		_budget -= 1
		var pos: Vector3 = (npc as Node3D).global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		var made: Array = NpcSpawner.spawn(_map, [{"id": "refuerzo", "role": "hostile", "armed": true, "count": 1}], [pos], _eye)
		for m in made:
			_watch(m)


func _process(delta: float) -> void:
	_check_time -= delta
	_police_tick()
	if _check_time > 0.0 or not is_instance_valid(_eye):
		return
	_check_time = 0.5
	_npcs = _npcs.filter(func(n) -> bool: return is_instance_valid(n))
	for npc in _npcs:
		if not (npc is Node3D) or npc.get("_dead") == true:
			continue
		var n := npc as Node3D
		var to_player := _eye.global_position - n.global_position
		to_player.y = 0.0
		if to_player.length() > BEHIND_RANGE:
			continue
		var forward := -n.global_transform.basis.z
		if forward.dot(to_player.normalized()) < -0.2:
			_shout(npc, "¿Quién anda ahí?")


func _shout(npc: Node, text: String) -> void:
	if not (npc is Node3D) or not npc.is_inside_tree():
		return
	var n := npc as Node3D
	Sfx.play_at(n, Sfx.shout(), n.global_position)
	var old := n.get_node_or_null("Shout")
	if old != null:
		old.queue_free()
	var label := Label3D.new()
	label.name = "Shout"
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 8
	label.position = Vector3(0, 2.1, 0)
	n.add_child(label)
	get_tree().create_timer(SHOUT_TIME).timeout.connect(_remove_shout.bind(weakref(label)))


func _remove_shout(ref: WeakRef) -> void:
	var label := ref.get_ref() as Node
	if label != null:
		label.queue_free()


## Policía: si está encendida, tras el primer disparo llega una unidad armada después de police_delay segundos.
func _police_tick() -> void:
	if not GameConfig.police or not is_instance_valid(_map):
		return
	if BulletImpact.shots_fired > _seen_shots and _police_at_ms < 0 and _police_sent < POLICE_CAP:
		_police_at_ms = Time.get_ticks_msec() + GameConfig.police_delay * 1000
	_seen_shots = BulletImpact.shots_fired
	if _police_at_ms >= 0 and Time.get_ticks_msec() >= _police_at_ms:
		_police_at_ms = -1
		var pos: Vector3 = _eye.global_position + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12)) if is_instance_valid(_eye) else Vector3(0, 0.5, 0)
		var made: Array = NpcSpawner.spawn(_map, [{"id": "policia", "role": "hostile", "armed": true, "count": POLICE_UNITS}], [pos], _eye)
		_police_sent += POLICE_UNITS
		for m in made:
			_watch(m)
		_shout_all("¡Policía! ¡Suelten las armas!")


func _shout_all(text: String) -> void:
	for npc in _npcs:
		if is_instance_valid(npc):
			_shout(npc, text)
			break
