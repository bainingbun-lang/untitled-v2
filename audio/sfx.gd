class_name Sfx
extends RefCounted

## Sonidos generados en código (sin archivos externos). Se silencian con el bus master
## en builds de depuración (ver settings.gd).
const RATE := 22050
static var _cache := {}


## Golpe seco: ruido con caída rápida y tono grave.
static func impact() -> AudioStreamWAV:
	return _make("impact", 0.18, func(t: float, d: float) -> float:
		return (randf() * 2.0 - 1.0) * exp(-t * 30.0) * 0.8 + sin(TAU * 90.0 * t) * exp(-t * 18.0) * 0.6)


## Clic de menú: tic corto y agudo.
static func click() -> AudioStreamWAV:
	return _make("click", 0.05, func(t: float, d: float) -> float:
		return sin(TAU * 1400.0 * t) * exp(-t * 90.0) * 0.5)


## Choque de metal: tono agudo con resonancia corta.
static func metal() -> AudioStreamWAV:
	return _make("metal", 0.3, func(t: float, d: float) -> float:
		return (sin(TAU * 820.0 * t) * 0.5 + sin(TAU * 1370.0 * t) * 0.3 + (randf() * 2.0 - 1.0) * 0.2) * exp(-t * 14.0) * 0.7)


## Choque de madera: golpe seco medio.
static func wood() -> AudioStreamWAV:
	return _make("wood", 0.15, func(t: float, d: float) -> float:
		return (sin(TAU * 240.0 * t) * 0.6 + (randf() * 2.0 - 1.0) * 0.3) * exp(-t * 35.0) * 0.8)


## Rebote blando (goma): tono grave que cae rápido.
static func soft() -> AudioStreamWAV:
	return _make("soft", 0.12, func(t: float, d: float) -> float:
		return sin(TAU * (160.0 - 400.0 * t) * t) * exp(-t * 28.0) * 0.7)


## Grito: tono que sube y cae con vibrato, más ruido de aire.
static func shout() -> AudioStreamWAV:
	return _make("shout", 0.7, func(t: float, d: float) -> float:
		var f := 260.0 + 160.0 * sin(TAU * 2.0 * t) + 60.0 * t
		var env := sin(PI * minf(t / d, 1.0)) * (1.0 - t / d)
		return (sin(TAU * f * t) * 0.5 + (randf() * 2.0 - 1.0) * 0.15) * env * 0.7)


## Disparo: estallido de ruido con caída muy rápida.
static func gunshot() -> AudioStreamWAV:
	return _make("gunshot", 0.35, func(t: float, d: float) -> float:
		return ((randf() * 2.0 - 1.0) * exp(-t * 25.0) + sin(TAU * 60.0 * t) * exp(-t * 12.0) * 0.5) * 0.9)


static func _make(key: String, seconds: float, fn: Callable) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v := clampf(float(fn.call(t, seconds)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	_cache[key] = wav
	return wav


## Carga un WAV real del proyecto (sin depender de la importación).
static func file(path: String) -> AudioStreamWAV:
	if _cache.has(path):
		return _cache[path]
	var wav: AudioStreamWAV = null
	if ResourceLoader.exists(path):
		wav = load(path) as AudioStreamWAV
	if wav == null:
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return null
		wav = AudioStreamWAV.load_from_buffer(bytes)
	_cache[path] = wav
	return wav


## Reproduce un sonido 3D en una posición del mundo; se libera al terminar.
static func play_at(parent: Node, stream: AudioStream, pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.max_distance = 60.0
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
