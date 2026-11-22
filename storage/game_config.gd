class_name GameConfig
extends RefCounted

## Ajustes de juego que el menú cambia. Se guardan en settings.cfg, sección [gameplay].
const AppPaths = preload("res://storage/app_paths.gd")
const GoreScript = preload("res://gore/gore_system.gd")
const SECTION := "gameplay"

## Escala de daño de los NPC contra el jugador: Fácil, Normal, Difícil.
const DIFFICULTY_SCALES := {"facil": 0.5, "normal": 1.0, "dificil": 1.5}
static var difficulty: String = "normal"
static var gore_level: int = 1


static func npc_damage_scale() -> float:
	return float(DIFFICULTY_SCALES.get(difficulty, 1.0))


static func load_config() -> void:
	var cf := ConfigFile.new()
	if cf.load(AppPaths.settings_file()) != OK:
		return
	difficulty = str(cf.get_value(SECTION, "difficulty", "normal"))
	gore_level = int(cf.get_value(SECTION, "gore_level", 1))
	GoreScript.set_gore_level(gore_level)


static func save_config() -> int:
	var cf := ConfigFile.new()
	cf.load(AppPaths.settings_file())
	cf.set_value(SECTION, "difficulty", difficulty)
	cf.set_value(SECTION, "gore_level", gore_level)
	return cf.save(AppPaths.settings_file())


static func set_difficulty(value: String) -> void:
	if DIFFICULTY_SCALES.has(value):
		difficulty = value


static func set_gore(level: int) -> void:
	gore_level = clampi(level, 0, 2)
	GoreScript.set_gore_level(gore_level)
