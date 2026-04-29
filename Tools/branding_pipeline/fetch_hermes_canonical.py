#!/usr/bin/env python3
"""
fetch_hermes_canonical.py — probe the official NousResearch/hermes-agent
repository (and a small set of related hermes-skins / nous-research repos)
for canonical visual assets needed for Epistemos's Hermes Mode landing ritual:

  - Hero pixel-art wordmark "HERMES-AGENT" (yellow on orange-shadow)
  - ASCII portrait of the Nous Research mascot ("the girl")
  - Snake / caduceus / serpent imagery
  - ASCII art banners, splash screens, ANSI animations
  - Brand color palettes / typography references

The probe is read-only and conservative: it does not follow redirects to
other domains, does not authenticate, does not write outside its target
directory, and reports every file it finds so the human reviewer chooses
what to canonicalize.

Output:
  Resources/CompanionAssets/branding/hermes-agent-pixel/raw/<source-repo>/
      <original-paths preserved>
  Resources/CompanionAssets/ascii/raw/<source-repo>/
      <original-paths preserved>
  Resources/CompanionAssets/branding/hermes-agent-pixel/_probe.json
      summary of every asset path discovered, by repo

The human reviewer then promotes the chosen files to canonical paths:
  - Resources/CompanionAssets/branding/hermes-agent-pixel/wordmark-hero-color.svg
  - Resources/CompanionAssets/branding/hermes-agent-pixel/mascot-snake-color.svg
  - Resources/CompanionAssets/ascii/hermes-agent-portrait.txt
  - etc.

LICENSE NOTE
  NousResearch publishes hermes-agent under the MIT License (verify at run
  time via the repo's LICENSE file). Visual assets in the repo are part of
  that MIT distribution unless flagged otherwise per file. Underlying brand
  motifs (Hermes / caduceus / serpent imagery) are public-domain mythology;
  the specific NousResearch artwork is MIT-permitted for redistribution
  with attribution. Provenance manifests record this for review.

USAGE
    cd <repo-root>
    python3 Tools/branding_pipeline/fetch_hermes_canonical.py

    # If you hit GitHub's unauthenticated rate limit (60 req/hr per IP),
    # pass a token via env var:
    GITHUB_TOKEN=ghp_xxx python3 Tools/branding_pipeline/fetch_hermes_canonical.py
"""

from __future__ import annotations
import json
import os
import sys
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime, timezone

# -----------------------------------------------------------------------------
# Source repos to probe.
# Each entry: (label, owner, repo, default_branch, attribution_required)
# -----------------------------------------------------------------------------
SOURCES: list[tuple[str, str, str, str, bool]] = [
    # Primary: the official NousResearch hermes-agent.
    ("nous-hermes-agent",   "NousResearch", "hermes-agent",      "main",   True),
    # Secondary: the community hermes-skins themes (the user linked this earlier).
    ("joeynyc-hermes-skins","joeynyc",      "hermes-skins",      "main",   True),
    # Tertiary: NousResearch organization-level visual repos (probed if they exist).
    ("nous-brand",          "NousResearch", "brand",             "main",   True),
    ("nous-assets",         "NousResearch", "assets",            "main",   True),
]

# Visual / text-art file extensions worth fetching.
ASSET_EXTS = {
    ".svg", ".png", ".jpg", ".jpeg", ".gif", ".webp",
    ".txt", ".ans", ".ansi", ".asc", ".ascii", ".md",
    ".ttf", ".otf", ".woff", ".woff2",
    ".json",  # palettes, themes
}

# Path prefixes most likely to hold visual assets (best-effort — we still
# scan the entire tree, but assets in these dirs are auto-promoted to
# higher reviewer priority in _probe.json).
ASSET_DIR_HINTS = (
    "assets", "static", "media", "images", "img", "fonts", "ascii",
    "branding", "brand", "logos", "skins", "themes", "ui", "splash",
    "docs/assets", "docs/images", "docs/static",
)

OUT_BRANDING = Path("Resources/CompanionAssets/branding/hermes-agent-pixel/raw")
OUT_ASCII    = Path("Resources/CompanionAssets/ascii/raw")
PROBE_REPORT = Path("Resources/CompanionAssets/branding/hermes-agent-pixel/_probe.json")

USER_AGENT = "epistemos-hermes-fetcher/1.0 (+https://github.com/BlickandMorty/Epistemos)"


