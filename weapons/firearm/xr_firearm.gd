extends XRToolsPickable

## Arma de fuego agarrable con xr-tools: gatillo (FirearmTrigger), cadencia, daño, retroceso visual
## y recarga manual: el cargador entra/sale por la SnapZone "MagazineWell" y la corredera
## (InteractableSlider "SlideOrigin/Slide") mete bala en recámara al ir atrás y volver.
## La munición la lleva WeaponReload; aquí solo se conectan los eventos.
signal shot(hit: Dictionary)

const BulletImpact = preload("res://gore/bullet_impact.gd")
const RemoteLog = preload("res://debug/remote_log.gd")

@export var damage := 40.0
@export var fire_interval := 0.25
@export var automatic := false
@export var pellets := 1
@export var spread_deg := 0.0
@export var max_range := 80.0
@export var magazine_size := 12
@export var spawn_chambered := true
@export var shot_sound: AudioStream
@export var recoil_back := 0.03
@export var recoil_up_deg := 6.0
@export var recoil_recover := 12.0
## Cargador del modelo importado; se oculta porque el cargador real es el nodo "Magazine".
@export var model_magazine: NodePath

var reload: WeaponReload
var _cooldown := 0.0
var _slide_back := false
var _mag: Node3D
var _model: Node3D
var _model_rest: Transform3D
var _trigger: Node
var _muzzle: Node3D
var _handle: XRToolsPickable
var _eject_ctrl: XRController3D
var _shot_pending := false


func _ready() -> void:
	super()
	add_to_group("holsterable")
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC # las fundas (Area3D) no ven cuerpos estáticos
	reload = WeaponReload.new(magazine_size)
	_model = get_node_or_null("Model")
	if _model:
		_paint_bare(_model)
	if _model:
		_model_rest = _model.transform
	if not model_magazine.is_empty():
		get_node(model_magazine).visible = false
	_muzzle = get_node_or_null("Muzzle")
	_trigger = get_node_or_null("FirearmTrigger")
	if _trigger:
		_trigger.fired.connect(try_fire)
	var own_mag := get_node_or_null("Magazine") as PhysicsBody3D
	if own_mag:
		add_collision_exception_with(own_mag) # un cargador cinemático dentro del arma la empujaría
	var well := get_node_or_null("MagazineWell")
	if well:
		well.has_picked_up.connect(_on_mag_in)
		well.has_dropped.connect(_on_mag_out)
	var slide := get_node_or_null("SlideOrigin/Slide")
	if slide:
		slide.slider_moved.connect(_on_slide_moved)
		_handle = slide.get_node_or_null("HandleOrigin/InteractableHandle")
	picked_up.connect(func(_p): _set_handle(true))
	dropped.connect(func(_p): _set_handle(false))
	grabbed.connect(func(_p, _by): _bind_eject())
	released.connect(func(_p, _by): _bind_eject())
	_set_handle(false)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _shot_pending:
		_shot_pending = false
		_cast_shot()
	if automatic and _trigger and _trigger.triggered:
		try_fire()
	if _model:
		_model.transform = _model.transform.interpolate_with(_model_rest, minf(1.0, recoil_recover * delta))


## Dispara si hay bala en recámara y la cadencia lo permite. Devuelve true si salió el tiro.
func try_fire() -> bool:
	if _cooldown > 0.0 or not is_inside_tree() or _muzzle == null or not is_instance_valid(_muzzle):
		return false
	_cooldown = fire_interval
	RemoteLog.crumb("FIRE %s: inicio cham=%s" % [name, str(reload.chambered)])
	if not reload.fire():
		return false
	_play(shot_sound)
	RemoteLog.crumb("FIRE %s: sonido ok" % name)
	_kick()
	RemoteLog.crumb("FIRE %s: kick ok" % name)
	_shot_pending = true # el rayo se lanza en _physics_process: direct_space_state fuera del paso de fisica cierra el juego
	return true


func _cast_shot() -> void:
	var world := get_world_3d()
	if world == null or _muzzle == null or not is_instance_valid(_muzzle):
		RemoteLog.crumb("FIRE %s: sin mundo" % name)
		return
	var space := world.direct_space_state
	RemoteLog.crumb("FIRE %s: espacio ok" % name)
	var exclude: Array[RID] = [get_rid()]
	if is_instance_valid(_mag):
		exclude.append(_mag.get_rid())
	var spread := deg_to_rad(spread_deg)
	for i in pellets:
		var dir := -_muzzle.global_basis.z
		if spread > 0.0:
			dir = dir.rotated(_muzzle.global_basis.x, randf_range(-spread, spread))
			dir = dir.rotated(_muzzle.global_basis.y, randf_range(-spread, spread))
		var from := _muzzle.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * max_range)
		q.exclude = exclude
		RemoteLog.crumb("FIRE %s: rayo armado" % name)
		var hit := space.intersect_ray(q)
		RemoteLog.crumb("FIRE %s: rayo hit=%s" % [name, str(hit.get("collider", "nada"))])
		if not hit.is_empty():
			BulletImpact.apply(hit["collider"], hit["position"], hit["normal"], damage / pellets, self)
			_paint_npc_damage(hit["collider"], hit["position"])
		shot.emit(hit)
	RemoteLog.crumb("FIRE %s: fin" % name)


