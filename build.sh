#!/usr/bin/env bash
# Build the Windows version of Salat Time from macOS or Linux.
#
#   ./build.sh            assets + strings + Qur'an check + publish x64 and arm64 + zips (+ installers)
#   ./build.sh --x64      only the x64 build
#   ./build.sh --run      run the app here (macOS/Linux) for a quick look at the windows
#
# Output: dist/  (SalatTime-<version>-win-x64.zip, ...-win-arm64.zip and,
# when NSIS is installed — brew install makensis — SalatTime-<version>-setup-x64.exe)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SHARED="$HERE/shared"
APP="$HERE/src/SalatTime"
CACHE="$HERE/.cache"
DIST="$HERE/dist"
# Optional: a checkout of the Mac app (the repository's `main` branch). When it is
# there, its built app saves re-downloading the recordings, and the shared strings
# are refreshed from it. The Windows project builds without it.
MAC_SOURCE="${SALAT_MAC_SOURCE:-$HERE/../Salat Time Source}"
MAC_RESOURCES="$MAC_SOURCE/Salat Time.app/Contents/Resources"
export PATH="$HOME/.dotnet:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1

command -v dotnet >/dev/null || { echo "The .NET 10 SDK is required: https://dot.net (or ~/.dotnet via dotnet-install.sh)"; exit 1; }

RIDS=("win-x64" "win-arm64")
RUN=0
for arg in "$@"; do
    case "$arg" in
        --x64) RIDS=("win-x64") ;;
        --arm64) RIDS=("win-arm64") ;;
        --run) RUN=1 ;;
    esac
done

size_of () { stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo 0; }

# ---------- assets: recordings and the Cairo face ----------------------------
# Same sources as the Mac build (build.sh). A built Mac app next door is reused
# to avoid downloading again; otherwise files are fetched once into .cache/.
echo "Preparing audio and fonts..."
mkdir -p "$CACHE/adhkar" "$APP/Assets/Audio/adhkar" "$APP/Assets/Fonts"

ASSABILE_BASE="https://media.assabile.com/assabile/adhan_3435370"
ASSABILE_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
fetch () {   # fetch <out> <url> <min-bytes> [referer]
    local out="$1" url="$2" min="$3" ref="${4:-}"
    [ -s "$out" ] && [ "$(size_of "$out")" -gt "$min" ] && return 0
    local args=(-sSfL --max-time 60 -A "$ASSABILE_UA" -o "$out")
    [ -n "$ref" ] && args+=(-H "Referer: $ref")
    if curl "${args[@]}" "$url" && [ "$(size_of "$out")" -gt "$min" ]; then return 0; fi
    rm -f "$out"; return 1
}

ADHANS=(
    "adhan_makkah_mulla.mp3:166d1f7c435a" "adhan_madinah.mp3:b30ca9a3e115" "adhan_aqsa.mp3:768559b47c2e"
    "adhan_dossari.mp3:f5370aa1a7e2" "adhan_zahrani.mp3:cb51ad2c0c7e" "adhan_obaid.mp3:45299e6a8a68"
    "adhan_majali.mp3:495dea4f4ea5" "adhan_yamani.mp3:091fa01b11f4" "adhan_kabbara.mp3:8bd66fa73ff9"
    "adhan_kourdi.mp3:8c052a5edec1" "adhan_feqy.mp3:83e17f5db5a7" "adhan_damradach.mp3:cd17c7200df5"
    "adhan_kreiny.mp3:229d65e40fdf" "adhan_jazairi.mp3:0bf83c80b583"
)
for entry in "${ADHANS[@]}"; do
    name="${entry%%:*}"; hash="${entry##*:}"
    if [ -s "$MAC_RESOURCES/$name" ]; then cp "$MAC_RESOURCES/$name" "$CACHE/$name"; fi
    fetch "$CACHE/$name" "$ASSABILE_BASE/$hash.mp3" 20000 "https://www.assabile.com/" || echo "  ($name skipped)"
    [ -s "$CACHE/$name" ] && cp "$CACHE/$name" "$APP/Assets/Audio/$name"
done

ADHKAR=(75 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 101 112 113 114)
for n in "${ADHKAR[@]}"; do
    f="$n.mp3"
    if [ -s "$MAC_RESOURCES/adhkar_audio/$f" ]; then cp "$MAC_RESOURCES/adhkar_audio/$f" "$CACHE/adhkar/$f"; fi
    if [ "$n" -ge 112 ]; then url="https://server8.mp3quran.net/afs/$f"; else url="https://www.hisnmuslim.com/audio/ar/$f"; fi
    fetch "$CACHE/adhkar/$f" "$url" 10000 || echo "  (adhkar $f skipped)"
    [ -s "$CACHE/adhkar/$f" ] && cp "$CACHE/adhkar/$f" "$APP/Assets/Audio/adhkar/$f"
