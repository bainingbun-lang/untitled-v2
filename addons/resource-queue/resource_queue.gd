extends Node

# Godot 4 port: same API as the Godot 3 threaded queue, backed by ResourceLoader.load_threaded_*.

var pending = {}

func start():
	pass

func stop():
	pass

func queue_resource(path, _p_in_front = false):
	if path in pending:
		return
	if ResourceLoader.has_cached(path):
		pending[path] = ResourceLoader.load(path)
	else:
		ResourceLoader.load_threaded_request(path)
		pending[path] = null

func cancel_resource(path):
	pending.erase(path)

func get_progress(path):
	if not path in pending:
		return -1
	if pending[path] != null:
		return 1.0
	var progress = []
	var status = ResourceLoader.load_threaded_get_status(path, progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_FAILED:
		return 1.0
	return progress[0] if progress.size() > 0 else 0.0

func is_ready(path):
	return path in pending and get_progress(path) >= 1.0

func get_resource(path):
	if path in pending:
		var res = pending[path]
		pending.erase(path)
		if res == null:
			res = ResourceLoader.load_threaded_get(path)
		return res
	return ResourceLoader.load(path)