func _paint_npc_damage(collider: Object, point: Vector3) -> void:
	if not (collider is Node) or not is_instance_valid(collider):
		return
	var npc := collider as Node
	while npc != null and not (npc is BasicNpc):
		npc = npc.get_parent()
	if npc == null:
		return
	var mesh := npc.find_child("*", true, false) as MeshInstance3D
	if mesh == null:
		for c in npc.find_children("*", "MeshInstance3D", true, false):
			mesh = c
			break
	if mesh == null or not is_instance_valid(mesh):
		return
	var uv := DamageUV.uv_at_point(mesh, point)
	if uv.x < 0.0:
		return
	var id := npc.get_instance_id()
	GoreSystem.apply_damage_to_mask(id, uv, 1.0, 8)
	var mat := mesh.material_override as ShaderMaterial
	if mat == null:
		GoreDamageMaterial.bind_damage_mask(id, mesh)
	else:
		var tex := mat.get_shader_parameter("damage_mask") as ImageTexture
		var img := GoreSystem.get_damage_mask(id)
		if tex != null and img != null:
			tex.update(img)


func _kick() -> void:
	if _model == null or not is_instance_valid(_model):
		return
	_model.transform = _model_rest.translated_local(Vector3(0, 0, recoil_back)) \
			.rotated_local(Vector3.RIGHT, deg_to_rad(recoil_up_deg))


func _on_mag_in(mag: Node3D) -> void:
	_mag = mag
	reload.insert_magazine(mag.rounds)
	RemoteLog.crumb("RELOAD %s: cargador entra rounds=%d mag_in=%s" % [name, mag.rounds, str(reload.magazine_in)])
	if spawn_chambered:
		spawn_chambered = false
		reload.rack_slide()


func _on_mag_out() -> void:
	if is_instance_valid(_mag):
		_mag.rounds = reload.magazine_rounds
	_mag = null
	reload.eject_magazine()
	RemoteLog.crumb("RELOAD %s: cargador sale" % name)


# Corredera atrás del todo y de vuelta adelante = un ciclo de recarga.
func _on_slide_moved(pos: float) -> void:
	var limit: float = get_node("SlideOrigin").limit_maximum
	# el recorrido real del mango es corto (~3 cm): umbrales alcanzables
	if pos >= limit * 0.6:
		if not _slide_back:
			RemoteLog.crumb("RELOAD %s: corredera atras pos=%.3f limit=%.3f" % [name, pos, limit])
		_slide_back = true
	elif _slide_back and pos <= limit * 0.4:
		_slide_back = false
		RemoteLog.crumb("RELOAD %s: corredera adelante pos=%.3f limit=%.3f" % [name, pos, limit])
		reload.rack_slide()
		RemoteLog.crumb("RELOAD %s: rack cham=%s" % [name, str(reload.chambered)])


## Con el arma en la mano, A/X de esa mano expulsa el cargador (B/Y queda libre para el menu de armas) (alternativa a sacarlo con la otra mano).
func _bind_eject() -> void:
	var c := get_picked_up_by_controller()
	if _eject_ctrl == c:
		return
	if is_instance_valid(_eject_ctrl):
		_eject_ctrl.button_pressed.disconnect(_on_eject_button)
	_eject_ctrl = c
	if c:
		c.button_pressed.connect(_on_eject_button)


func _on_eject_button(action: String) -> void:
	if action == "ax_button":
		var well := get_node_or_null("MagazineWell")
		if well and well.has_snapped_object():
			var mag: RigidBody3D = well.picked_up_object
			well.enabled = false # si no, la zona lo vuelve a capturar al soltarlo
			well.drop_object()
			mag.linear_velocity = global_basis * Vector3(0.0, -1.5, 0.0)
			get_tree().create_timer(0.6).timeout.connect(func(): well.enabled = true)


func _set_handle(on: bool) -> void:
	if _handle:
		_handle.enabled = on


func _play(stream: AudioStream) -> void:
	if stream == null or not is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	get_tree().root.add_child(p)
	p.global_position = global_position
	p.play()
	p.finished.connect(p.queue_free)


## Compatibilidad con el inventario/arsenal (piden action()): dispara.
func action() -> void:
	try_fire()


## Mallas importadas sin textura salen blancas: acero oscuro mate.
static var _steel: StandardMaterial3D


func _paint_bare(root: Node) -> void:
	if _steel == null:
		_steel = StandardMaterial3D.new()
		_steel.albedo_color = Color(0.13, 0.14, 0.16)
		_steel.metallic = 0.75
		_steel.roughness = 0.42
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null and mat.albedo_texture == null and mat.albedo_color.v > 0.9:
				m.set_surface_override_material(i, _wood() if m.name == &"Stock" else _steel)


static var _wood_mat: StandardMaterial3D


static func _wood() -> StandardMaterial3D:
	if _wood_mat == null:
		_wood_mat = StandardMaterial3D.new()
		_wood_mat.albedo_color = Color(0.36, 0.2, 0.1)
		_wood_mat.roughness = 0.6
	return _wood_mat
