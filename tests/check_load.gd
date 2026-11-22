extends SceneTree
# Loads every script and scene; reports failures. Run: godot --headless --path . -s tests/check_load.gd
var fails = 0

func _walk(dir):
	for f in DirAccess.get_files_at(dir):
		var p = dir.path_join(f)
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			var r = load(p)
			if r == null or (r is GDScript and not r.can_instantiate()):
				print("FAIL ", p); fails += 1
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_walk(dir.path_join(d))

func _init():
	_walk("res://")
	print("LOAD_CHECK fails=", fails)
	quit(1 if fails else 0)
