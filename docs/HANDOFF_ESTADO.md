# HANDOFF — estado, preferencias y cómo seguir (actualizado 2026-11-23)

Documento para retomar el trabajo si se corta la sesión. Léelo completo antes de actuar.

## 1. Quién es el usuario y cómo quiere que trabajes
- Habla español informal; está frustrado por promesas sin resultados. **Sé honesto**: no digas "listo" ni "pruébalo" sin haberlo verificado (con pruebas headless, el simulador de VR o capturas). Di siempre qué NO se pudo verificar sin casco.
- **No preguntes qué vas a hacer: hazlo.** Pregunta solo si algo bloquea de verdad (por ejemplo, falta una IP o una clave).
- **Modelos:** Opus orquesta lo difícil, Sonnet hace código acotado, Haiku solo explora/lee (nunca programa). Delega tareas largas a subagentes en segundo plano.
- Quiere un juego VR (Meta Quest 3S) sandbox tipo Garry's Mod: armas con agarre real y recarga manual, retroceso, gore realista, NPC que reaccionan (policías, civiles, guardias), mapas de verdad (no cajas), mods. **Sin dinero ni niveles.** Mapas con ~mitad de capacidad de NPC (casa 4-5, escuela hasta 60).
- Sonido: las pruebas y los builds de depuración van **sin sonido** (`UNTITLED_MUTE=1`, bus master silenciado si es debug); el APK de release lleva sonido.
- Ahorra tokens: usa `rtk` en comandos, caveman/ponytail, Serena (si conecta). El usuario tiene poco uso semanal (≈89% usado el 2026-11-23) y la ventana de contexto casi llena: trabaja con respuestas cortas.
- No hagas APK ni instales en el casco sin que lo pida (el 2026-11-23 lo pidió al final: "hasta que salga un resultado como lo que pedí quiero un apk").
- Nunca uses claves privadas pegadas en el chat: la clave SSH que subió se debe considerar comprometida; usar solo una nueva generada en Termux.

## 2. Proyecto
- Repo: `https://github.com/bainingbun-lang/untitled-v2` (rama local `base-nueva` → push a `origin main`). Carpeta: `/data/data/com.termux/files/home/untitled-base`.
- Godot 4.7, renderer Mobile, Meta Quest. Otro repo anterior: `untitled-vr` (carpeta `~/UNTITLED`, sistema de mods viejo, NEXT_STEPS de fase B).
- Referencias descargadas: `~/untitled-control/refs/` (godot-xr-tools, godot-vr-weapons, etc.) y `~/refs-vr/` (godot-xr-template MIT, flynn demo MIT, xr-tools demo MIT, Wintermute SIN licencia: solo consultar).
- Licencias: copiar solo MIT/CC0. Créditos en `docs/CREDITS.md` y en cada carpeta de assets.

## 3. Lo que existe (y está probado en headless)
- Menú 2D + panel VR con láser (`menu/`), configuración (gore, dificultad, bolsillos, relleno de NPC, zombis, policía).
- Mods como `.zip` (`mods/mod_packs.gd`, `docs/MODS.md`), datos en Descargas/Untitled (Android) o `user://`.
- NPC: `npc/` (spawner por área, reacciones: grito de refuerzos, alarma al caer uno, policía tras disparos, zombis, desarme al agarrar), golpe de puño, agarre y estrellón de NPC, decapitación con cuchillo.
- Armas: arsenal viejo (`weapons/*.tscn`) + armas xr-tools (`weapons/xr_*.tscn`, scripts en `weapons/firearm/`: gatillo `firearm_trigger.gd`, `xr_firearm.gd`, cargador `xr_magazine.gd`).
- Jugador nuevo sobre godot-xr-tools (`player/xr_player.tscn`), manos lowpoly con texturas en `assets/packs/hands_lowpoly.zip` (cargadas en runtime, no importadas).
- Mapas: sandbox, casa (CC0 Kenney), oficina (CC0 innerscene), escuela (CC0 OpenGameArt), instalación sci-fi (Quaternius CC0, texturas en `assets/packs/scifi_pieces.zip` extraído a `user://`). Todos en `maps/catalog.json`. Los `.glb/.gltf/.bin/.wav` se incluyen con `include_filter` en `export_presets.cfg` (preset QuestVR).
- Simulador de VR por software (`tools/vr_sim/vr_sim.gd`, `docs/VR_SIM.md`): trackers falsos en XRServer; permite caminar, agarrar, disparar, golpear y sacar capturas SIN casco.
- Pruebas: `bash tests/run_all.sh` (Xvfb en `:99`, `export DISPLAY=:99 UNTITLED_MUTE=1`; scripts que cargan escenas hacen `await process_frame` al inicio por los autoloads del addon).

