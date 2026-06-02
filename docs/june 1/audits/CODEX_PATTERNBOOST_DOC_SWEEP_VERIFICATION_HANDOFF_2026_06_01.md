---
state: codex-handoff
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
handoff_for: Codex verifier / build watcher
scope: PatternBoost docs sweep, lattice HTML, running build result
status: ready for independent verification
---

# Codex PatternBoost Doc Sweep Verification Handoff - 2026-06-01

Umbrella codeword: `JUNE1-PATTERNBOOST-LOCK`.
Full-thread codeword: `JUNE1-CANON-FUSION-LOCK`.

This handoff verifies the PatternBoost subset. For the entire June 1 thread,
including formal math, meta-breakthrough controls, constructive residency,
cache lineage, portable note/editor systems, engineering logic, semantic
working sets, substrate traces, verifier sparse routing, ColdStream,
mmap/hot-path cures, PatternBoost, lattice HTML, and build preservation, use
`docs/audits/CODEX_JUNE1_FULL_THREAD_CANON_REINTEGRATION_PROMPT_2026_06_01.md`.

## Mission

You are checking the previous Codex pass. Do not start by rewriting. Start by
capturing the build that the user says has been running the whole time, then
verify the doc/canon migration.

This handoff exists because the previous pass was large but intentionally
docs/artifact-only: it added a June 1 PatternBoost residency bridge across
live docs, prompts, falsifiers, audits, indexes, and the lattice HTML artifact.
The codeword `JUNE1-PATTERNBOOST-LOCK` must remain discoverable from the
primary June docs, the 345 bridge notes, AGENTS, the Living Index, the
LEGENDARY codeword doc, and the lattice HTML.

## First Action - Preserve The Running Build

The user says a build has been running continuously. The previous Codex thread
could not inspect that build because no app terminal was attached to this
thread. Your first job is to capture evidence from the existing build, not to
blindly restart it.

1. Inspect the terminal/session where the build is actually running.
2. Record the exact command, start time if visible, current status, and final
   result.
3. If it is still running, do not kill it unless the user explicitly tells you
   to. Watch until it completes or until you have enough evidence that it is
   hung.
4. If you cannot access that terminal, check for live build processes:

```bash
ps -axo pid,etime,command | rg 'xcodebuild|swift-build|swiftc|clang|metal|cargo'
```

5. Only after the original build has completed, or after you have proved it is
   inaccessible, decide whether to rerun:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
```

If build/test output fails, classify it carefully. The previous pass changed
docs plus `artifacts/lattice-coordinate-explainer/index.html`; it did not
change Swift, Rust, package files, Xcode project settings, or source code.

## Canonical Files To Read First

Read these before evaluating drift:

- `AGENTS.md`
- `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/audits/CODEX_JUNE1_FULL_THREAD_CANON_REINTEGRATION_PROMPT_2026_06_01.md`
- `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`
- `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`
- `docs/audits/RESIDENCY_PATTERNBOOST_DRIFT_SWEEP_2026_06_01.md`
- `docs/audits/JUNE1_PATTERNBOOST_LOCK_CLOSEOUT_2026_06_01.md`

The current doctrine is:

- PatternBoost is an offline/idle Pro Research discovery layer, not hidden live
  route authority.
- Legacy Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims must route
  through PatternBoost, Semantic Working Set, ColdStream, falsifiers, rollback,
  and AnswerPacket witness evidence before becoming live authority.
- Zero-copy means backend/compute/transport/proof hot paths. Intentional UI and
  product copies remain allowed for multiple graph versions, editor surfaces,
  undo-safe state, previews, and user-visible artifacts.
- Model size remains cold material until the working-set, transport, lease,
  abstention, and verifier gates prove a bounded active set.

## What Changed

Primary new/current anchors:

- `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`
- `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`
- `docs/audits/RESIDENCY_PATTERNBOOST_DRIFT_SWEEP_2026_06_01.md`
- `docs/audits/JUNE1_PATTERNBOOST_LOCK_CLOSEOUT_2026_06_01.md`

High-authority surfaces were updated, including:

- `AGENTS.md`
- `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/CANONICAL_DOC_INDEX_2026_05_16.md`
- `docs/_INDEX.md`
- `docs/fusion/ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md`
- `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md`
- `artifacts/lattice-coordinate-explainer/index.html`

The final pass also inserted a small `2026-06-01 current canon bridge` preface
into 345 live-scope markdown/html files that still contained legacy substrate
or model-residency terminology. This is intentional. Do not revert it as
"noise"; the bridge is what prevents old operational docs from steering future
agents without the June 1 architecture lock.

## Verification Commands

Run from `/Users/jojo/Downloads/Epistemos`.

Tracked diff formatting check:

```bash
git diff --check -- AGENTS.md docs artifacts/lattice-coordinate-explainer/index.html
```

Conflict-marker check. Use this exact pattern; a looser `=======` scan catches
decorative separators in old prompt docs.

```bash
rg -n '^(<<<<<<<( |$)|=======$|>>>>>>>( |$))' AGENTS.md docs artifacts/lattice-coordinate-explainer/index.html
```

Live-scope legacy drift check. Expected result: empty output.

```bash
rg --files -g '*.md' -g '*.html' AGENTS.md docs artifacts/lattice-coordinate-explainer/index.html |
  rg -v '(^docs/_archive/|^docs/_consolidated/50_research_corpus/|^docs/fusion/jordan.s research/|^docs/fusion/research/|^docs/fusion/salvage/|^docs/audits/codebase-verbatim-packets-2026-05-09/|^docs/google-research-pack-2026-03-18/)' |
  while IFS= read -r f; do
    if rg -qi '70B|AppColdStore|mmap|KV-Direct|NeuralImportance|ActiveAssembly|local cocktail|addressable neural substrate|Helios|ACS|UAS|unified active substrate|active cloud storage' "$f" &&
       ! rg -qi 'ResidencyPatternBoost|PatternBoost|RESIDENCY_PATTERNBOOST|2026-06-01' "$f"; then
      printf '%s\n' "$f"
    fi
  done
