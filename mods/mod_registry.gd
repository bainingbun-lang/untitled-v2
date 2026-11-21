class_name ModRegistry
extends RefCounted

const ModManifestScript = preload("res://mods/mod_manifest.gd")
const DEFAULT_PRIORITY := 100

var _loaded: Dictionary = {}
var _order: Array = []


func scan(root_dir: String) -> Dictionary:
	var errors: Array = []
	var candidates: Array = []
	var root := DirAccess.open(root_dir)
	if root == null:
		errors.append("no se pudo abrir el directorio '%s'" % root_dir)
		return {"ok": false, "errors": errors, "candidates": candidates}

	for sub_dir in root.get_directories():
		var dir := root_dir.path_join(sub_dir)
		var manifest_path := dir.path_join("mod.json")
		if not FileAccess.file_exists(manifest_path):
			continue

		var file := FileAccess.open(manifest_path, FileAccess.READ)
		if file == null:
			errors.append("%s: no se pudo leer mod.json" % dir)
			continue
		var text := file.get_as_text()
		file.close()

		var data: Variant = JSON.parse_string(text)
		if data == null:
			errors.append("%s: JSON invalido en mod.json" % dir)
			continue
		if typeof(data) != TYPE_DICTIONARY:
			errors.append("%s: mod.json debe ser un objeto JSON" % dir)
			continue

		_normalize_json_ints(data)
		var result := ModManifestScript.parse(data)
		if not result["ok"]:
			errors.append("%s: manifiesto invalido: %s" % [dir, " | ".join(result["errors"])])
			continue

		candidates.append({"manifest": result["manifest"], "dir": dir})

	return {"ok": errors.is_empty(), "errors": errors, "candidates": candidates}


func load_all(candidates: Array) -> Dictionary:
	var errors: Array = []
	var failed: Dictionary = {}
	var loaded_now: Array = []

	var by_id: Dictionary = {}
	for candidate in candidates:
		var manifest := _manifest_of(candidate)
		var module_id := str(manifest.get("id", ""))
		if module_id.is_empty() or by_id.has(module_id):
			continue
		by_id[module_id] = candidate

	var conflicts := ModManifestScript.find_conflicts(candidates)
	var conflicting: Dictionary = {}
	for conflict in conflicts:
		var message := str(conflict.get("message", "conflicto de reemplazo"))
		errors.append(message)
		for module_id in conflict.get("modules", []):
			conflicting[str(module_id)] = true

	var filtered: Array = []
	for candidate in candidates:
		var manifest := _manifest_of(candidate)
		var module_id := str(manifest.get("id", ""))
		if conflicting.has(module_id):
			failed[module_id] = "conflicto de reemplazo"
			continue
		filtered.append(candidate)

	var resolution := _resolve(filtered)
	for error in resolution["errors"]:
		errors.append(str(error))

	var order: Array = resolution["order"]
	for module_id in order:
		var id := str(module_id)
		if _loaded.has(id):
			continue
		if failed.has(id):
			continue
		if not by_id.has(id):
			continue

		var candidate: Dictionary = by_id[id]
		var manifest: Dictionary = candidate["manifest"]
		var dir := str(candidate.get("dir", ""))
		var blocked := _failed_dependency(manifest, failed)
		if not blocked.is_empty():
			failed[id] = "dependencia no disponible: %s" % blocked
			errors.append("%s no se carga porque su dependencia %s fallo" % [id, blocked])
			continue

		_loaded[id] = {"manifest": manifest, "dir": dir}
		_order.append(id)
		loaded_now.append(id)

	for candidate in candidates:
		var manifest := _manifest_of(candidate)
		var module_id := str(manifest.get("id", ""))
		if module_id.is_empty() or _loaded.has(module_id) or failed.has(module_id):
			continue
		failed[module_id] = "no resuelto (dependencias incompletas)"
		errors.append("%s no se cargo: dependencias incompletas" % module_id)

	return {
		"ok": failed.is_empty() and errors.is_empty(),
		"loaded": loaded_now,
		"failed": failed,
		"errors": errors,
		"order": order,
	}


