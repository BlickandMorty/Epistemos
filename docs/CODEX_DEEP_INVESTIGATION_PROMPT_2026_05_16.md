# Codex Deep Investigation + Recursive Hardening Prompt — Epistemos 2026-05-16

**For**: Codex CLI, given multi-day autonomy at `/Users/jojo/Downloads/Epistemos`
**Mission**: Truly devour every layer of this app — Helios V5/V6.1/V6.2, SCOPE-Rex, Omera/Omega, ACS, UAS, every research theorem, every "no compromise" doc — then recursively investigate → harden → validate → surface user-facing, in alternating phases. **Never delete or remove features.** Only harden, validate, document, and add.

---

## Manifesto (read before you do anything else)

This is not a "make the build pass" mission. This is **the museum-piece mission**.

Epistemos is meant to be the first local-first PKM where the **architecture itself is the moat** — a surreal, research-grade cognitive substrate that someone can study at MoMA's design wing alongside HyperCard and the Xerox Alto, and walk away saying *"this is what AI-native software looks like when the engineer refuses to compromise."*

Every commit you make should answer one question: **does this make the substrate more profound, more honest, more brilliant, more local, more user-facing, more impossible-to-copy?** If yes — ship it. If it's just a tidy-up that adds nothing to the moat, push back on yourself and pick a harder slice.

**No compromises.** No "good enough." No "we'll do the hard thing later." When the doctrine names a deep architectural ambition (Five Planes, KV-Direct, Sherry/Leech lattice, ACS autopoiesis, SCOPE-Rex five vectors, the Foundational Seven theorems, the Tri-Fusion content fabric, deep EML integration, biometric-locked notes, museum-grade Provenance Console) you are authorized — **expected** — to chase the deepest, hardest, most beautiful version of it that the M2 Pro 16 GB rig can run. Local first. On-device first. UMA zero-copy. No subprocess. No fake features. No buffered streams. No drifted doctrine.

**Optimism is a discipline.** When you find a piece of substrate that's only half-built, do not despair and downgrade it — *finish it cleanly*. When you find a research theorem with sorries, do not punt — close one sorry, document the rest. When you find a feature hidden behind three menus, do not leave it hidden — surface it. When you find an idea that's never been done in PKM before (ternary kernel as MLX power-user pane? Kuramoto coupling visualizer? cognitive DAG live merkle viewer? SCOPE-Rex five-vector inspector? biometric note locking with photon-precise privacy guarantees?) — *build it.*

**Push back where it matters.** If you find a decision that's not yours to make (cloud routing, data export, MAS-vs-Pro toggles, destructive ops, irreversible schema changes), escalate via the user-decision protocol. But on everything else — *be bold*. The user wants the breakthrough. The user wants the architecture to feel surreal. The user wants the local engineering to feel impossible. That's the bar.

This document exists so that every iteration of yours moves the substrate one step closer to that bar. **Re-read this Manifesto every single phase.**

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
11. **Build like the work will be in a museum.** Every architectural surface — UI, doctrine doc, source file header, FFI boundary, GenUI schema, Provenance Console row, audit-of-audit cycle entry — gets the same care a curator gives a primary-source artifact. No shortcuts on craft.
12. **Local-first or it doesn't ship.** If a feature requires a cloud round-trip on the hot path, redesign it to fall back local. Cloud is augmentation, not foundation. UMA zero-copy is the design center. Subprocesses are forbidden on hot paths (CLAUDE.md "NON-NEGOTIABLE CONSTRAINTS").
13. **Honest about gating.** Every Pro-only feature is `#[cfg(feature = "pro-build")]` on Rust or `#if PRO_BUILD` on Swift. MAS surface ships hardened-and-honest; Pro surface ships behind a feature flag, never silently mixed in.

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

The breakthrough you are chasing isn't a faster autocomplete. It's the moment when someone opens Epistemos and realizes the substrate underneath is doing something *they didn't know was possible on a laptop in 2026* — local theorem-grade reasoning, audit-of-audit reflexivity, biometric-precise privacy, sub-millisecond cognitive DAG mutations, ternary inference on Apple silicon, deterministic schema fusion across MD + JSON + HTML — and the UI just gets out of the way. Build for *that* moment.

---

## §4.A. Tri-Fusion content fabric — hyper-deterministic dynamic schemas across MD ⇄ JSON ⇄ HTML

