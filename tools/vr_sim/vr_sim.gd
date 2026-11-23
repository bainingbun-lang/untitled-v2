extends RefCounted
## Simulador de VR por software. Crea trackers falsos (cabeza, mano izq/der) en XRServer y los mueve;
## el XROrigin3D/XRController3D del rig los lee igual que con un casco. Todo con await.
## Uso: var sim = preload("res://tools/vr_sim/vr_sim.gd").new(tree); await sim.attach(scene_root)

const HAND_L := &"left_hand"
const HAND_R := &"right_hand"
const FPS := 60.0

var tree: SceneTree
var origin: XROrigin3D
var camera: XRCamera3D
var controllers := {}
var _trk := {}
var _head: XRPositionalTracker
var _head_local := Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))
var _hand_local := {}


func _init(t: SceneTree) -> void:
	tree = t


## Registra los trackers y localiza origen, cámara y mandos dentro de root. Devuelve false si falta algo.
func attach(root: Node) -> bool:
	await tree.process_frame
	for spec in [[HAND_L, XRPositionalTracker.TRACKER_HAND_LEFT], [HAND_R, XRPositionalTracker.TRACKER_HAND_RIGHT]]:
		var tr := XRServer.get_tracker(spec[0]) as XRPositionalTracker
		if tr == null:
			tr = XRControllerTracker.new() # sin runtime OpenXR: se registra a mano
			tr.type = XRServer.TRACKER_CONTROLLER
			tr.name = spec[0]
			tr.hand = spec[1]
			XRServer.add_tracker(tr)
		_trk[spec[0]] = tr
		_hand_local[spec[0]] = Transform3D(Basis.IDENTITY, Vector3(-0.25, 1.2, -0.2) if spec[0] == HAND_L else Vector3(0.25, 1.2, -0.3))
	_head = XRServer.get_tracker(&"head") as XRPositionalTracker
	if _head == null:
		_head = XRPositionalTracker.new()
		_head.type = XRServer.TRACKER_HEAD
		_head.name = &"head"
		XRServer.add_tracker(_head)
	origin = _find(root, "XROrigin3D") as XROrigin3D
	camera = _find(root, "XRCamera3D") as XRCamera3D
	if origin == null or camera == null:
		return false
	for c in root.find_children("*", "XRController3D", true, false):
		controllers[StringName(c.tracker)] = c
	for n in [["LeftController", HAND_L], ["LeftHand", HAND_L], ["RightController", HAND_R], ["RightHand", HAND_R]]:
		if not controllers.has(n[1]):
			var c := root.find_child(n[0], true, false)
			if c is XRController3D:
				controllers[n[1]] = c
	camera.current = true
	_push_head()
	for h in _trk:
		_push_hand(h)
	await _settle_body()
	return controllers.size() == 2


## Workaround: si el origen nace bajo el suelo (sandbox: origen y=0, suelo y=0.5) PlayerBody crece sin fin, el jugador
## llega a 2.5 m, choca con el techo y no puede caminar. Se sube el origen al suelo y se limita la altura del cuerpo.
func _settle_body() -> void:
	var body := origin.get_node_or_null("PlayerBody")
	if body == null:
		return
	body.set("player_height_max", 1.8)
	await tree.physics_frame
	var q := PhysicsRayQueryParameters3D.create(origin.global_position + Vector3(0, 3, 0), origin.global_position + Vector3(0, -3, 0), 1)
	var hit := origin.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		origin.global_position.y = hit.position.y
	await frames(60)


func _find(root: Node, cls: String) -> Node:
	if root.is_class(cls):
		return root
	var l := root.find_children("*", cls, true, false)
	return l[0] if l.size() > 0 else null


func detach() -> void:
	for h in _trk:
		XRServer.remove_tracker(_trk[h])
	if _head:
		XRServer.remove_tracker(_head)


func frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func wait(seconds: float) -> void:
	await frames(maxi(1, int(seconds * FPS)))


## Coloca al jugador (pies) en un punto del mundo y anula su velocidad (útil si cayó antes de que el mapa tuviera suelo).
func teleport(world_pos: Vector3) -> void:
	origin.global_position = world_pos
	var body := origin.get_node_or_null("PlayerBody")
	if body:
		body.global_position = world_pos
		body.set("velocity", Vector3.ZERO)
	await frames(30)


## Altura del primer suelo bajo (x, z) buscando desde `from_y` hacia abajo; null si no hay.
func floor_at(x: float, z: float, from_y := 5.0) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 20.0, z), 1)
	var hit := origin.get_world_3d().direct_space_state.intersect_ray(q)
	return null if hit.is_empty() else hit.position.y


