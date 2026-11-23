# NEXT_STEPS — versión 2 (untitled-base)

Adaptación del plan de `UNTITLED/NEXT_STEPS.md` a esta base. Orden de ejecución. Estado: `PENDIENTE` / `EN CURSO` / `HECHA` / `BLOQUEADA`.

## Objetivo de esta fase
Versión estable con menú principal (Jugar, Mods, Configuración) y un sistema de mods que pueda cambiar cualquier parte del juego con un archivo: gore, armas, NPC, mapas, sandbox. Un mod puede convertir el sandbox en otro juego (por ejemplo, terror) sin tocar el núcleo.

## Decisiones abiertas (necesito respuesta)
1. **Formato del mod:** ¿PCK (como documenta `UNTITLED/docs/MOD_SYSTEM.md`) o carpeta con `.gd`/`.tscn` que se lee tal cual? La carpeta es más fácil para "un simple archivo", pero no se puede proteger.
2. **Permisos:** ¿denegar por defecto (recomendado en `UNTITLED/docs/MOD_PERMISSIONS_AUDIT.md`)?

## Tareas

| # | Tarea | Estado | Dependencia |
|---|---|---|---|
| 1 | Unificar el registro de mods (pendiente: el flujo de zips no lo usa): `mods/mod_registry.gd` de esta base es una copia distinta del de `UNTITLED/core/mod_registry.gd`. Elegir uno y borrar el otro. | PENDIENTE | decisión 1 |
| 2 | Cerrar permisos por defecto: quitar la excepción de lista vacía en `ModApi.subscribe/emit`. Migrar `mods/example.hello` y sus pruebas. | PENDIENTE | decisión 2 |
| 3 | HECHA (por zip, ver `docs/MODS.md`) Puntos de override global: que un mod pueda reemplazar gore (`gore/gore_system.gd`), mapas (`maps/map_world_builder.gd`), NPC (`npc/basic_npc.gd`), armas (`weapons/`) y el sandbox (`sandbox/sandbox.gd`) con un solo archivo declarado en `mod.json`. | PENDIENTE | tarea 1 |
| 4 | Menú principal: escena con Jugar, Mods y Configuración. | HECHA (`menu/`) | ninguna |
| 5 | Pantalla Jugar: lista de mapas desde `maps/catalog.json`. | HECHA | tarea 4 |
| 6 | Pantalla Mods: instalados, importar desde Descargas y quitar. Activar/desactivar y quitar. | HECHA | tareas 1, 4 |
| 7 | Pantalla Configuración: gore (Apagado/Normal/Extremo) y dificultad (escala el daño NPC). | HECHA | tarea 4 |
| 8 | Mod de ejemplo (`mods/examples/demo_catalog.zip`). | HECHA | tarea 3 |
| 9 | Pruebas headless: importar/listar/montar un zip verificado; menú carga sin errores. `tests/test_mod_packs.gd` (8 pruebas, pasan). | HECHA | tareas 1–8 |
| 10 | Probar en casco: agarre con dos manos, cargador, corredera, gore. | BLOQUEADA | casco y tarea 9 |

## Hecho en esta pasada
- Datos en Descargas/Untitled (`storage/app_paths.gd`), con respaldo a `user://`.
- Mods como zip: importar, validar, listar, quitar y montar al arrancar (`mods/mod_packs.gd`). Documentado en `docs/MODS.md`.
- Menú principal con Jugar, Mods y Configuración (`menu/`).

## Lo que ya existe y no se rehace
- Gore, sandbox 7 NPCs, mapa de casa 2 pisos, pistola con botones A/B (cambios sin commit antes de esta fase).
- Sistema de mods completo en `UNTITLED/core/` (manifiesto, resolución, bus de eventos, copias, perfiles). Se reutiliza, no se reescribe.

## Estado de la última pasada (sesión larga)

