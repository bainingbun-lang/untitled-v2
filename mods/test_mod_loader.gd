extends SceneTree

const LoaderScript = preload("res://mods/mod_loader.gd")

const BOOT_ROOT := "res://mods/test_fixtures/boot"
const DUP_ROOT := "res://mods/test_fixtures/dup"
const EMPTY_ROOT := "res://mods/test_fixtures/empty"
const MISSING_ROOT := "res://mods/test_fixtures/no_existe"

var _checks := 0
var _failures: Array = []
var _case := ""


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, label])


func _initialize() -> void:
	_test_validate()
	_test_discover()
	_test_load_all()
	_test_duplicates()
	_test_paths()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_validate() -> void:
	var loader := LoaderScript.new()

	_case = "manifiesto minimo"
	var good: Dictionary = loader.validate({
		"schema_version": 1,
		"id": "val.mod",
		"version": "1.0.0",
		"engine": "4.7",
	})
	_expect(bool(good.get("ok", false)), "manifiesto minimo valido: %s" % str(good.get("errors", [])))
	var normalized: Dictionary = good.get("manifest", {})
	_expect(int(normalized.get("priority", -1)) == 100, "priority por defecto 100")
	_expect(str(normalized.get("runtime", "")) == "gdscript", "runtime por defecto gdscript")
	_expect(normalized.has("depends") and (normalized["depends"] as Dictionary).is_empty(), "depends por defecto vacio")
	_expect(normalized.has("replaces") and (normalized["replaces"] as Array).is_empty(), "replaces por defecto vacio")

	_case = "numeros de JSON"
	var floats: Dictionary = loader.validate({
		"schema_version": 1.0,
		"id": "val.float",
		"version": "2.0.0",
		"engine": "4.7",
		"priority": 5.0,
	})
	_expect(bool(floats.get("ok", false)), "schema_version y priority float se normalizan: %s" % str(floats.get("errors", [])))
	var float_manifest: Dictionary = floats.get("manifest", {})
	_expect(typeof(float_manifest.get("schema_version")) == TYPE_INT, "schema_version normalizado a int")
	_expect(int(float_manifest.get("priority", -1)) == 5, "priority normalizado a 5")

	_case = "manifiesto invalido"
	var bad: Dictionary = loader.validate({
		"schema_version": 2,
		"id": "VAL",
		"version": "1.0",
		"engine": "4.7",
		"runtime": "python",
		"platforms": ["ios"],
		"pack": "../mal.pck",
		"entry": "mods/main.gd",
	})
	_expect(not bool(bad.get("ok", true)), "manifiesto con 7 errores debe fallar")
	var error_text := " | ".join(bad.get("errors", []))
	_expect(error_text.contains("schema_version"), "detecta schema_version 2")
	_expect(error_text.contains("id:"), "detecta id invalido")
	_expect(error_text.contains("version:"), "detecta version invalida")
	_expect(error_text.contains("runtime:"), "detecta runtime invalido")
	_expect(error_text.contains("platforms:"), "detecta plataforma invalida")
	_expect(error_text.contains("pack:"), "detecta pack con ruta")
	_expect(error_text.contains("entry:"), "detecta entry sin res://")

	_case = "campos obligatorios"
	var empty_manifest: Dictionary = loader.validate({})
	_expect(not bool(empty_manifest.get("ok", true)), "manifiesto vacio debe fallar")
	_expect((empty_manifest.get("errors", []) as Array).size() == 4, "faltan schema_version, id, version y engine")


