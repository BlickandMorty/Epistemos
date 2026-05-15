# New-Session Handoff — 2026-05-15
**For:** any new Claude / Codex / agent session continuing the Epistemos MAS-first work.
**Source-of-truth bundle:** read the 5 docs in §1 in order. They cover everything without nuance loss.

---

## 1. Read these 5 docs first (in order)

1. **`CLAUDE.md`** — top-of-repo project rules (the immutable constraints).
2. **`docs/MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md`** — Atlas of every primitive + V1 status matrix + App Store checklist (rank 2 of the authority chain).
3. **`docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`** — the 54-item Master Fusion plan (Phase A V1 ship gates + Phase B no-compromise + Phase C audit PARTIAL closure + Phase D XPC mastery + Phase E submission). **§8 Implementation Log is the live ledger of what's shipped — read this every session start to see state.**
4. **`docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`** — native agent architecture doctrine (post-V1 sequencing). §13.5 distills the latest second-wave research; §11 maps every commit shipped 2026-05-13/14/15 into the new architecture.
5. **`docs/VARIANT_LADDER_TOOL_REGISTRY_2026_05_15.md`** — every MAS-allowed tool's Variant Ladder tier profile (the B.1 retrofit contract).

---

## 2. Active branch

```bash
git checkout codex/research-snapshot-2026-05-08
```

All work since 2026-05-14 lives on this branch. Push target is the same.

---

## 3. Scope rules (the things that override default behavior)

