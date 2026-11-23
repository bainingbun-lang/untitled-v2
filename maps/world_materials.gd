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

const PATTERN := preload("res://assets/prototype_materials/pattern.png")
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
		material.albedo_texture = PATTERN
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.25
	if mobile:
		material.render_priority = 1
		material.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL

	_materials[cache_key] = material
	return material


static func make_environment(mobile: bool) -> Environment:
	var environment := (load("res://assets/env/quest_env.tres") as Environment).duplicate(true) as Environment
	environment.ambient_light_energy = 1.5 if mobile else 1.6
	return environment
