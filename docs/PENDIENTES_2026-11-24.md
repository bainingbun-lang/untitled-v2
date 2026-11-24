# Pendientes para mañana (2026-11-24)

APK probado en el casco: "pasable". Build usado: run 45294475336, `main` en `0600b5e`. APK en `/sdcard/Download/untitled_vr_release.apk`.

## BUG PRIORITARIO
- **El juego se cierra al disparar** un arma sacada del menu de armas (mantener B/Y 0,5 s, elegir arma, soltar, apretar gatillo). Sin investigar todavia.
  - Pistas a revisar: el arma se crea en `inventory/weapon_menu.gd` (`give`) y se pone en la mano con `FunctionPickup._pick_up_object` (privado). Las armas de funda/mesa se agarran por el flujo normal, que si funciona en el simulador.
  - Comparar contra el agarre normal: `xr_firearm.gd` (`_bind_eject`, gatillo `firearm_trigger.gd`, `try_fire`), y ver el log del casco (`adb logcat -d -s godot:*`, o `user://logs/godot.log` previo).
  - Reproducir en el simulador: `tests/test_weapon_menu.gd` da el arma pero no dispara; añadir disparo (`sim.pull_trigger`) tras `wm.give(...)` y probar cada arma (pistol, ak47, shotgun, smg, sniper, barrett, machete).

## Controles (aclarado)
- Agarrar arma: grip (boton lateral). Disparar: gatillo.
- Menu de armas: mantener B (derecha) o Y (izquierda) 0,5 s; gatillo de la OTRA mano cambia de arma; soltar B/Y pone el arma en la mano.
- Expulsar cargador: A/X. B/Y ya no expulsa.
- Bolsa de cargadores: pecho; grip junto a ella con la mano libre mientras la otra sostiene un arma.

## Pendiente de verificar en el casco
- Por que no se agarraban las armas (en el simulador si). El grip registra a `192.168.1.5:8765` (receptor debe estar escuchando).
- Orientacion de la mano con el machete, vibracion, sensacion del golpe.
- Agarrar el tirador de la corredera con la mano (recorrido de solo 3 cm).
- Manchas y churretes de sangre (los decals si se dibujan con render Mobile).
- Rendimiento del gore.

## Sci-fi negro (sin arreglar)
- Reproducido localmente con render Mobile; ver `docs/SCIFI_NEGRO.md` y `tools/dev/facility_render_probe.gd`.
- Comparte texturas y materiales (348 a 55 MB). Sigue negro aqui; no se sabe si en el casco cambia.
- Probar: bajar a la mitad las piezas distintas; leer los registros `FACILITY:` del casco.

## Otras ideas pendientes
- Modelo de machete real (hoy es el cuchillo estirado). Katana, bate, hacha y cuchillo siguen con el sistema antiguo.
- NPC solo sueltan AK (solo llevan AK).
- Casa y oficina: escala, spawn, NPC que se matan entre si.
- 5 mensajes "Lambda capture ... freed" al cambiar de escena (gore y NPC).
- Codigo muerto: `inventory/inventory.gd`, `inventory/weapon_slot.gd`.
- Adb: falta el puerto de emparejamiento (Depuracion inalambrica > Parear con codigo).

## Hecho hoy (para no repetir)
Sonidos AK y machete, machete XR, menu de armas, botin de NPC (arma y cargador), 4 fundas, bolsa de cargadores infinitos/limitados (Configuracion), sangre nueva (gotas, manchas organicas, churretes), 60 errores `get_global_transform` arreglados.