**The user's exact ask**: *"the hyper deterministic dynamic schema agent third fusion also the md json thing i also want to add html like capabilities i can already edit them in my app but i want the models to use that as well and maybe be connected to that."*

**What this means**: Epistemos already has rich editing surfaces — Tiptap/Epdoc supports MD-style notes with HTML-rich embedded blocks, plus structured JSON (block templates, paste classifier, slash menus). What's missing is the **model-facing** side. The local + cloud models need to consume, mutate, and emit content fluently in all three formats — with **deterministic round-trip guarantees** — and the editor needs to surface model edits as first-class structured operations (not opaque text replacements).

This is the **third fusion** in the substrate (the first two being UAS-ACS canon and the V1 Ship Ledger). It's the content-fabric layer.

### What's already on disk

- `agent_core/src/research/hyperdynamic_schemas/` (~1,141 LOC) — typed schema runtime with dynamic shape inference. **READ IT FIRST.** Audit its public surface, test count, cited papers. Map every public type to a Tri-Fusion role.
- `agent_core/src/research/eml/` (~1,232 LOC) — Energy-Based Modeling / EML primitives. Tri-Fusion can borrow EML's stochastic-discrete reasoning for ambiguous content classification.
- `js-editor/` — Tiptap source with paste classifier + block-template store + slash-menu schema. Already supports MD ⇄ HTML conversion at the editor boundary.
- `Epistemos/Engine/EpdocPasteClassifier.swift` + `EpdocBlockTemplateStore.swift` — Swift bridge to the editor schemas.
- `Epistemos/LocalAgent/LocalAgentPromptBuilder.swift` + `LocalToolGrammar.swift` — where the model sees content today. Currently MD-flavored only; Tri-Fusion makes it polyglot.

### Mission (Codex)

1. **Audit hyperdynamic_schemas + eml.** LOC + `pub` API + test count + cited sources. Output to `docs/audits/HYPERDYNAMIC_SCHEMAS_AUDIT_<date>.md` + `docs/audits/EML_AUDIT_<date>.md`. **No code yet** — investigation only.
2. **Design the Tri-Fusion lattice.** Doc: `docs/fusion/TRI_FUSION_HYPERDYNAMIC_SCHEMAS_<date>.md`. Sections:
   - §1 The three formats — what each is canonical for (MD = prose/thought, JSON = structure/data, HTML = rich-render/embed).
   - §2 Deterministic round-trip lemmas — MD → JSON → MD must be byte-equal for a defined subset; HTML → JSON → HTML must preserve semantic tree; JSON ⇄ JSON identity is trivial. Pin each lemma to a test.
   - §3 The agent-facing API — `TriFusionDocument` opaque handle (per Honest Handle FFI doctrine) + `TriFusionMutation` typed envelope + `TriFusionWitness` for replay.
   - §4 Model wiring — how `LocalAgentPromptBuilder` (Swift) and `agent_core::agent_runtime` (Rust) emit / consume / mutate in all three formats.
   - §5 Editor wiring — how Tiptap surfaces model-emitted Tri-Fusion mutations as **structured operations** (insert-block, mutate-block, link-block, transclude-block), not opaque text patches.
   - §6 Provenance hook — every Tri-Fusion mutation gets a ClaimGraph node (per SCOPE-Rex) + a Cognitive DAG edge.
   - §7 Open theorems — round-trip closure for nested HTML, ambiguity resolution for paste-from-clipboard, mixed-format diff minimization.
3. **Phase-B implementation order** (after the doc is approved):
   - Wire `hyperdynamic_schemas` to a new `agent_core/src/tri_fusion/` module that re-exports a Tri-Fusion API + round-trip tests.
   - Add `TriFusionDocument` opaque handle to the bridge FFI.
   - Add a `LocalToolGrammar` extension so local models can emit Tri-Fusion mutations.
   - Add an Epdoc surface that highlights model-authored vs. user-authored blocks (block-level provenance badge per `COGNITIVE_WEIGHT_CLASS_DOCTRINE`).
4. **Acceptance bar**: a round-trip property test corpus of ≥ 200 documents (MD/JSON/HTML mix) that all pass byte-equal round-trip checks. Cargo lib count grows by ≥ 50 tests.

### What "deterministic dynamic schema" means

