---
state: candidate
candidate_promoted_on: 2026-05-05
audit_item: B2 (CANON_GAPS_AND_ADDENDA bonus block)
source_doc: /Users/jojo/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md (1014 lines, dated 2026-04-29)
companion_to: B1 (BIOMETRIC_TAMAGOTCHI_BRAINEXPORT lift-targets)
---

# B2 — Live Files + Unified Substrate — lift targets

> **State: candidate.** Read-then-absorb pass for CANON_GAPS_AND_ADDENDA
> bonus block B2. The source addendum is 1014 lines covering Wave 7
> of the Quick Capture standalone canon — Live Files architecture,
> auto-research loops, and the substrate-unification audit (the
> "negative app" mandate). This brief maps each section to current
> main, classifies what's net-new vs already-covered, and recommends
> specific lift targets — held for sign-off; no doctrine additions
> or code land in this slice.

## Source-doc summary (one paragraph per breakthrough)

The B2 addendum opens with **five load-bearing breakthroughs**:

1. **The document is the cell. The vault is the organism.** Each Live
   File maps to a biological cell (membrane = `is_live` toggle,
   nucleus = JSON/YAML schema, cytoplasm = Markdown body, metabolism
   = agent loop, receptors = FSEvents, apoptosis = state-machine
   Quarantine, mycelium = vault graph). The vault doesn't manage Live
   Files; it *is* Live Files.

2. **The determinism gradient (not a switch).** Cognitive Weight
   `0.0..=1.0` per file as a continuous slider on the spectrum from
   "schema-only deterministic" to "prose-only autonomous". Collapses
   the human-in-the-loop / human-on-the-loop debate into a per-file
   control surface.

3. **Auto-research loops on the user's own data.** Karpathy's
   AutoResearch pattern (March 2026) applied during NightBrain windows
   on the user's vault: run N variant experiments, measure against
   objective metrics (recall@5, defer-rate calibration, citation-
   grounding), keep wins, tombstone losses, surface morning summary.

4. **The Stateful Rotor — sub-5ms event-driven scheduling.** A Rust
   struct that holds metadata for every ActiveVector and re-evaluates
   them only when an FSEvents notification arrives. <1% additional
   CPU at idle on 50 ActiveVectors (vs 30-40× higher for polling).

5. **The unified substrate eliminates the subprocess class.** Audit
   finding: 6 places in the codebase still spawn subprocesses or load
   non-Rust/Swift runtimes. ZERO structural blockers to folding all
   of them into the Swift+Rust+Metal core.

## Map: each thread vs current main

| Thread | Already in main? | Where | Gap |
|---|---|---|---|
| Live File state machine (Static / ActiveVector / Metabolizing / Quarantined / Suspended) | ❌ NOT in main | — | New substrate; `agent_core/src/live_files/state.rs` doesn't exist |
| Cognitive Weight (0.0..=1.0 per file) | ❌ NOT in main | — | New retrieval-bias mechanism |
| Stateful Rotor (FSEvents-driven sub-5ms eval) | ❌ NOT in main | — | New Rust struct; FSEvents bridge exists at OS level but not wired into a rotor |
| Dual-mode JSON-header + Markdown-body file format | ❌ NOT in main | — | New file convention |
| Closed-grammar conditional logic | ❌ NOT in main | — | New 200-line Rust state machine |
| Cron-for-AI natural-language scheduling | ❌ NOT in main | — | New; would use `english-to-cron` + `tokio_cron_scheduler` (already canonical via uuid+chrono+tokio dep tree) |
| Vector Universe sophisticated scans (hierarchical + structural + pattern-detection) | ✅ partial | `agent_core/src/storage/vault.rs` (tantivy + bge-small embeddings); `Epistemos/Sync/SearchIndexService.swift` (FTS5) | Hierarchical embedding (file/section/block) + pattern-detection layer is new |
| Auto-research loops on user's vault | ✅ wired but partial | `Epistemos/KnowledgeFusion/Autoresearch/AutoresearchLoop.swift` exists | The Karpathy pattern is partially implemented; the "objective-metric only" discipline + tombstone semantics needs canonicalization |
| **Subprocess audit — MoLoRA Python** | ✅ exists as subprocess in main | `Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift:53` ("communicates via stdin/stdout JSON lines") | B2 §3.1 wants this ported to MLX-Swift adapter API — major doctrine §2.2 invariant #2 reinforcement |
| **Subprocess audit — QLoRA Python** | ✅ exists as subprocess in main | `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift:50` (actor) | B2 §3.2 wants this ported to MLX-Swift training API |
| **Subprocess audit — Hermes Python** | ✅ ALREADY REMOVED 2026-05-05 | (deleted in this branch) | B2 §3.3 is already closed; the Compile-Verify-Mint Tier-3 skills path is canonical |
| **Subprocess audit — OrphanSubprocessCleanup + PythonEnvironmentManager** | ✅ partially obsolete | `Epistemos/Bridge/OrphanSubprocessCleanup.swift` (still exists per B2 reference; needs grep verification) | When MoLoRA + QLoRA port, these delete themselves |
| CloudProviderAuthService URLSession | ✅ exists; sanctioned by B2 | `Epistemos/Cloud/CloudProviderAuthService.swift` | B2 §3.5 explicitly KEEPS this; only documentation update needed |
| Glowing UI metabolic-state Metal shader | ❌ NOT in main | — | New visual surface (analogous to LandingWave shader) |
| Eidos Plus auto-research deliberation engine | ❌ NOT in main | (referenced as Wave 8; partial in `AutoresearchLoop`) | New deliberation surface |

