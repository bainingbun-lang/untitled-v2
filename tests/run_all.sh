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
run "combate (perdigones, cabeza)" res://tests/test_combat.gd "RESULTADO: OK"
exit $fail
