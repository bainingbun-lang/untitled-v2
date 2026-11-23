#!/usr/bin/env bash
# Compila el APK de VR (Quest) en CI (Linux x86_64). Requiere: godot, JDK17, Android SDK, plantillas de exportacion 4.7.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; P="$ROOT/build/vr_project"; OUT="${1:-$ROOT/build/untitled_vr_debug.apk}"
GODOT="${GODOT:-godot}"; PRESET="QuestVR"
VENDOR_VERSION="5.2.0-stable"
VENDOR_SHA256="2a3958fff0de2dbdc4f1a036b5e4cfcea12ae7e45f8deebf4b45e5e9718c4e35"
VENDOR_URL="https://github.com/GodotVR/godot_openxr_vendors/releases/download/${VENDOR_VERSION}/godotopenxrvendorsaddon.zip"
TEMPLATE_ZIP="$HOME/.local/share/godot/export_templates/4.7.stable/android_source.zip"
KEYSTORE="${KEYSTORE:-$HOME/.android/debug.keystore}"
rm -rf "$P"; mkdir -p "$P/addons" "$P/android/build" "$(dirname "$OUT")"
for e in "$ROOT"/* "$ROOT"/.godot; do b="$(basename "$e")"; case "$b" in build|backups|briefs|spikes|native|.git|.godot|*.md) continue;; esac; [ -e "$e" ] && cp -r "$e" "$P/"; done
T="$(mktemp -d)"; curl -fsSL "$VENDOR_URL" -o "$T/v.zip"; echo "$VENDOR_SHA256  $T/v.zip" | sha256sum -c -
unzip -q "$T/v.zip" -d "$T/u"; A="$(find "$T/u" -type d -name godotopenxrvendors | head -1)"; [ -n "$A" ] || { echo "sin addon"; exit 1; }
cp -r "$A" "$P/addons/"
unzip -q "$TEMPLATE_ZIP" -d "$P/android/build"; if [ -d /data/data/com.termux ]; then sed -i "1s|^#!.*|#!/data/data/com.termux/files/usr/bin/sh|" "$P/android/build/gradlew"; fi
touch "$P/android/.gdignore"; find "$P/android" -name '*.import' -type f -delete
BV="$("$GODOT" --version 2>/dev/null | sed -n 's/^\([0-9.]*stable\).*/\1/p' | head -1)"; printf '%s' "${BV:-4.7.stable}" > "$P/android/.build_version"
printf '\norg.gradle.daemon=false\norg.gradle.jvmargs=-Xmx3g\n' >> "$P/android/build/gradle.properties"
python3 "$ROOT/tools/vr_project_settings.py" "$P/project.godot"
sed -i "s#/data/data/com.termux/files/home/untitled-control/keys/debug.keystore#$KEYSTORE#g" "$P/export_presets.cfg"
"$GODOT" --headless --path "$P" --import || true
# Segunda pasada: deja la cache de import completa para que la exportacion no reimporte en bucle.
"$GODOT" --headless --path "$P" --import || true
if [ "${RELEASE:-0}" = "1" ]; then
  # Build de release: con sonido (el silencio solo aplica a builds de depuracion).
  # Firmada con el keystore de CI para poder instalarla en el Quest.
  sed -i "s#^keystore/release=\"\"#keystore/release=\"$KEYSTORE\"#; s#^keystore/release_user=\"\"#keystore/release_user=\"androiddebugkey\"#; s#^keystore/release_password=\"\"#keystore/release_password=\"android\"#" "$P/export_presets.cfg"
  "$GODOT" --headless --path "$P" --export-release "$PRESET" "$OUT"
else
  "$GODOT" --headless --path "$P" --export-debug "$PRESET" "$OUT"
fi
test -s "$OUT" && echo "APK_OK $(stat -c%s "$OUT") $(sha256sum "$OUT" | cut -c1-16)"
