extends SceneTree

## Escenas con el jugador xr-tools: sandbox, menús y mapas se instancian y corren frames sin SCRIPT ERROR
## (run_all.sh falla si ve "SCRIPT ERROR"); el menú VR recibe un clic del mando en su UI; menu_button emite menu_requested.
## Ejecutar: DISPLAY=:99 godot --headless --path . --script res://tests/test_xr_scenes.gd
const SCENES := [
	"res://sandbox/sandbox.tscn", "res://menu/main_menu.tscn", "res://menu/vr_menu.tscn",
	"res://maps/house_model/house_map.tscn", "res://maps/downloaded/school/school_map.tscn",
	"res://maps/downloaded/office/office_map.tscn",
]
var _fails := 0
var _trk := {}


func _init() -> void:
	await process_frame
	for t in [[&"left_hand", XRPositionalTracker.TRACKER_HAND_LEFT], [&"right_hand", XRPositionalTracker.TRACKER_HAND_RIGHT]]:
		var tr := XRControllerTracker.new()
		tr.type = XRServer.TRACKER_CONTROLLER
		tr.name = t[0]
		tr.hand = t[1]
		XRServer.add_tracker(tr)
		_trk[t[0]] = tr
	var head := XRPositionalTracker.new()
	head.type = XRServer.TRACKER_HEAD
	head.name = &"head"
	XRServer.add_tracker(head)
	head.set_pose(&"default", Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for path in SCENES:
		var packed := load(path) as PackedScene
		_expect(packed != null, "%s carga" % path.get_file())
		if packed == null:
			continue
		var inst := packed.instantiate()
		root.add_child(inst)
		for i in 30:
			await physics_frame
		var needs_player: bool = path.get_file() != "main_menu.tscn"
		var p := inst.get_node_or_null("XRPlayer")
		_expect(not needs_player or (p != null and inst.get_node_or_null("VRPlayer") == null), "%s: usa XRPlayer" % path.get_file())
		if path.ends_with("vr_menu.tscn"):
			await _menu_click(inst, p)
		if p != null and path.ends_with("sandbox.tscn"):
			var got := []
			p.menu_requested.connect(func(): got.append(1))
			_trk[&"left_hand"].set_input(&"menu_button", true)
			await physics_frame
			_trk[&"left_hand"].set_input(&"menu_button", false)
			_expect(got.size() == 1, "menu_button emite menu_requested")
		inst.queue_free()
		await process_frame
		await process_frame
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)


## Apunta el mando derecho a un botón del menú 2D y aprieta trigger_click: el botón debe recibir el clic.
func _menu_click(menu: Node, player: Node3D) -> void:
	var button: Button = menu._viewport.get_child(0)._nav_buttons.values()[0]
	var panel: Node3D = menu._panel
	var still := 0 # el panel sigue a la cabeza con suavizado: esperar a que deje de moverse (con tope) antes de apuntar
	var last := panel.global_position
	for i in 600:
		await physics_frame
		still = still + 1 if panel.global_position.distance_to(last) < 0.0005 else 0
		last = panel.global_position
		if still >= 10:
			break
	var clicked := []
	button.pressed.connect(func(): clicked.append(1))
	var rect := button.get_global_rect()
	var c := rect.get_center()
	var size: Vector2 = menu.PANEL_SIZE
	var view: Vector2 = Vector2(menu.VIEW_SIZE)
	var target: Vector3 = panel.global_transform * Vector3(c.x / view.x * size.x - size.x * 0.5, size.y * 0.5 - c.y / view.y * size.y, 0.0)
	var xf := Transform3D(panel.global_basis.orthonormalized(), target + panel.global_basis.z.normalized() * 1.0)
	_trk[&"right_hand"].set_pose(&"grip", player.global_transform.affine_inverse() * xf, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for i in 5:
		await physics_frame
	var hit: Dictionary = menu._ray_panel(player.get_right_controller())
	_expect(not hit.is_empty(), "el rayo del mando cae sobre el botón del menú")
	_trk[&"right_hand"].set_input(&"trigger_click", true)
	await physics_frame
	_trk[&"right_hand"].set_input(&"trigger_click", false)
	await physics_frame
	_expect(clicked.size() == 1, "trigger_click del mando hace clic en la UI del menú VR")


func _expect(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fails += 1