func _test_discover() -> void:
	var loader := LoaderScript.new()
	_case = "discover con manifiestos invalidos"
	var result: Dictionary = loader.discover(BOOT_ROOT)
	_expect(not bool(result.get("ok", true)), "discover debe reportar rechazos")
	var ids: Array = []
	for candidate in result.get("candidates", []):
		ids.append(str((candidate["manifest"] as Dictionary).get("id", "")))
	ids.sort()
	_expect(ids == ["fixture.base", "fixture.dep", "fixture.missing"], "candidatos incorrectos: %s" % str(ids))
	var rejected: Dictionary = result.get("rejected", {})
	_expect(rejected.size() == 2, "dos subdirectorios rechazados: %s" % str(rejected))
	_expect(rejected.has("invalid") and str(rejected["invalid"]).contains("manifiesto invalido"), "manifiesto invalido rechazado")
	_expect(rejected.has("not_object") and str(rejected["not_object"]).contains("objeto JSON"), "JSON array rechazado")


func _test_load_all() -> void:
	var loader := LoaderScript.new()
	_case = "carga con dependencias"
	var report: Dictionary = loader.load_all(BOOT_ROOT)
	_expect(report.has("loaded") and report.has("rejected") and report.has("order"), "reporte con loaded, rejected y order")
	_expect((report.get("loaded", []) as Array) == ["fixture.base", "fixture.dep"], "loaded en orden: %s" % str(report.get("loaded", [])))
	_expect((report.get("order", []) as Array) == ["fixture.base", "fixture.dep"], "orden de dependencias: %s" % str(report.get("order", [])))
	_expect(not bool(report.get("ok", true)), "reporte no ok por rechazos")
	var rejected: Dictionary = report.get("rejected", {})
	_expect(rejected.size() == 3, "2 rechazos de discover mas dependencia faltante: %s" % str(rejected))
	_expect(rejected.has("fixture.missing") and str(rejected["fixture.missing"]).contains("fixture.absent"), "dependencia ausente rechazada con motivo")
	_expect(loader.is_loaded("fixture.base"), "fixture.base cargado")
	_expect(loader.is_loaded("fixture.dep"), "fixture.dep cargado")
	_expect(not loader.is_loaded("fixture.missing"), "fixture.missing no cargado")
	_expect(loader.loaded_ids() == ["fixture.base", "fixture.dep"], "ids cargados en orden")
	var registry = loader.get_registry()
	_expect(registry.get_manifest("fixture.dep").get("id", "") == "fixture.dep", "registry conserva el manifiesto")
	_expect(str(registry.get_dir("fixture.base")).ends_with("/base"), "registry conserva la carpeta del mod")


func _test_duplicates() -> void:
	var loader := LoaderScript.new()
	_case = "ids duplicados"
	var report: Dictionary = loader.load_all(DUP_ROOT)
	_expect((report.get("loaded", []) as Array).is_empty(), "ningun mod cargado con id duplicado")
	var rejected: Dictionary = report.get("rejected", {})
	_expect(rejected.has("fixture.dup"), "id duplicado rechazado")
	_expect(str(rejected.get("fixture.dup", "")).contains("id duplicado"), "motivo del rechazo menciona el duplicado")


func _test_paths() -> void:
	var loader := LoaderScript.new()
	_case = "directorio vacio"
	var empty: Dictionary = loader.discover(EMPTY_ROOT)
	_expect(bool(empty.get("ok", false)), "directorio vacio ok")
	_expect((empty.get("candidates", []) as Array).is_empty(), "sin candidatos")
	_expect((empty.get("rejected", {}) as Dictionary).is_empty(), "sin rechazos")

	_case = "directorio inexistente"
	var missing: Dictionary = loader.discover(MISSING_ROOT)
	_expect(not bool(missing.get("ok", true)), "directorio inexistente no ok")
	_expect((missing.get("candidates", []) as Array).is_empty(), "sin candidatos")
	_expect((missing.get("rejected", {}) as Dictionary).has(MISSING_ROOT), "rechazo claveado por la ruta")
	var load_missing: Dictionary = loader.load_all(MISSING_ROOT)
	_expect((load_missing.get("loaded", []) as Array).is_empty(), "load_all sin cargados")
	_expect((load_missing.get("order", []) as Array).is_empty(), "load_all sin orden")
