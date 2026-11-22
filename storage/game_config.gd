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
## Arma del bolsillo izquierdo (se saca con la mano izquierda).
const POCKET_WEAPONS := ["pistol", "ak47", "knife", "sniper", "machete", "shotgun", "barrett"]
static var left_pocket: String = "pistol"
## Relleno de NPC por m² de mapa, y zombis en lugar de algunos civiles.
const DENSITY_PER_M2 := {"bajo": 0.08, "medio": 0.16, "alto": 0.3}
static var density: String = "medio"
static var zombies: bool = false


static func npc_damage_scale() -> float:
	return float(DIFFICULTY_SCALES.get(difficulty, 1.0))


static func load_config() -> void:
	var cf := ConfigFile.new()
	if cf.load(AppPaths.settings_file()) != OK:
		return
	difficulty = str(cf.get_value(SECTION, "difficulty", "normal"))
	gore_level = int(cf.get_value(SECTION, "gore_level", 1))
	left_pocket = str(cf.get_value(SECTION, "left_pocket", "pistol"))
	density = str(cf.get_value(SECTION, "density", "medio"))
	zombies = bool(cf.get_value(SECTION, "zombies", false))
	if not POCKET_WEAPONS.has(left_pocket):
		left_pocket = "pistol"
	GoreScript.set_gore_level(gore_level)


static func save_config() -> int:
	var cf := ConfigFile.new()
	cf.load(AppPaths.settings_file())
	cf.set_value(SECTION, "difficulty", difficulty)
	cf.set_value(SECTION, "gore_level", gore_level)
	cf.set_value(SECTION, "left_pocket", left_pocket)
	cf.set_value(SECTION, "density", density)
	cf.set_value(SECTION, "zombies", zombies)
	return cf.save(AppPaths.settings_file())


static func set_difficulty(value: String) -> void:
	if DIFFICULTY_SCALES.has(value):
		difficulty = value


static func set_gore(level: int) -> void:
	gore_level = clampi(level, 0, 2)
	GoreScript.set_gore_level(gore_level)


static func set_left_pocket(weapon_id: String) -> void:
	if POCKET_WEAPONS.has(weapon_id):
		left_pocket = weapon_id


static func density_per_m2() -> float:
	return float(DENSITY_PER_M2.get(density, 0.16))
