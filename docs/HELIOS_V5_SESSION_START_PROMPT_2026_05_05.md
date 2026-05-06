# HELIOS V5 — Session-Start Prompt

> **Purpose:** paste this whole file (or its body below) as the first message of a new Claude / Codex / agent session to bring the new session up to speed on HELIOS V5 integration with the Epistemos Cognitive DAG substrate. Self-contained — reads cold, no prior session context required.

> **How to use:** copy from the `─── BEGIN PROMPT ───` line to `─── END PROMPT ───`. Paste as your first message in the new session. Optionally append your specific ask after it (e.g. *"Start with W1 AnswerPacket emission"* or *"Verify the v2 plan before any code lands"*).

---

─── BEGIN PROMPT ───

You are picking up HELIOS V5 integration with the Epistemos Cognitive DAG substrate, mid-arc. The architecture is locked; W1–W26 implementation slices are held for per-slice sign-off. Read this brief carefully before touching anything.

## 1. Lock state (architectural decisions: canon)

**HELIOS V5 Canon Lock v2 is sealed (architecturally) after namespace hardening 2026-05-05.**

- **Lock phrase:** *"Five lanes, three tiers, seven-plus-three-plus-seven, one Monday."*
- **Verified Floor:** commit `ac8c6d28` (pinned). Every commit since is `not-yet-shipped` until Codex independently verifies.
- **Three locked ballot answers:**
  - Q1=C — full lane split per Gate Register
  - Q2=optimal-combination — Tier-1 ULP-equivalent ON in MAS / Tier-2 model-file-changing FLAGGED OFF in MAS / Tier-3 runtime-mutating Vault-only never in MAS
  - Q3=C — aggregate B5 + per-slice WRV + per-slice rollback

**Theorem namespace (locked, do NOT collide):**
- **R0** Raw Research Archive (append-only at `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/`)
- **E1–E7** Epistemos Core Theorems (substrate-foundational; v2.0 hardened seven)
- **H1–H17** Helios Operational Claims (build/canon claims; H1 is WBO-7 Master Inequality)
- **PCF-1…PCF-10** Parameter Connectome Family (Goodfire VPD integration; CANDIDATE)
- **W1–W26** Work Slices (PR-ready wiring; held for per-slice sign-off)
- **L1–L5** Lanes (L1 MAS-add / L2 Pro-tier / L3 Research / L4 Reserved / L5 Vault)

## 2. Mandatory reading order (read EVERY doc; token cost irrelevant)

Before touching any code, read these in order:

**0a. `docs/fusion/helios v5 first.md`** — **PRIMARY SOURCE OF TRUTH** (754 lines). v5 DEFINITIVE CANON LOCK with `[VERIFIED-AGAINST-RESEARCH-DOCS]` / `[NEEDS-SOURCE-FILE-VERIFICATION]` / `[DRIFT-DETECTED]` tags per claim. Validates the integration brief's substrate-presence assertions against bundled research docs. **Read this BEFORE the integration plan.**

**0b. `docs/fusion/helios v5 updated.md`** — **PRIMARY SOURCE OF TRUTH** (625 lines). v5.2 TRULY FINAL with `[VERIFIED-WEB-Q1-2026]` tags + 2 citation drifts caught (Bodnar 2202.04579, Wang 2508.18893 withdrawn) + 10 PCF candidate theorems + the user audit verdict. **Read this BEFORE the integration plan.**