```

June-stack companion check. Expected result: empty output.

```bash
comm -23 \
  <(rg -l 'SEMANTIC_WORKING_SET_COMPILER_2026_06_01|VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01|COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01|MMAP_REPLACEMENT_AND_HOTPATH_CURE_ATLAS_2026_06_01|CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01|CACHE_LINEAGE_AUTORESEARCH_PARADIGM_2026_06_01|META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01|FRONTIER_LOCAL_REASONING_16GB_ARCHITECTURE_2026_05_31|NEURAL_IMPORTANCE_ROUTING_ATLAS_2026_05_31' docs artifacts AGENTS.md | sort) \
  <(rg -l 'RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01|Residency PatternBoost|Pattern-Boosted Residency|F-RESIDENCY-PATTERNBOOST|F-Residency-PatternBoost|PatternBoost-derived|PatternBoost' docs artifacts AGENTS.md | sort)
```

Bridge count. Expected result from the previous pass: `345`.

```bash
rg -l '^> \*\*2026-06-01 current canon bridge \\(JUNE1-PATTERNBOOST-LOCK\\):' docs artifacts/lattice-coordinate-explainer/index.html | wc -l
```

Umbrella codeword count. Expected minimum: the primary June docs, AGENTS,
Living Index, LEGENDARY codeword doc, the lattice HTML, and all bridge-prefaced
live docs.

```bash
rg -l 'JUNE1-PATTERNBOOST-LOCK' AGENTS.md docs artifacts/lattice-coordinate-explainer/index.html | wc -l
```

Broad classifier. Expected result from the previous pass:
`{'live': 0, 'provenance': 313}`.

```bash
python3 - <<'PY'
from pathlib import Path
import re
root = Path('/Users/jojo/Downloads/Epistemos')
legacy = re.compile(r'70B|AppColdStore|mmap|KV-Direct|NeuralImportance|ActiveAssembly|local cocktail|addressable neural substrate|Helios|ACS|UAS|unified active substrate|active cloud storage', re.I)
current = re.compile(r'ResidencyPatternBoost|PatternBoost|RESIDENCY_PATTERNBOOST|2026-06-01', re.I)
provenance_prefixes = [
    ('docs','_archive'), ('docs','_consolidated','50_research_corpus'),
    ('docs','fusion',"jordan's research"), ('docs','fusion','research'),
    ('docs','fusion','salvage'),
    ('docs','audits','codebase-verbatim-packets-2026-05-09'),
    ('docs','google-research-pack-2026-03-18'),
    ('docs','_archive','google_research_packs'),
]
counts = {'live': 0, 'provenance': 0}
for path in list((root / 'docs').rglob('*')) + [
    root / 'AGENTS.md',
    root / 'artifacts/lattice-coordinate-explainer/index.html',
]:
    if not path.is_file() or path.suffix.lower() not in {'.md', '.html'}:
        continue
    try:
        parts = path.relative_to(root).parts
        text = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    if legacy.search(text) and not current.search(text):
        bucket = 'provenance' if any(parts[:len(p)] == p for p in provenance_prefixes) else 'live'
        counts[bucket] += 1
print(counts)
PY
```

## Expected Verification State

The previous Codex pass observed:

- live-scope legacy drift filter: empty
- June-stack companion filter: empty
- broad classifier: `live = 0`, `provenance = 313`
- bridge preface count: `345`
- `git diff --check`: clean
- conflict-marker scan: clean
- new June-doc trailing-whitespace scan: clean

## What Not To Do

- Do not revert the bridge prefaces. They are the anti-drift mechanism.
- Do not rewrite imported research/provenance corpora wholesale. The 313
  residuals are intentionally quarantined as provenance.
- Do not promote old SSD-as-RAM, mmap-as-control-plane, 70B-hot-resident, or
  ACS-as-product-authority claims without the June 1 falsifier bundle.
- Do not kill the long-running build just to rerun it from scratch.
- Do not stage or commit unless the user explicitly asks.

## If Something Fails

If a drift check fails, fix the smallest affected doc by adding a local June 1
supersession/bridge note. Do not refactor the document body unless the document
is active canon and the old wording would directly mislead implementation.

If the build fails, capture the exact failure. Then classify it:

- source/build failure: likely unrelated to this docs-only pass unless the
  worktree already had source changes;
- docs/resource packaging failure: inspect whether the lattice HTML artifact is
  included in any build phase;
- timeout/hang: preserve logs and process evidence before rerunning.

After verification, append the build result and any rerun command to
`docs/audits/RESIDENCY_PATTERNBOOST_DRIFT_SWEEP_2026_06_01.md` or create a
small follow-up verification note next to this handoff.
