extends Control

## Menú principal: Jugar (mapas), Mods (instalar, activar, quitar) y Configuración.
## Los mapas salen de res://maps/catalog.json, que un mod puede reemplazar.
## Los mods se importan desde Descargas/Untitled/importar y se activan al reiniciar.
## Funciona igual en pantalla plana y dentro del panel 3D del casco (vr_menu.gd).

const ModPacks = preload("res://mods/mod_packs.gd")
const AppPaths = preload("res://storage/app_paths.gd")
const GameConfig = preload("res://storage/game_config.gd")
const CATALOG := "res://maps/catalog.json"
const DIFFICULTIES := [["Fácil", "facil"], ["Normal", "normal"], ["Difícil", "dificil"]]
const GORE_LEVELS := ["Apagado", "Normal", "Extremo"]
const POCKET_LABELS := {"pistol": "Pistola", "ak47": "AK-47", "knife": "Cuchillo", "sniper": "Sniper", "machete": "Machete"}

const BG := Color("0d1014")
const CARD := Color("161b22")
const CARD_EDGE := Color("242c36")
const BUTTON := Color("21262d")
const BUTTON_HOVER := Color("2d3541")
const ACCENT := Color("e0503a")
const TEXT := Color("e6edf3")
const MUTED := Color("8b949e")
const GOOD := Color("3fb950")
const BAD := Color("f85149")

