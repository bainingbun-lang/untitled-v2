#!/usr/bin/env bash
# Corre todas las pruebas headless del proyecto y resume el resultado.
# Uso: DISPLAY=:99 ./tests/run_all.sh   (DISPLAY solo hace falta para escenas con render)
set -u
cd "$(dirname "$0")/.."
export UNTITLED_MUTE=1
fail=0
run() {
	local name="$1" script="$2" marker="$3"
	local out
	out=$(timeout 300 godot --headless --path . --script "$script" 2>&1)
	if echo "$out" | grep -q "$marker" && ! echo "$out" | grep -q "SCRIPT ERROR"; then
		echo "OK    $name"
	else
		echo "FALLO $name"
		echo "$out" | grep -E "FAIL|SCRIPT ERROR" | head -5
		fail=1
	fi
}
run "mods (zip, activar, quitar)" res://tests/test_mod_packs.gd "RESULTADO: OK"
run "armas (recarga, disparo, cadencia)" res://weapons/test_weapon_handling.gd "PASS ("
run "arsenal (todas las armas cargan)" res://tests/test_arsenal.gd "RESULTADO: OK"
run "reacciones (alarma al caer un NPC)" res://tests/test_reactions.gd "RESULTADO: OK"
run "combate (perdigones, cabeza)" res://tests/test_combat.gd "RESULTADO: OK"
run "simulador VR (caminar, agarrar, disparar, puñetazo)" res://tests/test_vr_sim.gd "RESULTADO: OK"
run "armas xr-tools (agarre, gatillo, cargador, corredera)" res://tests/test_xr_weapons.gd "RESULTADO: OK"
run "jugador xr-tools (manos con zip, agarre)" res://tests/test_xr_player.gd "RESULTADO: OK"
run "fundas con arma al inicio" res://tests/test_fundas.gd "RESULTADO: OK"
run "machete XR (funda, corte, sonidos)" res://tests/test_xr_machete.gd "RESULTADO: OK"
run "menu de armas" res://tests/test_weapon_menu.gd "RESULTADO: OK"
run "botin de NPC (arma y cargador)" res://tests/test_loot.gd "RESULTADO: OK"
run "simulador: menu, machete y corte a un NPC" res://tests/test_sim_machete.gd "RESULTADO: OK"
run "mapa instalacion sci-fi (piezas, colision, NPC)" res://tests/test_facility_map.gd "RESULTADO: OK"
run "sandbox xr (mesa, agarre, cargador, corredera, disparo, puñetazo)" res://tests/test_xr_sandbox.gd "RESULTADO: OK"
run "escenas xr (sandbox, menús, mapas, clic del menú VR)" res://tests/test_xr_scenes.gd "RESULTADO: OK"
exit $fail