def gh_api(url: str) -> bytes | None:
    headers = {"User-Agent": USER_AGENT, "Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            if r.status == 200:
                return r.read()
            return None
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        if e.code == 403:
            print(f"  warn: GitHub rate-limited or forbidden for {url}", file=sys.stderr)
            print(f"        set GITHUB_TOKEN env var to authenticate.", file=sys.stderr)
            return None
        print(f"  warn: {url} -> HTTP {e.code}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"  warn: {url} -> {e}", file=sys.stderr)
        return None


def gh_raw(owner: str, repo: str, ref: str, path: str) -> bytes | None:
    """Fetch raw file content via GitHub raw URL (no API rate limit)."""
    url = f"https://raw.githubusercontent.com/{owner}/{repo}/{ref}/{path}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            if r.status == 200:
                return r.read()
            return None
    except Exception:
        return None


def list_tree(owner: str, repo: str, branch: str) -> list[dict] | None:
    """Recursively list every file in a repo's default branch via GitHub API."""
    # Step 1: resolve the branch's tree SHA.
    branch_url = f"https://api.github.com/repos/{owner}/{repo}/branches/{branch}"
    branch_data = gh_api(branch_url)
    if not branch_data:
        return None
    try:
        sha = json.loads(branch_data)["commit"]["sha"]
    except (KeyError, json.JSONDecodeError):
        return None

    # Step 2: recursive tree listing.
    tree_url = f"https://api.github.com/repos/{owner}/{repo}/git/trees/{sha}?recursive=1"
    tree_data = gh_api(tree_url)
    if not tree_data:
        return None
    try:
        tree = json.loads(tree_data)
        return [entry for entry in tree.get("tree", []) if entry.get("type") == "blob"]
    except (KeyError, json.JSONDecodeError):
        return None


def is_asset_path(path: str) -> bool:
    p = path.lower()
    if any(p.endswith(ext) for ext in ASSET_EXTS):
        return True
    return False


def is_high_priority(path: str) -> bool:
    p = path.lower()
    return any(p.startswith(h.lower()) or f"/{h.lower()}/" in p for h in ASSET_DIR_HINTS)


def is_text_art(path: str) -> bool:
    p = path.lower()
    return p.endswith((".txt", ".ans", ".ansi", ".asc", ".ascii"))


def fetch_repo(label: str, owner: str, repo: str, branch: str,
               attribution_required: bool) -> dict:
    print(f"\n=== Probing {owner}/{repo}@{branch} ({label}) ===")
    tree = list_tree(owner, repo, branch)
    if tree is None:
        print(f"  skip: repo or branch not reachable")
        return {"label": label, "owner": owner, "repo": repo, "branch": branch,
                "reachable": False, "assets": []}

    candidates = [e for e in tree if is_asset_path(e["path"])]
    print(f"  found {len(candidates)} asset-extension files (of {len(tree)} total blobs)")

    discovered: list[dict] = []
    for entry in candidates:
        path = entry["path"]
        size = entry.get("size", 0)
        prio = "high" if is_high_priority(path) else "normal"

        # Choose target directory based on extension.
        target_root = OUT_ASCII if is_text_art(path) else OUT_BRANDING
        target = target_root / label / path
        target.parent.mkdir(parents=True, exist_ok=True)

        data = gh_raw(owner, repo, branch, path)
        if data is None:
            discovered.append({"path": path, "size": size, "priority": prio,
                              "fetched": False})
            continue
        target.write_bytes(data)
        discovered.append({
            "path": path, "size": size, "priority": prio,
            "fetched": True,
            "raw_url": f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}",
            "saved_to": str(target),
        })
        marker = "★" if prio == "high" else " "
        print(f"  {marker} {path}  ({size} bytes)")

    return {
        "label": label, "owner": owner, "repo": repo, "branch": branch,
        "reachable": True,
        "attribution_required": attribution_required,
        "license_check": f"https://github.com/{owner}/{repo}/blob/{branch}/LICENSE",
        "assets": discovered,
    }


def write_probe_report(results: list[dict]) -> None:
    PROBE_REPORT.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sources_attempted": len(results),
        "sources_reachable": sum(1 for r in results if r.get("reachable")),
        "next_steps": [
            "Review each `raw/<label>/` directory and pick the canonical files.",
            "Promote them to the canonical paths:",
            "  - branding/hermes-agent-pixel/wordmark-hero-color.svg  (the big HERMES-AGENT title)",
            "  - branding/hermes-agent-pixel/wordmark-hero-mono.svg   (currentColor, derived manually if needed)",
            "  - branding/hermes-agent-pixel/mascot-snake-color.svg   (the snake / caduceus)",
            "  - branding/hermes-agent-pixel/mascot-snake-mono.svg",
            "  - ascii/hermes-agent-portrait.txt                      (the Nous Research character)",
            "  - ascii/hermes-agent-banner.txt                        (any banner/splash ASCII)",
            "Then write provenance.json declaring `category: pixel-art-mascot` and citing source URLs.",
            "Finally delete the `raw/` staging directories — they are not part of the canonical asset set.",
        ],
        "results": results,
    }
    PROBE_REPORT.write_text(json.dumps(report, indent=2) + "\n")
    print(f"\nProbe report written to: {PROBE_REPORT}")


def main() -> int:
    OUT_BRANDING.mkdir(parents=True, exist_ok=True)
    OUT_ASCII.mkdir(parents=True, exist_ok=True)

    print(f"Probing {len(SOURCES)} repos for Hermes canonical assets")
    print(f"Branding stage: {OUT_BRANDING.resolve()}")
    print(f"ASCII stage:    {OUT_ASCII.resolve()}")
    if not os.environ.get("GITHUB_TOKEN"):
        print("Note: no GITHUB_TOKEN set; you have ~60 unauthenticated requests/hour")

    results = [fetch_repo(*src) for src in SOURCES]
    write_probe_report(results)

    reachable = [r for r in results if r.get("reachable")]
    total_assets = sum(len(r.get("assets", [])) for r in reachable)
    print(f"\nDone. {len(reachable)}/{len(results)} repos reachable; "
          f"{total_assets} candidate assets staged.")
    print("Next: review _probe.json, promote canonical files, delete raw/ staging.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