done

if [ -s "$MAC_RESOURCES/Cairo-Variable.ttf" ]; then cp "$MAC_RESOURCES/Cairo-Variable.ttf" "$CACHE/Cairo-Variable.ttf"; fi
fetch "$CACHE/Cairo-Variable.ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/cairo/Cairo%5Bslnt%2Cwght%5D.ttf" 10000
cp "$CACHE/Cairo-Variable.ttf" "$APP/Assets/Fonts/Cairo-Variable.ttf"
echo "  $(ls "$APP/Assets/Audio" | grep -c '^adhan_') adhans, $(ls "$APP/Assets/Audio/adhkar" | wc -l | tr -d ' ') adhkar recitations, Cairo font"

# The morning/evening adhkar must have real recordings, as on the Mac.
python3 - "$APP/Assets/Audio/adhkar" "$SHARED/adhkar.json" <<'PY'
import json, pathlib, sys
audio = pathlib.Path(sys.argv[1]); library = json.load(open(sys.argv[2], encoding="utf-8"))
missing = [f"{c} #{i}" for c in ("morning", "evening") for i, e in enumerate(library.get(c, []), 1)
           if not (audio / e.get("audio_file", "")).is_file()]
if missing: sys.exit("Adhkar audio missing: " + ", ".join(missing))
print("  morning/evening adhkar recordings verified")
PY

# ---------- strings shared with the Mac app ----------------------------------
if [ -f "$MAC_SOURCE/main.swift" ]; then
    python3 "$HERE/tools/extract_strings.py" "$MAC_SOURCE" >/dev/null && echo "  strings.json refreshed from the Mac app ($MAC_SOURCE)"
else
    echo "  using the committed strings.json (no Mac checkout at $MAC_SOURCE)"
fi

# ---------- Qur'an assets: fail closed on any mismatch -----------------------
python3 - "$SHARED/QuranAssets" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1]); manifest = json.load(open(root / "source-manifest.json", encoding="utf-8"))
expected = {}
def walk(o):
    if isinstance(o, dict):
        if "sha256" in o and (o.get("path") or o.get("file")): expected[o.get("path") or o.get("file")] = o["sha256"]
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(manifest)
shipped = ["Hafs/hafsData_v2-0.json", "Warsh/warshData_v2-1.json"] + \
          [p for p in expected if p.startswith("Translations/QuranEnc/")] + [p for p in expected if p.startswith("Fonts/")]
bad = [p for p in shipped if p not in expected or hashlib.sha256((root / p).read_bytes()).hexdigest() != expected[p].lower()]
if bad: sys.exit("Qur'an asset verification failed: " + ", ".join(bad))
print(f"  {len(shipped)} Qur'an files verified against source-manifest.json")
PY

if [ "$RUN" = 1 ]; then
    exec dotnet run --project "$APP" -c Debug
fi

# ---------- publish ----------------------------------------------------------
VERSION=$(sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p' "$APP/SalatTime.csproj" | head -1)
mkdir -p "$DIST"
for rid in "${RIDS[@]}"; do
    out="$DIST/SalatTime-$VERSION-$rid"
    echo "Publishing $rid → $out"
    rm -rf "$out"
    dotnet publish "$APP/SalatTime.csproj" -c Release -r "$rid" --self-contained true \
        -p:PublishSingleFile=false -p:DebugType=none -p:EnableWindowsTargeting=true \
        -o "$out" -v quiet -nologo
    rm -f "$DIST/SalatTime-$VERSION-$rid.zip"
    (cd "$DIST" && zip -qr "SalatTime-$VERSION-$rid.zip" "SalatTime-$VERSION-$rid")
    echo "  $(du -sh "$DIST/SalatTime-$VERSION-$rid.zip" | cut -f1)  SalatTime-$VERSION-$rid.zip"

    # Installer (per-user, no administrator rights) when NSIS is available.
    if command -v makensis >/dev/null; then
        arch="${rid#win-}"
        LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 makensis -V2 -DVERSION="$VERSION" -DARCH="$arch" -DSOURCE="$out" \
            -DOUTFILE="$DIST/SalatTime-$VERSION-setup-$arch.exe" "$HERE/installer/SalatTime.nsi"
        echo "  $(du -sh "$DIST/SalatTime-$VERSION-setup-$arch.exe" | cut -f1)  SalatTime-$VERSION-setup-$arch.exe"
    fi
done
echo "Done. Builds are in $DIST"