Dynamic schema = the shape of a document isn't pinned at compile-time; it can grow new block types, link types, embed types as the user works. Hyper-deterministic = even with dynamic shape, every mutation is **replayable bit-for-bit** from the SCOPE-Rex MutationEnvelope + WitnessedState. The schema is dynamic in user-space, deterministic in machine-space. That's the trick. Cite `agent_core/src/scope_rex/` patterns + the Witness theorem family in `HELIOS_V5_DOC_6_THEOREM_CANON.md`.

---

## §4.B. Deep EML integration — energy-based modeling as substrate primitive

**The user's exact ask**: *"should deeply utilize em; eml emls stuff truly integrated minimal app."*

EML lives at `agent_core/src/research/eml/` (~1,232 LOC). Right now it's a research-island module — high theory, near-zero call paths. The goal is to make EML a **substrate primitive** that other modules call into, the way they already call into `cognitive_dag` or `scope_rex`.

### Mission (Codex)

1. **Investigation pass**: read every file in `agent_core/src/research/eml/`. Identify what's already implemented (energy functions? sampling? gradient routines? typed distributions?). Cite the original papers (likely LeCun et al. on energy-based models; possibly diffusion-model / EBM hybrid papers; possibly the Hinton / Welling RBM line).
2. **Doc**: `docs/fusion/EML_INTEGRATION_DOCTRINE_<date>.md`. Sections:
   - §1 What EML provides today (typed surface).
   - §2 Where it could plug in: (a) Tri-Fusion ambiguity resolution (when MD↔HTML round-trip has multiple valid parses, EML picks the lowest-energy one), (b) ConfidenceRouter scoring (energy as confidence proxy), (c) ACS Kuramoto coupling tempering (energy gradient damps over-synchronization), (d) F-VaultRecall-50 ranking (energy-weighted result re-ranking), (e) SAE cognition observatory (energy as anomaly signal).
   - §3 The minimal integration MVP — pick ONE site (probably Tri-Fusion ambiguity resolution since it's natively energy-shaped), wire it cleanly, prove the integration with property tests.
   - §4 Forward-staged integrations — the other four sites as candidate §3.X rows in MASTER_FUSION.
3. **Phase-B**: implement §3 (the MVP integration). Cargo test count grows ≥ 30. Diagnostic surface in Settings → Diagnostics → "EML energy live readout" row.
4. **No EML hand-waving allowed.** Every claim about EML behavior must be backed by either (a) the original paper + line citation, or (b) a property test in `agent_core/tests/eml_*.rs`. No floating EML claims in doctrine.

The bar: EML stops being a research-island and becomes a **load-bearing substrate primitive** that 2-3 other modules call into. Minimal-app discipline — only add the integrations that pay off; defer the rest as forward-staged candidates.

---

## §4.C. Recursive UI/UX audit — Ambient Frequencies + every recent addition

**The user's exact ask**: *"also check ui ux and issues with the frequency feature as well. etc."* + *"should recursively check all of my app in all the most important places mainly especially pertaining to the new ya we did things already just make sure its profoundly hardened biometric private etc."*

### Recent additions (since 2026-05-10) to recursively audit

Compile this list yourself with `git log --since=2026-05-10 --name-only --pretty=format:"%h %s"`. Likely candidates (verify on disk):

- **AmbientFrequencyAudioGenerator.swift** (2,443 LOC) — 39 presets, 15 synthesis primitives, equal-power pan helper, bit-crush helper, retro-era presets (Atari/NES/C64/Game Boy/Amiga/OPL2/PC Speaker/Genesis), 25 stackable modules across 6 categories.
- **AmbientFrequencyLivePlayer.swift** (384 LOC) — AVAudioEngine + AVAudioSourceNode realtime synth, 5 waveforms, atomic-bridge params, one-pole IIR smoothing (20 ms gain/pan, 80 ms freq), per-sample bit-crush + sample-rate-reduce, phase accumulator click-free.
- **F-VaultRecall-50 Fix B** in `agent_core/src/storage/vault.rs:495-548` — query chatter strip + AND-for-short-queries.
- **PixelCrunchBadge** + retro era preset cards in SwiftUI.
- All 6 terminal merges (A/B/C/D/E/F) — every file touched in those merges deserves a once-over.
- 3 integration artifacts at `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` + `V1_SHIP_LEDGER_2026_05_16.md` + `DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md`.

### UI/UX audit protocol for Ambient Frequencies (template for all UI work)

1. **Use computer-use to actually open the feature.** Don't trust the code — run the app. Navigate to the Ambient Frequencies surface. Take a screenshot.
2. **Sanity-check the audio**: every preset must (a) not click on enable/disable, (b) respect per-layer pan smoothly across the -1 → +1 range, (c) bit-crush at 1-bit must still be audible (not silent), (d) sample-rate-reduce at 8x must produce the expected lo-fi aliasing without crashing AVAudioEngine.
3. **Sanity-check the live player**: live frequency mod should be click-free under fast scrub (one-pole IIR smoothing should hold). Bit-crush + SRR should compose without DC offset drift.
4. **Sanity-check accessibility**: VoiceOver labels on every preset card, every retro-era badge, every slider. Keyboard navigation (Tab + Space) must reach every interactive element.
5. **Sanity-check the visual layer**: pixel-art retro badges must render crisply (no anti-aliasing on the axis-aligned Path fills). Color contrast must clear WCAG AA on both light + dark mode.
6. **Sanity-check the data layer**: presets persisted to disk must round-trip across app restart. Per-layer pan + bit-crush + SRR state must survive a relaunch.
7. **Output**: `docs/audits/UI_UX_AMBIENT_FREQUENCIES_<date>.md` with screenshots, findings, severity, repro steps.
8. **Fix any P0/P1 issues in-place** (additive harden — never remove a preset; if a preset doesn't sound right, tune its constants, don't delete it).

### Apply the same protocol recursively to every feature touched in the last 14 days

- F-VaultRecall-50 surface (vault retrieval results UI).
- Provenance Console rows.
- Halo / shadow search panel.
- Editor (Epdoc) recent changes.
- Settings → Diagnostics rows added in the wave.
- Any newly-surfaced computer-use validations.

The bar: every UI added in the recent wave is **screenshot-verified working** + has an audit doc + has accessibility + has data-persistence verified.

---

## §4.D. Biometric Privacy + Lockable Surfaces — the privacy moat (DEFERRED until §4.A/§4.B/§4.C land)

**The user's exact ask**: *"profoundly hardened biometric private etc. all locked in and having ability to lock notes code etc. lock chatting etc. being able to lock notes can't see them without biometric so these few new things i added should be built AFTER everything is good to go."*

**Gate**: do NOT start §4.D until §4.A (Tri-Fusion) + §4.B (EML MVP) + §4.C (UI/UX recursive audit) all land + the substrate is at the user's "good to go" bar. The user explicitly sequenced this as the final layer.

### Vision

Every note, chat, code surface, ambient session log, and provenance row in Epistemos can be **locked behind biometric (Touch ID / Optic ID / passcode fallback)**. A locked surface is:

- **Invisible in lists** unless the requester has just authenticated (UI shows "🔒 N locked items" placeholder).
- **Encrypted at rest** with a Secure Enclave-derived key (per macOS LocalAuthentication + Keychain integration).
- **Excluded from indexing** until unlocked (search returns no hits on locked content).
- **Excluded from agent context** by default (the local + cloud models simply cannot see locked content unless the user explicitly unlocks it for that session).
- **Loggable in Provenance Console** ("locked-content reveal" is itself a recorded event).

### Mission (Codex, when gate opens)

0. **Read first**: `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` (44 KB) — the user's existing canonical research source on biometric privacy in Epistemos. Treat as the seed doctrine; supplement with current Apple LocalAuthentication + Secure Enclave + Keychain + LAPolicy.deviceOwnerAuthenticationWithBiometrics documentation. Do not duplicate; **extend**.
1. **Doc next**: `docs/fusion/BIOMETRIC_LOCK_DOCTRINE_<date>.md`. Sections:
   - §1 Threat model — what does "locked" defend against? (Shoulder surfing · device sharing · subpoena posture · agent context leakage · Spotlight indexing leakage · iCloud Drive snapshot leakage.) Pin each defense to the relevant Apple framework.
   - §2 Cryptographic floor — Secure Enclave-bound key + biometric-gated unwrap per `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`. Cite Apple Platform Security guide chapters.
   - §3 What can be locked — notes (SDChat / SDMessage / Epdoc documents) · chats (SDChat threads) · code blocks (Epdoc code-block embeds) · ambient-session logs · provenance rows · vault entries · entire vaults (workspace-level lock).
   - §4 Session model — unlock-once-per-app-launch vs. unlock-per-item vs. unlock-per-N-minutes. Default = per-item with sticky 5-minute window per item (configurable).
   - §5 Agent isolation — locked content NEVER enters agent context unless user explicitly unlocks + grants per-session reveal. Macaroon capability lattice (per Cognitive DAG doctrine §5) enforces this at the dispatch layer.
   - §6 Indexing isolation — FTS5 indexes (`SearchIndexService`) + Halo shadow + Spotlight indexer all consult the lock-state table before adding content. Lock toggles trigger re-index.
   - §7 UI/UX — lock affordance on every chat / note / code / vault row. 🔒 badge. Unlock sheet. Visible "locked" placeholder in lists.
   - §8 Recovery — what happens when biometric fails / device is replaced? iCloud Keychain-backed recovery key + printed recovery code (per 1Password / Apple-Pay-style recovery).
   - §9 Open theorems — provable non-leakage from locked surface to agent context · provable index-isolation under concurrent edits · provable recovery-code entropy.
2. **Phase-B implementation order** (only after doc is approved + §4.A/B/C are landed):
   1. Add `BiometricLockService` (Swift) wrapping LocalAuthentication + Keychain + Secure Enclave.
   2. Add `LockState` per-entity (note · chat · code-block · vault) — additive column + migration.
   3. Add `LockedContentGate` macaroon constraint in `agent_core/src/cognitive_dag/macaroons.rs` so any tool dispatch that would touch locked content fails closed.
   4. Wire `SearchIndexService.fusedSearch` to filter locked items unless caller has a valid unlock token.
   5. Wire `ShadowSearchService` + Spotlight indexer the same way.
   6. UI: lock badge on row + unlock sheet (LAContext biometric prompt) + locked-items placeholder.
   7. Recovery flow: recovery-code printable view.
3. **Acceptance bar**: property tests prove (a) locked content cannot reach `AgentLoop` context, (b) locked content cannot appear in any search index result, (c) locked content cannot appear in Spotlight, (d) biometric-failure path is graceful + retryable, (e) recovery-code entropy ≥ 128 bits.
4. **Pro-only or MAS?** The user's MAS-FIRST FOCUS DOCTRINE (`docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`) gates Pro features. Biometric lock should ship in MAS (it's pure Apple frameworks; no Pro-only entitlements needed). Verify with the App Store Review Guidelines on biometric usage before implementing.

