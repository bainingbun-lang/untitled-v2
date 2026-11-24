# Mapa sci-fi negro: diagnostico (2026-11-24)

## Reproducir sin casco
Este telefono tiene Vulkan por software (lavapipe), asi que se puede usar el MISMO renderizador que el Quest (Mobile):

    setsid nohup Xvfb :99 -screen 0 1280x720x24 &
    FAC_FRAMES=3 FAC_MODE=base DISPLAY=:99 UNTITLED_MUTE=1 godot --rendering-method mobile --rendering-driver vulkan --path . --script res://tools/dev/facility_render_probe.gd

Imprime `MEAN[modo]=brillo medio` (0.0 = negro) y guarda `$TMPDIR/fac_<modo>.png`. Cada fotograma tarda ~1,5 s por software. Sin `--rendering-method mobile` el render cae a gl_compatibility, que no dibuja decals y NO reproduce el negro.

## Resultado: base = negro (0.0). Con todos los materiales planos = 0.49
- La geometria se dibuja bien (pasillo, marcos, NPC).
- Quitar texturas, normales, metalico, mipmaps, culling, luces o WorldEnvironment: sigue negro.
- Material nuevo sin textura en TODAS las mallas: se ve. Con textura: negro.
- Dejar originales solo UNA categoria (Platform, Wall, Door, Prop, Column) y el resto plano: se ve. Mitad o un cuarto plano: negro. Tres cuartos plano: se ve.
- Fusionar mallas repetidas en 33 MultiMesh: sigue negro (no es el numero de dibujados).

## Causa NO confirmada
Falla por la suma de piezas con material original, no por una pieza ni un material concreto. Descartado: texturas, mipmaps, luces, entorno, UV, numero de dibujados.

## Cambios hechos (aunque no arreglan el negro aqui)
Las piezas cargaban 96 materiales y 108 texturas con solo 17 distintas (348 MB sin mipmaps). `facility_map.gd` ahora comparte texturas y materiales identicos: 61 materiales, 17 texturas, 55 MB.

## Siguiente paso sugerido
Ver los registros `FACILITY:` del casco real (RemoteLog), y probar bajar a la mitad de piezas distintas.
