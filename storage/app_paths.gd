class_name AppPaths
extends RefCounted

## Carpeta de datos del juego. En Android va a Descargas para que el usuario vea y edite
## sus archivos (mods, ajustes, texturas). Si no hay permiso de escritura, cae a user://.
const ANDROID_ROOT := "/storage/emulated/0/Download/Untitled"


## Raíz donde viven todos los datos del juego.
static func root() -> String:
	if OS.get_name() == "Android" and _is_writable(ANDROID_ROOT):
		return ANDROID_ROOT
	return "user://"


## Ruta absoluta de un archivo o carpeta dentro de la raíz, creando las carpetas padre.
static func path(relative: String) -> String:
	var full := root().path_join(relative)
	var parent := full.get_base_dir()
	if parent != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
	return full


static func settings_file() -> String:
	return path("settings.cfg")


static func controller_settings_file() -> String:
	return path("controller_settings.cfg")


static func mods_dir() -> String:
	return path("mods/.keep").get_base_dir()


static func _is_writable(dir_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dir_path)
	var probe := dir_path.path_join(".write_probe")
	var fa := FileAccess.open(probe, FileAccess.WRITE)
	if fa == null:
		return false
	fa.close()
	DirAccess.remove_absolute(probe)
	return true
