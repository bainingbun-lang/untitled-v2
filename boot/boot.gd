extends Node

const RemoteLog = preload("res://debug/remote_log.gd")
const ModPacks = preload("res://mods/mod_packs.gd")

func _ready():
	RemoteLog.crumb("BOOT: _ready start")
	var label = Label.new()
	label.name = "BootStatus"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	
	call_deferred("_initialize_xr")

func _initialize_xr():
	var status_label = get_node("Layer/BootStatus")
	var xr_interface = XRServer.find_interface("OpenXR")
	
	if not xr_interface:
		status_label.text = "ERROR: OpenXR interface not found"
		print("Boot: OpenXR interface not found"); RemoteLog.crumb("BOOT: FALLO interfaz OpenXR no encontrada")
		return
	
	status_label.text = "Inicializando OpenXR..."
	
	var init_result = xr_interface.initialize()
	if not init_result:
		status_label.text = "ERROR: Failed to initialize OpenXR"
		print("Boot: Failed to initialize OpenXR"); RemoteLog.crumb("BOOT: FALLO initialize OpenXR")
		return
	
	RemoteLog.crumb("BOOT: XR initialized")
	
	status_label.text = "OpenXR inicializado. Configurando viewport..."
	
	var viewport = get_viewport()
	if not viewport:
		status_label.text = "ERROR: No viewport found"
		print("Boot: No viewport found")
		return
	
	viewport.use_xr = true
	
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	status_label.text = "XR listo. Cargando menú..."
	print("Boot: XR initialized successfully, loading demo_room")
	
	var mounted = ModPacks.mount_all()
	RemoteLog.crumb("BOOT: mods montados %d" % mounted.size())
	RemoteLog.crumb("BOOT: before change_scene")
	await get_tree().change_scene_to_file("res://menu/main_menu.tscn")
	RemoteLog.crumb("BOOT: after change_scene")