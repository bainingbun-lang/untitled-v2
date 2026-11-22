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