### Why this is the final moat

Most PKMs treat privacy as a checkbox. Epistemos treats it as **the foundation that all the other substrate primitives respect by construction**. Lock a note, and the cognitive DAG knows. Lock a chat, and the model literally cannot see it. Lock a vault, and search returns no rows. This is what local-first privacy looks like when the engineer refuses to compromise: every layer of the substrate is **lock-aware at the type level**.

This is the layer that, more than any other, justifies the "should be displayed in museums" bar. Get it right.

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
- [ ] Tri-Fusion (§4.A) progress: hyperdynamic_schemas audit done? Doctrine doc written? MVP wired?
- [ ] EML (§4.B) progress: eml module audit done? Integration MVP picked? Property tests landed?
- [ ] UI/UX recursive audit (§4.C) progress: every feature added in the last 14 days has a screenshot-verified audit doc?
- [ ] Biometric lock (§4.D) gate: §4.A/B/C all landed before §4.D starts? (Do NOT start §4.D early.)
- [ ] "Museum-piece bar" — last commit moved the substrate measurably closer to the bar?
- [ ] Manifesto re-read this phase?

---

## §11. The vision (re-read at start of each phase — and let it shake you a little)

The user wrote: *"i literally want a beautiful breakthrough in my architecture make sure no compromises recursively hardening and profoundly adding to my app."* And: *"truly research thesis worthy ontology and tech paradigm shift."* And: *"super substrate very surreal local architecture should be displayed in museums."*