func is_loaded(module_id: String) -> bool:
	return _loaded.has(module_id)


func loaded_ids() -> Array:
	return _order.duplicate()


func get_manifest(module_id: String) -> Dictionary:
	if not _loaded.has(module_id):
		return {}
	var record: Dictionary = _loaded[module_id]
	return record.get("manifest", {})


func get_dir(module_id: String) -> String:
	if not _loaded.has(module_id):
		return ""
	var record: Dictionary = _loaded[module_id]
	return str(record.get("dir", ""))


func _normalize_json_ints(data: Dictionary) -> void:
	for key in ["schema_version", "priority"]:
		if not data.has(key):
			continue
		var value: Variant = data[key]
		if typeof(value) != TYPE_FLOAT:
			continue
		var number: float = value
		if is_equal_approx(number, round(number)):
			data[key] = int(number)


func _manifest_of(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = entry
	if data.has("manifest") and typeof(data["manifest"]) == TYPE_DICTIONARY:
		return data["manifest"]
	return data


func _failed_dependency(manifest: Dictionary, failed: Dictionary) -> String:
	var depends: Variant = manifest.get("depends", {})
	if typeof(depends) != TYPE_DICTIONARY:
		return ""
	var keys: Array = depends.keys()
	keys.sort()
	for key in keys:
		var dep_id := str(key)
		if failed.has(dep_id):
			return dep_id
	return ""


func _resolve(candidates: Array) -> Dictionary:
	var errors: Array = []
	var records: Dictionary = {}
	var counts: Dictionary = {}

	for candidate in candidates:
		var manifest := _manifest_of(candidate)
		var module_id := str(manifest.get("id", ""))
		if module_id.is_empty():
			errors.append("manifiesto invalido: id ausente")
			continue
		counts[module_id] = int(counts.get(module_id, 0)) + 1
		if not records.has(module_id):
			records[module_id] = manifest

	var ids_sorted: Array = records.keys()
	ids_sorted.sort()

	var failed: Dictionary = {}
	var depends: Dictionary = {}

	for module_id in ids_sorted:
		var id := str(module_id)
		if int(counts[id]) > 1:
			failed[id] = true
			errors.append("id duplicado '%s' (%d manifiestos)" % [id, int(counts[id])])
			continue
		var manifest: Dictionary = records[id]
		var raw_depends: Variant = manifest.get("depends", {})
		if typeof(raw_depends) != TYPE_DICTIONARY:
			failed[id] = true
			errors.append("%s: depends invalido" % id)
			continue
		depends[id] = raw_depends
		var version := str(manifest.get("version", ""))
		if not _is_version(version):
			failed[id] = true
			errors.append("%s: version invalida '%s'" % [id, version])

	var changed := true
	while changed:
		changed = false
		for module_id in ids_sorted:
			var id := str(module_id)
			if failed.has(id) or not depends.has(id):
				continue
			var dep_keys: Array = depends[id].keys()
			dep_keys.sort()
			for dep_key in dep_keys:
				var dep_id := str(dep_key)
				var raw_range := str(depends[id][dep_key])
				if not _is_range(raw_range):
					failed[id] = true
					errors.append("%s: rango de dependencia invalido '%s'" % [id, raw_range])
					changed = true
					break
				if not records.has(dep_id) or failed.has(dep_id):
					failed[id] = true
					errors.append("%s requiere %s, no disponible" % [id, dep_id])
					changed = true
					break
				var installed := str(records[dep_id].get("version", ""))
				if not _satisfies(installed, raw_range):
					failed[id] = true
					errors.append("%s requiere %s %s, instalada %s" % [id, dep_id, raw_range, installed])
					changed = true
					break

	var indegree: Dictionary = {}
	var remaining: Dictionary = {}
	for module_id in ids_sorted:
		var id := str(module_id)
		if failed.has(id):
			continue
		remaining[id] = true
		var count := 0
		for dep_key in depends[id].keys():
			if not failed.has(str(dep_key)):
				count += 1
		indegree[id] = count

	var ready: Array = []
	for module_id in ids_sorted:
		var id := str(module_id)
		if remaining.has(id) and int(indegree[id]) == 0:
			ready.append(id)

	var order: Array = []
	while not ready.is_empty():
		ready.sort_custom(
			func(a, b):
				var pa := int(records[a].get("priority", DEFAULT_PRIORITY))
				var pb := int(records[b].get("priority", DEFAULT_PRIORITY))
				if pa != pb:
					return pa < pb
				return a < b
		)
		var id := str(ready.pop_front())
		order.append(id)
		for module_id in ids_sorted:
			var other := str(module_id)
			if other == id or not remaining.has(other):
				continue
			if depends[other].has(id):
				indegree[other] = int(indegree[other]) - 1
				if int(indegree[other]) == 0 and not ready.has(other):
					ready.append(other)

	for module_id in ids_sorted:
		var id := str(module_id)
		if remaining.has(id) and not order.has(id):
			failed[id] = true
			errors.append("dependencia circular: %s" % id)

	return {"ok": errors.is_empty(), "errors": errors, "order": order}


func _is_version(value: String) -> bool:
	var parts := value.split(".")
	if parts.size() != 3:
		return false
	for part in parts:
		if part.is_empty():
			return false
		for i in part.length():
			if not "0123456789".contains(part[i]):
				return false
	return true


func _parse_version(value: String) -> Array:
	if not _is_version(value):
		return []
	var parts := value.split(".")
	return [int(parts[0]), int(parts[1]), int(parts[2])]


func _compare_versions(a: String, b: String) -> int:
	var pa := _parse_version(a)
	var pb := _parse_version(b)
	if pa.is_empty() or pb.is_empty():
		return 0
	for i in 3:
		if pa[i] < pb[i]:
			return -1
		if pa[i] > pb[i]:
			return 1
	return 0


func _range_tokens(range: String) -> Array:
	var text := range.strip_edges()
	text = text.replace("\t", " ").replace("\n", " ").replace("\r", " ")
	return text.split(" ", false)


func _is_range(range: String) -> bool:
	var tokens := _range_tokens(range)
	if tokens.is_empty():
		return false
	for token in tokens:
		if token == "*":
			continue
		if token.begins_with("^"):
			if not _is_version(token.substr(1)):
				return false
			continue
		var rest: String = token
		for candidate in [">=", "<=", ">", "<", "="]:
			if token.begins_with(candidate):
				rest = token.substr(candidate.length())
				break
		if not _is_version(rest):
			return false
	return true


func _satisfies(version: String, range: String) -> bool:
	if not _is_version(version) or not _is_range(range):
		return false
	for token in _range_tokens(range):
		if token == "*":
			continue
		if token.begins_with("^"):
			var base_text: String = token.substr(1)
			var base := _parse_version(base_text)
			if _compare_versions(version, base_text) < 0:
				return false
			var upper := ""
			if base[0] > 0:
				upper = "%d.0.0" % (base[0] + 1)
			else:
				upper = "0.%d.0" % (base[1] + 1)
			if _compare_versions(version, upper) >= 0:
				return false
			continue
		var op := ""
		var rest: String = token
		for candidate in [">=", "<=", ">", "<", "="]:
			if token.begins_with(candidate):
				op = candidate
				rest = token.substr(candidate.length())
				break
		var result := _compare_versions(version, rest)
		if op == ">=" and result < 0:
			return false
		elif op == ">" and result <= 0:
			return false
		elif op == "<=" and result > 0:
			return false
		elif op == "<" and result >= 0:
			return false
		elif (op == "=" or op.is_empty()) and result != 0:
			return false
	return true