### Hecho y probado headless
- Pruebas: `bash tests/run_all.sh` (mods: 8 casos; armas: 23 comprobaciones).
- Armas: sniper, machete, escopeta (8 perdigones, 12 de daño), Barrett (150 de daño), subfusil (cadencia 0.07 s). Bolsillos izquierdo y derecho configurables.
- Escopeta: 8 perdigones dispersos, cada uno con su impacto. Probado en sandbox: 96 de daño a un NPC.
- Cabeza: disparo ≥ 40 de daño en la cabeza abre la herida; cuchillo con 4 cortes en el cuello decapita.
- Golpes: el puño y el agarre de NPC (estrellón) aplican impacto con cabeza/torso.
- NPC: grito de refuerzo, aviso "¿Quién anda ahí?" por detrás, reacción según gravedad ("Oye, basta", "Me rindo").
- Policía: tras disparos, llega una unidad armada a los 30 s o 5 min (apagada por defecto, nunca en la sandbox).
- Zombis: se acercan al jugador dentro de 14 m (configurable en Configuración).
- Población: casa 4, escuela hasta 60, oficina 37 (modelo a escala x3).
- Sonido: sonidos reales del proyecto para disparos de NPC; grito e impacto generados en código.
- Correr: mantener presionado el botón de caminar (x2.2).
- Agarrar un NPC armado lo desarma.
- Bolsillo derecho configurable, subfusil, pruebas de combate (`tests/test_combat.gd`) incluidas en `tests/run_all.sh`.

### Pendiente / no verificado
- Tácticas (rodear, quitar arma a policías): no implementado.
- Correr con joystick o mano: no implementado.
- Cartucho manual: la lógica existe (`weapons/weapon_reload.gd`); falta el gesto de mano.
- Retroceso: ajustado en escopeta y Barrett; no visto en VR.
- Todo lo de VR con mando real: sin probar (no hay casco aquí).
- Mapas descargados: escuela, casa, oficina. Faltan hospital y edificio de trabajo (sin fuente CC0 con descarga directa).

### Pasada de arsenal y gore (sesión de 40 min máx.)
- Arsenal ampliado: revólver, fusil de asalto, PDW, tanto y hacha, con estadísticas propias. Prueba `tests/test_arsenal.gd` carga todas las armas.
- Recarga manual: el botón A saca el cargador y el B corre la corredera en todas las armas basadas en `vr_weapon_pistol.gd` (pistola, AK, fusil, PDW, subfusil). Probado en headless, no en mando real.
- Gore: rastro de sangre al piso desde heridas abiertas y decapitaciones.
- Modelo 3D pendiente: `godot-xr-tools/assets/3dmodelscc0/models/sniper_rifle/sniper_rifle.glb` (sitio 3dmodelscc0, que es CC0; el archivo de licencia no lo dice explícitamente, confirmar). Falta importarlo en Godot (`--import` falla aquí con segfault) y poner el cuerpo en el sniper.
- Pendiente: más modelos de armas descargados, gore con partes del cuerpo que salgan volando, tácticas de NPC.

### Cierre de la pasada (arsenal, modelo CC0 y gore)
- Armas nuevas: revólver, fusil, PDW, tanto, hacha, katana, bate (cuerpo a cuerpo sin desmembrar), francotirador con modelo CC0 de 3dmodelscc0.
- Modelo CC0 del francotirador importado en `weapons/models/sniper_cc0/` (licencia en `License.txt`: confirmar que sea CC0 en el sitio de origen).
- Gore: charcos al morir y bajo cabezas cortadas; rastro de sangre al piso.
- Pruebas: `bash tests/run_all.sh` (mods, armas, arsenal, combate). Todas pasan. Smoke de todas las escenas principales sin errores de script.
- Limitaciones: el bate usa la lógica de corte del cuchillo (sin desmembrar). Los charcos usan altura de piso fija (0.53 m), no raycast.