1. **MAS-first.** Every change must be App-Store-safe. CI gates: `strings` + `nm -gU` on the MAS bundle must return ZERO matches for the Pro-only allowlist.
2. **No Helios architecture changes.** V6.1 / SCOPE-Rex / 5-plane formalism / scope_rex kernels / resonance daemon — don't touch. Toggles default OFF; substrate stays as doctrine target.
3. **Graph is protected.** No camera / renderer / layout / edges / physics / hologram changes WITHOUT scoped user approval. (Exception that already shipped: hide `metalView` on note route, keep `blurView` + `darkenLayer` visible so the note panel inherits the graph's blur ontology — commit `916e4f2e6`.)
4. **Vault is sensitive.** Vault fixes start with evidence + minimal rationale + rollback-safe plan. No reset/delete/casual migration.
5. **8-question PR discipline** per `MAS_FINAL_STRETCH_NO_NUANCE_LOST` §6 — apply to every PR.
6. **No silent deferrals.** Every deferred item gets a row in the Master Fusion Plan §8 Implementation Log AND/OR an audit row.

---

## 4. What shipped on 2026-05-14/15 (this session window)

22 commits between `8e371de91` (earlier session) and `ca12083b3` (latest). Highlights:

**Urgent user-reported bug fixes:**
- `f7f3c273a` — Tantivy LockBusy retry + read-only fallback (vault writer reliability)
- `930b86989` — Gemma 3/4 + Mistral excluded from `canActAsAgent` (they don't honor Hermes `<tool_call>` grammar)
- `41be78202` — `list_notes` auto-routes to `vault.search` on `query` param (fixes "Qwen listed only 7 irrelevant notes")
- `916e4f2e6` — Graph blur wallpaper preserved when navigating to note (regression fix on prior `8e371de91`)

**Master Fusion Plan Phase B shipped:**
- `9b7629752` — B.5: `epistemos.{soul,skill,episode,semantic}.v1` schemas
- `c2b7eaab5` — B.2: Variant Ladder tool registry (30 MAS tools profiled)
- `7cb1ed426` — B.3: `EscalationPolicy::Never` default on VariantLadder + 5 source-guard tests
- `c3a84f9e9` — B.4: `LocalTextModelID.reasoningTokenCap` per-model table + 6 source-guard tests

**Master Fusion Plan Phase C shipped/closed:**
- `06819a33a` — C.15: 3 orphan surfaces marked SCAFFOLD-ONLY (KaTeXSnippets, KIVIQuantization, variant_ladder)
- `8547c0aa9` — C.6: Vault Organizer V1 known-limitation tooltip (folder-name match)
- `504c2696d` — C.10: CodeFileService canonical first-fix-pass collapse
- `4cf6a691b` — C.3 (Brotli off main) + C.9 (AgentGrep off main) audit closures
- `868511ed9` — C.11: `/image` hide three-layer gating verified
- `ca12083b3` — C.4: Prose reparse debounce machinery on `ProseTextView2`
- `bb80399e0` — Audit sweep: RCA5-P2-002 + RCA-P0-004 + RCA11-P1-007 closed

**Design / doctrine:**
- `98ee8c9bc` — `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` (16 sections, ~600 lines)
- `0244d85b0` — Hermes 2.0 §13.5: distilled the second research wave (Phi-4 / Mistral Small / Nemotron lineup, 4-layer brain, Aider PageRank, RAG via Halo Shadow, new acceptance test #7 pinning the "Qwen 7 notes" bug)
- `eb5dd1e3e` — Codex next-session kickoff doc (earlier session)

All commits visible via:
```bash
git log --oneline codex/research-snapshot-2026-05-08 ^main | head -30
```

---

## 5. What's queued — pick from these next

### From the Master Fusion Plan Phase B (no-compromise quality)
- **B.1** — Variant Ladder dispatcher retrofit on `vault.search` (3-5 days; LARGEST B; depends on `VaultBackend` trait refactor — see Codex handoff doc for two approaches)
- **B.6** — Cognitive Weight Class W1 badge (UI work; 4-5 days)
- **B.7** — Knowledge Sieve + Gap Winner Rule (algorithm change in ClaimLedger)
- **B.8** — `clarify` tool UI card (GenUI schema + ClarifyGenUIView + ChatCoordinator wiring)
- **B.9** — NightBrain task bodies (10 bodies; 5-7 days)

### From Phase C (audit PARTIAL closure)
- **C.1** — Hidden-capture metadata existing-note migration (Settings → Privacy utility)
- **C.5** — NotesSidebar cache invalidation + epdoc manifest I/O off the sidebar rebuild path
- **C.7** — Scoped credential delivery → FFI-only delivery (no env-var across FFI)
- **C.8** — Verified-write coverage closure (5 named paths)
- **C.13** — DB fallback fault-injection runtime matrix
- **C.14** — Launch path deeper audit (Instruments trace)
- **C.16** / **C.17** — Operator smokes (mic temp-file + Current Access proof)
- **C.18-22** — UIX verifications (theme picker / .epdoc routing / sidebar performance)

### Phase A (V1 ship gates — user-action items)
Per Plan §A.1-A.6: MAS Release build verification + provider credential live smoke + MAS simple-rewrite smoke + graph framing decision + App Store Connect metadata + TestFlight soak.

### Phase D (XPC Mastery — gated on Phase A.1 green + paid Developer signed builds)
13 items D.1-D.13 per Plan §D.

---

## 6. Audit register state (top-of-tree truth)

`docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` is the master audit ledger. Status terms:
- **CONFIRMED** — issue verified but no fix yet
- **PATCHED** — code-level fix landed + tests green
- **PATCHED PARTIAL** — structural fix in place, manual smoke / deeper profiling pending
- **PATCHED PARTIAL → PATCHED** rows updated 2026-05-15: RCA-P0-004, RCA5-P2-002, RCA9-P0-001, RCA10-P1-006, RCA11-P1-007, RCA-P1-001, RCA4-P1-002, RCA2-P1-014, RCA12-P1-003, RCA-P2-010

Remaining `PATCHED PARTIAL` rows (~16) listed in Master Fusion Plan §2 cross-reference table.

---

## 7. The Hermes Agent Core 2.0 design (the agent architecture)

Two key sentences:

> **Architecture sentence:** *Epistemos agents are Hermes-governed native agents whose executor can be local, cloud, MCP, or Pro CLI, but whose memory, permissions, schemas, artifacts, and audit trail always belong to Epistemos.*

> **Routing sentence:** *Don't train one custom MoE — route between off-the-shelf specialists (Controller / Reasoning / Coding / Tiny / Chat) that already exist on HuggingFace + MLX-community.*

Sequencing: lands AFTER V1 MAS submission per Plan §B + §D acceptance bars (Phase A complete + Phase B core merged + Phase C core merged + Phase D Stage 1 merged + V1 submitted). 6-week implementation timeline in §12 of the design doc.

V2.x catalog additions doctrine-targeted: Phi-4 14B (reasoning), Phi-4-mini 3.8B (quick tasks), Nemotron Nano 4B (tiny QA), Qwen 3.5 7B (76/100 HumanEval coding primary).

---

## 8. Local development hygiene

```bash
# Always run at session start:
git status --short
git log --oneline -10

# Build:
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify

# Rust tests:
cargo test --manifest-path agent_core/Cargo.toml --lib

# Lint:
swiftlint

# Push:
git push origin codex/research-snapshot-2026-05-08
```

---

## 9. Single-sentence summary for the new-session prompt

> *"Continue the MAS-first work on `codex/research-snapshot-2026-05-08`. Read `docs/NEW_SESSION_HANDOFF_2026_05_15.md` for the full handoff, then pick the next item from §5. No Helios architecture changes. Graph is protected. 8-question PR discipline. Every shipped item gets an Implementation Log row in `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §8."*

That sentence is enough for a cold-start session to pick up exactly where this one left off without losing any nuance.

---

*— End of New-Session Handoff. 9 sections. Read in order, then pick the next item.*
