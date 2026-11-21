extends SceneTree

const RemoteLog = preload("res://debug/remote_log.gd")

var _checks := 0
var _failures: Array = []
var _case := ""


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, label])


func _initialize() -> void:
	await _run()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _run() -> void:
	_case = "constantes y estado inicial"
	_expect(RemoteLog.HOST == "192.168.1.5", "HOST del receptor")
	_expect(RemoteLog.PORT == 8765, "PORT del receptor")
	_expect(RemoteLog.RETRY_DELAY_MSEC == 3000, "reintento de 3 s")
	RemoteLog.retry_at_msec = 0
	_expect(RemoteLog.retry_at_msec == 0, "retry_at_msec empieza en 0")

	var source := FileAccess.get_file_as_string("res://debug/remote_log.gd")
	_expect(source.count("retry_at_msec = Time.get_ticks_msec() + RETRY_DELAY_MSEC") == 2, "las dos rutas de fallo programan el reintento")
	_expect(source.contains("DisplayServer.get_name() == \"headless\""), "guard headless presente en send")

	_case = "headless no envia"
	_expect(DisplayServer.get_name() == "headless", "la prueba corre en headless")
	RemoteLog.send("test_send", "cuerpo")
	_expect(RemoteLog.retry_at_msec == 0, "send en headless no toca el temporizador")
	RemoteLog.crumb("test_crumb")
	_expect(RemoteLog.retry_at_msec == 0, "crumb en headless no toca el temporizador")
	RemoteLog.upload_previous_logs()
	_expect(RemoteLog.retry_at_msec == 0, "upload_previous_logs en headless no toca el temporizador")

	_case = "ventana de reintento"
	var future := Time.get_ticks_msec() + RemoteLog.RETRY_DELAY_MSEC
	RemoteLog.retry_at_msec = future
	RemoteLog.send("test_retry", "cuerpo")
	_expect(RemoteLog.retry_at_msec == future, "dentro de la ventana no se reintenta")
	RemoteLog.retry_at_msec = Time.get_ticks_msec() - 1
	RemoteLog.send("test_expirado", "cuerpo")
	_expect(RemoteLog.retry_at_msec < Time.get_ticks_msec(), "fuera de la ventana sigue sin enviar en headless")
	RemoteLog.retry_at_msec = 0
