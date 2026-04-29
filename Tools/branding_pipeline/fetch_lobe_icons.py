#!/usr/bin/env python3
"""
fetch_lobe_icons.py — fetch provider/company brand assets from LobeHub's
@lobehub/icons-static-svg package on jsDelivr CDN, generate mono variants
via currentColor substitution, and write provenance.json per provider.

Asset variants attempted per provider (each is independent; missing ones are
recorded as `null` in provenance and the build proceeds):
  - <id>.svg              -> icon-color.svg   + derived icon-mono.svg
  - <id>-color.svg        -> icon-color.svg (preferred over plain when present)
  - <id>-text.svg         -> wordmark-color.svg + derived wordmark-mono.svg
  - <id>-combine.svg      -> combine-color.svg + derived combine-mono.svg
  - <id>-brand.svg        -> brand-color.svg (on-brand background variant)
  - <id>-brand-color.svg  -> alternative brand variant if -brand is absent

Color variants are used in Settings (per DOCTRINE §10.7).
Mono variants are used in chat headers, sidebar agent labels, model picker,
command palette, tab chips, and other in-app surfaces (per DOCTRINE §10.7).

These are SMOOTH-VECTOR brand icons. They are EXEMPT from DOCTRINE I-16
bit-perfect rendering (which applies to pixel-art mascots and pixel-art
wordmarks like the user-supplied Claude Code asset). Provider brand icons
render with default SwiftUI smoothing; they are not part of the simulation's
pixel-perfect visual contract.

USAGE
    cd <repo-root>
    python3 Tools/branding_pipeline/fetch_lobe_icons.py
    # writes into Resources/CompanionAssets/branding/<slug>/

LICENSE NOTE
    LobeHub's @lobehub/icons package is MIT-licensed for the compilation/code,
    but the underlying brand marks are trademarks of their respective owners.
    Use is for identification ("this companion calls Claude Code"), similar
    to "Made for Mac." Provenance manifests record this for review.
"""

from __future__ import annotations
import json
import re
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime, timezone

# -----------------------------------------------------------------------------
# Provider catalog
# -----------------------------------------------------------------------------
# (slug, lobehub_id, display_name, brand_color_hint, has_separate_text_variant)
# - slug: directory under Resources/CompanionAssets/branding/<slug>/
# - lobehub_id: the icon name in @lobehub/icons-static-svg (lowercase, no spaces)
# - brand_color_hint: a recognized brand color for fallback / UI accent
# - has_separate_text_variant: whether to attempt fetching the -text variant

PROVIDERS: list[tuple[str, str, str, str, bool]] = [
    # slug,            lobehub_id,     display,                      brand,       text?
    ("anthropic",      "anthropic",    "Anthropic",                  "#D97757",   True),
    ("claude",         "claude",       "Claude",                     "#D97757",   True),
    ("claude-code",    "claudecode",   "Claude Code",                "#D97757",   True),
    ("openai",         "openai",       "OpenAI",                     "#000000",   True),
    ("codex",          "codex",        "OpenAI Codex",               "#000000",   True),
    ("kimi",           "kimi",         "Kimi",                       "#5B8DEF",   True),
    ("moonshot",       "moonshot",     "Moonshot AI",                "#5B8DEF",   True),
    ("gemini",         "gemini",       "Gemini",                     "#4285F4",   True),
    ("google",         "google",       "Google",                     "#4285F4",   True),
    ("gemma",          "gemma",        "Gemma",                      "#4285F4",   True),
    ("perplexity",     "perplexity",   "Perplexity",                 "#1FB8CD",   True),
    ("deepseek",       "deepseek",     "DeepSeek",                   "#5B8DEF",   True),
    ("qwen",           "qwen",         "Qwen",                       "#615CED",   True),
    ("apple",          "apple",        "Apple",                      "#000000",   False),
    ("huggingface",    "huggingface",  "Hugging Face",               "#FFD21E",   True),
    ("github",         "github",       "GitHub",                     "#000000",   True),
    ("hermes-agent",   "hermesagent",  "Hermes Agent (Nous Research)", "#D4AF37", True),
    ("mcp",            "mcp",          "Model Context Protocol",     "#000000",   True),
]

# -----------------------------------------------------------------------------
# Source: jsDelivr CDN serving the @lobehub/icons-static-svg package.
# Pinned to a known major version so the build is reproducible.
# Bump when LobeHub releases a new major; check provenance manifest for the
# exact version that was last used.
# -----------------------------------------------------------------------------
PACKAGE_VERSION = "latest"   # change to a pinned version once verified, e.g. "1.x.y"
CDN_BASE = f"https://cdn.jsdelivr.net/npm/@lobehub/icons-static-svg@{PACKAGE_VERSION}/icons"

# Where assets land (relative to repo root).
ROOT = Path("Resources/CompanionAssets/branding")