# ---- cabeza ----

## Posición/giro de la cabeza en espacio del origen (yaw/pitch en grados).
func move_head(local_pos: Vector3, yaw_deg := 0.0, pitch_deg := 0.0) -> void:
	_head_local = Transform3D(Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0)), local_pos)
	_push_head()
	await tree.physics_frame


func head_world() -> Transform3D:
	return camera.global_transform


## Gira la cabeza para mirar a un punto del mundo.
func look_at_point(world: Vector3) -> void:
	var p: Vector3 = origin.global_transform.affine_inverse() * world
	var t := Transform3D(Basis.IDENTITY, _head_local.origin).looking_at(p, Vector3.UP)
	_head_local = t
	_push_head()
	await tree.physics_frame


func _push_head() -> void:
	_head.set_pose(&"default", _head_local, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	camera.transform = _head_local # respaldo: sin interfaz XR activa la cámara no siempre sigue al tracker


# ---- manos ----

func hand_local(hand: StringName) -> Transform3D:
	return _hand_local[hand]


func hand_world(hand: StringName) -> Vector3:
	return origin.global_transform * _hand_local[hand].origin


func _push_hand(hand: StringName, lin_vel := Vector3.ZERO) -> void:
	var t: Transform3D = _hand_local[hand]
	for pose in [&"default", &"grip", &"aim"]:
		_trk[hand].set_pose(pose, t, lin_vel, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)


## Mano en pose absoluta del origen (un solo frame).
func set_hand_local(hand: StringName, t: Transform3D) -> void:
	_hand_local[hand] = t
	_push_hand(hand)
	await tree.physics_frame


## Mano relativa a la cabeza (pos en metros, euler en grados).
func move_hand(hand: StringName, pos_rel_head: Vector3, euler_deg := Vector3.ZERO) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z)))
	await set_hand_local(hand, _head_local * Transform3D(b, pos_rel_head))


## Interpola la mano hasta un punto del mundo (rotación se conserva).
func reach(hand: StringName, world_pos: Vector3, seconds := 0.5) -> void:
	var start: Transform3D = _hand_local[hand]
	var goal: Vector3 = origin.global_transform.affine_inverse() * world_pos
	var n := maxi(1, int(seconds * FPS))
	for i in n:
		var t := start
		t.origin = start.origin.lerp(goal, float(i + 1) / n)
		var vel := (goal - start.origin) / (n / FPS)
		_hand_local[hand] = t
		_push_hand(hand, origin.global_basis * vel)
		await tree.physics_frame
	_push_hand(hand)


## Golpe: mano al objetivo a `speed` m/s (por encima de 3 m/s cuenta como puñetazo).
func punch(hand: StringName, target_world: Vector3, speed := 6.0) -> void:
	var d := hand_world(hand).distance_to(target_world)
	await reach(hand, target_world, maxf(d / speed, 1.0 / FPS))
	await frames(2)


# ---- botones ----

func press(hand: StringName, action: StringName) -> void:
	_trk[hand].set_input(action, true)
	await tree.physics_frame


func release(hand: StringName, action: StringName) -> void:
	_trk[hand].set_input(action, false)
	await tree.physics_frame


func squeeze_grip(hand: StringName, value: float) -> void:
	_trk[hand].set_input(&"grip", value)
	_trk[hand].set_input(&"grip_click", value > 0.7)
	await tree.physics_frame


func pull_trigger(hand: StringName, value := 1.0) -> void:
	_trk[hand].set_input(&"trigger", value)
	_trk[hand].set_input(&"trigger_click", value > 0.7)
	await tree.physics_frame


## Joystick de la mano (eje "primary", movimiento; "secondary" para giro si se pide).
func stick(hand: StringName, v: Vector2, action := &"primary") -> void:
	_trk[hand].set_input(action, v)
	await tree.physics_frame


## Camina con el joystick izquierdo (dir.y>0 = adelante, dir.x>0 = derecha) durante `seconds`.
func walk(dir: Vector2, seconds: float) -> void:
	await stick(HAND_L, dir)
	await wait(seconds)
	await stick(HAND_L, Vector2.ZERO)


## Giro de la cabeza/origen con el joystick derecho (secondary) pulsando un tick.
func turn(x: float) -> void:
	await stick(HAND_R, Vector2(x, 0), &"primary")
	await frames(2)
	await stick(HAND_R, Vector2.ZERO, &"primary")


# ---- captura ----

## Guarda la vista de la cabeza. Necesita render (Xvfb, no --headless). Devuelve false si no hay imagen.
func screenshot(path: String) -> bool:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := camera.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return img.save_png(path) == OK