1. `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` — v2 plan (architecture decisions + W1–W26 wiring; downstream of 0a + 0b)
2. `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` — finalization (E/H/PCF mappings + 8 cognitive functions + 4 demos + SCOPE-Rex full surface + six-tier memory + anti-drift + benchmarks + no-Hermes rule §R; downstream of 0a + 0b)
2.5. `docs/PRESERVATION_FIRST_AUDIT_POLICY_2026_05_05.md` — discipline for "dead-code" audits (NEVER auto-delete based on "no callers found" alone; preserve scaffold)
3. `docs/SESSION_RETROSPECTIVE_2026_05_05.md` — full 2026-05-05 session retrospective (~89 commits)
4. `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` — WRV state pipeline + canon promotion protocol + no-date-gates rule (THE prospective discipline)
5. `docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md` — close-out doc with Codex drift register status table
6. `docs/CODEX_FULL_HANDOFF_2026_05_05.md` — every open item from the canon-hardening session
7. `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` — Codex's own audit (CD-001 through CD-009)
8. `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` — the doctrine (especially §3 distribution profiles, §4.0 UX posture, §4.1 Resonance Gate, §A.6 four memory layers, Annex A.15 + A.16, Annex C)
9. `docs/MMAP_UTILIZATION_AUDIT_2026_05_05.md` — mmap doctrine (companion to §2.2 invariant #1)
10. `docs/MIRROR_DISPATCH_COVERAGE_2026_05_05.md` — Cognitive DAG mirror coverage (CD-006)
11. `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` — MAS/Pro subprocess discipline (CD-007)
12. `docs/CD_008_PARTIAL_CLOSURE_2026_05_05.md` — verification status
13. **HELIOS v4 preservation package** at `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/`:
    - `README.md` (start here)
    - `EPISTEMOS_HELIOS_v4_MASTER_CANON_COMPACT.md`
    - `PRESERVED_RESEARCH_LEDGER.md`
    - `source_docs/EPISTEMOS_FINAL_SEVEN_THEOREMS_v2_HARDENED.md` (PRIMARY SOURCE for E1–E7)
    - `source_docs/scope_rex_omega.md` (SCOPE-Rex spine)
    - `source_docs/helios_v3.md` (memory/inference capstone with WBO-6, six-tier memory, KV-Direct gate)
14. Existing state:candidate briefs (per `feedback_doc_verbosity` memory: read these too):
    - `docs/A1_REDB_PERSISTENT_BACKEND_SCOPING_2026_05_05.md` (state: canon-partial; slices 1-4 LANDED)
    - `docs/STATIC_NOTE_VS_DYNAMIC_WEIGHT_DELIBERATION_2026_05_05.md` (state: canon, IMPLEMENTED)
    - `docs/B1_BIOMETRIC_TAMAGOTCHI_BRAINEXPORT_LIFT_TARGETS_2026_05_05.md`
    - `docs/B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md`
    - `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md`

## 3. Non-negotiable rules (these will fire as gates if violated)

### 3.1 NO HERMES ANYWHERE (USER 2026-05-05)

> *"no more hermes agent im not using hermes anymore at all so male sure that does not bleedinto what im doing."*

- No new code uses the `Hermes` prefix
- No new doctrine references Hermes as a forward target
- No new tests against `Hermes*` substrate
- The "local agent" path is canonical; the prefix is gone
- D.7 Schema (DOMINO + GBNF AnswerPacket) lands as `agent_core/src/scope_rex/answer_packet.rs`, NEVER as extension of `HermesPromptBuilder.swift`
- 18 existing `Epistemos/LocalAgent/Hermes*.swift` files are flagged for sign-off-gated rename to `LocalAgent*` per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §R — DO NOT touch them as part of W1–W26
- Auto-memory: `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/feedback_no_hermes_anywhere.md`

### 3.2 Canon promotion protocol (state machine)

```
research → candidate → canon → (superseded | historical | rejected)
```

- Doctrine-shaping work goes through `state: candidate` (a brief surveying substrate + recommending path + queuing sign-off) BEFORE landing as `state: canon`
- **DO NOT implement state:candidate items without explicit user/Codex sign-off**
- Currently held for sign-off: W1–W26 slices, the 18 Hermes-prefixed file rename, A1 redb slice 5, B1/B2/B3 phase-runtime work

### 3.3 WRV pipeline (state machine for "shipped")

```
research → implemented → wired → reachable → visible → verified → released
```

- A claim is "shipped" only when WRV-state = `released`
- "compiles + tests pass" = `verified`, NOT `released`
- Per-slice WRV proof (Wired/Reachable/Visible) + rollback procedure required before any slice promotes from `candidate` to `canon`

### 3.4 Three-tier MAS rule (App Store §2.5.2 compliance)

- **Tier 1** ON in MAS by default (mathematically equivalent ≤ 2 ULP drift; no model-file change; no behavior change)
- **Tier 2** bundled in MAS but defaults OFF (alternate model files BUNDLED in `.app`, not downloaded; behavior change requires user consent)
- **Tier 3** never ships in MAS (Pro-only / Research-only / Vault-only)
- W26 `tools/app-review-audit/` is the per-release compliance gate

### 3.5 No-date-gates rule

Only six valid gate types: capability / verification / distribution / entitlement / licensing / doctrine. Date strings as gates are non-canonical.

### 3.6 Run `git status` at session START

Lesson from 2026-05-05: caught Codex's V2.3 LSP work uncommitted after 73 commits. Always inspect working tree at session-start. If prior-session WIP looks ready to land, verify locally (re-run tests) and commit BEFORE starting new work.

Auto-memory: `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/feedback_session_start_git_status.md`

## 4. What's already in main (don't rebuild)

- **SCOPE-Rex Core (τ + π + λ)** SHIPPED at `agent_core/src/resonance/{tau,pi,lambda,mod}.rs` + `Epistemos/Engine/ResonanceService.swift`. Pro (+δ + ρ) and Research (+κ + η) are NEW.
- **Cognitive DAG Phase 8.A-8.G** complete at `agent_core/src/cognitive_dag/{node,edge,storage,merkle,companions,macaroons,migration,dispatch,resonance}.rs`. 10 NodeKind + 10 EdgeKind + capability binding (CD-005) + macaroon-derived per-mirror caps (A2 + A2-followup) + 4 dispatch mirrors (Skills/Procedural/Provenance/Companion).
- **4 of 5 Monday-Move primitives** — TypedArtifact ≈ `Epistemos/Models/MutationEnvelope.swift` + `agent_core/src/mutations/envelope.rs`; MutationEnvelope exists; ClaimFrame ≈ `agent_core/src/provenance/ledger.rs Claim`; EvidenceLedger ≈ `ClaimLedger`. **Only AnswerPacket + GBNF + DOMINO is genuinely new** (W1 slice).
- **A1 redb persistent backend** slices 1-4 LANDED (slice 5 dispatch wiring pending).
- **XPC trust spine** at `Epistemos/XPC/XPCTrust.swift` (Codex #5/#9 closed).
- **Static/Dynamic discriminator** IMPLEMENTED (`NodeKind::is_dynamic_rooted()`).
- **Six-tier memory** L0-L3 + L7 partial via `agent_core/src/storage/vault.rs` + tantivy + `epistemos-shadow` HNSW + ShmPool TTL eviction. L4-L5 (Pro) + L6 (Research) NEW.
- **CI gates B1-B4** wired in `.github/workflows/ci.yml`. B5 = HELIOS theorem-invariant smoke (NEW per W24 + W25).
- **3 of 5 v1-candidate items closed by Codex continuation:** Static/Dynamic IMPLEMENTED, A1 slices 1-4 LANDED, B1+B2+B3 Tier-1 doctrine lifts LANDED.

## 5. The 12-week roadmap (calendar advisory; thresholds are ground truth)

| Week | W-slices | Verification gate |
|---|---|---|
| 1–2 | W1 AnswerPacket emission, W2 ClaimKind 5-arm extension, W3 VRM UI labels | grammar conformance ≥ 99% on 1k-question dev set |
| 3 | W4 Residency Governor, W5 Semantic BTM V1.5 | unit tests + 50-conversation replay |
| 4 | W6 Active-Support Atlas indexing, W7 half-softmax post-not-pre, W8 KV-Direct gate | E1 ULP-equality on M2 Max; E4 half-softmax ≤ 2 ULP; E3 KV-Direct round-trip equality on 10³ traces |
| 5 | W9-W11 Settings toggles (Verified Research Mode, Connectome Browser, Experimental Metal Kernels) | all default OFF; W26 §2.5.2 audit passes |
| 6 | W12 T-MAC, W13 BitNet b1.58, W14 Sparse Ternary GEMM, W15 Modern Hopfield retrieval | each Tier-2 kernel passes its bundled-model smoke test |
| 7 | W23 forensic citation registry tool | CLI prints arXiv ID + DOI + mathlib4 path for any T<N> / E<N> / H<N> |
| 8 | W24 sorry-budget tracker (requires Lean repo creation) + W25 hardware falsifier rig | tracker fails CI if E1-E7 sorry > budget OR PCF sorry > 7; rig runs nightly on M2 Max |
| 9–10 | W17-W19 Lane 3 PCF (VPD extraction + ParamAnchor + Dual Connectome Trace) | PCF-1…PCF-10 falsifiers run; promote passing ones to EB |
| 11 | W16 Pro-tier T-MAC + Atlas joint path | Pro-build matrix on M2 Max passes |
| 12 | W26 §2.5.2 compliance audit + TestFlight pre-flight | Apple TestFlight build accepted, no §2.5.2 flag |
| Vault | W20 ModelSurgery + W21 Active Rank-One Runtime + W22 HCache/KVCrush (separate cadence) | Vault feature builds; no MAS dep |

**Slip protocol:** calendar weeks are advisory. Hold the deliverable thresholds as ground truth, not the calendar. Each week's deliverable promotes to `state: canon` independently.

## 6. Explicit don'ts (will burn time if violated)

- **Don't implement W-slices without per-slice sign-off** — the architecture is canon; the implementation is candidate.
- **Don't add Hermes anywhere** — see §3.1.
- **Don't put runtime VPD training, ModelSurgery, or Active Rank-One Runtime execution in MAS** — Vault-only per Tier-3.
- **Don't promote PCF-1…PCF-10 above CANDIDATE** until per-falsifier passes on M2 Max OR until parallel-Claude verifies the Goodfire May 5, 2026 page (already `[VERIFIED-WEB-2026-05-05]` per audit).
- **Don't claim "released" without Codex verification** — `verified` is the ceiling for autonomous work.
- **Don't add date-string gates** — only the six valid types per §3.5.
- **Don't commit dirty `benchmarks/results/*.json`** — CD-009 procedural rule (these are local re-runs, not intentional baseline updates).
- **Don't auto-promote `state: candidate` items** — see §3.2.
- **Don't skip the `git status` step at session start** — see §3.6.
- **Don't reach for `tower-lsp 0.20`** — upstream unmaintained per v5.2 verification; use `tower-lsp-community/tower-lsp-server` fork. Pre-W4 dep change.
- **Don't cite Bodnar et al. as `arXiv:2206.04386`** — correct ID is `arXiv:2202.04579` (NeurIPS 2022) per v5.2 audit Patch 3.
- **Don't cite Wang `arXiv:2508.18893` as a standing critique of Cybenko** — Wang withdrawn 2025-12-05; Cybenko 1989 stands per v5.2 audit Patch 4.

## 7. First action

After reading the docs in §2:

1. **Run `git status --short`** and inspect working tree (per §3.6 lesson)
2. **Verify local CI gates:**
   - `cd agent_core && cargo test --lib` (expect 879/879 pass)
   - `cd agent_core && cargo test --lib --features lsp-runtime lsp_runtime` (expect 17/17 pass)
   - `cd agent_core && cargo run --bin epistemos_doctrine_lint -- "$(cd .. && pwd)"` (expect ALL GATES PASS)
   - `cd agent_core && cargo run --example generate_sample_epbundle -- /tmp/cv.epbundle && cargo run --bin epistemos_trace -- verify-replay /tmp/cv.epbundle` (expect ok)
3. **Ask the user** which path they want to take:
   - **Path A:** Start with the 18 Hermes-prefixed file rename slice (clean slate before HELIOS V5 W1)?
   - **Path B:** Start with HELIOS V5 W1 (AnswerPacket emission) + run rename in parallel?
   - **Path C:** Start with HELIOS V5 W1 + accept Hermes-prefix legacy until after W26?
   - **Path D:** Something else?

Do NOT pick Path A/B/C autonomously — wait for explicit user sign-off per §3.2 canon promotion protocol.

## 8. Where to ask for help

- **Sign-off questions:** ask the user explicitly. Per the canon promotion protocol, doctrine-shaping work waits for sign-off.
- **Verification questions:** Codex is the final overseer. Per `docs/CODEX_VERIFICATION_HANDOFF_2026_05_05.md`: "act as if work has not been done. Verify everything. Sign off only what you can independently confirm."
- **Engineering best-method questions:** the user runs a parallel Claude session for engineering review. You can flag risks in your output for that review to pressure-test.
- **Anti-drift mechanisms:** see `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §N (10 mechanisms operationalize canon promotion protocol for build time).
- **Benchmarks + tests:** see `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §O. Recommendation: NO new in-app benchmarking surface; existing CI substrate is right shape.

## 9. The closing line you live by

*"Five lanes, three tiers, seven-plus-three-plus-seven, one Monday. Verified Floor `ac8c6d28`. Architecture decided. Build held for per-slice sign-off. No Hermes anywhere. Stay canonical and exceed."*

─── END PROMPT ───

---

## (Optional) shorter version if the above is too long

If you want a more compact version for clipboard ergonomics, here's the 1-paragraph form:

> You are picking up HELIOS V5 integration with the Epistemos Cognitive DAG substrate. Architecture is `state: canon` (locked 2026-05-05; ballot Q1=C / Q2=optimal-combination / Q3=C; Verified Floor `ac8c6d28`; lock phrase "Five lanes, three tiers, seven-plus-three-plus-seven, one Monday"). Implementation slices W1–W26 are `state: candidate` held for per-slice sign-off per `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`. Theorem namespace: R0 (raw archive) + E1–E7 (Epistemos Core) + H1–H17 (Helios Operational; H1 = WBO-7) + PCF-1…PCF-10 (Parameter Connectome Family). NON-NEGOTIABLE: NO HERMES anywhere — see `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §R; 18 existing `Epistemos/LocalAgent/Hermes*.swift` files flagged for sign-off-gated rename. PRESERVATION DISCIPLINE: NEVER auto-delete based on "no callers found" alone — see `docs/PRESERVATION_FIRST_AUDIT_POLICY_2026_05_05.md`. **PRIMARY SOURCE OF TRUTH:** `docs/fusion/helios v5 first.md` + `docs/fusion/helios v5 updated.md` — read THESE FIRST, then `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` + `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` + `docs/SESSION_RETROSPECTIVE_2026_05_05.md` + `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` + the v4 preservation package at `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/`. Run `git status --short` first. Verify local CI gates (cargo test --lib + lsp-runtime + doctrine-lint + verify-replay). Then ASK which path the user wants: rename now (Path A), parallel (Path B), after (Path C), or other (Path D). Do NOT pick autonomously.

---

## Cross-references (for the new session to verify the prompt against)

- This prompt itself: `docs/HELIOS_V5_SESSION_START_PROMPT_2026_05_05.md`
- **PRIMARY SOURCE OF TRUTH (v5 source canon, persisted in repo):**
  - `docs/fusion/helios v5 first.md` (754 lines, v5 DEFINITIVE CANON LOCK with VERIFIED-AGAINST-RESEARCH-DOCS tags)
  - `docs/fusion/helios v5 updated.md` (625 lines, v5.2 TRULY FINAL with VERIFIED-WEB-Q1-2026 tags + audit corrections)
- v2 plan: `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md`
- v2 finalize: `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md`
- Preservation policy: `docs/PRESERVATION_FIRST_AUDIT_POLICY_2026_05_05.md`
- Canon promotion protocol: `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`
- Session retrospective: `docs/SESSION_RETROSPECTIVE_2026_05_05.md`
- Codex full handoff: `docs/CODEX_FULL_HANDOFF_2026_05_05.md`
- Auto-memory directory: `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/`
- HELIOS v4 preservation package: `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/`
- Verified Floor commit: `ac8c6d28`
