# Gore

- Texturas de salpicadura: pinceles de "100 grunge brushstrokes and splatters set" (CC0), https://opengameart.org/content/100-grunge-brushstrokes-and-splatters-set. Un subconjunto va en `assets/packs/gore_decals.zip` y se carga en tiempo de ejecución con ZIPReader (no se importan en el proyecto, para que el CI no se atore reimportando imágenes).
- Se usan como alfa de nodos `Decal` teñidos de rojo oscuro (manchas en pared y piso, charcos, heridas, rastros). Código: `gore/wound_decals.gd`, `gore/gore_system.gd`, `gore/bullet_impact.gd`, `gore/npc_impact.gd`.
- Niveles: `GoreSystem.GoreLevel` OFF / NORMAL / EXTREME; hay límites de decals y partículas para rendimiento en Quest (renderer Mobile).
- Pruebas: `gore/test_gore_system.gd` (65 comprobaciones). Capturas de verificación hechas con Xvfb y el simulador de VR.
- No verificado sin casco: rendimiento real en Quest y cómo se ve la sangre en estéreo.
