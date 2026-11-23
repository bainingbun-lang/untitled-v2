# Créditos

- **godot-xr-tools** (MIT) - Bastiaan Olij y contribuidores. Addon en `addons/godot-xr-tools`, incluidas las manos, modelos, animaciones y texturas (empaquetadas en `assets/packs/hands_lowpoly.zip`).
- **godot-xr-template** (MIT) - GodotVR. Estructura del jugador (`player/xr_player.tscn`): XROrigin3D, manos con colisión, FunctionPickup, MovementDirect/Turn/Sprint y PlayerBody.
- **Escopeta del sandbox** (`weapons/shotgun_mit/`, MIT) - de `godot_openvr_fps` (Bastiaan Olij y Noah Beard, 2019): malla de `Assets/Shotgun.scn` convertida a formato Godot 4 y su textura `Items_Albedo.png` (64x64).
- **Materiales de prototipo** (`assets/prototype_materials/`, MIT) - de `godot-xr-template` (GodotVR / Godot XR): textura `pattern.png` (256x256) y materiales tintados wood_brown, stone_grey, sandstone, dark_brown. Licencia en `assets/prototype_materials/LICENSE.txt`. `maps/world_materials.gd` usa la textura en suelo, paredes, techo y madera con triplanar mundial.

## Quaternius Ultimate Gun Pack (CC0)
weapons/models/quaternius/*.glb (Pistol_1, Bullpup_2, Revolver_1) — https://quaternius.com

## Sonidos del machete (CC0)
- machete_swish: "Swishes Sound Pack" (swish-1) por artisticdude, https://opengameart.org/content/swishes-sound-pack
- machete_hit: "8 Wet Squish Slurp Impacts" (impactsplat01) por Independent.nu, https://opengameart.org/content/8-wet-squish-slurp-impacts
- machete_gore: "Fleshy Bone Break/Snap SFX" (Wet Break 9) por Zane Little Music, https://opengameart.org/content/fleshy-bone-breaksnap-sfx

## Sangre
- Manchas procedurales (gore/gore_textures.gd, `_blob`): idea del splat con radio deformado por ruido de Alenvei/GODOT4-Blood-splatter-Tutorial (MIT, Copyright (c) 2023 Alenvei), https://github.com/Alenvei/GODOT4-Blood-splatter-Tutorial. Codigo propio, no se copio el shader.
- Churretes que resbalan por paredes (gore/wound_decals.gd, `add_run`): implementacion propia. No se uso codigo de repos sin licencia (Godot_Dismemberment, bloodstain).

## Municion y cargadores
- `weapons/ammo_reserve.gd`: adaptado de `godot_weapon_manager` (MIT, Copyright (c) 2023 Colormatic), `resources/weapons/ammo/ammo_reserve.gd`; se quita el EventBus y se conservan `add_ammo_to_reserve` y `take_ammo_from_reserve`.
- `player/mag_pouch.gd` (bolsa de cargadores del pecho): codigo propio; ninguno de los repositorios de referencia trae un dispensador. Consultados sin copiar codigo: godot-xr-tools `belt_snap_zone.tscn` y godot-vr-weapons `m1911.gd` (ambos MIT).
