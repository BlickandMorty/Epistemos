# Codex Deep Investigation + Recursive Hardening Prompt — Epistemos 2026-05-16

**For**: Codex CLI, given multi-day autonomy at `/Users/jojo/Downloads/Epistemos`
**Mission**: Truly devour every layer of this app — Helios V5/V6.1/V6.2, SCOPE-Rex, Omera/Omega, ACS, UAS, every research theorem, every "no compromise" doc — then recursively investigate → harden → validate → surface user-facing, in alternating phases. **Never delete or remove features.** Only harden, validate, document, and add.

---

## §0. Immutable rules (read every iter)

1. **NEVER delete a feature.** If you find something incomplete, harden it. If you find a half-built thing, finish it cleanly. If you find two versions of the same thing, audit which is better and consolidate WITHOUT losing the loser's good ideas (extract them into the winner first).
2. **NEVER delete tests.** If a test is failing, fix the code OR convert the test to `#[ignore]` with a TODO marker — never delete.
3. **NEVER delete docs.** Audit doctrine docs (`docs/fusion/*` + `docs/audits/*` + `docs/*.md`) — if drifted, update the row in place + log the transition. Mark superseded sections as "SUPERSEDED" with cross-link to replacement, don't remove.
4. **§5.0 reconciliation gate is non-negotiable.** BEFORE writing any doctrine row, audit row, or claim, verify substrate state on disk (`rg`/`grep` + `wc -l` + `git log --follow`). Doctrine that contradicts code = code wins; fix the doctrine.
5. **Additive only.** Every commit is `feat(...)` or `fix(...)` or `harden(...)` or `audit(...)` — never `revert(...)` or `delete(...)`. If reverting is needed, ask the user first.
6. **Cargo baseline must hold or grow.** `cargo test --manifest-path agent_core/Cargo.toml --lib` must pass at >= 1671 (current main baseline at session start). Run it every iter. If it drops, your last change broke something — revert that commit + investigate.
7. **Build must hold.** `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` must succeed. Run it after every Rust + Swift change.
8. **Commit every substantive change.** HEREDOC body + Co-Authored-By trailer. Push every 5-10 commits.
9. **No production code touched on doc-only iters.** No doc rewrites on code-only iters. Keep slices clean and reviewable.
10. **Pin every claim to a primary source** (paper / chip datasheet / Apple docs / canonical emulator). Cite verbatim. Never paraphrase a research claim without re-reading.

---

## §1. Canonical reading order (read on FIRST iter, re-read every 10 iters)

### Tier 1 — top-floor doctrine (read fully):

1. `CLAUDE.md` — project rules, NON-NEGOTIABLE CONSTRAINTS, FILE MAP
2. `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` — Atlas of 43 §3.x rows + Wave A-J §6 tables
3. `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` — §0 immutable rules + §10 Compromises + §8 Implementation Log (302 rows)
4. `docs/CODEX_HANDOFF_2026_05_16.md` — session handoff (state of app right now)
5. `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` — original final doctrine
6. `docs/fusion/EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` — what got rethought
7. `docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md` — what was recovered
8. `docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` — V2 roadmap

### Tier 2 — Helios lineage (read fully, all versions):

9. `docs/fusion/helios v5 first.md` (754 LOC, V5 lock with VERIFIED-AGAINST-RESEARCH-DOCS tags)
10. `docs/fusion/helios v5 updated.md` (625 LOC, V5.2 final with VERIFIED-WEB-Q1-2026 tags)
11. `docs/fusion/helios v6.2.md` (V6.2 spec including S1-S8 falsifier sequence)
12. `docs/HELIOS_V5_DOC_0_INDEX.md` + `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` (Foundational Seven E1-E7)
13. `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md`
14. `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` (V6.1 KV-Direct gate + ACS + sparse-active-assembly)
15. `docs/audits/HELIOS_SUBSTRATE_INVENTORY_2026_05_12.md`
16. `docs/audits/V6_2_PER_BUBBLE_BINDING_RESEARCH_2026_05_12.md`