## Anti-hype filter

The source-doc itself is more measured than B1 (less marketing
content). Nothing flagged for explicit rejection. Two cautions to
honor when lifting:

- **"Negative app" framing** — language is evocative but "the
  substrate IS the product" is the canonical doctrine §2.2 invariant
  #2 already. Don't lift the marketing phrase; rely on the existing
  doctrine.
- **Karpathy "11% speedup transferred to a larger model"** — verified
  claim but specific numerical transfers are not lift candidates;
  lift the *pattern* (objective-metric variant testing with tombstone
  discipline), not the numbers.

## Recommended lift targets (priority-ordered, held for sign-off)

### Tier 1 — Lift to doctrine (no code)

| Target | Where | Why |
|---|---|---|
| **Cell-organism metaphor as design generator** | doctrine Annex (A.18 candidate) | The cell metaphor isn't decoration — it generates four concrete design rules (autonomy, message-passing, apoptosis as feature, millions-of-cells homeostasis). Lifting names the metaphor as canonical-substrate-shape; future Live Files implementation has the contract. |
| **Determinism gradient (Cognitive Weight) as canonical mechanism** | doctrine §4.0 (UX posture) addendum + §2.2 invariant #4 (tiered determinism) addendum | Pairs with the existing C4 "one composer, two modes" doctrine — same continuous-spectrum approach to user control. Lifting now positions Cognitive Weight as the canonical mechanism. |
| **Stateful Rotor pattern + sub-5ms tick-budget contract** | doctrine §7 build-order graph entry + §6 forbidden ("no polling on the Live Files surface") | Polling vs FSEvents is a load-bearing battery-life invariant on Apple Silicon. Lifting names the pattern + the budget so any future polling-shaped patch fails review. |
| **Closed-grammar conditional logic** | doctrine §6 forbidden (no `eval`/JS/Python in user-composed Live File logic) | This is the safe-by-construction guarantee. Lifting it as a forbidden line prevents drift if future Live Files implementation tempts the team to add a scripting backdoor. |
| **Subprocess audit closure (MoLoRA + QLoRA ports)** | doctrine §2.2 invariant #2 addendum | The Hermes subprocess was already removed 2026-05-05. The B2 audit identifies MoLoRA + QLoRA as the remaining structural debt. Lifting the audit + porting plan into doctrine pins the invariant-#2 enforcement target. |

### Tier 2 — Build-order graph additions (queue for substantive work)