## 4. Cómo compilar y probar
- Local en este teléfono **no** se puede compilar el APK (Gradle se queda sin RAM, aunque haya swap).
- APK en GitHub: `gh workflow run build-vr-apk-v2.yml` (workflow v2: borra los `*.import` y la caché antes de importar; con eso desapareció el bucle de "reimport" que tardaba >30 min). Tarda ~4-5 min. Se descarga con `gh run download <id> -R bainingbun-lang/untitled-v2 -n untitled-vr-release-apk -D <carpeta>`. Ojo: el último paso "Publicar en Releases" puede fallar (ya se corrigió para el nombre `untitled_vr_release.apk`, verificar).
- Instalar en el Quest: `adb connect 192.168.1.9:5555` (depuración inalámbrica; la IP/puerto puede cambiar, pedirlos) → `adb -s 192.168.1.9:5555 install -r untitled_vr_release.apk` → `adb shell monkey -p org.untitled.vr -c android.intent.category.LAUNCHER 1`. Brillo: `adb shell settings put system screen_brightness 255`.
- No usar `sleep` largo encadenado en Bash; para esperar usar `timeout 110 bash -c 'until ...; do sleep 10; done'`.

## 5. Pendiente al 2026-11-23 (ordenado)
1. **Errores de spawn del jugador** (encontrados con el simulador): en `sandbox.tscn` el jugador nace bajo el piso (origen y=0, piso y=0.5; la cápsula choca con el techo y no camina bien); en `maps/downloaded/scifi/facility_map.tscn` cae al vacío ~4 s mientras se construye el mapa; en la sandbox caminar al frente choca con la mesa. Arreglar en `sandbox/` y los mapas, y probar con `VrSim`.
2. **Gore bueno** (agente Sonnet `gore` en curso): texturas CC0 reales (pinceles grunge) en zip, charcos, rastros, muñón con chorro, verificado con capturas. Ver `docs/GORE.md`.
3. Integración final del jugador xr-tools con golpe de puño, agarre de NPC, fundas/bolsillos y armas agarrables con recarga manual (agente Opus en curso). Hay una prueba inestable: `tests/test_reactions.gd` (depende de la posición aleatoria).
4. Modelos de escopeta/subfusil (hoy son cajas) y puertas con hoja en la instalación sci-fi; texturas de otros mapas.
5. Compilar el APK de release con el workflow v2, descargarlo, instalarlo en el Quest y revisar logs con `adb logcat`.
6. Más mapas con licencia libre: Retro house pack (itch, CC0), Modular Dungeon (rgsdev, CC0), SigilsVault cathedral (CC0), Quaternius medieval/downtown (CC0). Hospital y edificio de trabajo no encontrados con licencia libre. GM Construct NO (copyright Facepunch/Valve).
7. Tácticas de NPC (rodear, quitar arma a policías) y correr con joystick (el rig xr-tools trae MovementSprint; falta calibrarlo con el action map).

## 6. Trampas conocidas
- `class_name` duplicados con el addon (XRToolsPickable, XRToolsFunctionPickup): ya se quitaron del código propio; no volver a ponerlos.
- No borrar `addons/godot-xr-tools/hands/scenes/collision` (los scripts de colisión lo necesitan).
- Godot 4 en CI/APK: archivos fuente crudos (`.glb`, `.gltf`, `.bin`) no van en el PCK salvo por `include_filter`; usar zips en `assets/packs/` + cargadores en runtime.
- Los `.import`, `.uid` y `.godot/` generados no se suben (salvo los `.uid` de scripts propios).
- Un build de GitHub que se queda en "reimport" en bucle = cancelar y revisar `gh run view <id> --log`; no volver a quitar archivos del addon al azar.
