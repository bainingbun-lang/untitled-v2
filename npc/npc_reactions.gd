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
const Sfx = preload("res://audio/sfx.gd")
## Tiempo tras aparecer en el que los daños (caídas al piso, choques) no provocan reacciones.
const GRACE_TIME := 3.0

var _map: Node3D
var _eye: Node3D
var _npcs: Array = []
var _budget := REINFORCEMENTS
var _check_time := 0.0
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
	_shout(npc, "¡REFUERZOS!")
	if _budget > 0 and is_instance_valid(_map):
		_budget -= 1
		var pos: Vector3 = (npc as Node3D).global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		var made: Array = NpcSpawner.spawn(_map, [{"id": "refuerzo", "role": "hostile", "armed": true, "count": 1}], [pos], _eye)
		for m in made:
			_watch(m)


func _process(delta: float) -> void:
	_check_time -= delta
	if _check_time > 0.0 or not is_instance_valid(_eye):
		return
	_check_time = 0.5
	for npc in _npcs:
		if not is_instance_valid(npc) or not (npc is Node3D):
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
	get_tree().create_timer(SHOUT_TIME).timeout.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free())