| Build-order entry | Tier | Depends on |
|---|---|---|
| Phase W7-A — Live File state machine (Rust core, 5-state machine + FSEvents wire) | Core | (none) |
| Phase W7-B — Stateful Rotor + sub-5ms tick discipline | Core | W7-A |
| Phase W7-C — Cognitive Weight slider + retrieval-bias function | Core | W7-A + Vector Universe |
| Phase W7-D — Dual-mode JSON-header + Markdown-body file format + closed-grammar conditions | Core | W7-A |
| Phase W7-E — Cron-for-AI scheduling | Core | W7-A + tokio_cron_scheduler |
| Phase W7-F — Vector Universe hierarchical/structural/pattern scans | Core | existing tantivy + bge-small + new sidecar format |
| Phase W7-G — Glowing UI Metal shader for metabolic state | Core | W7-A + existing LandingWave shader pattern |
| **Phase W7-H — MoLoRA Python → MLX-Swift port (subprocess elimination)** | Pro | MLX-Swift adapter API |
| **Phase W7-I — QLoRA Python → MLX-Swift port (subprocess elimination)** | Pro | MLX-Swift training API |
| **Phase W7-J — OrphanSubprocessCleanup + PythonEnvironmentManager deletion** | (cleanup) | W7-H + W7-I |
| Phase W8 — Eidos Plus auto-research deliberation engine | Pro | W7-A + AutoresearchLoop |

### Tier 3 — Already canonical (no lift needed)

| Already canonical | Note |
|---|---|
| Auto-research loops (AutoresearchLoop.swift exists) | Refine the discipline (objective-metric only, tombstone losses) but the substrate is in main |
| CloudProviderAuthService URLSession | Sanctioned per B2 §3.5 — keep as-is, document as the only sanctioned external HTTP path |
| Hermes Python subprocess removal | ✅ ALREADY DONE 2026-05-05 in this branch |

## What this slice does NOT do

- Does NOT add doctrine sections — proposes them; no merges.
- Does NOT touch `MoLoRAInferenceService.swift` / `QLoRATrainer.swift` — those are the W7-H/I anchors, not deliverables.
- Does NOT add `agent_core/src/live_files/` — that's W7-A territory.
- Does NOT modify `AutoresearchLoop.swift` — discipline refinement queued for W8.

## Sign-off questions for the next deliberation

1. The MoLoRA + QLoRA subprocess elimination (W7-H + W7-I) is direct doctrine §2.2 invariant #2 reinforcement. Is this Pro-priority or should it land in Core given the doctrine alignment?
2. Should the Live Files file-format convention (JSON header + Markdown body) be standardized as a `.epdoc` extension or stay as `.md` with header sniffing?
3. Cognitive Weight slider — per-file UI in Settings or inline-in-editor floating control?
4. The Stateful Rotor's <5ms tick budget — assertion or warning? (B2's example uses `assert!`; for production we may want `tracing::warn!` instead so a slow tick under thermal throttling doesn't crash.)
5. Cron-for-AI natural-language parser: lift `english-to-cron` crate or roll our own bounded grammar (closed grammar discipline argues for the latter)?

## Cross-refs

- Source: `/Users/jojo/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md`
- CANON_GAPS_AND_ADDENDA bonus B2 entry
- Doctrine §2.2 invariant #2 (single-binary in-process substrate)
- Doctrine §6 (Hard Forbidden List)
- Doctrine §7 (Build-Order Dependency Graph)
- Existing Pro substrate: `Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift`, `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift`, `Epistemos/KnowledgeFusion/Autoresearch/AutoresearchLoop.swift`
- 2026-05-05 Hermes removal (closes B2 §3.3 already)
- Sister briefs: `docs/B1_BIOMETRIC_TAMAGOTCHI_BRAINEXPORT_LIFT_TARGETS_2026_05_05.md`, future `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_*.md`

## Bottom line

B2 is a 1014-line Wave-7 substrate-unification addendum. Three of
its load-bearing observations (cell-organism metaphor, determinism
gradient, Stateful Rotor) are doctrine-ready Tier-1 lifts. Three
others (Live File state machine, Cognitive Weight, dual-mode format)
are Tier-2 build-order entries (Phases W7-A through W7-G). The
**subprocess audit (W7-H + W7-I)** is the most directly canon-aligned
work — porting MoLoRA + QLoRA from Python subprocess to MLX-Swift
in-process closes the last structural debt against doctrine §2.2
invariant #2 (Hermes was the third subprocess; already removed
2026-05-05). Held for sign-off.
