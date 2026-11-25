class_name MapLoader
extends RefCounted

## Carga un mapa en un hilo y cambia de escena al terminar; el menú sigue dibujando (sin congelar el visor).
## Devuelve false si la carga no pudo empezar o falló.
static func go(tree: SceneTree, path: String, on_progress: Callable = Callable()) -> bool:
	if not ResourceLoader.exists(path):
		push_warning("MapLoader: no existe " + path)
		return false
	if ResourceLoader.load_threaded_request(path) != OK:
		return false
	var prog := []
	while true:
		var st := ResourceLoader.load_threaded_get_status(path, prog)
		if on_progress.is_valid() and not prog.is_empty():
			on_progress.call(float(prog[0]))
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			push_warning("MapLoader: fallo al cargar " + path)
			return false
		await tree.process_frame
	tree.change_scene_to_packed(ResourceLoader.load_threaded_get(path) as PackedScene)
	return true
