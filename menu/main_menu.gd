extends Control

## Menú principal: Jugar (mapas), Mods (instalados e importación) y Configuración.
## Los mapas salen de res://maps/catalog.json, que un mod puede reemplazar.
## Los mods se importan desde Descargas/Untitled/importar y se activan al reiniciar.

const ModPacks = preload("res://mods/mod_packs.gd")
const AppPaths = preload("res://storage/app_paths.gd")
const CATALOG := "res://maps/catalog.json"

var _content: VBoxContainer
var _status: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var title := Label.new()
	title.text = "UNTITLED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	root.add_child(title)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(nav)
	for entry in [["Jugar", _show_play], ["Mods", _show_mods], ["Configuración", _show_settings]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(180, 56)
		b.pressed.connect(entry[1])
		nav.add_child(b)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_content)
	_show_play()


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()


func _show_play() -> void:
	_clear()
	for m in _load_catalog():
		var b := Button.new()
		b.text = str(m.get("name", "Mapa"))
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(func() -> void: get_tree().change_scene_to_file(str(m.get("scene", ""))))
		_content.add_child(b)


func _show_mods() -> void:
	_clear()
	var importer := Button.new()
	importer.text = "Importar mods desde Descargas/Untitled/importar"
	importer.pressed.connect(_import_pending)
	_content.add_child(importer)
	var installed := ModPacks.list_installed()
	if installed.is_empty():
		_content.add_child(_label("No hay mods instalados."))
	for m in installed:
		var row := HBoxContainer.new()
		var lbl := _label("%s  %s" % [m.get("name", ""), m.get("version", "")])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var rm := Button.new()
		rm.text = "Quitar"
		var file_name := str(m.get("file", ""))
		rm.pressed.connect(func() -> void:
			ModPacks.remove_installed(file_name)
			_show_mods())
		row.add_child(rm)
		_content.add_child(row)


func _show_settings() -> void:
	_clear()
	_content.add_child(_label("Carpeta de datos: " + AppPaths.root()))
	_content.add_child(_label("Los cambios de mods necesitan reiniciar el juego."))


func _import_pending() -> void:
	var dir_path := AppPaths.path("importar/.keep").get_base_dir()
	var dir := DirAccess.open(dir_path)
	var ok := 0
	var bad: Array = []
	if dir != null:
		for f in dir.get_files():
			if str(f).get_extension() != "zip":
				continue
			var r := ModPacks.import_zip(dir_path.path_join(str(f)))
			if r.get("ok", false):
				ok += 1
			else:
				bad.append("%s: %s" % [f, ", ".join(r.get("errors", []))])
	_status.text = "Importados: %d. %s Reinicia el juego para aplicarlos." % [ok, "" if bad.is_empty() else "Errores: " + "; ".join(bad)]
	_show_mods()


func _load_catalog() -> Array:
	var fa := FileAccess.open(CATALOG, FileAccess.READ)
	if fa == null:
		return []
	var parsed = JSON.parse_string(fa.get_as_text())
	return parsed if parsed is Array else []


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
