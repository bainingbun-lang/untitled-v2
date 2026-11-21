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

	if mobile:
		material.render_priority = 1
		material.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	else:
		material.uv1_world_triplanar = true

	_materials[cache_key] = material
	return material


static func make_environment(mobile: bool) -> Environment:
	var sky := Sky.new()
	var procedural := ProceduralSkyMaterial.new()
	procedural.sky_top_color = Color(0.16, 0.32, 0.58)
	procedural.sky_horizon_color = Color(0.70, 0.78, 0.86)
	procedural.ground_bottom_color = Color(0.26, 0.25, 0.23)
	sky.sky_material = procedural

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5 if not mobile else 0.4
	environment.ambient_light_color = Color(0.15, 0.12, 0.1)
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.55, 0.42, 0.32)
	environment.fog_density = 0.005 if not mobile else 0.0035
	environment.fog_sun_scatter = 0.2
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.1
	environment.tonemap_white = 5.5
	environment.background_energy_multiplier = 0.85
	environment.glow_enabled = not mobile
	environment.glow_intensity = 0.12
	return environment
