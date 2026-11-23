# Simulador de VR (tools/vr_sim/vr_sim.gd)

Permite a un agente sin casco mover la cabeza y las dos manos, apretar botones y caminar, en headless o con capturas en Xvfb.

## Cómo funciona
`VrSim` registra en `XRServer` trackers falsos (`head`, `left_hand`, `right_hand`) y les pone poses (`set_pose` en "default"/"grip"/"aim") e inputs (`set_input`). Los `XRController3D` del rig los leen igual que con un casco, así que FunctionPickup, MovementDirect, el gatillo del arma, etc. reaccionan de verdad. `attach` busca `XROrigin3D`, `XRCamera3D` y los `XRController3D` por `tracker` o por nombre (LeftController/LeftHand/...); sirve con `XRPlayer` (player/xr_player.tscn) y con cualquier rig xr-tools.

## API (todo con `await`)
| Llamada | Qué hace |
|---|---|
| `attach(root)` | Registra trackers, encuentra el rig, estabiliza el cuerpo. Devuelve bool |
| `walk(Vector2(x, y), seg)` | Joystick izquierdo (`primary`); y>0 adelante, y<0 atrás |
| `stick(mano, v, accion)` / `turn(x)` | Joystick libre / giro con la mano derecha |
| `move_head(pos_local, yaw, pitch)` / `look_at_point(p)` | Cabeza en espacio del origen |
| `move_hand(mano, pos_rel_cabeza, euler_deg)` | Mano relativa a la cabeza |
| `reach(mano, punto_mundo, seg)` | Interpola la mano hasta un punto del mundo (con velocidad) |
| `punch(mano, punto, vel)` | Mano rápida al punto (>3 m/s cuenta como puñetazo en `xr_hand_extras.gd`) |
| `press/release(mano, accion)` | Botón: `ax_button`, `by_button`, `menu_button`, `trigger_click`, `grip_click`... |
| `squeeze_grip(mano, v)` / `pull_trigger(mano, v)` | Ejes analógicos `grip` / `trigger` (+ click >0.7) |
| `teleport(pos)` / `floor_at(x, z)` | Colocar al jugador / medir el suelo |
| `screenshot(ruta)` | PNG de la cabeza; requiere render (sin `--headless`) |
| `wait(seg)` / `frames(n)` / `detach()` | Tiempo en frames de física (60 Hz) / quitar trackers |

Manos: `&"left_hand"`, `&"right_hand"`.

## Ejemplo
```gdscript
const VrSim = preload("res://tools/vr_sim/vr_sim.gd")
var sim = VrSim.new(self)            # self = SceneTree o nodo con get_tree()
await sim.attach(sandbox)
await sim.reach(&"right_hand", arma.global_position, 0.3)
await sim.squeeze_grip(&"right_hand", 1.0)     # arma.is_picked_up() == true
await sim.pull_trigger(&"right_hand")          # arma.shot se emite
await sim.walk(Vector2(0, -1), 1.0)            # camina ~3 m atrás
await sim.punch(&"right_hand", npc.global_position + Vector3(0, 1, 0), 6.0)
await sim.screenshot("/data/data/com.termux/files/usr/tmp/vrsim/x.png")
```
Los scripts que cargan escenas deben hacer `await process_frame` antes (autoloads de xr-tools); `attach` ya lo hace.

## Pruebas
- `tests/test_vr_sim.gd` (en `run_all.sh`): agarre, disparo, soltar, caminar, puñetazo a NPC, captura (solo con render). Headless, ~10 s.
- `tools/vr_sim/demo_walk_grab_shoot.gd`: agarrar -> disparar -> caminar -> golpear + capturas del sandbox y de `facility_map.tscn` en `/data/data/com.termux/files/usr/tmp/vrsim/`. Ejecutar sin `--headless`: `DISPLAY=:99 UNTITLED_MUTE=1 godot --path . --script res://tools/vr_sim/demo_walk_grab_shoot.gd`.

## Hallazgos del proyecto (no corregidos, fuera de mi alcance)
- `sandbox.tscn` pone el `XRPlayer` en y=0 pero el suelo está en y=0.5: `PlayerBody` nace bajo el suelo, su cápsula crece hasta 2.5 m, choca con el techo y el jugador no puede caminar. `attach` lo evita subiendo el origen al suelo y limitando `player_height_max` a 1.8 (workaround solo del simulador).
- En el sandbox, caminar hacia adelante (-z) desde el spawn choca con la mesa; las pruebas caminan hacia atrás.
- En `facility_map.tscn` el jugador cae al vacío mientras el mapa se construye (~4 s); usar `floor_at` + `teleport`.

## Lo que NO se puede simular
- Hápticos/vibración (no hay mando real; `trigger_haptic_pulse` no tiene efecto observable).
- Rastreo real: ruido, pérdida de tracking, oclusión de manos, deriva, guardian/límites de la sala.
- Rendimiento y fotogramas de un Quest (el render en Xvfb es software, sin estéreo ni distorsión de lentes).
- Hand tracking (dedos articulados): solo se simulan los mandos, no `XRHandTracker`.
- Interfaz OpenXR real (reproyección, foveación, passthrough, action map del runtime): se omite; los nombres de acción deben coincidir con `action_map.tres`.
- Física de brazo/hombro coherente: la mano se teletransporta por interpolación, sin cinemática del cuerpo.
