#!/usr/bin/env bash
# Baut die EXE unter Linux mit Mono (mcs). Gleiches Ergebnis wie build.ps1, nur ohne Manifest.
# Aufruf: ./build/build.sh [x.y.z]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
ver="${1:-$(head -n1 "$root/VERSION")}"
ver="${ver#v}"
[[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version muss x.y.z sein (ist: $ver)"; exit 1; }
mkdir -p "$root/dist" "$root/obj"
sed -E "s/Assembly(File)?Version\(\"[0-9.]+\"\)/Assembly\1Version(\"$ver.0\")/" \
    "$root/launcher/EdenUpdaterHost.cs" > "$root/obj/EdenUpdaterHost.cs"
mcs -target:winexe -platform:anycpu -optimize+ \
    -win32icon:"$root/assets/EdenUpdater.ico" \
    -resource:"$root/src/EdenUpdater.ps1",EdenUpdater.ps1 \
    -out:"$root/dist/EdenUpdater.exe" "$root/obj/EdenUpdaterHost.cs"
echo "Fertig: $root/dist/EdenUpdater.exe (Version $ver)"
