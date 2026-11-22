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

## Límites conocidos
- **Scripts ya cargados no cambian** hasta reiniciar. Por eso los mods se montan al arrancar y no en caliente.
- Un mod mal hecho puede romper el juego. Si el juego no abre tras instalar un mod, quítalo desde Descargas/Untitled/mods borrando su `.zip` y reinicia.
- La pantalla del menú es 2D. En el casco sigue sin verificarse; hace falta un panel 3D (pendiente, ver `NEXT_STEPS.md`).

## Permisos
Por ahora un mod puede tocar cualquier archivo del juego. Es una decisión explícita para que cualquier cosa sea moddeable. El sistema de permisos de la API (`UNTITLED/docs/MOD_PERMISSIONS_AUDIT.md`) queda como trabajo pendiente y no está conectado a los zips todavía.