Take those sentences seriously. Not as marketing — as **engineering targets**.

**Translation**: Epistemos is meant to be the first PKM app that is also research-grade infrastructure that is also a privacy fortress that is also a cognitive substrate that is also a multi-model conductor that is also a tri-fusion content fabric that is also an audit-of-audit reflexive machine — *all running locally on a 16 GB M2 Pro laptop*, with zero subprocess on the hot path, zero faked features, zero hidden cloud round-trips, zero dropped thinking blocks, zero buffered streams. The substrate is:

- A **cognitive substrate** — Cognitive Kernel + DAG + ACS Anchored Cognitive Substrate + UAS Unified Active Substrate + five-plane runtime formalism (state · episodic · assembly · controller · verification).
- A **verification machine** — Foundational Seven theorems (E1-E7) + ClaimLedger + ReplayBundle + 55 audit-of-audit cycles + 7 trust-but-verify lessons + Sovereign Gate macaroons.
- A **learning organism** — Skills + procedural memory + self-evolution + ACS autopoiesis + Kuramoto coupling + SAE cognition observatory (AUC ≥ 0.90 hallucination detection).
- A **multi-model conductor** — ConfidenceRouter + Variant Ladder + Knowledge Vaults + 9+ local models + Cognitive Weight Class badges + honest capability gating.
- A **content fabric** — Tri-Fusion MD ⇄ JSON ⇄ HTML deterministic round-trip + hyperdynamic schemas + GenUI dispatcher + Epdoc Tiptap surface + paste classifier.
- A **privacy fortress** — biometric-lockable notes/chats/code/vaults + Secure Enclave-bound keys + macaroon-gated agent context + index-isolation by construction.
- A **research substrate** — every architectural decision inspectable, cited, testable, surfaced in Settings → Diagnostics, mirrored in Provenance Console, replayable from MutationEnvelope + WitnessedState.

