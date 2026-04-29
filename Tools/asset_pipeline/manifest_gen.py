#!/usr/bin/env python3
"""
manifest_gen.py — generate / refresh provenance.json for each
atlas in `Epistemos/Resources/CompanionAssets/atlas/`.

Per DOCTRINE §10.2 each atlas needs a provenance manifest that
records:
  - category (always "raster-companion-atlas" for these)
  - origin (epistemos-original / artist-refined / model-assisted)
  - license (CC0-1.0 for V1; varies for V2 artist work)
  - author (the human who authored the Character DNA + the
    artist if a refinement pass happened)
  - model (if AI assistance was used; null for V1 procedural)
  - generated_at (ISO-8601 UTC)
  - generator (the tool that produced the PNG, e.g. this script
    or `procedural_atlas_v1.py`)
  - allowed_inspirations (lifted from the matching Character DNA)
  - forbidden_inspirations (lifted from the matching Character DNA)
  - doctrine_refs (e.g. ["§5.3", "§10.1", "§10.2", "§10.5"])

V1 entries are written by this script as the procedural atlas
ships. V2+ entries get rewritten by the artist's tooling when
they refine.
"""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent.parent
ATLAS_DIR = REPO_ROOT / "Epistemos" / "Resources" / "CompanionAssets" / "atlas"
DNA_DIR = REPO_ROOT / "docs" / "simulation-mode" / "character-dna"


# =============================================================================
# Character DNA → inspiration lists (lifted from each preset's md)
# =============================================================================

INSPIRATION_LISTS: dict[str, dict[str, list[str]]] = {
    "block_compact": {
        "allowed": [
            "Bauhaus square — geometric, deliberate, chunky",
            "Early-arcade pixel-art enemies (1-bit silhouette discipline)",
            "Tetris pieces (chunky, satisfying weight)",
            "Industrial robots (no-nonsense block-with-prop archetype)",
        ],
        "forbidden": [
            "Kimi CLI mascot (verbatim trace)",
            "Codex CLI mascot (verbatim trace)",
            "Tamagotchi / Bandai pixel-pet silhouettes (Bandai trademark)",
            "Apple Macintosh-classic silhouette",
        ],
    },
    "block_wide": {
        "allowed": [
            "User-supplied Claude Code mascot direction (warm-orange wide block, multi-leg, single antenna, negative-space eyes) — INSPIRATION ONLY",
            "Bookends — scholarly cube on legs",
            "Industrial cooling units (wide-with-vents silhouette)",
            "Sci-fi consoles from 8-bit era games (trustworthy-terminal feel)",
        ],
        "forbidden": [
            "Verbatim pixel-trace of Claude Code mascot SVG",
            "Anthropic's Claude logo (smooth-vector A-shape)",
            "Tamagotchi pixel pets (Bandai trademark)",
            "Classic Macintosh smiling-mac silhouette",
            "Apple //e profile",
        ],
    },
    "orb": {
        "allowed": [
            "Ancient hovering spheres in mythological / sci-fi imagery",
            "8-bit ball enemies (drifting circle archetype)",
            "Crystal balls / scrying orbs",
            "Bauhaus circle counterpart to the Block's square",
            "Kimi CLI's circular variant — INSPIRATION ONLY",
        ],
        "forbidden": [
            "OpenAI logo (smooth-vector swirl mark; different asset)",
            "Verbatim Kimi orb mascot tracing",
            "Pokémon Voltorb / Electrode (Nintendo IP)",
            "Tamagotchi orb-pets (Bandai trademark)",
        ],
    },
    "sage": {
        "allowed": [
            "Generic JRPG mage / scholar / monk silhouettes",
            "Bauhaus humanoid figure abstractions",
            "Wizard / wanderer pixel-art conventions (8-bit RPG genre)",
            "Tarot Hermit illustrations",
        ],
        "forbidden": [
            "Specific Nintendo / SNK / Capcom pixel sprites (Mario, Link, Geno)",
            "Earthbound NPC sprites (Nintendo IP)",
            "Specific D&D character art (WotC IP)",
            "Game-of-Thrones / LOTR / WoT character likenesses",
            "Tamagotchi pixel pets (Bandai trademark)",
        ],
    },
    "hermes_snake": {
        "allowed": [
            "Mythological caduceus (Hermes staff with serpents)",
            "Ouroboros imagery (snake-eating-its-tail loop)",
            "8-bit JRPG snake enemies (spiral-coil archetype)",
            "Canonical NousResearch caduceus SVG — DIRECTION REFERENCE ONLY",
        ],
        "forbidden": [
            "Verbatim pixel-trace of any NousResearch asset",
            "Pokemon Ekans / Arbok (Nintendo IP)",
            "Specific D&D dragon / snake illustrations (WotC IP)",
            "Slytherin imagery (Warner Bros / Bloomsbury IP)",
            "Apophis / Stargate symbology (MGM IP)",
        ],
    },
}


def emit_provenance(slug: str) -> dict[str, Any]:
    """Write `<slug>.provenance.json` for one atlas. Returns the
    written manifest dict so a higher-level pipeline can combine
    them into a single index."""
    insp = INSPIRATION_LISTS[slug]
    dna_path = DNA_DIR / f"{slug}.md"
    if not dna_path.is_file():
        raise FileNotFoundError(f"missing Character DNA: {dna_path}")

    now = dt.datetime.now(tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    prov = {
        "category": "raster-companion-atlas",
        "origin": "epistemos-original",
        "license": "CC0-1.0",
        "author": "Epistemos asset pipeline (procedural V1)",
        "model": None,
        "character_dna": str(dna_path.relative_to(REPO_ROOT)),
        "generated_at": now,
        "generator": "Tools/asset_pipeline/procedural_atlas_v1.py",
        "allowed_inspirations": insp["allowed"],
        "forbidden_inspirations": insp["forbidden"],
        "doctrine_refs": ["§5.1", "§5.3", "§10.1", "§10.2", "§10.3", "§10.5", "I-16"],
        "v2_substitution_policy": (
            "When an artist refines this atlas to V2 in Aseprite, the "
            "artist works from the matching Character DNA + this V1 atlas. "
            "Their refined PNG must keep the silhouette parameters (aspect, "
            "legs, antennae, eye_treatment) doctrine-mandated by §5.1; only "
            "the pixel pattern within the silhouette changes. The artist's "
            "provenance.json must record the artist name, date, model used "
            "(if any), and a visual-diff report against this V1 atlas."
        ),
    }
    out = ATLAS_DIR / f"{slug}.provenance.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(prov, indent=2) + "\n")
    return prov


def main() -> None:
    for slug in INSPIRATION_LISTS:
        emit_provenance(slug)
        print(f"  ✓ {slug}.provenance.json")


if __name__ == "__main__":
    main()
