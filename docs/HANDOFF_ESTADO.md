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

---

# ACTUALIZACIÓN 2026-11-23 (noche) — leer esto primero

## Estado real (verificado EN EL CASCO con capturas por adb)
- Menú VR: lista de los 5 mapas completa (sin scroll). Sandbox carga bien (ladrillo, zócalo, techo, mesa con armas, 7 NPC). Casa, oficina y escuela cargan, pero se ven pobres.
- **MAPA SCI-FI NEGRO en el casco** (en el simulador se ve bien). Descartado: texturas con `.import` (ya no se extraen), texturas 2048 px (ya se reducen a 1024), falta de entorno (trae WorldEnvironment). Sigue negro aunque el juego vive y coloca 30 NPC. Hipótesis sin confirmar: el jugador nace dentro de geometría por `player/void_guard.gd` (ajuste de suelo) o la cámara XR no renderiza en ese mapa. Probar: sacar el void_guard del facility, mover el spawn, o poner luz/cielo propios.
- **Casa** (`house_map`): se ve cielo y paredes grises sueltas, jugador fuera o escala mala. **Oficina**: plano gris con NPC, varios tirados (¿se matan entre ellos?). Revisar escala/spawn de los glb cargados con `load()`.
- ~60 errores `get_global_transform: !is_inside_tree` cada vez que se CAMBIA de escena (no en la primera carga). Inofensivos por ahora; origen sin encontrar.

## Hecho hoy (todo en GitHub rama main de untitled-v2)
- Armas: pistola/subfusil con modelos Quaternius CC0; sniper/Barrett giradas (estaban al revés); acero oscuro y madera en la culata (pintado en runtime en `weapons/firearm/xr_firearm.gd`, porque los overrides de nodos glb no se serializan en la escena); cargadores oscuros.
- Jugador: **las fundas ahora se llenan al empezar** con las armas de Configuración (derecha AK, izquierda pistola). Se sacan acercando la mano a la cadera + grip. Test: `tests/test_fundas.gd`.
- Menú VR: scroll con joystick, arrastre de sliders, más botones que hacen clic, lista de mapas más alta.
- Gore: gotas de sangre finas/oscuras. Madera de la sandbox sin ondas. Manos con SSS/rim. Sci-fi con puertas con hoja, ventanas, cables, columnas. Casa con luces, techo de yeso, zócalos, props.
- Carga de `.glb`/`.wav` importados en Android (`ResourceLoader.exists` + `load()` antes que `FileAccess`): la casa ya no cae a la procedural.
- Herramienta de lineup de armas: `tools/dev/weapon_lineup.gd` (foto de lado de todas las armas).

## Cómo probar EN EL CASCO por adb (lo más valioso de hoy)
1. Quest: depuración inalámbrica activa → `adb connect IP:5555` (hoy 192.168.1.9:5555; puede cambiar).
2. Instalar: `adb -s $Q install -r untitled_vr_release.apk`. **Dar permiso de archivos (si no, no lee Descargas ni mods):** `adb -s $Q shell appops set org.untitled.vr MANAGE_EXTERNAL_STORAGE allow`.
3. Mantener despierto: `adb shell am broadcast -a com.oculus.vrpowermanager.prox_close` (NO mandar `automation_disable` después, lo deshace). Al terminar: `automation_disable`.
4. Abrir: `adb shell monkey -p org.untitled.vr -c android.intent.category.LAUNCHER 1`. Sale el aviso "Detección de la posición": pulsarlo con `adb shell input tap 760 785` ("Continuar sin seguimiento").
5. Cambiar de mapa sin mandos: `adb shell "echo 'scene res://sandbox/sandbox.tscn' > /storage/emulated/0/Download/Untitled/cmd.txt"` (el juego lo lee cada 1 s, lo borra y lo ejecuta; también `quit`). Escenas: `res://sandbox/sandbox.tscn`, `res://maps/house_model/house_map.tscn`, `res://maps/downloaded/office/office_map.tscn`, `.../school/school_map.tscn`, `.../scifi/facility_map.tscn`. Código en `settings.gd` (`_poll_remote_cmd`).
6. Captura: `adb shell am start-foreground-service -n com.oculus.metacam/.capture.CaptureService -a TAKE_SCREENSHOT`, esperar 4 s, `adb pull /sdcard/Oculus/Screenshots/<último>.jpg`. (`screencap` normal sale vacío.) Esperar ≥25 s tras cambiar de mapa. Script del teléfono: `~/shot.sh <nombre>` (si no existe, recrearlo).
7. `adb` NO puede mover mandos/láser ni hacer scroll con joystick: eso solo lo prueba el usuario. `input tap/swipe` solo alcanzan paneles 2D del sistema.
8. Logs: `adb logcat -d -s godot:*`.
9. Cerrar: `adb shell am force-stop org.untitled.vr`; apagar: `adb shell input keyevent KEYCODE_SLEEP` y `adb shell reboot -p`.

## CI / APK
- `gh workflow run build-vr-apk-v2.yml -R bainingbun-lang/untitled-v2`, ~7 min. A veces falla el último paso ("cannot connect to daemon tcp:5037"): `gh run rerun <id>` y listo.
- Descargar artefacto: la red del teléfono es inestable; reintentar `gh run download <id> -n untitled-vr-release-apk -D carpeta` hasta 3 veces con `timeout 90`.
- En el APK los `.glb`/`.wav` solo existen importados (en `.godot/imported`), no crudos. Los zips en `assets/packs/` sí van crudos.

## Preferencias del usuario (resumen)
- Español informal, breve. Honestidad: nunca decir "listo" sin verificar; decir qué NO se verificó. No pedir permiso: actuar. Quiere avances reales, no repasar archivos 50 veces ni quedarse en una sola cosa (repartir en varios frentes; usó agentes Sonnet en paralelo con archivos disjuntos).
- Uso semanal de modelos casi agotado (93% el 2026-11-23; se reinicia martes 9:00 a.m.): respuestas cortas, pocas lecturas, sin agentes innecesarios, imágenes solo las clave.
- Quiere juego funcional y bonito: gore, armas con mecanismo (recarga manual, golpes), modelos buenos, mapas reales, gráficos "chidos". Pidió armas cuerpo a cuerpo con mecanismo de golpe y modelos "chinos" (cuchillos, machetes, katanas): NO hecho todavía.
- Nunca usar la clave SSH que pegó (comprometida).

## Pendiente, en orden
1. Sci-fi negro en el casco (ver hipótesis arriba) — probar con capturas por adb.
2. Casa y oficina: escala/spawn/texturas; NPC que se matan entre sí en la oficina.
3. Armas cuerpo a cuerpo con mecanismo de golpe + más modelos (CC0/MIT).
4. Probar con el usuario: scroll/clics del menú con láser, sacar armas de la cadera, botones del Quest.
5. Origen de `get_global_transform` al cambiar de escena.
6. Manos más bonitas, paredes del sci-fi menos uniformes, rendimiento con sombras.
