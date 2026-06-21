# RESEARCH FINALIZATION INDEX (2026-06-20)

Owner directive: *"finish all unfinished research (wikilinks especially) + the new directives, no truncated/redacted info,
all real; then a couple more cycles to finalize; save it all, make it deliberate in the plan; muddiness checks everywhere;
keep checking the loop."* This is the **master cross-reference + completeness/muddiness audit** for the active build
corpus, so nothing is lost, rots, or contradicts. 58 SS-* slices total on main; the ACTIVE build set + status is below.

## Completeness / no-truncation audit (owner's #1 concern) — PASS
All 2026-06-20 slices verified: **0 truncation/redaction markers** (`[truncated]`/`redacted`/`TBD`/`...`), each ends with
a proper Sources/cross-ref section, all web findings captured in full (Karpathy gist, nashsu/llm_wiki, penfieldlabs,
flowershow + forks, Obsidian modes, Tiptap/ProseMirror — all summarized completely, none cut off). Code-grounded slices
carry exact file:line evidence (SS-CR, SS-MV, SS-2S, SS-GC, SS-THX, SS-DD).

## Cross-corpus muddiness audit (SS-CLEAN applied to the research itself) — CLEAN
- **md-first is consistent** across `EPDOC_MD_V2`, `SS-EDGE`, `SS-2S` (md = source of truth; JSON/HTML = projections;
  Tiptap JSON-first default is INVERTED). No contradiction.
- **Pill directive:** the live rule is KEEP-the-pill (load-bearing for the curved window), page-relevant buttons, drop
  recent-chat. The "landing-only" text remaining in `SS-GC` is inside its explicitly-marked **SUPERSEDED** block (kept only
  for the file:line map). The loop already built the correct version. No live contradiction.
- **SS-TC deferral** is honest + correct (waits for on-device confirmation the theme hang is gone post-SS-THX cache, else
  it worsens the hang on an uncached path). Recorded, not lost.
- **Shared-seam invariant** (one md serializer + one wikilink/backlink + one asset pipeline across both editor surfaces)
  is asserted in SS-2S/SS-EDGE/SS-WL/SS-CLEAN — the concrete anti-cloning rule. No divergent cores planned.
- No orphan slices: every active slice is referenced by the ledger + the loop cron order.

## Active build set — dependency-ordered, with status (✅ done / 🔧 in-progress / ⏳ queued / ⏸ deferred)
1. ✅ SS-CR — chat "credentials rejected" repair (local never→cloud + Keychain race). *Live-send PENDING OWNER test.*
2. ✅ SS-GC — code-editor white bar + pill (keep mounted, page-relevant, drop recent-chat).
3. ✅ SS-THX — theme-switch hang: cached `AppCustomTheme.resolved` (4a) + HTMLWorkspace theme repaint (4b).
4. 🔧 SS-DD — remove eye/gear dropdown chevrons (`.menuIndicator(.hidden)`) + sweep borderlessButton icon-menus.
5. ⏳ SS-MV — model-vault repair: inject vault into LOCAL MLX path; user-added files; staleness refresh; System-tab audit.
6. ⏳ SS-TC — theme granular color slots (userBubbleText). **UN-DEFERRED** (owner no-risk-deferral rule): the SS-THX cache
   landed (`EpistemosTheme.swift:295` resolvedCache + invalidation :1506) so the uncached-hot-path concern is resolved →
   safe to code now; on-device visual confirm is a nice-to-have, not a blocker.
7. ⏳ SS-QC — quick-capture destination presets + TTS read-back + voice/model picker. (now also surface-choice via SS-2S.)
8. ⏳ SS-2S — two-surface fidelity: (A) Prose inserted-image persistence + md-image rendering, (B) honest caveat chip,
   (C) view-switch after EPDOC_MD_V2 Ph3, (D) capture surface picker. *Data-loss fixes (A) are independent + high-value.*
