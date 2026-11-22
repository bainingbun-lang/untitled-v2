extends SceneTree

## Prueba headless del ciclo de mods: importar, listar, desactivar, montar y quitar.
## Ejecutar: godot --headless --path . --script res://tests/test_mod_packs.gd
const ModPacks = preload("res://mods/mod_packs.gd")
const AppPaths = preload("res://storage/app_paths.gd")

var _fails := 0


func _init() -> void:
	ModPacks.remove_installed("untitled.demo-catalog.zip")  # estado limpio aunque quede de una prueba previa
	var example := ProjectSettings.globalize_path("res://mods/examples/demo_catalog.zip")
	var bad := _make_bad_zip()

	var r := ModPacks.import_zip(example)
	_expect(r.get("ok", false), "importa el mod de ejemplo")
	_expect(_find(ModPacks.list_installed(), "untitled.demo-catalog").get("enabled", false), "queda activo tras importar")

	ModPacks.set_enabled("untitled.demo-catalog.zip", false)
	_expect(not _find(ModPacks.list_installed(), "untitled.demo-catalog").get("enabled", true), "se puede desactivar")
	_expect(not ModPacks.mount_all().has("untitled.demo-catalog.zip"), "un mod desactivado no se monta")
	ModPacks.set_enabled("untitled.demo-catalog.zip", true)
	_expect(ModPacks.mount_all().has("untitled.demo-catalog.zip"), "un mod activo se monta")

	_expect(not ModPacks.import_zip(bad).get("ok", true), "rechaza un ZIP sin mod.json")

	_expect(ModPacks.remove_installed("untitled.demo-catalog.zip"), "se puede quitar")
	_expect(_find(ModPacks.list_installed(), "untitled.demo-catalog").is_empty(), "ya no aparece tras quitar")

	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)


func _expect(cond: bool, label: String) -> void:
	print(("PASS: " if cond else "FAIL: ") + label)
	if not cond:
		_fails += 1


func _find(list: Array, id: String) -> Dictionary:
	for m in list:
		if m.get("id", "") == id:
			return m
	return {}


func _make_bad_zip() -> String:
	var dir := AppPaths.path("tests_tmp/.keep").get_base_dir()
	var zip_path := dir.path_join("sin_manifiesto.zip")
	var zw := ZIPPacker.new()
	zw.open(zip_path)
	zw.start_file("readme.txt")
	zw.write_file("hola".to_utf8_buffer())
	zw.close_file()
	zw.close()
	return zip_path