### Tier 3 — Cognitive substrate doctrine:

17. `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` (Phases 1-7)
18. `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` (Phase 8.A-G)
19. `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` (T0 sub-track 4)
20. `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` (§4.1 tier discipline)
21. `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` (W1-W4 weight badges)
22. `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` (opaque handles + versioned envelopes)
23. `docs/fusion/LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` (Wave 7 substrate)
24. `docs/fusion/LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04.md` (research order discipline)
25. `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` (MAS-shippable scope)
26. `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` (5-service XPC decomposition)
27. `docs/fusion/PROVENANCE_CONSOLE_DOCTRINE_2026_05_04.md`
28. `docs/fusion/FIVE_LAWS_AND_PHASE_I_2026_05_04.md` (the Five Laws)

### Tier 4 — SCOPE-Rex / Omera / Omega:

29. `docs/fusion/jordan's research/scope rex omega.md`
30. `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_MASTER_ARCHITECTURE.md` (CMS-X v3 + Layer-3 Compression Governance + SCOPE-Rex Core Components table)
31. `docs/fusion/EPISTEMOS_FUSION_HANDOFF_2026_05_03.md` (fusion handoff state)
32. `docs/fusion/RECOVERY_LOOP_FINDINGS_2026_05_04.md`

### Tier 5 — Three integration artifacts (synthesis layer):

33. `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` — UAS-ACS no-loss register
34. `docs/fusion/V1_SHIP_LEDGER_2026_05_16.md` — v1/v1.1/v2/never classification (~85 feature rows)
35. `docs/fusion/DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md` — concrete user scenario

### Tier 6 — Gap audits + audit-of-audit register:

36. `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md` (PASS-1)
37. `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` (PASS-2 + §9 register with **55 audit-of-audit cycles** + 7 trust-but-verify lessons)
38. `docs/CANONICAL_AUDIT_LOG.md`
39. `docs/CRITIQUE_LOG.md`

### Tier 7 — V6.1 acceptance proofs + per-feature decision research:

40. `docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md` (B's wave-by-wave evidence)
41. `docs/TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md` (C's merge-readiness verdict)
42. `docs/audits/user-decisions/*.md` — 13 user-decision research docs

### Tier 8 — Code substrate (read source files directly):

43. `agent_core/src/research/` — 30+ modules (ACS, ternary, sherry_lattice, continual_learning, cognition_observatory, eml, paper_registry, ane_direct, koopman, mamba3, rwkv7, etc.)
44. `agent_core/src/cognitive_dag/` — 10 NodeKind + 10 EdgeKind + macaroons (930 LOC) + companions + mirrors
45. `agent_core/src/scope_rex/` — MutationEnvelope + WitnessedState + ClaimGraph + RunEventLog
46. `agent_core/src/storage/vault.rs` — vault retrieval (includes F-VaultRecall-50 Fix B at lines 495-548)
47. `agent_core/src/agent_loop.rs` — main agent loop
48. `agent_core/src/tools/` — 50+ tools
49. `epistemos-research/src/` — Lane 3 research-only types (acs.rs, five_planes.rs, etc.)
50. `Epistemos/Engine/AmbientFrequencyAudioGenerator.swift` + `AmbientFrequencyLivePlayer.swift` (recent feature work)

### Tier 9 — External canon (QuickCapture, outside the repo):

51. `~/Documents/Epistemos-QuickCapture/PLAN.md` (245 KB)
52. `~/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md` (53 KB)
53. `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` (44 KB)
54. `~/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` (68 KB)
55. `~/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md` (63 KB)

---

## §2. The phase loop (alternating investigation ↔ fixing)

Run this pattern indefinitely until told to stop. Each "phase" is several iters; each iter takes ~2-5 min depending on scope. Use `/loop` cadence if you have it; otherwise just iterate.

### Phase A — INVESTIGATION (read-only, doc-only)

Goal: build truthful map of substrate state.

**A.1 First-pass read**: Tier 1-3 doctrine, read each cover-to-cover. No notes yet — just absorb.

**A.2 Code-side inventory**: walk `agent_core/src/research/` + `agent_core/src/cognitive_dag/` + `agent_core/src/scope_rex/` + `epistemos-research/src/`. For each module: LOC + `pub` API surface + cited papers/sources + test count.

**A.3 Drift detection (§5.0 protocol)**:
- For each doctrine row claiming a substrate state ("ABSENT" / "PARTIAL" / "SHIPPED" / "NOT-STARTED"), independently RE-RUN the grep. Don't trust the doctrine's grep claim — execute it yourself.
- Document drift findings in `docs/DRIFT_REPORT_<DATE>.md` with verbatim grep output.

**A.4 Theorem audit**: for each Foundational Seven theorem (E1-E7) in `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md`, verify:
   - Lean proof status in `epistemos-lean/` (35 sorries / ≤149 budget per project memory)
   - Code-side substantiation in `agent_core/src/research/` or `epistemos-research/src/`
   - Acceptance test (if any) in `agent_core/tests/`

**A.5 Backlog reconciliation**: walk MASTER_FUSION §3.x (43 rows). For each row, confirm the cited source-doc exists on disk + the cited code-anchor exists. Log mismatches as drift entries.

**A.6 Research-coverage audit**: re-read PASS-1 + PASS-2 + the 55 audit-of-audit cycles. Look for blind spots: research topics referenced in `docs/fusion/jordan's research/*` that aren't in any §3.x doctrine row.

**A.7 Agent-repo + PKM study**: for the agent repos and PKM apps the user has cloned (look in `~/code/` or wherever the user keeps clones — likely candidates: `Hermes-Function-Calling`, `hermes-agent-self-evolution`, `atropos`, `claude-code-cli`, `obsidian`, `logseq`, `tana`, `reflect`, `roam`, etc.):
  - For each: identify the 3-5 most innovative features / patterns
  - Map each to existing Epistemos doctrine — does Epistemos already have this concept? If yes, harden it. If no, add a §3.X candidate row in MASTER_FUSION (forward-staging only; no code yet).
  - **DO NOT clone new repos without user permission.** Only study clones already on disk.

**Phase A exit**: produce `docs/INVESTIGATION_REPORT_<DATE>.md` with: drift findings · theorem status table · backlog reconciliation · agent-repo lessons. Commit as `audit(investigation-pass-N): <date>` and pause for user review before Phase B.

### Phase B — FIXING / HARDENING (code-allowed, additive only)

Goal: address findings from Phase A. **NEVER DELETE** anything.

**B.1 Drift fixes**: for each drift entry from A.3, fix the LESSER source. If code says X and doctrine says Y, and code wins, update doctrine. If both are valid (e.g., different abstractions), add a disambiguation row.

**B.2 Doctrine reconciliation**: every doctrine row should have a corresponding code reality OR an explicit `state: NOT-STARTED` marker. No silent half-truths.

**B.3 Theorem proofs**: for each E1-E7 theorem with a Lean sorry, see if the sorry is closeable via a simple lemma. If yes, close it. If no, document the open obligation more precisely in the theorem-canon doc.

**B.4 Substrate maturation**: for each `agent_core/src/research/` module:
   - Add property tests that pin the canonical invariants (e.g., `kuramoto_critical_coupling_holds` · `ternary_pack_zero_alloc` · `sherry_codebook_orthonormality`).
   - Add diagnostic surfaces (per the B's pattern in Wave I A2UI catalog).
   - Wire dormant modules into actual call paths if the doctrine says they should be wired but currently aren't (e.g., `CircuitBreaker` is shipped but only used by `heal/` — extend to `variant_ladder` per B2-M9 doctrine).

**B.5 User-facing surfacing**: the user said "lots of things may be hidden — make it all useful to users as well." For each substrate piece, find or create the user-visible surface:
   - Settings panes
   - Diagnostic health rows
   - Cognitive Weight badge surfaces (per `COGNITIVE_WEIGHT_CLASS_DOCTRINE`)
   - Provenance Console rows
   - GenUI dispatcher entries

   Examples to surface (not exhaustive):
   - The 55 audit-of-audit cycles → Provenance Console "Audit register" tab
   - The 13 user-decision queue → a "Decisions awaiting you" inbox in Settings
   - The ACS Kuramoto coupling → visualizer in Diagnostics
   - The SAE cognition observatory → optional "explain why this answer" surface
   - The Ternary kernel diagnostics → MLX power-user pane
   - Ambient Frequencies feature: cross-link with other audio + meditation surfaces
   - User-decision research docs: surface as "you have 13 decisions pending" in app

**B.6 Computer-use validation**: for any user-facing surface that lands, **use computer-use to actually open the app + click through it**. Verify the UI renders as expected. Take screenshots. Compare to design intent. If broken, fix the SwiftUI view (without removing features).

**B.7 Test growth**: every Phase B iter should grow `cargo test --lib` count. Target +10-50 tests per iter. Coverage focus: invariants, not implementation details.

**B.8 Acceptance-bar pinning**: for each Wave (B.1-B.7 · C · D · F · G · I · J), the V6.1 acceptance proofs (`docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md`) lists claimed bars. Where the asserting test doesn't exist, write it. Where the cargo invocation doesn't return clean, fix the test or the code.

**Phase B exit**: commit each fix with HEREDOC + Co-Authored-By trailer. After 5-10 commits, run full `cargo test --lib` + xcodebuild + push origin main. Pause for user review before next Phase A.

### Phase C — RECURSIVE AUDIT (audit-of-audit pattern)

Every 10 fixing-phase iters, run one audit-of-audit cycle on the window. Pattern:
1. List the 10 commits + their claimed scope.
2. Re-grep each citation independently (don't trust commit messages).
3. Run cargo test + xcodebuild on each commit if possible (use `git stash` + `git checkout <commit>` + test + return).
4. Find any drift introduced + log to PASS-2 §9 register.
5. Add 1-2 new trust-but-verify lessons.
6. Push.

### Phase D — UNIFICATION / SYNTHESIS (post-recursive)

After every 3 full investigation→fixing cycles, run a synthesis pass:
1. Update the 3 integration artifacts (`UNIFIED_ACTIVE_SUBSTRATE_CANON` · `V1_SHIP_LEDGER` · `DAY_IN_THE_LIFE_POWER_USER`) with new substrate findings.
2. Add a new "What changed since 2026-05-16" section to each.
3. Update MASTER_FUSION §3.x rows with new state columns.

### Phase E — USER-DECISION ESCALATION

When you reach a wall that requires user input (one of the 13 open user-decisions, or a new design question), DO NOT GUESS. Add a row to `docs/audits/user-decisions/` with options + tradeoffs + recommendation + decision-blocker reason. Surface the issue clearly in your next commit message. **Never silently pick an answer.**

---

## §3. The agent-repo + PKM-app study mission

The user wrote: *"my app should be studying from all the agent repos i cooned and wanted cooned. all pkms i want my app to consume all of them. to devourer all of their moats and extend profoundly robust engineering."*

### Likely repos to study (look for them on disk, don't clone new ones):

**Agent repos** (look in `~/code/`, `~/repos/`, `~/Documents/`, `~/Desktop/`):
- `Hermes-Function-Calling` (NousResearch) — prompt format for tool calls
- `hermes-agent-self-evolution` (NousResearch) — auto-skill patterns
- `atropos` (NousResearch) — RL trajectory training
- `claude-agent-sdk` / `claude-code` (Anthropic) — Claude Code architecture
- `openai-agents-sdk` (OpenAI) — Agents SDK
- `goose` (Block, Inc.) — Rust agent runtime (referenced in project memory as a model)
- `aider` (paul-gauthier) — code editing agent
- `cursor-core` (private?) — Cursor IDE agent surface
- `swe-agent` (princeton-nlp) — SWE-Bench solver pattern

**PKM apps** (look on disk + read their docs):
- `obsidian` (the open source plugins ecosystem if cloned)
- `logseq` (open source)
- `tana` (proprietary; only inspectable via public marketing)
- `reflect` (proprietary)
- `roam-research` (proprietary)
- `mem.ai` (proprietary)
- `notion` (proprietary)
- `craft` (proprietary)
- `bear` (proprietary)
- `dendron` (open source)

### What to extract from each:

For each repo found on disk:
1. **README + ARCHITECTURE.md + docs/** — read fully
2. **Top 5 most-innovative features** — what's their moat?
3. **3 deepest engineering decisions** — what's the principled choice they made?
4. **Anti-patterns to avoid** — what mistakes did they make that we should not?
5. **1 thing worth devouring** — what concept/pattern/test should Epistemos absorb?

Document findings in `docs/AGENT_REPO_STUDY_<DATE>.md` per repo. Map each insight back to a MASTER_FUSION §3.x row OR add a new candidate row.

### What "devouring their moats" means:

NOT "copy their code" (license + IP). It means:
- Understand what makes them durable (network effects? data graph? UX? speed?)
- Identify which moats Epistemos could match or surpass via its substrate
- Implement Epistemos-native versions of the underlying capability
- Surface them user-facing so users can SEE Epistemos has these capabilities

Example: Obsidian's moat = plugins + backlinks. Epistemos already has cognitive DAG + macaroon-gated tool registry. Surface "Plugins" as a user-facing tab that shows the available tools + macaroons + lets the user enable/disable each.

---

## §4. The "research-thesis-worthy" mission

The user wrote: *"truly research thesis worthy ontology and tech paradigm shift."*

This is the long-horizon ambition. Epistemos already has:
- Six-tier memory hierarchy (`§3.2`)
- Cognitive Kernel + DAG (`§3.10` + `§3.11`)
- ACS Anchored Cognitive Substrate (`§3.8` — Kuramoto + autopoiesis + VSM governance)
- Helios V6.1 5-plane formalism (state · episodic · assembly · controller · verification)
- SCOPE-Rex (Sparse · Claim · Ontology · Proof · Execution + State Witness)
- KV-Direct gate (memory-arch floor)
- F-ULP-Oracle (arithmetic floor)
- F-70B-Local-Cocktail (capability ceiling)
- Sherry/Leech lattice VQ
- Ternary kernel
- 55 audit-of-audit cycles with 7 trust-but-verify lessons
- 43 doctrine §3.x rows pinning every named concept

These are not features — they're a coherent **research-grade architecture**. Your job is to:
1. **Cite each component to a primary source** (Wikipedia / arXiv / Apple docs / canonical emulator). No floating claims.
2. **Run the experiments** described in the doctrine where possible. Don't just write doctrine.
3. **Surface the architecture in the app** as a "Research" or "Architecture" tab in Settings. Make it inspectable to power users.
4. **Add the open theorems** as bounties in a `OPEN_THEOREMS.md` doc — anyone (you, the user, future contributors) can pick one up.
5. **Connect dots between siblings** that the doctrine separates. The audit-of-audit pattern can be applied to drift detection in the SAE cognition observatory; the macaroon lattice can govern access to ACS-emitting agents; Kuramoto coupling can pace NightBrain admission windows.

The paradigm shift: **the app is research-grade infrastructure with a user-facing surface, not the other way around.** Most PKM apps are user-facing with thin infra. Epistemos inverts that. Communicate this in user docs + Settings.

---

## §5. Computer-use validation protocol

For every user-facing surface that lands (new Settings pane, new diagnostic row, new visualizer), Codex MUST:

1. Run `request_access` for the Epistemos app via the computer-use MCP.
2. Build the app: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
3. Launch the app: `open /path/to/built/Epistemos.app`
4. Use `screenshot` + `left_click` + `type` to actually navigate to the new surface.
5. Take a screenshot of the working surface.
6. Save the screenshot to `docs/verification/screenshots/<feature>-<date>.png` and reference it in the commit message.
7. If broken: capture the broken state, fix the SwiftUI view, retry.

This is the "test it yourself" discipline. Doctrine claims must be visually verifiable.

---

## §6. Anti-rules (things to NEVER do without explicit user permission)

1. **NEVER `git push --force`** to any branch.
2. **NEVER `git reset --hard`** without first making a backup branch.
3. **NEVER delete a worktree** without first verifying no uncommitted work.
4. **NEVER modify `main`** directly — always work in `codex/research-snapshot-2026-05-08` or a new feature branch.
5. **NEVER add a new top-level Rust crate** without lockstep updating MASTER_FUSION §3.X + adding a FILE MAP entry + a CI test stub (per B2-M15 PR-discipline rule).
6. **NEVER change `Cargo.toml`/`Package.swift`** without updating `docs/legal/licenses.md` in the same commit.
7. **NEVER touch `Epistemos.xcodeproj/`** directly — use `xcodegen` per CLAUDE.md.
8. **NEVER call cloud APIs (Anthropic/OpenAI/Perplexity) without explicit user permission** + Sovereign Gate macaroon issuance per `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01 §6`.
9. **NEVER bypass the Sovereign Gate** for any destructive action class (vault deletion, settings reset, API key change, etc.).
10. **NEVER make assumptions about user identity, hardware, or preferences** — read `user_profile.md` + `user_hardware.md` + `MEMORY.md` first.

---

## §7. Iteration cadence + commit discipline

- **Every iter**: state check (`git status --short && git log --oneline -5 && cargo test --lib`).
- **Every 3-5 iters**: push to remote.
- **Every 10 iters**: run audit-of-audit cycle.
- **Every 20 iters**: run synthesis pass (update integration artifacts).
- **Every 50 iters**: write a session summary doc + commit it.

Commit message format:
```
<type>(<scope>): <one-line summary>

<paragraph explaining what + why>

<details: files touched, tests added, source citations>

<discipline: cargo test count before/after, build verified, etc.>

Co-Authored-By: Codex <noreply@anthropic.com>
```

Types: `feat` · `fix` · `harden` · `audit` · `docs` · `test` · `refactor` (rare, additive-only) · `chore`.

---

## §8. Concrete first-week mission (suggested ordering)

### Day 1 — INVESTIGATION onboarding
- Read Tier 1 + Tier 2 doctrine.
- Run Phase A.1 + A.2 + A.3 (first-pass read + code inventory + drift detection).
- Output: `docs/INVESTIGATION_REPORT_2026_05_17.md` (or whatever date).

### Day 2 — THEOREMS + BACKLOG
- Run Phase A.4 + A.5 (theorem audit + backlog reconciliation).
- For each Foundational Seven theorem, document Lean status + code substantiation.
- For each §3.x row, verify cited code-anchor exists.

### Day 3 — AGENT-REPO STUDY
- Run Phase A.7 (study repos on disk).
- One doc per repo: `docs/AGENT_REPO_STUDY_<repo-name>_<date>.md`.
- Map each insight back to MASTER_FUSION.

### Day 4 — FIXING #1
- Phase B.1-B.4 (drift fixes + doctrine reconciliation + theorem proofs + substrate maturation).
- Target: +50 tests, +5 doctrine reconciliations.

### Day 5 — USER-FACING SURFACING
- Phase B.5 + B.6 (surface hidden capabilities + computer-use validation).
- Add 3-5 new Settings panes or diagnostic rows.
- Screenshot each.

### Day 6 — RECURSIVE AUDIT
- Phase C: audit-of-audit on the 5 days of work.
- Push everything.

### Day 7 — SYNTHESIS
- Phase D: update 3 integration artifacts.
- Update MASTER_FUSION §3.x rows.
- Write `docs/SESSION_SUMMARY_2026_05_<day>.md`.

Then repeat from Day 1, but with deeper layer.

---

## §9. Escalation channels

If you hit something that genuinely requires user input:
1. Add to `docs/audits/user-decisions/<new-decision-id>.md` with options + recommendations.
2. Surface in your next commit message: `**USER ATTENTION**: <description>`.
3. **Do not block on it.** Continue with other phases.

If you find a CRITICAL bug (data loss, security hole, broken build that breaks main):
1. STOP everything.
2. Commit what you have with `BLOCKER:` prefix.
3. Don't push.
4. Surface the issue in stark terms.

---

## §10. Reference checklist (re-read every 20 iters)

- [ ] §0 immutable rules: 10 rules, none violated this iter?
- [ ] §5.0 reconciliation gate: every claim grep-verified this iter?
- [ ] Cargo test count: ≥ 1671 (current main baseline)?
- [ ] xcodebuild: builds clean on last Swift change?
- [ ] No features deleted this iter? (must be true)
- [ ] No tests deleted this iter? (must be true)
- [ ] No docs deleted (only updated/superseded)? (must be true)
- [ ] Every commit has HEREDOC body + Co-Authored-By?
- [ ] Pushed in the last 10 iters?
- [ ] Audit-of-audit due (every 10 iters)?
- [ ] Synthesis pass due (every 20 iters)?

---

## §11. The vision (re-read at start of each phase)

The user wrote: *"i literally want a beautiful breakthrough in my architecture make sure no compromises recursively hardening and profoundly adding to my app."*

**Translation**: Epistemos is meant to be the first PKM app that is also research-grade infrastructure. Most PKMs are CRUD over notes. Epistemos is:
- A cognitive substrate (Cognitive Kernel + DAG + ACS + UAS)
- A verification machine (Foundational Seven theorems + audit-of-audit cycles + ClaimLedger)
- A learning organism (Skills + procedural memory + self-evolution + ACS autopoiesis)
- A multi-model conductor (ConfidenceRouter + Variant Ladder + Knowledge Vaults + 9 local models)
- A surfaced research substrate (every architectural decision is inspectable + cited + testable)

The breakthrough is that **the architecture itself is the moat** — Epistemos is a workable research thesis on what AI-native PKM looks like, while ALSO being a daily-driver tool.

Your job: keep that bar honest. If you find places where the substrate is more hype than substance, harden it (write tests, add diagnostics, surface in UI). If you find places where the substrate is real but invisible to users, surface it. **Never let claims drift away from code.**

---

## §12. Cadence directive

Run this loop at **~5-minute cadence** when in INVESTIGATION phases (read + grep) and **~10-15 minute cadence** when in FIXING phases (code + test + commit). 

If you have a `/loop` skill, fire it with the prompt: `/loop <text of this whole doc>` (or paste verbatim into Codex CLI as a single mission). 

If you exhaust auto-implementable work and reach a wall, do a **graceful wind-down** per the §9 escalation channels: omit further loop scheduling, write a final session-summary commit, pause for user direction.

---

## §13. Definition of done (this is intentionally unreachable)

This investigation is **never complete**. Every doctrine update reveals new questions. Every test added reveals adjacent untested invariants. Every user-facing surface reveals adjacent hidden capabilities.

The goal isn't to finish. The goal is to leave the substrate **measurably more honest and more hardened every day** — with the path forward always documented, always cited, always testable.

When the user calls "stop," wind down cleanly. Until then, **keep going. Keep investigating. Keep hardening. Keep adding. Keep proving.**

---

*— End of CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16. Paste verbatim into Codex CLI. Codex should execute autonomously until told to stop. All work lands on `codex/research-snapshot-2026-05-08` branch (or a new feature branch) — NEVER on main directly. main is canonical.*
