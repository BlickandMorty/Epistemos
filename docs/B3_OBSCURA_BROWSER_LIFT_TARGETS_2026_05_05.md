---
state: candidate
candidate_promoted_on: 2026-05-05
codex_continuation_update: 2026-05-05 Tier-1 doctrine lifts landed; runtime phases remain candidate
audit_item: B3 (CANON_GAPS_AND_ADDENDA bonus block)
source_doc: /Users/jojo/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md (1190 lines, dated 2026-04-29)
companion_to: B1 + B2 lift-targets briefs
---

# B3 — Obscura Browser + Eidos Search — lift targets

> **State: candidate for runtime implementation.** Read-then-absorb pass for CANON_GAPS_AND_ADDENDA
> bonus block B3. The source addendum is 1190 lines covering Wave 6
> of the Quick Capture standalone canon — the Pro-tier in-process
> browser engine (Obscura), embedded JS execution (deno_core), and
> a new agent-native search engine (Eidos). This brief maps each
> section to current main, classifies what's net-new vs already-covered,
> and recommends specific lift targets. Codex continuation landed the
> Tier-1 doctrine lifts into `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`;
> W6 runtime work remains queued behind deliberation briefs.

## Source-doc summary (one paragraph per axis)

The B3 addendum is the **all-in-process commitment** carried to its
logical conclusion: every browser/JS/search subsystem becomes a
Cargo dependency in `agent_core`, never a subprocess. Three engines:

- **Obscura** — Rust browser engine with stealth posture. Library
  embed (4 crates: obscura-browser / obscura-net / obscura-dom /
  obscura-js). Drives the engine via library API, not the WebSocket-
  CDP server crate. Renders JavaScript-heavy SPAs, captures
  screenshots into a shared memory buffer, ~5ms frame-ready → SwiftUI
  redraw via UniFFI `Vec<u8>` ownership transfer.

- **deno_core** — V8 isolate as a Cargo dep for Pro user-script
  execution (Playwright/Puppeteer-style). Shares V8 with Obscura via
  `[patch.crates-io]` rusty_v8 dedup so the linker doesn't see
  duplicate symbols. NOT `deno_runtime` (we want only the V8 isolate
  primitive, not the full Deno runtime).

- **Eidos** — agent-native search engine. Local-first inversion of
  Exa.ai: bge-small (384-dim) HNSW index over vault drawers + curated
  external sources, Tantivy keyword fallback, Metal-cosine re-rank,
  optional llguidance-constrained LLM re-rank. **Closed-vocabulary
  citations** — every result is a typed reference to a vault drawer
  ID (sha256), so hallucinated citations are structurally impossible.

The thesis: subprocesses are "suboptimal everywhere, not just for
MAS" — three structural problems (helper binary versioning skew,
helper sandbox signing complexity, lifecycle race windows) all
disappear when the engine is a library embed.

## Map: each thread vs current main

| Thread | Already in main? | Where | Gap |
|---|---|---|---|
| Obscura browser engine (in-process via Cargo dep) | ❌ NOT in main | — | Zero substrate; entirely new |
| deno_core embedded V8 isolate | ❌ NOT in main | — | Zero substrate; entirely new |
| V8 dedup via `[patch.crates-io]` discipline | ❌ NOT in main | — | Pre-emptive contract for when Obscura + deno_core land |
| Eidos HNSW index over vault drawers | ❌ NOT in main | — | New retrieval surface; ShadowSearchService partially overlaps but uses different stack (usearch + tantivy + RRF) |
| Eidos closed-vocabulary citations | ✅ partial | citation grammar pattern in `agent_core/src/llguidance/` (if it exists) + `RRFFusionQuery.swift` returns drawer IDs | Closed-vocab citation enum binding is partial |
| Eidos Metal-cosine re-rank | ❌ NOT in main | — | New Metal kernel |
| Eidos llguidance-constrained re-rank | ✅ partial | grammar-bound dispatch exists (LocalToolGrammar) | LLM re-rank specifically as a search-result step is new |
| SwiftUI browser surface (Pro, cmd-shift-B) | ❌ NOT in main | — | New view |
| Stealth posture (anti-fingerprinting) | ❌ NOT in main | — | New crate-level config |
| Tools/skills catalog additions for browser | ❌ NOT in main | — | New tool surface |
| Resource lifecycle (zombies impossible per single-process) | ✅ doctrinally satisfied | `agent_core/src/shared_memory.rs::ShmPool` TTL eviction + memory pressure handling; doctrine §2.2 invariant #2 | The single-process commitment is already canonical; B3 just leverages it |
| Computer-use surface (Pro tier) | ✅ partial | `Epistemos/Omega/Inference/DeviceAgentService.swift`, `Vision/VisualVerifyLoop.swift`, `Vision/ScreenCaptureService.swift` | These cover macOS-app driving via AX + screen capture; B3's Obscura covers web driving in-process |
| Helper-binary anti-pattern doctrine | ✅ doctrinally satisfied | doctrine §2.2 invariant #2 | B3 §1.1 names three structural reasons; lifting them as a doctrine note pins the rationale |

