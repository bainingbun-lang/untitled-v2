extends SceneTree

func _init() -> void:
	await process_frame
	var M = load("res://menu/main_menu.gd")
	var b = M.CycleButton.new()
	for t in ["Apagado", "Normal", "Extremo"]:
		b.add_item(t)
	b.select(1)
	var got := []
	b.item_selected.connect(func(i): got.append(i))
	b.get_child(2).pressed.emit()
	b.get_child(2).pressed.emit()
	b.get_child(0).pressed.emit()
	var ok: bool = got == [2, 0, 2] and b.get_child(1).text == "Extremo"
	print(("PASS " if ok else "FAIL ") + b.get_child(1).text + str(got))
	quit(0 if ok else 1)