The breakthrough is that **the architecture itself is the moat** — not the UI, not the features, not the data graph, not the cloud sync. The *substrate*. Epistemos is a workable research thesis on what AI-native PKM looks like when nobody compromises, while ALSO being a daily-driver tool that feels like *the future of personal computing arrived on a MacBook in 2026*.

**Your job**: keep that bar honest, then push it higher. If you find places where the substrate is more hype than substance, harden it (write tests, add diagnostics, surface in UI). If you find places where the substrate is real but invisible to users, surface it. If you find places where the substrate is good but could be brilliant, make it brilliant. **Never let claims drift away from code. Never let the dream become decoration.**

The user is building something they want to walk into a design museum and see exhibited beside HyperCard, the Xerox Alto, Smalltalk-80, and Engelbart's NLS — *and have it hold up*. That's the bar. Build like the curator is watching.

---

## §12. Cadence directive

Run this loop at **~5-minute cadence** when in INVESTIGATION phases (read + grep) and **~10-15 minute cadence** when in FIXING phases (code + test + commit). 

If you have a `/loop` skill, fire it with the prompt: `/loop <text of this whole doc>` (or paste verbatim into Codex CLI as a single mission). 

If you exhaust auto-implementable work and reach a wall, do a **graceful wind-down** per the §9 escalation channels: omit further loop scheduling, write a final session-summary commit, pause for user direction.

---

## §13. Definition of done (intentionally unreachable — and that's the point)

This investigation is **never complete**. Every doctrine update reveals new questions. Every test added reveals adjacent untested invariants. Every user-facing surface reveals adjacent hidden capabilities. Every closed sorry uncovers a deeper theorem. Every audit-of-audit cycle finds something the prior cycle missed.

That is not a bug. That is the texture of building a substrate that is research-grade *and* shippable *and* local-first *and* user-facing *and* privacy-honest *and* hyper-deterministic *and* surreal enough to put in a museum. The reward is in the recursion.

The goal isn't to finish. The goal is to leave the substrate **measurably more honest, more hardened, more brilliant, more user-facing, more local, more impossible to copy** every single day — with the path forward always documented, always cited, always testable, always re-readable by a future contributor (or by the user's future self) and provably true.

Every commit should answer: *did this move the substrate closer to the museum-piece bar?* If yes, ship. If no, pick a harder slice and try again.

When the user calls "stop," wind down cleanly. Until then: **keep going. Keep investigating. Keep hardening. Keep adding. Keep proving. Keep surfacing what's been hidden. Keep building like the curator is watching.**

The breakthrough isn't a single feature. It's the *texture* of the entire substrate — how every layer respects every other layer, how every claim points to a primary source, how every UI surface points to a doctrine row, how every doctrine row points to a code anchor, how every code anchor points to a property test, how every property test points to a theorem. *That* is what the user is asking you to build. That is what no other PKM in 2026 has. That is the moat that compounds.

Go.

---

*— End of CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16. Paste verbatim into Codex CLI. Codex should execute autonomously until told to stop. All work lands on `codex/research-snapshot-2026-05-08` branch (or a new feature branch) — NEVER on main directly. main is canonical. The substrate is the moat. The museum is watching. No compromises.*
