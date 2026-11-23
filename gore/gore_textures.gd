extends RefCounted

## Texturas de sangre (CC0, ver docs/GORE.md) leídas EN TIEMPO DE EJECUCIÓN de assets/packs/gore_decals.zip.
## Nombres del zip: splat_NN (estallido), drop_NN (gotas con satélites), trail_NN (rastro, eje largo vertical), pool_NN (charco).
const ZIP_PATH := "res://assets/packs/gore_decals.zip"
const CACHE_DIR := "user://packs/"
const KINDS := ["splat", "drop", "trail", "pool"]

static var _tex: Dictionary = {}
static var _loaded := false
static var _fallback: ImageTexture
static var _orm: ImageTexture


static func _ensure() -> void:
	if _loaded:
		return
	_load_zip()
	_add_procedural()


static func _load_zip() -> void:
	_loaded = true
	var zr := ZIPReader.new()
	if zr.open(ZIP_PATH) != OK:
		var bytes := FileAccess.get_file_as_bytes(ZIP_PATH)
		var cache := CACHE_DIR + ZIP_PATH.get_file()
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)
		var f := FileAccess.open(cache, FileAccess.WRITE) if not bytes.is_empty() else null
		if f == null:
			push_warning("GoreTextures: no se pudo abrir %s, uso textura procedural" % ZIP_PATH)
			return
		f.store_buffer(bytes)
		f.close()
		if zr.open(cache) != OK:
			return
	var names := Array(zr.get_files())
	names.sort()
	for n in names:
		var kind: String = String(n).get_file().get_basename().rsplit("_", true, 1)[0]
		var img := Image.new()
		if kind in KINDS and img.load_png_from_buffer(zr.read_file(n)) == OK:
			img.generate_mipmaps()
			if not _tex.has(kind):
				_tex[kind] = []
			_tex[kind].append(ImageTexture.create_from_image(img))
	zr.close()


static func variant_count(kind: String) -> int:
	_ensure()
	return (_tex[kind] as Array).size() if _tex.has(kind) else 0


static func total_count() -> int:
	_ensure()
	var n := 0
	for k in _tex:
		n += (_tex[k] as Array).size()
	return n


## Textura de un tipo; i<0 = al azar. Sin zip devuelve una mancha procedural (nunca null).
static func get_texture(kind: String, i: int = -1) -> Texture2D:
	_ensure()
	if not _tex.has(kind):
		return _get_fallback()
	var arr: Array = _tex[kind]
	return arr[(randi() if i < 0 else i) % arr.size()]


static func is_pack_texture(t: Texture) -> bool:
	_ensure()
	for k in _tex:
		if (_tex[k] as Array).has(t):
			return true
	return false


## Rojo oscuro con variación; fresh 1 = recién salida (más viva), 0 = seca.
static func blood_color(fresh: float = 0.7) -> Color:
	var v := randf_range(0.8, 1.15)
	return Color(lerpf(0.30, 0.62, fresh) * v, 0.012 * v, 0.012 * v, randf_range(0.82, 0.96))


## ORM constante (rugosidad baja) para que el decal parezca húmedo.
static func orm_texture() -> Texture2D:
	if _orm == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.16, 0.0, 1.0))
		_orm = ImageTexture.create_from_image(img)
	return _orm


static func _get_fallback() -> Texture2D:
	if _fallback == null:
		var s := 64
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7741
		var h: Array = []
		for k in 6:
			h.append([rng.randf_range(0.03, 0.09), float(k + 2), rng.randf_range(0.0, TAU)])
		for y in s:
			for x in s:
				var dx := (x + 0.5) / s * 2.0 - 1.0
				var dy := (y + 0.5) / s * 2.0 - 1.0
				var edge := 0.5
				for e in h:
					edge += e[0] * sin(e[1] * atan2(dy, dx) + e[2])
				img.set_pixel(x, y, Color(1, 1, 1, clampf((edge - sqrt(dx * dx + dy * dy)) / 0.08, 0.0, 1.0)))
		_fallback = ImageTexture.create_from_image(img)
	return _fallback


static func _add_procedural() -> void:
	for kind in ["splat", "drop"]:
		if not _tex.has(kind):
			_tex[kind] = []
	for i in 5:
		_tex["splat"].append(_blob(101 + i, 0.38, 1.0))
	for i in 3:
		_tex["drop"].append(_blob(201 + i, 0.2, 0.6))


## Mancha organica: radio deformado por lobulos y ruido, mas gotas satelite (tecnica de Alenvei/GODOT4-Blood-splatter-Tutorial, MIT).
static func _blob(seed_v: int, base: float, spiky: float) -> ImageTexture:
	var s := 96
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	var spikes: Array = []
	for k in rng.randi_range(4, 8):
		spikes.append([rng.randf_range(0.0, TAU), rng.randf_range(0.12, 0.4) * spiky, rng.randf_range(0.05, 0.12)])
	var sats: Array = []
	for k in rng.randi_range(5, 10):
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(0.5, 0.85)
		sats.append([cos(a) * d, sin(a) * d, rng.randf_range(0.025, 0.07)])
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var dx := (x + 0.5) / s * 2.0 - 1.0
			var dy := (y + 0.5) / s * 2.0 - 1.0
			var ang := atan2(dy, dx)
			var edge := base + noise.get_noise_2d(cos(ang) * 2.5, sin(ang) * 2.5) * 0.14 * spiky + noise.get_noise_2d(cos(ang) * 9.0 + 40.0, sin(ang) * 9.0) * 0.045 * spiky
			for sp in spikes:
				var da := absf(wrapf(ang - sp[0], -PI, PI))
				edge += sp[1] * exp(-(da * da) / (sp[2] * sp[2]))
			var a := clampf((edge - sqrt(dx * dx + dy * dy)) / 0.06, 0.0, 1.0)
			for sat in sats:
				a = maxf(a, clampf((sat[2] - Vector2(dx - sat[0], dy - sat[1]).length()) / 0.02, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
