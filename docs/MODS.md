# Mods y datos

## Dónde se guardan los datos
En Android, todo va a **Descargas/Untitled** (`/storage/emulated/0/Download/Untitled`):
- `settings.cfg` y `controller_settings.cfg` (ajustes).
- `mods/` (mods instalados, como `.zip`).
- `importar/` (aquí dejas los `.zip` nuevos antes de importarlos desde el menú).

Para que funcione, la app pide acceso a todos los archivos (Android 11 o superior). Si no lo concedes, los datos se quedan en la carpeta interna de la app, y el menú Configuración muestra cuál está en uso.

En PC se usa la carpeta `user://` de Godot. Los logs del motor (`godot.log`) siguen ahí porque Godot los escribe por su cuenta.

## Qué es un mod
Un mod es un **archivo `.zip`** con:
- `mod.json` en la raíz, con al menos: `schema_version` (entero, `1`), `id` (formato `autor.nombre`), `name`, `version` (semver, por ejemplo `1.0.0`) y `engine` (versión de Godot, por ejemplo `"4.7"`).
- Los archivos en **la misma ruta que tendrían dentro del proyecto**. Por ejemplo, `res://gore/gore_system.gd` va como `gore/gore_system.gd` dentro del zip.

Cualquier tipo de archivo sirve: scripts `.gd`, escenas `.tscn`, texturas `.png`, audio, datos `.json`, modelos, etc. Al montar el zip, sus archivos **reemplazan** a los del juego con la misma ruta, y los que no existen en el juego se agregan.

Ejemplo, un zip que cambia el sandbox a otro juego:
```
mod.json
sandbox/sandbox.gd        (reemplaza al original)
sandbox/sandbox.tscn      (opcional, otra escena)
textures/sangre.png       (textura nueva)
```

## Cómo instalar
1. Copia el `.zip` a `Descargas/Untitled/importar/`.
2. Abre el juego → **Mods** → **Importar**. El menú valida `mod.json` y copia el mod a `mods/`.
3. **Reinicia el juego.** Los mods se montan al arrancar, antes de cargar el menú.
4. Para quitar un mod: **Mods** → **Quitar**, y reinicia.

Si el zip tiene errores, el menú te dice cuáles. Un zip se rechaza si:
- No tiene `mod.json` en la raíz.
- El manifiesto no pasa la validación (campos faltantes o tipos incorrectos).
- Tiene rutas peligrosas (`..`, rutas absolutas o barras invertidas).

## Mapas
Los mapas se listan desde `maps/catalog.json`. Para agregar un mapa, un mod reemplaza ese archivo o agrega una entrada:
```json
[
  {"name": "Sandbox: casa de 2 pisos", "scene": "res://sandbox/sandbox.tscn"},
  {"name": "Mi mapa", "scene": "res://mods/mi_mapa/mi_mapa.tscn"}
]
```

## Activar, desactivar y quitar
En **Mods** cada mod tiene un botón **Activo/Desactivado** y **Quitar**. Desactivar no borra el zip: el estado se guarda en `mods_state.json`. Los cambios se aplican al reiniciar.

## Permisos declarados
`mod.json` puede declarar `"permissions"` con áreas de: `gore`, `sandbox`, `maps`, `npc`, `weapons`, `textures`, `audio`, `scripts`, `data`. Un nombre fuera de esa lista rechaza el mod. Hoy el permiso es **informativo**: se muestra en la lista de mods, pero no restringe nada, porque un mod es un overlay de archivos y puede tocar cualquiera.

## Configuración
En **Configuración** eliges:
- **Gore:** Apagado, Normal o Extremo. Se aplica al instante y se guarda en `settings.cfg` (sección `[gameplay]`).
- **Dificultad:** Fácil, Normal o Difícil. Escala el daño de los disparos de los NPC contra el jugador (x0.5, x1, x1.5).

## Mapas
Los mapas se listan desde `maps/catalog.json`. Para agregar un mapa, un mod reemplaza ese archivo o agrega una entrada:
```json
[
  {"name": "Sandbox: casa de 2 pisos", "scene": "res://sandbox/sandbox.tscn"},
  {"name": "Mi mapa", "scene": "res://mods/mi_mapa/mi_mapa.tscn"}
]
```

## Mod de ejemplo
`mods/examples/demo_catalog.zip` agrega una entrada al catálogo de mapas. Copíalo a `Descargas/Untitled/importar/` para probarlo. Su fuente está en `mods/examples/demo_catalog/`.

## Menú en el casco
Al arrancar en VR se abre el menú en un panel 3D frente al jugador. Apunta con el rayo de cualquier mando y pulsa el gatillo. Es el mismo menú 2D renderizado en un SubViewport. **No verificado en casco real.**

## Pruebas
`godot --headless --path . --script res://tests/test_mod_packs.gd` prueba importar, desactivar, montar, rechazar un ZIP sin manifiesto y quitar.

## Límites conocidos
- **Scripts ya cargados no cambian** hasta reiniciar.
- Un mod mal hecho puede romper el juego. Para quitarlo sin abrir el juego, borra su `.zip` de `Descargas/Untitled/mods/` y reinicia.
- Los permisos son informativos, no se aplican.
- `mods/mod_registry.gd` (copia distinta del de `UNTITLED/core/`) sigue en uso por `mod_loader.gd` para descubrir carpetas. El flujo de zips no lo usa. Unificarlos queda pendiente.
- `godot.log` sigue en `user://` porque Godot lo escribe por su cuenta.