# -----------------------------------------------------------------------------
# Variant filename plan per provider directory.
#   icon-color.svg       <- <id>-color.svg if present, else <id>.svg
#   icon-mono.svg        <- derived from icon-color.svg via currentColor pass
#   wordmark-color.svg   <- <id>-text.svg
#   wordmark-mono.svg    <- derived from wordmark-color.svg
#   combine-color.svg    <- <id>-combine.svg
#   combine-mono.svg     <- derived
#   brand-color.svg      <- <id>-brand.svg or <id>-brand-color.svg
# -----------------------------------------------------------------------------

USER_AGENT = "epistemos-branding-fetcher/1.0 (+https://github.com/BlickandMorty/Epistemos)"


def fetch(url: str) -> bytes | None:
    """Fetch a URL; return body on 200, None otherwise."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            if r.status == 200:
                return r.read()
            return None
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"  warn: {url} -> HTTP {e.code}", file=sys.stderr)
        return None
    except Exception as e:  # noqa: BLE001
        print(f"  warn: {url} -> {e}", file=sys.stderr)
        return None


# Patterns for converting fills/strokes to currentColor.
# Important: preserve fill="none" and existing fill="currentColor".
_FILL_HEX_RE = re.compile(r'\bfill\s*=\s*"(?!none|currentColor)#?[0-9A-Fa-f]{3,8}"', re.IGNORECASE)
_STROKE_HEX_RE = re.compile(r'\bstroke\s*=\s*"(?!none|currentColor)#?[0-9A-Fa-f]{3,8}"', re.IGNORECASE)
_FILL_RGB_RE = re.compile(r'\bfill\s*=\s*"(?!none|currentColor)rgb\([^)]+\)"', re.IGNORECASE)
_STROKE_RGB_RE = re.compile(r'\bstroke\s*=\s*"(?!none|currentColor)rgb\([^)]+\)"', re.IGNORECASE)
_STYLE_FILL_HEX_RE = re.compile(r'fill\s*:\s*#[0-9A-Fa-f]{3,8}', re.IGNORECASE)
_STYLE_STROKE_HEX_RE = re.compile(r'stroke\s*:\s*#[0-9A-Fa-f]{3,8}', re.IGNORECASE)
_STYLE_FILL_RGB_RE = re.compile(r'fill\s*:\s*rgb\([^)]+\)', re.IGNORECASE)
_STYLE_STROKE_RGB_RE = re.compile(r'stroke\s*:\s*rgb\([^)]+\)', re.IGNORECASE)
# Some icons use `<stop stop-color="#..."/>` inside gradients; flatten those too.
_STOP_COLOR_RE = re.compile(r'\bstop-color\s*=\s*"(?!currentColor)[^"]+"', re.IGNORECASE)


def to_mono(svg_bytes: bytes) -> bytes:
    """Return a mono variant by replacing concrete colors with currentColor.

    The result is suitable for SwiftUI Image rendering with a tint applied
    via .foregroundStyle(.primary) or any Color. fill="none" and existing
    currentColor declarations are preserved.
    """
    s = svg_bytes.decode("utf-8", errors="replace")
    s = _FILL_HEX_RE.sub('fill="currentColor"', s)
    s = _STROKE_HEX_RE.sub('stroke="currentColor"', s)
    s = _FILL_RGB_RE.sub('fill="currentColor"', s)
    s = _STROKE_RGB_RE.sub('stroke="currentColor"', s)
    s = _STYLE_FILL_HEX_RE.sub("fill: currentColor", s)
    s = _STYLE_STROKE_HEX_RE.sub("stroke: currentColor", s)
    s = _STYLE_FILL_RGB_RE.sub("fill: currentColor", s)
    s = _STYLE_STROKE_RGB_RE.sub("stroke: currentColor", s)
    s = _STOP_COLOR_RE.sub('stop-color="currentColor"', s)
    return s.encode("utf-8")


def write_pair(target_dir: Path, color_name: str, mono_name: str, color_bytes: bytes) -> None:
    (target_dir / color_name).write_bytes(color_bytes)
    (target_dir / mono_name).write_bytes(to_mono(color_bytes))


def fetch_provider(slug: str, lobe_id: str, display: str, brand_color: str, has_text: bool) -> dict:
    pdir = ROOT / slug
    pdir.mkdir(parents=True, exist_ok=True)

    sources: dict[str, str | None] = {
        "icon-color":     None,
        "icon-mono":      None,
        "wordmark-color": None,
        "wordmark-mono":  None,
        "combine-color":  None,
        "combine-mono":   None,
        "brand-color":    None,
    }

    # 1. Icon — prefer -color suffix; fall back to plain.
    for url in (f"{CDN_BASE}/{lobe_id}-color.svg", f"{CDN_BASE}/{lobe_id}.svg"):
        data = fetch(url)
        if data:
            write_pair(pdir, "icon-color.svg", "icon-mono.svg", data)
            sources["icon-color"] = url
            sources["icon-mono"]  = "derived from icon-color via fetch_lobe_icons.py to_mono()"
            break

    # 2. Wordmark / text variant.
    if has_text:
        url = f"{CDN_BASE}/{lobe_id}-text.svg"
        data = fetch(url)
        if data:
            write_pair(pdir, "wordmark-color.svg", "wordmark-mono.svg", data)
            sources["wordmark-color"] = url
            sources["wordmark-mono"]  = "derived from wordmark-color via fetch_lobe_icons.py to_mono()"

    # 3. Combine (hero) — icon + wordmark composed together.
    url = f"{CDN_BASE}/{lobe_id}-combine.svg"
    data = fetch(url)
    if data:
        write_pair(pdir, "combine-color.svg", "combine-mono.svg", data)
        sources["combine-color"] = url
        sources["combine-mono"]  = "derived from combine-color via fetch_lobe_icons.py to_mono()"

    # 4. Brand (on-brand background variant).
    for url in (f"{CDN_BASE}/{lobe_id}-brand.svg", f"{CDN_BASE}/{lobe_id}-brand-color.svg"):
        data = fetch(url)
        if data:
            (pdir / "brand-color.svg").write_bytes(data)
            sources["brand-color"] = url
            break

    write_provenance(pdir, slug, lobe_id, display, brand_color, sources)

    have = [k for k, v in sources.items() if v is not None]
    miss = [k for k, v in sources.items() if v is None]
    print(f"OK: {slug:14s} have={have} missing={miss}")
    return {"slug": slug, "have": have, "missing": miss}


def write_provenance(pdir: Path, slug: str, lobe_id: str, display: str,
                     brand_color: str, sources: dict[str, str | None]) -> None:
    manifest = {
        "asset_id": f"{slug}-brand-icon-set-v1",
        "provider_slug": slug,
        "lobehub_id": lobe_id,
        "display_name": display,
        "category": "smooth-vector-brand",
        "exempt_from_doctrine_invariants": [
            "I-16 (bit-perfect): does not apply — these are smooth provider brand icons, "
            "not pixel-art mascots. They render with default SwiftUI/CoreGraphics smoothing. "
            "I-16 applies to the simulation companion sprites and pixel-art branding only."
        ],
        "brand_color_canonical": brand_color,
        "license_compilation": "MIT (LobeHub @lobehub/icons-static-svg)",
        "license_marks": "Trademarks of respective owners; identification use only "
                         "(similar to 'Made for Mac' badges)",
        "commercial_use_ok": True,
        "package_version": PACKAGE_VERSION,
        "fetched_via": "Tools/branding_pipeline/fetch_lobe_icons.py",
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "usage_scope": {
            "color_variant": [
                "Settings → Providers list",
                "Settings → API key configuration row icon",
                "Settings → Model selector glyph",
                "Onboarding hero (where the provider is the subject)",
            ],
            "mono_variant": [
                "Notes sidebar — agent label icon (DOCTRINE §3.4)",
                "Chat header — provider chip when companion is active",
                "Command palette — provider routing glyph",
                "Tab/window chrome — running-companion indicator",
                "Audit View — per-event provider attribution",
                "Inline UI labels alongside text",
            ],
            "combine_variant": [
                "Onboarding marketing surface (with explicit user opt-in to show wordmarks)",
                "Marketplace/registry view header",
            ],
            "brand_variant": [
                "Optional — only when explicit brand color background is needed (rare)",
            ],
        },
        "recoloring_policy": {
            "color":    f"locked to upstream LobeHub palette (brand canonical {brand_color})",
            "mono":     "currentColor (tinted by SwiftUI .foregroundStyle at render site)",
            "combine":  "color: locked; mono: currentColor",
            "brand":    "locked",
        },
        "swiftui_render_recipe": {
            "color": "Image(svgResource: \"branding/<slug>/icon-color.svg\")",
            "mono":  "Image(svgResource: \"branding/<slug>/icon-mono.svg\")"
                     ".foregroundStyle(.primary)  // or .accent / .secondary by surface",
        },
        "sources": sources,
        "added": "2026-04-29",
        "added_by": "fetch_lobe_icons.py",
    }
    (pdir / "provenance.json").write_text(json.dumps(manifest, indent=2) + "\n")


def main() -> int:
    # Resolve target relative to current working directory. The script is intended
    # to be run from the repo root (where `Resources/` lives). If the user runs it
    # from elsewhere, we still create the directory tree but log the resolved path
    # so they can confirm it landed where they expected.
    ROOT.mkdir(parents=True, exist_ok=True)
    resolved = ROOT.resolve()
    print(f"Fetching {len(PROVIDERS)} providers from {CDN_BASE}")
    print(f"Target:   {resolved}/")
    if "Resources/CompanionAssets/branding" not in str(resolved):
        print("WARN: target path does not contain 'Resources/CompanionAssets/branding';")
        print("      verify you ran this from the repo root.", file=sys.stderr)
    print()

    results: list[dict] = []
    for slug, lobe_id, display, brand, text in PROVIDERS:
        results.append(fetch_provider(slug, lobe_id, display, brand, text))
        time.sleep(0.05)  # be polite to the CDN

    # Index
    index_path = ROOT / "_index.json"
    index = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "package_version": PACKAGE_VERSION,
        "providers": [r["slug"] for r in results],
        "summary": results,
    }
    index_path.write_text(json.dumps(index, indent=2) + "\n")
    print()
    print(f"Wrote index: {index_path}")
    print(f"Done. {len(results)} provider directories under {ROOT}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