9. ⏳ SS-HW — HTML workspace honesty GateStatus → upgrade (DOM/preview/web-app builder).
10. ⏳ SS-HGT — home-graph tunnel perf + epdocs/html access through the tunnel.
11. ⏳ SS-ALIVE + SS-PERF2 — remaining fluid animations + perf wins.
12. ⏳ SS-SH — blank Settings SIDEBAR (panel `.formStyle` already landed; sidebar still blank — NOT a test-only "done").
13. ⏳ SS-LS / SS-AD / SS-XR — MLX-LoRA-Studio integration, adapter UX, external training repos (NON-Companion parts).
14. ⏳ SS-IL — inline note-AI: keep streaming + send animation + pixel-art scroll-down arrow + "cold box" AI separation
    + **Metal streaming overlay** (SwiftUI `.layerEffect`/`TimelineView`, reuse `Shaders/ThinkingGlow.metal`; "materialize→
    dissolve→editable" hand-off; overlay only, `allowsHitTesting(false)`, no idle GPU).
15. ⏳ SS-IR — instant-recall: VERIFIED wired+enabled but invisible w/o hits/vault-search-service → discoverable resting
    bubble + empty-state + health diagnostic, then bubble→NSPopover + add to Epdoc.
16. ⏳ SS-HW — HTML workspace: honesty GateStatus → upgrade; chat full-surface `regenerate` into website/explainer (HTML/JSON
    streaming, atomic/versioned/reversible); mini-chat primary driver / main-chat explicit-target-only.

### Coverage-completeness note (Owner-Request Coverage Sweep, SS-CLEAN)
Previously-unindexed slices now tracked so none rots: **SS-AL** (agent-loop robustness — DONE), **SS-Y** (masked-logit —
DONE), **SS-FM** (frontmatter/tags — folded into EPDOC_MD_V2 Phase 4), **SS-UMA** (instant-recall zero-copy — folded into
SS-IR), **SS-SH** (substrate-health — = item 12, blank sidebar still open). The sweep is now a recurring discipline (SS-CLEAN).

## MAJOR CYCLES (sequenced after the quick wins)
- **EPDOC md-first editor** — authority `EPDOC_MD_V2_BUILD_SEQUENCE_2026_06_20.md` (7 phases). Acceptance bar = **SS-EDGE**
  (take over Obsidian/Logseq/Notion/Roam: Notion-parity blocks w/ lossless md, block-refs+transclusion, Bases tables,
  vault import, fix P7.2 canvas). Fidelity contract = **SS-2S**. NEVER touch TK2/Prose internals beyond the agreed md-image
  upgrade.
- **SS-WL wikilink + auto-research** ("the money") — best-of-forks: Karpathy LLM-Wiki ingest+lint + nashsu/llm_wiki
  persistent crash-safe queue (overnight) + typed edges → existing `cognitive_dag` EdgeKinds. **In-use parser SEPARATE from
  the overnight runner**, sharing one AST + backlink index. `![[embed]]` unifies wikilink + image (SS-2S asset pipeline).
- **SS-BWB big-win backlog** — settings split, a11y/Dynamic-Type, ⌘K palette, vault export, unified search, etc. (last).

## Owner scope boundaries (loop NEVER touches) — restated
> **⚠️ SUPERSEDED 2026-06-20 for the MODEL-AGNOSTIC SUBSTRATE.** The owner authorized the loop to BUILD the model-agnostic
> substrate in-loop (authority: `SUBSTRATE_BUILD_SEQUENCE_2026_06_20.md` + the monitor SCOPE BOUNDARY + memory
> `project_substrate_build_authorized_2026_06_20.md`). LOOP **MAY** build: `agent_runtime_v2/*` System G, `scope_rex/answer_packet.rs`
> + Swift `AnswerPacket` mirror, `LocalAgent/RuntimeRouter*`, `uas/*` ACS-admission, `eml_rerank.rs`, `cognitive_dag/*` EXCEPT
> `companions.rs`, `provenance/*`, recall/Eidos, ModelVaults/KnowledgeFusion, graph-engine markdown, Halo/Shadow,
> AgentCommandCenter/ToolTierBridge. The lines below stay HARD OFF-LIMITS but ONLY for: (1) NEW MODEL brain-1 — SSM/Mamba-3,
> M0 interrupt, `signal_bus.rs`, lattice-WBO quant-safety, ternary/QAT, `research/*.rs` interrupt internals + Mamba2 shaders;
> (2) the 70B; (3) Companion→Osaurus clones. New model plugs in LATER behind `LocalModelHandoff` + `AnswerPacket.attention_mode`.
> So `answer_packet.rs` below = the dual-brain research file, NOT the model-agnostic `scope_rex` one.
- Dual-brain: research/*.rs, signal_bus.rs, answer_packet.rs, epistemos-research/*, active_assembly/*, M0/M1/bus/SSM/lattice.
- Companion→Osaurus: Models/Companion/*, State/Companion/*, CompanionCreationFlow + companion UI, ActOsaurus/*,
  Vendor/Osaurus/*, LocalModelServer.swift, AgentBlueprint.swift, cognitive_dag/companions.rs.
- ModelVaults/KnowledgeFusion is NOT Companion (loop MAY edit). SS-WL typed edges touch cognitive_dag edge kinds but NOT
  companions.rs.

## SS-CLEAN muddiness gate points (woven into the build)
- Loop cadence: every ~5 iters / end-of-cycle → pause → scan (dead-flag/orphan, duplicate/divergent impls, stale
  docs/ledger, green-without-witness, layering mud) → self-correct → re-verify → continue.
- Per-feature: one serializer / one wikilink seam / one asset pipeline; round-trip fidelity tests; user-facing end-to-end
  before "done"; honest caveats over silent disappearance.
- Last-auditor (monitor): every fire re-checks the above + scope boundaries + 0 lost owner requests.

**Status: research finalized.** Remaining work is implementation, sequenced above; the loop builds it with the SS-CLEAN
gate, and the monitor audits each unit user-facing end-to-end.

## Cross-reference — ALSO-ACTIVE build clusters from IMPLEMENTATION_SEQUENCE_2026_06_19 (added 2026-06-20 per nuance audit)
These are CAPTURED-FULL with BUILD intent but live in the older `IMPLEMENTATION_SEQUENCE_2026_06_19.md` (Tiers 1–2), not above.
They are PART OF THE ACTIVE QUEUE — do NOT treat as "finished research." The loop builds them alongside the list above:
- **SS-Z / SS-AA / SS-AB — per-model bespoke engineering framework** (each local AND cloud model gets a tuned profile;
  Tier-1, partly landed). Includes **SS-AB model-picker use-case descriptions** (`pickerUseCase`/`benefitsDescription`) +
  "advertise the best models" — owner: deliberate descriptions/profiles per model on the picker.
- **SS-Y — hyperdynamic determinism / "make local agents MORE useful than cloud" / playground thesis** (masked-logit part
  DONE; broader local>cloud + HyperdynamicLoop de-orphaning, IMPLEMENTATION_SEQUENCE items 10–12, still ACTIVE).
- **SS-H — skills/superpowers usable across local AND cloud engines** (keystone landed; keep reachable on chat surface).
- **SS-I — external skill ecosystems** (Anthropic/Vercel/Google skill packs accessible to all engines) — had NO active-build
  line in either sequence; it is hereby IN the active queue (chat-surface first, Act/Work only where non-clashing per owner).

## QUEUE vs FULL PLAN — and where Obscura / Act / Work live (added 2026-06-20 per owner question)
The "active build set" above is a **priority-ordered SUBSET of LOOP-BUILDABLE work, not a cap and not the whole plan.**
The FULL plan = the **194 open `[ ]` items in the ledger**. The Owner-Request Coverage Sweep + NUANCE-COMPLETENESS gate
re-walk ALL 194 every ~5 iters, so anything off the active list is NOT dropped — it resurfaces until built. The active
list just says what the loop builds NEXT, in order.

Two domains the active list does NOT lead with, but which ARE in the plan:
- **OBSCURA built-in browser — IN THE PLAN, loop-buildable, now queued.** Ledger items @1451 + @2101; prior research
  `B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md` (Tier-1 lifts LANDED) + HELIOS_V5 §B3 (W6-A..W6-I runtime, never built)
  + `agent_core/src/browser_engine/mod.rs` (467 lines — partial backend exists). BUILD the working in-app browser
  (WKWebView built-in + Rust backend); network/subprocess parts Pro/dev-gated per CLAUDE.md (no hidden sidecar on MAS).
  Tied to Work mode + HTML canvas P7.2 + browser-use. → added to the active queue (after the current SUBSTRATE/owner-facing
  batch); the WKWebView/non-subprocess slice is loop-safe, the network runtime is Pro-gated.
- **ACT (Osaurus) / WORK (Goose/OpenCode) — IN THE PLAN, but split by the scope boundary.** ~199 ledger mentions. The CLONE
  BACKENDS (Osaurus/ActOsaurus, Goose port, Companion→Osaurus refactor) are **OWNER / Cursor domain = HARD OFF-LIMITS for
  the loop** — the loop will NOT build those (by design, not a drop; see SCOPE BOUNDARY). The LOOP-BUILDABLE parts are: the
  per-model engineering + skills landing **chat-first** (SS-Z/Y/H/I, ENGINEERING-SCOPE-CHAT-FIRST constraint) and any Act/Work
  surface that is **non-clashing** (e.g. the Osaurus/Act right-side panel @3345 as Epistemos UI, IP-infusion seams that don't
  edit clone code). Those loop-buildable parts ride the coverage sweep; the clone backends wait for the owner's Cursor work.

So: nothing is lost. Queue = rolling priority subset; ledger = full 194; sweep = the safety net; clone backends = owner-domain
by the scope boundary (tracked, not loop-built). Cross-ref SS-FOLLOWON, SS-CLEAN coverage sweep, SCOPE BOUNDARY.

## ► WALK-ORDER AUTHORITY = MASTER_BUILD_QUEUE_2026_06_20.md (owner 2026-06-20: "queue = the entire plan, in order")
The loop now walks `MASTER_BUILD_QUEUE_2026_06_20.md` — ALL 194 open ledger items placed in dependency order (Tier 0→5)
+ a parallel OWNER-DOMAIN track + STANDING passes. Operating contract per item: DELIBERATE-FIRST (re-read the item's
research/slice + canonical source BEFORE building) → NO-RISK-DEFERRAL → self-verify + ship → interleave SS-CLEAN +
repair + nuclear-checker every ~5 items. The active list above is the near-term slice of that walk; the master queue is
the full ordered set so nothing is "just the next N." 100%-completion: the walk doesn't end until every tier is built.

## ► ENGINEERING DISCIPLINE = LOOP_HARDENED_ENGINEERING_CONTRACT_2026_06_20.md (owner 2026-06-20: "super-hardened, failproof; always read the plan")
Every iteration: read the plan FIRST (master queue → ledger verbatim → slice/CONNECTION_MAP → this index), then follow the
HARDENED CONTRACT (deliberate → safe-seam → savepoint → flag-gated/crash-safe/no-data-loss/no-regression build → exhaustive
self-verify → nuclear+repair passes → ship+record → self-heal). Deeper analysis ALWAYS cites the plan; never act from memory.
