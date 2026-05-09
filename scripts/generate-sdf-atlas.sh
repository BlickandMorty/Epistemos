#!/bin/bash
# Generate the SDF label atlas for graph-engine label rendering.
#
# Produces two artifacts committed to Epistemos/Resources/:
#   - sdf_labels.png   (MTSDF 4-channel 1024x1024 atlas)
#   - sdf_labels.json  (per-glyph UV + em-unit metrics)
#
# Run this from the repo root. Re-run whenever the font or charset changes.
# The two artifacts are bundled into Epistemos.app's Resources and loaded
# at startup via graph_engine_load_label_atlas().
#
# Parameters per Tier 1 research ("Epistemos Graph SDF Label System — Deep
# Engineering Report", Part I):
#   -type mtsdf          : multi-channel + true SDF, 4 RGBA channels
#   -size 48             : glyph size; large enough for crisp graph labels
#   -emrange 0.4         : distance field range in em units
#   -pxrange 6           : pixel range for smooth falloff
#   -dimensions 1024 1024: fixed atlas size (ASCII fits easily)
#   -yorigin top         : Metal texture coords (top-left origin)
#
# Per CODEX_PROMPT_CHAIN.md §B-2.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${REPO_ROOT}/Epistemos/Resources"

# Variant selection — controls the output filename AND the default font:
#   --variant mono    → sdf_labels.{png,json}        + JetBrainsMono-Regular.ttf
#   --variant retro   → sdf_labels_retro.{png,json}  + RetroGaming.ttf
#   --variant system  → sdf_labels_system.{png,json} + Helvetica/SFNS
# An explicit `-font <path>` overrides the variant's default font.
# Defaults to "mono" so graph labels stay high-quality and monospaced.
VARIANT="mono"
FONT_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --variant)
            VARIANT="${2:-retro}"
            shift 2
            ;;
        -font)
            FONT_PATH="${2:-}"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 [--variant mono|retro|system|sfpro] [-font /path/to/font.ttf]" >&2
            exit 1
            ;;
    esac
done

case "$VARIANT" in
    mono)
        PNG_OUT="${OUT_DIR}/sdf_labels.png"
        JSON_OUT="${OUT_DIR}/sdf_labels.json"
        VARIANT_DEFAULT_FONT_CANDIDATES=(
            "${REPO_ROOT}/Epistemos/Resources/Fonts/JetBrainsMono-Regular.ttf"
            "/System/Library/Fonts/SFNSMono.ttf"
            "/System/Library/Fonts/Menlo.ttc"
        )
        ;;
    retro)
        PNG_OUT="${OUT_DIR}/sdf_labels_retro.png"
        JSON_OUT="${OUT_DIR}/sdf_labels_retro.json"
        VARIANT_DEFAULT_FONT_CANDIDATES=(
            "${REPO_ROOT}/Epistemos/Resources/Fonts/RetroGaming.ttf"
            "/System/Library/Fonts/Helvetica.ttc"
        )
        ;;
    system)
        PNG_OUT="${OUT_DIR}/sdf_labels_system.png"
        JSON_OUT="${OUT_DIR}/sdf_labels_system.json"
        VARIANT_DEFAULT_FONT_CANDIDATES=(
            "/System/Library/Fonts/Helvetica.ttc"
            "/System/Library/Fonts/HelveticaNeue.ttc"
        )
        ;;
    sfpro)
        PNG_OUT="${OUT_DIR}/sdf_labels_sfpro.png"
        JSON_OUT="${OUT_DIR}/sdf_labels_sfpro.json"
        VARIANT_DEFAULT_FONT_CANDIDATES=(
            "/System/Library/Fonts/SFNS.ttf"
            "/System/Library/Fonts/SFNSRounded.ttf"
            "/System/Library/Fonts/SFNSText.ttf"
            "/System/Library/Fonts/SFNSDisplay.ttf"
        )
        ;;
    *)
        echo "ERROR: Unknown --variant: $VARIANT (expected: mono | retro | system | sfpro)" >&2
        exit 1
        ;;
esac

# Font resolution priority: explicit -font → $EPISTEMOS_SDF_FONT → variant default.
if [[ -z "$FONT_PATH" && -n "${EPISTEMOS_SDF_FONT:-}" ]]; then
    FONT_PATH="$EPISTEMOS_SDF_FONT"
fi
if [[ -z "$FONT_PATH" ]]; then
    for candidate in "${VARIANT_DEFAULT_FONT_CANDIDATES[@]}"; do
        if [[ -f "$candidate" ]]; then
            FONT_PATH="$candidate"
            break
        fi
    done
fi

if [[ -z "$FONT_PATH" || ! -f "$FONT_PATH" ]]; then
    echo "ERROR: No font found at \"$FONT_PATH\"." >&2
    exit 1
fi

if ! command -v msdf-atlas-gen &>/dev/null; then
    echo "ERROR: msdf-atlas-gen not installed." >&2
    echo "Install with: brew install msdf-atlas-gen" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

echo "Font:     $FONT_PATH"
echo "PNG out:  $PNG_OUT"
echo "JSON out: $JSON_OUT"

# msdf-atlas-gen v1.4 defaults to the ASCII charset, and the `-charset`
# flag now expects a file path (not a keyword). The default works for us.
msdf-atlas-gen \
    -type mtsdf \
    -font "$FONT_PATH" \
    -size 48 \
    -emrange 0.4 \
    -pxrange 6 \
    -dimensions 1024 1024 \
    -imageout "$PNG_OUT" \
    -json "$JSON_OUT" \
    -yorigin top

echo
echo "SDF atlas generated. Rebuild the app to pick up label rendering."
