class_name WorldMaterials
extends RefCounted

const SURFACE_COLORS := {
	"ground": Color(0.36, 0.30, 0.22),
	"asphalt": Color(0.20, 0.21, 0.22),
	"concrete": Color(0.55, 0.56, 0.58),
	"metal": Color(0.42, 0.47, 0.52),
	"wood": Color(0.45, 0.31, 0.19),
	"brick": Color(0.55, 0.27, 0.20),
	"glass": Color(0.20, 0.30, 0.50, 0.35),
}

static var _tex_cache: Dictionary = {}
const TEXTURED := ["ground", "brick", "concrete", "wood"]

static var _materials: Dictionary = {}


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("vr")


static func surface_material(surface: String, mobile: bool = false) -> StandardMaterial3D:
	var key := surface.strip_edges().to_lower()
	if not SURFACE_COLORS.has(key):
		key = "concrete"
	var cache_key := key + (".mobile" if mobile else "")
	if _materials.has(cache_key):
		return _materials[cache_key] as StandardMaterial3D

	var material := StandardMaterial3D.new()
	material.albedo_color = SURFACE_COLORS[key]
	match key:
		"metal":
			material.metallic = 0.8
			material.roughness = 0.35
		"glass":
			material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
			material.metallic = 0.6
			material.roughness = 0.1
		"ground":
			material.roughness = 0.95
		"brick":
			material.roughness = 0.85
		"wood":
			material.roughness = 0.6
		_:
			material.roughness = 0.8

	if key in TEXTURED:
		material.albedo_color = Color.WHITE
		material.albedo_texture = _albedo(key)
		var nm := _normal(key)
		if nm != null:
			material.normal_enabled = true
			material.normal_texture = nm
			material.normal_scale = 0.6
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * (0.5 if key == "brick" else 0.35)
	if mobile:
		material.render_priority = 1
		material.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL

	_materials[cache_key] = material
	return material


static func make_environment(mobile: bool) -> Environment:
	var environment := (load("res://assets/env/quest_env.tres") as Environment).duplicate(true) as Environment
	environment.ambient_light_energy = 1.5 if mobile else 1.6
	return environment


## Texturas generadas por código (sin archivos): ladrillo con mortero, concreto, madera con vetas, tierra.
static func _albedo(key: String) -> ImageTexture:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var n := 256
	var img := Image.create(n, n, true, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.04
	noise.fractal_octaves = 4
	var fine := FastNoiseLite.new()
	fine.frequency = 0.35
	var base: Color = SURFACE_COLORS[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	for y in n:
		for x in n:
			var c := base
			var v := noise.get_noise_2d(x, y) * 0.5 + fine.get_noise_2d(x, y) * 0.12
			match key:
				"brick":
					var bh := 32
					var bw := 64
					var row := y / bh
					var xo := x + (bw / 2 if row % 2 == 1 else 0)
					var mortar := (y % bh) < 3 or (xo % bw) < 3
					var brick_id := int(row) * 16 + (xo / bw)
					var tone := float((brick_id * 2654435761) % 1000) / 1000.0
					c = Color(0.62, 0.60, 0.55) if mortar else base.lerp(Color(0.40, 0.18, 0.13), tone * 0.7)
					c = c.lightened(v * 0.5)
				"wood":
					var grain := sin(x * 0.9 + noise.get_noise_2d(x * 0.05, y * 0.6) * 1.2) * 0.5 + 0.5
					c = base.lerp(Color(0.30, 0.19, 0.10), grain * 0.3)
					if x % 64 < 2:
						c = c.darkened(0.45)
					c = c.lightened(v * 0.3)
				"ground":
					c = base.lightened(v * 0.8)
				_:
					c = base.lightened(v * 0.9)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


static func _normal(key: String) -> Texture2D:
	if key == "wood":
		return null
	var cache_key := key + ".n"
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08 if key != "brick" else 0.15
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 6.0 if key != "brick" else 10.0
	_tex_cache[cache_key] = tex
	return tex