### Armas con agarre de xr-tools (weapons/xr_*.tscn)
- Escenas: `xr_pistol` (modelo derringer CC0), `xr_ak47`, `xr_sniper`, `xr_barrett` (modelo sniper CC0 escalado), `xr_shotgun` y `xr_smg` (cajas). Se generan con `weapons/firearm/build_xr_weapons.gd` (editar la tabla WEAPONS y volver a ejecutar; no editar las .tscn a mano).
- Cada arma: XRToolsPickable (`weapons/firearm/xr_firearm.gd`), colisión en caja alineada al modelo, empuñadura (handle "Grip", la única que deja disparar), puntos extra para la otra mano (guardamanos/culata, second_hand_grab=SECOND), FirearmTrigger, cargador agarrable (`xr_magazine.gd`) en una SnapZone "MagazineWell", y corredera/cerrojo/bomba con InteractableSlider + InteractableHandle. La munición sigue en `WeaponReload`.
- Prueba: `tests/test_xr_weapons.gd` (en run_all.sh).
- BLOQUEO: el jugador (`player/vr_player.tscn`, VRHand propio) no tiene XRToolsFunctionPickup, así que estas armas aún no se agarran en la sandbox ni están en el inventario (SCENES sigue apuntando a las armas antiguas). Siguiente paso: añadir FunctionPickup a cada mano del jugador sin romper puño/agarre de NPC/funda, y luego cambiar SCENES a las xr_*.
- Sin verificar (requiere casco): posición/rotación de las manos en los grab points, orientación del cañón de la derringer (se asume -Z), que meter el cargador funcione soltándolo cerca del pozo (SnapZone en modo DROPPED, radio 6 cm), sensación del retroceso (solo visual, el modelo se desplaza y vuelve), y que el arma sostenida no choque con el cuerpo (xr-tools pone collision_mask=0 al agarrar).
- Escopeta y subfusil usan cargador extraíble (escopeta tipo Saiga); la escopeta de tubo queda pendiente.

## Jugador xr-tools en todas las escenas (sandbox, vr_menu y 3 mapas)
Hecho y probado headless (`tests/test_xr_sandbox.gd`, `tests/test_xr_scenes.gd`): `player/xr_player.tscn` reemplaza a `vr_player.tscn`; mesa con pistola, AK, escopeta y subfusil con cargadores de repuesto; golpe de puño y agarre de NPC (`player/xr_hand_extras.gd`); fundas en la cintura (SnapZone, grupo `holsterable`); menu_button emite `menu_requested` y, fuera del menú, vuelve a `menu/vr_menu.tscn`.

Causas de "no se puede agarrar / manos locas" encontradas y arregladas: (1) la mano que agarra la pistola se llevaba el cargador (la empuñadura y la boca del cargador casi coinciden): ahora `weapons/firearm/magazine_well.gd` solo deja sacar el cargador con el arma ya sujeta y con la otra mano; (2) las SnapZone no veían cuerpos congelados como estáticos: armas y cargadores usan `FREEZE_MODE_KINEMATIC` (y el arma ignora la colisión con su propio cargador); (3) al expulsar con A/X o B/Y la zona recapturaba el cargador (se desactiva 0.6 s).

### No hecho / pendiente
- Sin probar en casco: sensación del agarre, posición exacta de la mano en cada arma (agarres de escopeta/subfusil) y orientación de la escopeta MIT (en pantalla sale con la culata atrás; confirmar en el casco).
- Subfusil: sin modelo libre. Los modelos de Kenney (weaponpack, CC0, `uzi`/`shotgun`) están en `untitled-control/refs/godot-vr-weapons/...` solo como `.import` y `.mtl`; falta el `.obj`. Sigue siendo una caja. Wintermute descartado (sin licencia).
- Del jugador viejo no se portó: teletransporte (el nuevo usa movimiento directo + giro por pasos con xr-tools), ajustes de altura/`ControllerSettings`/`Settings.apply_to_player` (la clase `VRPlayer` sigue en el repo, sin usar), `bounds_escaped` (cabeza dentro de una pared), guantes animados, pausa. `Settings` y la pantalla de configuración no actúan sobre el jugador nuevo.
- `Inventory`/`Holster`/`VrWeaponHand` del sandbox viejo ya no se instancian en el sandbox (siguen en el repo). Las fundas nuevas guardan armas xr_* sueltas dentro de la zona; no hay bolsillos de cargadores.
- Menú VR: sigue con su puntero propio (rayo + `trigger_click`), no el FunctionPointer de xr-tools; la prueba demuestra que el clic llega a la UI.
- Aviso "Lambda capture ... was freed" al liberar los mapas de colegio/oficina en pruebas: preexistente, sin SCRIPT ERROR.
