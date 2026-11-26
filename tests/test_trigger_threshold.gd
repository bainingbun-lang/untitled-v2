extends SceneTree

const T = preload("res://weapons/firearm/trigger_hysteresis.gd")
var _fails := 0


func _expect(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fails += 1


func _init() -> void:
	_expect(T.next_state(false, 0.1) == false, "0.1 sigue false")
	_expect(T.next_state(false, 0.5) == false, "0.5 desde false sigue false")
	_expect(T.next_state(false, 0.8) == true, "0.8 pasa a true")
	_expect(T.next_state(true, 0.5) == true, "0.5 desde true sigue true")
	_expect(T.next_state(true, 0.2) == false, "0.2 pasa a false")
	print("RESULTADO: OK" if _fails == 0 else "RESULTADO: FALLO (%d fallos)" % _fails)
	quit(0 if _fails == 0 else 1)
