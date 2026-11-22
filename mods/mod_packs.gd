class_name ModPacks
extends RefCounted

## Mods como ZIP. Un mod es un .zip con mod.json en la raíz y los archivos en la misma
## estructura que res:// (scripts, escenas, texturas, audio, datos...). Al montarlo, Godot
## sobrescribe esos archivos, así que un mod puede cambiar cualquier cosa del juego.
## Límites: un script ya cargado no cambia hasta reiniciar. Los mods desactivados no se montan.

const ModLoaderScript = preload("res://mods/mod_loader.gd")
const AppPaths = preload("res://storage/app_paths.gd")
const MANIFEST := "mod.json"
const STATE_FILE := "mods_state.json"
## Áreas que un mod declara que toca. Informativo: se muestra en la lista de mods.
const PERMISSIONS := ["gore", "sandbox", "maps", "npc", "weapons", "textures", "audio", "scripts", "data"]


## Valida un ZIP y lo copia a la carpeta de mods. Devuelve {ok, errors, id, path}.
static func import_zip(zip_path: String) -> Dictionary:
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		return _fail(["no se pudo abrir el ZIP"])
	var files := zr.get_files()
	var errors: Array = []
	for f in files:
		var name := str(f)
		if name.begins_with("/") or name.contains("..") or name.contains("\\"):
			errors.append("ruta peligrosa en el ZIP: " + name)
	if not files.has(MANIFEST):
		errors.append("falta %s en la raíz del ZIP" % MANIFEST)
	var manifest: Dictionary = {}
	if errors.is_empty():
		manifest = _read_manifest(zr)
		var parsed: Dictionary = ModLoaderScript.new().validate(manifest)
		if not parsed.get("ok", false):
			errors.append_array(parsed.get("errors", []))
		for p in manifest.get("permissions", []):
			if not PERMISSIONS.has(str(p)):
				errors.append("permiso desconocido: " + str(p))
	zr.close()
	if not errors.is_empty():
		return _fail(errors)

	var id := str(manifest.get("id", ""))
	var dest := AppPaths.mods_dir().path_join(id.replace("/", "_") + ".zip")
	DirAccess.copy_absolute(zip_path, dest)
	return {"ok": true, "errors": [], "id": id, "path": dest}


## Monta todos los ZIP activos de la carpeta de mods. Llamar antes de cargar la escena principal.
static func mount_all() -> Array:
	var mounted: Array = []
	var off := disabled_files()
	var dir := DirAccess.open(AppPaths.mods_dir())
	if dir == null:
		return mounted
	for f in dir.get_files():
		if str(f).get_extension() != "zip" or off.has(str(f)):
			continue
		if ProjectSettings.load_resource_pack(AppPaths.mods_dir().path_join(str(f)), true):
			mounted.append(str(f))
	return mounted


## Lista los mods instalados con su manifiesto y estado, para la pantalla Mods.
static func list_installed() -> Array:
	var out: Array = []
	var off := disabled_files()
	var dir := DirAccess.open(AppPaths.mods_dir())
	if dir == null:
		return out
	for f in dir.get_files():
		if str(f).get_extension() != "zip":
			continue
		var zr := ZIPReader.new()
		if zr.open(AppPaths.mods_dir().path_join(str(f))) != OK:
			continue
		var m := _read_manifest(zr)
		zr.close()
		out.append({
			"file": str(f),
			"id": m.get("id", ""),
			"name": m.get("name", str(f)),
			"version": m.get("version", ""),
			"permissions": m.get("permissions", []),
			"enabled": not off.has(str(f)),
		})
	return out


## Activa o desactiva un mod sin borrarlo. Se aplica al reiniciar.
static func set_enabled(file_name: String, enabled: bool) -> void:
	var off := disabled_files()
	if enabled:
		off.erase(file_name)
	elif not off.has(file_name):
		off.append(file_name)
	var fa := FileAccess.open(AppPaths.path(STATE_FILE), FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify({"disabled": off}))
		fa.close()


## Borra un mod instalado. Se aplica al reiniciar.
static func remove_installed(file_name: String) -> bool:
	set_enabled(file_name, true)
	return DirAccess.remove_absolute(AppPaths.mods_dir().path_join(file_name)) == OK


static func disabled_files() -> Array:
	var fa := FileAccess.open(AppPaths.path(STATE_FILE), FileAccess.READ)
	if fa == null:
		return []
	var parsed = JSON.parse_string(fa.get_as_text())
	if parsed is Dictionary and parsed.get("disabled") is Array:
		return parsed["disabled"]
	return []


static func _read_manifest(zr: ZIPReader) -> Dictionary:
	if not zr.file_exists(MANIFEST):
		return {}
	var parsed = JSON.parse_string(zr.read_file(MANIFEST).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


static func _fail(errors: Array) -> Dictionary:
	return {"ok": false, "errors": errors, "id": "", "path": ""}