var _content: VBoxContainer
var _status: Label
var _nav_buttons: Dictionary = {}
var _current := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _build_theme()

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(980, 0)
	card.add_theme_stylebox_override("panel", _box(CARD, CARD_EDGE, 16, 28))
	center.add_child(card)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	card.add_child(root)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	root.add_child(header)
	var title := Label.new()
	title.text = "UNTITLED"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", TEXT)
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Sandbox moddable"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", MUTED)
	header.add_child(subtitle)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	root.add_child(nav)
	for entry in [["Jugar", _show_play], ["Mods", _show_mods], ["Configuración", _show_settings]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(200, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(entry[1])
		nav.add_child(b)
		_nav_buttons[entry[0]] = b

	var divider := HSeparator.new()
	root.add_child(divider)

	_status = Label.new()
	_status.add_theme_color_override("font_color", MUTED)
	_status.add_theme_font_size_override("font_size", 15)
	root.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

	_show_play()


func _build_theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", _box(BUTTON, CARD_EDGE, 10, 12))
	t.set_stylebox("hover", "Button", _box(BUTTON_HOVER, ACCENT, 10, 12))
	t.set_stylebox("pressed", "Button", _box(ACCENT, ACCENT, 10, 12))
	t.set_stylebox("focus", "Button", _box(BUTTON, ACCENT, 10, 12))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_font_size("font_size", "Button", 18)
	t.set_stylebox("normal", "OptionButton", _box(BUTTON, CARD_EDGE, 10, 10))
	t.set_stylebox("hover", "OptionButton", _box(BUTTON_HOVER, ACCENT, 10, 10))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_font_size("font_size", "OptionButton", 17)
	t.set_stylebox("panel", "PopupMenu", _box(CARD, CARD_EDGE, 10, 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 17)
	return t


func _box(bg: Color, edge: Color, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


func _mark_nav(section: String) -> void:
	_current = section
	for k in _nav_buttons:
		var b: Button = _nav_buttons[k]
		b.add_theme_stylebox_override("normal", _box(ACCENT if k == section else BUTTON, ACCENT if k == section else CARD_EDGE, 10, 12))


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", TEXT)
	return l


func _show_play() -> void:
	_clear()
	_mark_nav("Jugar")
	_status.text = "Elige un mapa para empezar."
	_content.add_child(_heading("Mapas"))
	for m in _load_catalog():
		var b := Button.new()
		b.text = "   " + str(m.get("name", "Mapa"))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(func() -> void: get_tree().change_scene_to_file(str(m.get("scene", ""))))
		_content.add_child(b)


func _show_mods() -> void:
	_clear()
	_mark_nav("Mods")
	var top := HBoxContainer.new()
	top.add_child(_heading("Mods instalados"))
	top.add_child(_spacer())
	var importer := Button.new()
	importer.text = "Importar desde Descargas/Untitled/importar"
	importer.pressed.connect(_import_pending)
	top.add_child(importer)
	_content.add_child(top)

	var installed := ModPacks.list_installed()
	if installed.is_empty():
		_content.add_child(_muted("No hay mods instalados. Copia un .zip a Descargas/Untitled/importar y pulsa Importar."))
	for m in installed:
		_content.add_child(_mod_row(m))


func _mod_row(m: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(CARD, CARD_EDGE, 10, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_lbl := Label.new()
	name_lbl.text = "%s  %s" % [m.get("name", ""), m.get("version", "")]
	name_lbl.add_theme_font_size_override("font_size", 18)
	info.add_child(name_lbl)
	var perms: Array = m.get("permissions", [])
	var meta := Label.new()
	meta.text = "Áreas: " + (", ".join(PackedStringArray(perms)) if not perms.is_empty() else "sin declarar")
	meta.add_theme_color_override("font_color", MUTED)
	meta.add_theme_font_size_override("font_size", 14)
	info.add_child(meta)

	var file_name := str(m.get("file", ""))
	var enabled: bool = m.get("enabled", true)
	var toggle := Button.new()
	toggle.text = "Activo" if enabled else "Desactivado"
	toggle.add_theme_color_override("font_color", GOOD if enabled else MUTED)
	toggle.custom_minimum_size = Vector2(130, 44)
	toggle.pressed.connect(func() -> void:
		ModPacks.set_enabled(file_name, not enabled)
		_status.text = "Reinicia el juego para aplicar el cambio."
		_show_mods())
	row.add_child(toggle)

	var rm := Button.new()
	rm.text = "Quitar"
	rm.add_theme_color_override("font_color", BAD)
	rm.custom_minimum_size = Vector2(110, 44)
	rm.pressed.connect(func() -> void:
		ModPacks.remove_installed(file_name)
		_status.text = "Mod quitado. Reinicia el juego para aplicar el cambio."
		_show_mods())
	row.add_child(rm)
	return card


func _show_settings() -> void:
	_clear()
	_mark_nav("Configuración")
	_status.text = ""
	_content.add_child(_heading("Gameplay"))

	var gore := OptionButton.new()
	for i in GORE_LEVELS.size():
		gore.add_item(GORE_LEVELS[i], i)
	gore.select(GameConfig.gore_level)
	gore.item_selected.connect(func(i: int) -> void: GameConfig.set_gore(i); _save())
	_content.add_child(_setting_row("Gore", gore))

	var diff := OptionButton.new()
	var selected := 1
	for i in DIFFICULTIES.size():
		diff.add_item(DIFFICULTIES[i][0], i)
		if DIFFICULTIES[i][1] == GameConfig.difficulty:
			selected = i
	diff.select(selected)
	diff.item_selected.connect(func(i: int) -> void: GameConfig.set_difficulty(DIFFICULTIES[i][1]); _save())
	_content.add_child(_setting_row("Dificultad", diff))

	var pocket := OptionButton.new()
	var keys: Array = GameConfig.POCKET_WEAPONS
	for i in keys.size():
		pocket.add_item(POCKET_LABELS.get(keys[i], keys[i]), i)
		if keys[i] == GameConfig.left_pocket:
			pocket.select(i)
	pocket.item_selected.connect(func(i: int) -> void: GameConfig.set_left_pocket(keys[i]); _save())
	_content.add_child(_setting_row("Bolsillo izquierdo", pocket))

	_content.add_child(_spacer_v())
	_content.add_child(_heading("Datos"))
	_content.add_child(_muted("Carpeta de datos: " + AppPaths.root()))


func _setting_row(text: String, control: Control) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(CARD, CARD_EDGE, 10, 14))
	var row := HBoxContainer.new()
	card.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(200, 0)
	row.add_child(lbl)
	control.custom_minimum_size = Vector2(220, 40)
	row.add_child(control)
	return card


func _save() -> void:
	var err := GameConfig.save_config()
	_status.text = "Guardado." if err == OK else "No se pudo guardar la configuración (error %d)." % err


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
				bad.append("%s: %s" % [f, ", ".join(PackedStringArray(r.get("errors", [])))])
	_status.text = "Importados: %d. %s Reinicia el juego para aplicarlos." % [ok, "" if bad.is_empty() else "Errores: " + "; ".join(PackedStringArray(bad))]
	_show_mods()


func _load_catalog() -> Array:
	var fa := FileAccess.open(CATALOG, FileAccess.READ)
	if fa == null:
		return []
	var parsed = JSON.parse_string(fa.get_as_text())
	return parsed if parsed is Array else []


func _muted(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", MUTED)
	l.add_theme_font_size_override("font_size", 15)
	return l


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _spacer_v() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 12)
	return c
