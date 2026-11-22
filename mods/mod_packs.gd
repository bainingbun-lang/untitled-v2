class_name ModPacks
extends RefCounted

## Mods como ZIP. Un mod es un .zip con mod.json en la raíz y los archivos en la misma
## estructura que res:// (scripts, escenas, texturas, audio, datos...). Al montarlo, Godot
## sobrescribe esos archivos, así que un mod puede cambiar cualquier cosa del juego.
## Límite: un script que ya estaba cargado no se cambia hasta reiniciar.

const ModLoaderScript = preload("res://mods/mod_loader.gd")
const AppPaths = preload("res://storage/app_paths.gd")
const MANIFEST := "mod.json"


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
	zr.close()
	if not errors.is_empty():
		return _fail(errors)

	var id := str(manifest.get("id", ""))
	var dest := AppPaths.mods_dir().path_join(id.replace("/", "_") + ".zip")
	DirAccess.copy_absolute(zip_path, dest)
	return {"ok": true, "errors": [], "id": id, "path": dest}


## Monta todos los ZIP de la carpeta de mods. Llamar antes de cargar la escena principal.
static func mount_all() -> Array:
	var mounted: Array = []
	var dir := DirAccess.open(AppPaths.mods_dir())
	if dir == null:
		return mounted
	for f in dir.get_files():
		if str(f).get_extension() != "zip":
			continue
		var path := AppPaths.mods_dir().path_join(str(f))
		if ProjectSettings.load_resource_pack(path, true):
			mounted.append(str(f))
	return mounted


## Lista los mods instalados con su manifiesto, para la pantalla Mods.
static func list_installed() -> Array:
	var out: Array = []
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
		out.append({"file": str(f), "id": m.get("id", ""), "name": m.get("name", str(f)), "version": m.get("version", "")})
	return out


## Borra un mod instalado. Los cambios ya montados se aplican al reiniciar.
static func remove_installed(file_name: String) -> bool:
	return DirAccess.remove_absolute(AppPaths.mods_dir().path_join(file_name)) == OK


static func _read_manifest(zr: ZIPReader) -> Dictionary:
	if not zr.file_exists(MANIFEST):
		return {}
	var parsed = JSON.parse_string(zr.read_file(MANIFEST).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


static func _fail(errors: Array) -> Dictionary:
	return {"ok": false, "errors": errors, "id": "", "path": ""}