## Anti-hype filter

Source is engineering-tight; only one line worth flagging:

- ✅ Lift the **three structural reasons subprocess fails** (versioning skew, signing complexity, lifecycle race) — these are real and lift cleanly into doctrine
- ❌ Do NOT lift the "Exa Series B $85M / Nebius $275M" valuations — facts at a moment in time, not doctrine
- ✅ Lift the **closed-vocabulary citations** discipline — this is a structurally-anti-hallucination pattern aligned with doctrine §6 forbidden ("hallucinated citations are structurally impossible")

## Recommended lift targets (priority-ordered, held for sign-off)

### Tier 1 — Lift to doctrine (landed by Codex continuation; no runtime code)

| Target | Where | Why |
|---|---|---|
| **Three reasons subprocess fails (versioning skew, signing complexity, lifecycle race)** | doctrine §2.2 invariant #2 addendum | Names the structural rationale for the existing invariant. Future deliberation briefs that propose helper binaries get a checklist to argue against. |
| **Library-embed pattern as canonical for engine integration** | doctrine §2.2 invariant #2 addendum | The Obscura/deno_core pattern (Cargo dep, library API, never the IPC server crate) generalizes — same rule applies to any future engine integration (audio, video, OCR, etc.). |
| **Closed-vocabulary citations as anti-hallucination structural guarantee** | doctrine §6 forbidden ("hallucinated citations are structurally impossible") + Annex A.13 (Knowledge Sieve / Gap Winner Rule) addendum | Pairs with existing grammar-bound dispatch doctrine. Names the closed-enum citation pattern as the canonical mechanism. |
| **V8 dedup discipline (`[patch.crates-io]` to prevent duplicate-symbol linker errors)** | new doctrine note in §9 Canonical Code Anchors | Forward-staging contract for when Obscura + deno_core land; without the dedup discipline declared up front, the integration will hit linker errors. |
| **Eidos thesis (local-first inversion of Exa)** | new doctrine note pairing with §4.3 (Halo) | Halo is the always-on contextual surface; Eidos is the explicit-search surface. Both project from canonical state (doctrine §2.2 #5, the C5 lift); both use the same vault HNSW + Tantivy substrate. |

### Tier 2 — Build-order graph additions (queue for substantive work)

| Build-order entry | Tier | Depends on |
|---|---|---|
| Phase W6-A — Obscura library embed (`obscura-browser/net/dom/js` Cargo deps) | Pro | V8 dedup contract |
| Phase W6-B — deno_core V8 isolate Cargo dep | Pro | W6-A V8 version match |
| Phase W6-C — UniFFI bridge for screenshot Vec<u8> ownership transfer | Pro | W6-A + Swift integration |
| Phase W6-D — SwiftUI browser surface (cmd-shift-B reveal) | Pro | W6-C |
| Phase W6-E — Eidos vault HNSW index (`instant_distance::HnswMap`) | Core (vault search) / Pro (web augmentation) | existing tantivy + bge-small + new Metal kernel |
| Phase W6-F — Eidos Metal-cosine re-rank kernel | Core | W6-E + existing MetalRuntimeManager |
| Phase W6-G — Eidos llguidance-constrained LLM re-rank | Core | W6-E + existing local model + LocalToolGrammar |
| Phase W6-H — Closed-vocabulary citation grammar binding | Core | W6-E + existing RRFFusionQuery (which already returns drawer IDs) |
| Phase W6-I — Tool/skill catalog additions (browse_url, eidos_search, ...) | Pro (browse_url) / Core (eidos_search) | W6-A through W6-H |

### Tier 3 — Already canonical (no lift needed)

| Already canonical | Note |
|---|---|
| Single-process commitment (no subprocess for inference) | Doctrine §2.2 invariant #2 + §6 forbidden line. B3 just leverages it. |
| Computer-use surface (macOS app driving) | Already in `Epistemos/Omega/` (Pro tier). B3 adds a complementary web-driving surface, doesn't replace this. |
| ShmPool memory pressure | Already in `agent_core/src/shared_memory.rs`. B3 §1.2 commits to in-process; ShmPool is the canonical memory governance. |

## What this slice does NOT do

- Does NOT add doctrine sections — proposes them; no merges.
- Does NOT add `obscura-*` Cargo deps — that's W6-A territory.
- Does NOT add `deno_core` Cargo dep — that's W6-B.
- Does NOT add `agent_core/src/eidos/` — that's W6-E through W6-H.
- Does NOT touch existing `Omega/Vision/*` computer-use surface — that's a complementary axis.

## Sign-off questions for the next deliberation

1. The Obscura crate is a public GitHub repo (h4ckf0r0day/obscura) — has it been audited for security posture beyond what the addendum claims? Same question for the V8 versioning story.
2. Eidos vs ShadowSearchService — do these merge into one search surface or stay as two complementary systems (ShadowSearchService = always-on Halo backing; Eidos = explicit query)?
3. The closed-vocabulary citation grammar binding lifts cleanly into doctrine but the actual implementation is non-trivial (it constrains the LLM's output via llguidance) — single PR or staged W6-G first?
4. Metal-cosine re-rank kernel — is this a new kernel under `Epistemos/Shaders/` or does it reuse the existing Mamba-2 / LandingWave kernel patterns?
5. The "stealth posture" feature flag (`obscura-browser features = ["stealth"]`) has fingerprinting-evasion implications. Does that conflict with the C5 doctrine ("visual layers project; they do not invent state") or is stealth strictly a network-layer behavior?

## Cross-refs

- Source: `/Users/jojo/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md`
- CANON_GAPS_AND_ADDENDA bonus B3 entry
- Doctrine §2.2 invariant #2 (single-binary in-process)
- Doctrine §4.3 (Freeform Pulse + Residency Rail — Halo pairing)
- Doctrine §6 (Hard Forbidden List — hallucinated citations)
- Doctrine Annex A.13 (Knowledge Sieve + Gap Winner Rule)
- Existing search: `Epistemos/Engine/HaloController.swift`, `Epistemos/Engine/ShadowSearchService.swift`, `Epistemos/Sync/RRFFusionQuery.swift`, `epistemos-shadow/` crate
- Existing computer-use (Pro tier): `Epistemos/Omega/Inference/DeviceAgentService.swift`, `Epistemos/Omega/Vision/{VisualVerifyLoop,ScreenCaptureService,Screen2AXFusion}.swift`
- Sister briefs: `docs/B1_BIOMETRIC_TAMAGOTCHI_BRAINEXPORT_LIFT_TARGETS_2026_05_05.md`, `docs/B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md`

## Bottom line

B3 is a 1190-line Wave-6 addendum proposing in-process browser
(Obscura) + embedded V8 (deno_core) + agent-native search (Eidos).
Zero of the runtime substrate is in main today; this remains net-new
feature surface. The five Tier-1 doctrine lifts (subprocess-failure
rationale, library-embed pattern, closed-vocab citations, V8 dedup
contract, Eidos local-first inversion thesis) now codify the contracts
before code lands. Nine Tier-2 build-order entries (Phases W6-A
through W6-I) queue the implementation behind sign-off.

Net for the B-bonus trio (B1 + B2 + B3): three lift-targets briefs
landed, ALL bonus blocks read-then-absorbed, Tier-1 doctrine now
landed, and runtime code still unimplemented — the addenda's content
is mapped into the canonical decision queue and any future
implementation has the decision tree pre-staged.
