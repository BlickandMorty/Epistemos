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
