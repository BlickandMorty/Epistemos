# MAS Complete Fusion Implementation Plan — No Compromise (except POSTV1 exclusions)
**Date:** 2026-05-14
**Scope:** Everything that gets done before / during V1 MAS submission EXCEPT explicit POSTV1 exclusions.
**Includes:** All V1 ship gates · Wave A No-Compromise quality wins · Wave F XPC Mastery · Every remaining PATCHED PARTIAL / OPEN / DEFERRED audit item that ISN'T in POSTV1 exclusions · the 5-recursive-pass discipline.
**Excludes (explicitly):** Wave B (V6.1 EML floor) · Wave C (V6.2 6 Metal kernels) · Wave D (Halo V1 6-state FSM + Eidos) · Wave E (SCOPE-Rex V2) · Wave G (Simulation v1.7+ full) · Wave H (UI/UX V2.6 advanced) · Wave I (A2UI 24 remaining components) · Wave J research tier · `POSTV1-EXCL-001`.
**Authority:** This doc sits at rank 3 of the authority chain (per `MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §2), right after `CLAUDE.md` + `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md`.

---

## 0. The protected surfaces and immutable rules

1. **Graph is protected.** No camera / renderer / layout / edges / physics / hologram changes WITHOUT user-issued scoped approval. The graph-camera-framing fix (`V1-GATE-GRAPH-001`) requires a separate explicit user "yes, touch `GraphCamera.swift` initial framing only" sign-off.
2. **Vault is sensitive.** Vault fixes start with evidence + minimal rationale + rollback-safe plan. No reset/delete/casual migration.
3. **No Pro features bleed into MAS.** `mas-build` Cargo feature gates everything `#[cfg(feature = "pro-build")]`. Symbol-leak audits (`strings` + `nm`) stay ZERO matches.
4. **8-question PR discipline** (`MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §6) applies to every PR.
5. **No silent deferrals.** Every deferred item has a row in `## Implementation Log` at the bottom.

---

## 1. Phase organization

5 phases, mostly parallel, with sequencing constraints noted:

| Phase | Owner | Time | Parallel? | Depends on |
|---|---|---|---|---|
| **A — V1 Ship Gates** | User (you) + Codex verification | 1-2 days wall-clock | yes (most of A) | nothing |
| **B — Wave A No-Compromise Quality** | Codex | 5-10 days | yes | nothing |
| **C — Recursive Audit PARTIAL Closure** | Codex | 5-10 days | yes | nothing |
| **D — Wave F XPC Mastery** | Codex | 2-4 weeks | AFTER A green | needs paid Developer signed builds proven first |
| **E — V1 Submission + 5 Recursive Passes** | User + Codex | 1-3 days | sequential | A complete + B/C sampled green + D Stage 1 (VaultXPC) merged |

Net: from today, target **V1 MAS submission in ~3-5 weeks** assuming Codex runs continuously through B + C + D.

---

## Phase A — V1 Ship Gates (USER + Codex)

Goal: clear the 5 user-action gates from Codex's audit + the App Store Connect admin work. Each sub-gate has its acceptance bar.

### A.1 MAS Release build verification (USER, ~5 min)

```bash
cd /Users/jojo/Downloads/Epistemos
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Release build

MAS_APP=$(find ~/Library/Developer/Xcode/DerivedData/Epistemos-*/Build/Products/Release -name "Epistemos.app" 2>/dev/null | head -1)

# Confirm sandbox + App Group both present
codesign -d --entitlements - "$MAS_APP" 2>&1 | grep -A3 "app-sandbox"
# Expected: app-sandbox = true
codesign -d --entitlements - "$MAS_APP" 2>&1 | grep -A3 "application-groups"
# Expected: group.com.epistemos.shared

# Re-run leak audits
find "$MAS_APP" -type f -print0 | xargs -0 strings 2>/dev/null | \
  grep -E '^(/usr/local/bin/(claude|codex|gemini|kimi)|/usr/bin/osascript|/bin/bash|/bin/sh|/usr/local/bin/docker)$'
# Expected: ZERO matches

nm -gU "$MAS_APP/Contents/Frameworks/libagent_core.dylib" 2>/dev/null | \
  grep -iE 'osascript|bash_execute|cli_passthrough|stdio_mcp|browser_subprocess|imessage_send|cronjob|cli_(claude|codex|gemini|kimi)|computer_use|screencap'
# Expected: ZERO matches

# Apple's official scanner
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-audit-gate \
  scripts/scan_appstore_bundle.sh "$MAS_APP"
# Expected: PASS
```

**Acceptance bar:** BUILD SUCCEEDED + sandbox=true + App Group present + 0 string matches + 0 symbol matches + scanner PASS.

### A.2 Provider credential live smoke (USER, ~10 min)

This single action unblocks 2 separate gates:

1. Launch Pro app (`Epistemos` scheme).
2. Settings → Inference → add **OAuth account session OR API key** for OpenAI **or** Anthropic.
3. In chat, on Pro mode + the cloud provider you just added, ask: *"search the web for 'state space models' and summarize 3 results"*
4. Expected: native approval card renders → you approve → `web.search` runs → response cites sources.

**Unblocks:**
- `V1-GATE-LIVE-PRO-001` — cloud-agent smoke complete
- First-run web-approval live smoke complete

### A.3 MAS simple-rewrite live smoke (USER, ~5 min)

1. Launch the **MAS audit bundle** (`Epistemos-AppStore` Release build, or whichever fresh isolated MAS build you used for prior scratch soaks).
2. Create a scratch note titled "Test note" with body "*This is a test note that needs to be rewritten in fewer words.*"
3. Settings → ensure either a local model is installed/ready OR a cloud provider credential is added.
4. In the note's ask bar, type: *"rewrite this in one shorter sentence"*
5. Expected: response renders inline / in panel; the no-runtime "Set Up Model" placeholder (`af78d5f3a`) is NOT what you see.

**Unblocks:** `V1-GATE-LIVE-MAS-001` — simple rewrite smoke complete.

### A.4 Graph first-open framing decision (USER, scoped approval OR explicit accept-as-is)

Pick one:

**Option (a) — Approve scoped graph camera patch:**
Tell Codex: *"Approved: patch the initial graph camera/bootstrap framing path. Touch `Epistemos/Graph/GraphCamera.swift` (or equivalent) ONLY for the first-open framing fit-to-content. Renderer / Metal SDF / node layout / edge geometry / hologram visuals / selection highlight stay UNTOUCHED."*

**Option (b) — Accept as known behavior:**
Add a one-line UI tip near the graph Zoom-to-Fit button: *"Tap to fit nodes on screen"* (no graph rendering code; this is a UI tooltip / hint string change).

Either way, document the choice in `Implementation Log`.

**Unblocks:** `V1-GATE-GRAPH-001` — first-open framing resolved.

### A.5 App Store Connect metadata (USER, ~1-2 hours)

Per `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §4.4. Checklist:

- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) verified in `Epistemos.app/Contents/Resources/`
- [ ] App Privacy answers — "Data Not Collected"
- [ ] Privacy policy URL — live + accessible
- [ ] Support URL — live + accessible
- [ ] Screenshots — minimum 1 per macOS device class, recommended 5+ (2560×1600 / 2880×1800 / 1280×800)
- [ ] App description + keywords + promotional text
- [ ] Pricing + Availability (countries)
- [ ] App Review notes — describe local-first architecture; no auto-cloud calls; provide demo credential if a feature gates on it
- [ ] Export Compliance — "No" (HTTPS/system crypto only) OR "Yes" + ECCN
- [ ] Age rating questionnaire
- [ ] Sandbox file-access language in review notes
- [ ] DSA trade representative (if EU)

**Acceptance bar:** App Store Connect listing 100% complete + URLs live + screenshots uploaded.

### A.6 TestFlight upload + internal soak (USER, ~1 day)

1. In Xcode: **Product → Archive** (with `Epistemos-AppStore` scheme + Release config)
2. Xcode Organizer opens → **Validate App** → fix any errors → **Distribute App → App Store Connect → Upload**
3. Wait for App Store Connect processing (5-30 min)
4. Add yourself + trusted testers as internal testers
5. Install via TestFlight Mac app
6. Run the **16-item manual workflow matrix** (`MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §4.3):
   - First launch · no-model setup · local chat · cloud-key missing · model install · note read+search · AI accept+discard · attachment grant · file attachment · export · history · vault import rollback · settings privacy/permissions · accessibility · quit-reopen
7. Fix any regressions → re-upload → re-test

**Acceptance bar:** all 16 items green on TestFlight build + at least one second tester confirms.

---

## Phase B — Wave A No-Compromise Quality Wins (CODEX, parallel)

Codex executes these in priority order. They can run alongside Phase A; none require Apple Developer cert or signed builds.

### B.1 (Wave A1) — Variant Ladder dispatcher retrofit on `vault.search`

**Source:** `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` §4.2 + §5, `docs/fusion/jordan's research/deterministicapp.md` §2.1.

**Acceptance:**
- `vault.search` dispatch in `agent_core/src/tools/registry.rs` walks `VariantLadder<I,O>` from `agent_core/src/variant_ladder/mod.rs`
- Tier 1 (Tantivy lexical BM25) → Tier 2 (embedding semantic) → Tier 3 (RRF hybrid) → Tier 4 (LLM with grammar) → defer
- `FLOOR_T1 ≥ 0.85`, `FLOOR_T2 ≥ 0.75`, `FLOOR_T3 ≥ 0.70` thresholds wired
- `LadderLog` row writes to Provenance Console per call
- Source-guard test pattern per doctrine §4.2 (happy-path Tier 1 exit + escalation gate proof)

**Estimated:** 3-5 days. Highest-ROI no-compromise win.

### B.2 (Wave A2) — `## Variant Ladder` PR-description sweep on 30 MAS-allowed tools

For each of the 30 tools in `coreAppStoreAllowedToolNames`, append a `## Variant Ladder` section to its registration doc string (or a per-tool `_ladder.md` file under `agent_core/src/tools/`) documenting:
- Which tiers are populated
- Which tiers are deliberately skipped + why
- Confidence floors
- Example inputs that exercise each tier

**Source:** doctrine §4.1.
**Estimated:** 2-3 days (doc-only, 30 routes).

### B.3 (Wave A3) — `escalate_on_empty: false` default + opt-in gate

**Acceptance:**
- Default tool registration sets `escalate_on_empty: false`
- Any tool that escalates Tier 4+ without user opt-in carries `// VARIANT-LADDER-DEFER:` marker + audit row
- User opt-in paths: explicit `/cloud` slash command, ⌥-submit, or Settings escalation toggle

**Source:** doctrine §6.
**Estimated:** 1-2 days.

### B.4 (Wave A4) — `reasoning` field token cap at GBNF compile

**Acceptance:**
- `LocalToolGrammar.buildToolCallingPlan` clamps `reasoning` field length to ≤256 tokens (≤32 for Qwen 7B per Brief Is Better)
- Per-model cap in `LocalTextModelID` capabilities table
- Grammar compile-time test verifies clamp

**Source:** `deterministicapp.md` §1, `helios v3.md` §"Brief Is Better".
**Estimated:** 1-2 days.

### B.5 (Wave A5) — `epistemos.*.v1` JSON schemas

Author 4 typed schemas + register with `MutationEnvelope` schema-validated writes:
- `epistemos.soul.v1` — user identity / preferences / agent persona
- `epistemos.skill.v1` — Voyager-style executable skill (code + NL description)
- `epistemos.episode.v1` — CoALA episodic memory entry
- `epistemos.semantic.v1` — CoALA semantic memory fact

**Acceptance:**
- 4 `.schema.json` files under `agent_core/schemas/`
- Schemars round-trip parity test
- `MutationEnvelope` rejects malformed writes

**Source:** `deterministicapp.md` §5.
**Estimated:** 3-4 days.

### B.6 (Wave A6) — Cognitive Weight Class W1 metadata badge

**Acceptance:**
- `CognitiveWeight` struct read from `EpistemosSidecar` metadata at retrieval time
- 4-tier badge renders on every loaded resource in Halo + composer (Soft / Preferred / Strong / Policy-grade)
- `policy_authority` silently downgraded in W1 (W1 §6 acceptance)
- W1 source-guard test
- Halo Shadow attachment + composer attachment plan both display weight

**Source:** `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` §3 + W1 acceptance bar.
**Estimated:** 4-5 days (UI work).

### B.7 (Wave A7) — Knowledge Sieve + Gap Winner Rule for ClaimLedger

**Acceptance:**
- ClaimLedger ranking gets prime-composite-gap boost in `agent_core/src/provenance/ledger.rs`
- Gap nodes (waiting / unverified) deprioritized per No-Later-Simpler-Composite curriculum
- RRF k=60 fusion query in `Epistemos-shadow` gains "prime-composite-gap" rank boost
- Determinism test pins seed → output

**Source:** `docs/fusion/jordan's research/kimis deep research/ternary_reconceptualization.md` Prime-Composite-Gap section.
**Estimated:** 3-4 days.

### B.8 (Wave A8) — `clarify` tool surface UI card

**Acceptance:**
- New `GenUISchema.clarify` schema in `Epistemos/GenUI/Catalog.swift`
- `ClarifyGenUIView` renderer (typed question + multiple-choice + free-text fallback)
- `GenUIDispatcher` registers schema; ChatCoordinator surfaces dedicated card when agent emits `clarify.ask`
- Agent loop honors clarify response in next-turn message history

**Source:** `MAS_RELEASE_MANIFEST_2026_05_13.md` §Composer helpers + `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`.
**Estimated:** 3-4 days.

### B.9 (Wave A9) — NightBrain task bodies (10 tasks)

Replace NoOp placeholders in `agent_core/src/nightbrain/live.rs` with real bodies:
- `vault_consolidate` — coalesce duplicate notes / dedup
- `claim_evidence_decay` — decay stale ClaimLedger entries
- `procedural_curate` — promote validated procedures to durable storage
- `companion_refresh` — recompute companion embeddings
- `provenance_compact` — compact MutationEnvelope log
- `skill_index_rebuild` — re-index Voyager skill library
- `attachment_grant_audit` — sweep expired R.5 grants
- `embedding_health_check` — verify Halo Shadow index integrity
- `cognitive_dag_merkle_verify` — periodic Merkle root verify
- `instant_recall_rebuild` — vault-index actor rebuild

**Source:** `docs/fusion/CANONICAL_DRIFT_AUDIT_2026_05_04.md` NightBrain row.
**Estimated:** 5-7 days (one task body per ~half day).

---

## Phase C — Recursive Audit PARTIAL Closure (CODEX, parallel)

Codex closes the remaining 23 PATCHED PARTIAL items + 1 OPEN that are NOT in POSTV1 exclusions. Grouped by category for parallel execution:

### C.1 Hidden-capture metadata existing-note migration

**Items:** `RCA-P0-003` + `RCA5-P1-006` + `RCA10-P0-001`

New captures already clean. Existing-note migration is a one-shot Swift utility:
- Scan vault for notes with HTML-comment capture metadata
- Surface in a Settings → Privacy "Migrate hidden capture metadata" action
- User-initiated; not auto

**Source:** all 3 audit entries.
**Estimated:** 2-3 days.

### C.2 Off-main-actor retrieval refactor

**Items:** `RCA-P1-011` + `RCA2-P1-008` + `RCA5-P1-007` (duplicate)

Move `QueryEngine` / `QueryRuntime` / live query reevaluation off `@MainActor` + typed-diff Rust watcher.

- `QueryRuntime` becomes `actor` (not `@MainActor`)
- Typed `QueryDiff` Rust struct via FFI
- Swift consumes diffs on main; SQL/graph work stays off-main

**Acceptance:**
- No `@MainActor` annotation on `QueryEngine` / `QueryRuntime`
- Live query reevaluation < 16 ms p99 on M2 Pro
- Targeted Instruments trace evidence

**Source:** all 3 audit entries.
**Estimated:** 5-7 days (structural refactor).

### C.3 Editor asset reads + Brotli decompression off main

**Item:** `RCA-P1-001`

`EpdocEditorURLSchemeHandler.serve` already actor-isolated post `2026-05-13`. Remaining: Brotli decompression on cold open. Move to background actor with caller awaiting result.

**Acceptance:**
- `decompressBrotli` runs on `Task.detached(priority: .userInitiated)`
- Cold editor open p99 < 250 ms

**Estimated:** 1-2 days.

### C.4 Prose editor debounced incremental reparse

**Item:** `RCA4-P1-002`

Per-keystroke reparse is already bounded by fast Rust FFI. Remaining: debounced incremental reparse for `ProseTextView2`.

- 50-150 ms debounce window
- Incremental tree-sitter delta reparse
- Token cache invalidated only for changed ranges

**Acceptance:**
- p99 keystroke handling < 8 ms on 10k-line note
- Determinism test (same input → same output)

**Estimated:** 3-5 days.

### C.5 NotesSidebar cache invalidation + epdoc manifest I/O

**Item:** `RCA2-P1-011`

`rebuildCache()` cache-invalidation gaps + `.epdoc` package manifest I/O on sidebar rebuild.

- Listen for folder rename/reparent/sort/collection notifications
- Move `.epdoc` package manifest reads off the sidebar rebuild path (lazy on-demand)

**Acceptance:**
- Sidebar rebuild p99 < 50 ms on 1000-note vault
- Source-guard test pins cache-invalidation invariant

**Estimated:** 3-4 days.

### C.6 Vault Organizer duplicate/folder-suggestion drift

**Item:** `RCA2-P2-005`

Folder-matching limitation explicitly documented. Full-path migration deferred per current audit note. Decision: **document as known limitation in V1; defer full-path migration to V1.1**.

**Acceptance:** UI tip explaining folder-name match (not full-path); audit row updated.

**Estimated:** 1 day (UI string + doc only).

### C.7 Scoped credential delivery (final hardening)

**Item:** `RCA4-P1-001`

Process-wide credential env mirroring already REMOVED 2026-05-09. Current state: scoped to `withScopedAgentCoreEnvironment(operation:)`. Remaining: FFI-only delivery (no env vars across process boundary).

**Acceptance:**
- All cloud provider credentials enter `agent_core` via typed FFI argument, not env var
- Source-guard test proves no env-var leak across FFI

**Source:** `RCA4-P1-001` audit entry.
**Estimated:** 4-6 days (FFI surface change).

### C.8 Verified-write coverage closure

**Item:** `RCA7-P1-006`

Remaining high-risk paths needing `resourceVerifiedWrite`:
- `AppCoordinator` write paths
- `CodeEditorView` writes
- `ModelVaultBrowserStore`
- `JournalIntents`
- Sync/import flows

**Acceptance:**
- All 5 named paths route through `resourceVerifiedWrite` or readback-verifying wrapper
- Regression tests per path

**Source:** `APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` §2.
**Estimated:** 5-7 days.

### C.9 AgentGrep editor/code file I/O hot-path split

**Item:** `RCA10-P1-006`

Visible code editor hot path already green. Remaining: AgentGrep pending.

- AgentGrep file reads off `@MainActor`
- Bounded buffer to limit blast radius
- Targeted Instruments trace evidence

**Estimated:** 2-3 days.

### C.10 CodeFileService containment first canonical fix

**Item:** `RCA9-P0-001`

CodeFileService containment is in place + visible editor routing covered. Remaining: explicit collapse into canonical "first" fix-pass naming + audit reconciliation.

**Acceptance:** audit doc update + source-guard test pinning canonical surface.

**Estimated:** 1 day (doc + test).

### C.11 `/image` command + MLX image generation

**Items:** `RCA12-P1-003` + `RCA2-P1-014` + `RCA3-P2-003`

`/image` slash command shows in UI but MLX image generation is scaffold-only. Decision: **hide `/image` command in V1** until provider route is explicit.

- Gate `/image` in `ACCSlashCommand.coreAllowedCommands` with `#if FEATURE_IMAGE_GEN`
- Default flag OFF for V1
- Add scaffold marker to `media.image_generate` if it surfaces

**Source:** 3 audit entries.
**Estimated:** 1-2 days.

### C.12 Connected-vault note to Graph/Search/Halo manual smoke

**Item:** `RCA5-P1-013`

Architecture is correct but end-to-end manual smoke (create note → graph node → search hit → Halo hit) is operator-only.

**Action:** Codex does the operator smoke via computer-use after Phase A.3 unblocks live note flow.

**Acceptance:** screenshot evidence + audit row updated.

**Estimated:** 1 hour live smoke.

### C.13 DB fallback model-container init inspection

**Items:** `RCA-P0-002` + `RCA10-P0-003`

Normal editing already blocked. Remaining: fault-injection runtime matrix to prove DB fallback can't create silent in-memory sessions.

- Inject corrupt store / missing schema / version mismatch / locked file
- Assert: fail-fast + user-visible error + no silent in-memory replacement
- Source-guard tests for each fault class

**Estimated:** 4-6 days.

### C.14 Launch path deeper audit

**Item:** `RCA-P1-003`

Companion seed deferred. Remaining: deeper launch-path audit (first-click responsiveness profile).

- Instruments trace from launch to first input event
- Identify any blocking work
- Move to background where possible

**Acceptance:** p99 launch-to-first-input < 800 ms on M2 Pro.

**Estimated:** 4-6 days.

### C.15 Orphan / archived runtime quarantine

**Item:** `RCA-P2-010`

Sweep ArenaBridge + Helios kernel scaffolds + any other surfaces not in production tool list. Mark `SCAFFOLD-ONLY` on the surfaces I missed in earlier passes.

- ArenaBridge gets `// SCAFFOLD-ONLY:` header
- Helios kernel scaffolds get the same
- Audit doc updated

**Estimated:** 2-3 days.

### C.16 Voice temp-file cleanup MIC smoke

**Items:** `RCA5-P1-005` + `RCA9-P1-007`

Automated cleanup tests green. Remaining: manual MIC smoke on every composer voice completion path.

**Action:** Codex computer-use smoke — record voice query → finish → verify temp file deleted.

**Acceptance:** screenshot evidence + audit row.

**Estimated:** 1 hour live smoke.

### C.17 Current Access runtime proof

**Item:** `RCA12-P1-006`

Automated parity green. Remaining: manual runtime proof that 3 attachment grants are enforced.

**Action:** Codex computer-use smoke — seed 3 attachment grants → trigger tool calls on each → verify enforcement.

**Acceptance:** screenshot + audit row.

**Estimated:** 1 hour live smoke.

### C.18 SDF graph label budget guard

**Item:** `RCA11-P2-005`

GRAPH-ADJACENT — read-only smoke only.

**Action:** observe fullscreen graph + frame hitch report. Do NOT patch graph rendering. If hitches reproduce, file evidence for graph approval discussion.

**Estimated:** 30 min observation.

### C.19 Settings Appearance theme picker

**Item:** `UIX-2026-05-09-007`

Verify the Settings Appearance theme picker shows current theme + persists selection across launches.

**Estimated:** 1 day (UI verify + any minor fixes).

### C.20-C.22 UIX remaining

| Item | Action |
|---|---|
| `UIX-2026-05-09-001` Native theme restoration without overlay/compositing regressions | Test all 4 themes (Classic/Platinum/Ember + dark variants) live; pin invariants |
| `UIX-2026-05-09-002` `.epdoc` routing + formatting command regressions | Verify all formatting commands (bold/italic/code/list/heading) work across epdoc + markdown |
| `UIX-2026-05-09-003` Notes/sidebar performance regression | Already addressed by C.5 NotesSidebar work; verify post-fix |

**Estimated:** 3-4 days combined.

---

## Phase D — Wave F XPC Mastery (CODEX, sequential AFTER A.1 verified)

**Gate:** Phase A.1 MAS Release build with paid Team signing must be green BEFORE starting D. Wave F needs proven signed builds first.

Per `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` (17 sections):

### D.1 VaultXPC service (narrowest entitlements first)

**Source:** XPC_MASTERY §2.2 + §1.4.

**Acceptance:**
- `VaultXPC.entitlements` with `app-sandbox = true` + `application-groups` + `files.bookmarks.app-scope` ONLY (no network.client, no JIT)
- Service exposes vault.* operations via XPC interface
- Main app routes vault operations through XPC service
- Trust attestation per §3
- Source-guard test pins entitlement set + XPC interface shape

**Estimated:** 3-5 days.

### D.2 CapabilityGrant HMAC-SHA256 tokens (in-process first)

**Source:** XPC_MASTERY §4.

**Acceptance:**
- `CapabilityGrant` Rust struct in `agent_core/src/capabilities/` with `bitflags` (TOOL_USE / FILE_READ / FILE_WRITE / VAULT_READ / VAULT_WRITE / NETWORK / COMPUTER_USE etc.)
- HMAC-SHA256 signing with rotating key
- Time-limited (default 5 min)
- Caveat narrowing (e.g., "VAULT_READ scoped to /path/to/note.md only")
- In-process verify path first; XPC wire integration next stage
- Doctrine source-guard test

**Estimated:** 2-3 days.

### D.3 mach-port signaling skeleton

**Source:** XPC_MASTERY §9.

**Acceptance:**
- mach-port created via `xpc_connection_create_mach_service`
- Control plane = typed XPC messages
- Data plane = JSON payload over XPC (text/JSON first; IOSurface comes in D.5)
- Source-guard test + integration test against VaultXPC

**Estimated:** 2 days.

### D.4 AgentXPC service

**Source:** XPC_MASTERY §2.3.

**Acceptance:**
- `AgentXPC.entitlements` with `app-sandbox = true` + `application-groups` + `network.client` (no file access, no JIT)
- Service hosts `agent_core::agent_loop::run_agent_loop` + tool registry
- Main app routes agent runs through XPC service
- Vault operations cross to VaultXPC via capability grants

**Estimated:** 4-6 days.

### D.5 IOSurface zero-copy data plane

**Source:** XPC_MASTERY §9.

**Acceptance:**
- `IOSurfaceRef` allocated in main app
- Passed via `xpc_shmem_create` or FD passing to AgentXPC/ProviderXPC
- Streaming token responses use shared buffer
- 10x+ throughput vs JSON payload at scale

**Estimated:** 3-5 days.

### D.6 ProviderXPC service

**Source:** XPC_MASTERY §2.4.

**Acceptance:**
- `ProviderXPC.entitlements` narrowest of all: `app-sandbox = true` + `application-groups` + `network.client` ONLY (no file access, no JIT, no automation, no bookmarks)
- Service holds cloud provider URLSession + credential access
- Routes all Anthropic/OpenAI/Google/Z.AI/Kimi/MiniMax/DeepSeek/Perplexity HTTP

**Estimated:** 4-6 days.

### D.7 WASMExecXPC service

**Source:** XPC_MASTERY §2.5 + §5 (sandbox-within-sandbox for WASM).

**Acceptance:**
- `WASMExecXPC.entitlements` with `app-sandbox = true` + `application-groups` + `cs.allow-jit` + `cs.disable-library-validation` (needs JIT for Wasmtime)
- Wasmtime + Winch single-pass + pulley-interpreter fallback
- Pyodide-WASM + QuickJS-WASM bundled in `Resources/Wasm/` (~16 MB)
- Sandbox-within-sandbox WASM execution per §5
- Capability-gated execution (no WASM module runs without explicit CapabilityGrant)

**Estimated:** 5-7 days (largest single Wave F item).

### D.8 Per-service trust attestation

**Source:** XPC_MASTERY §3.

**Acceptance:**
- Each XPC service verifies caller's audit token via `xpc_connection_get_audit_token`
- Caller must be from the same Team ID + correct entitlements
- Rejects rogue caller attempts (source-guard test)

**Estimated:** 2 days.

### D.9 Audit trail across XPC boundaries

**Source:** XPC_MASTERY §6.

**Acceptance:**
- Every XPC call emits `AgentEvent` to provenance ledger
- Ledger entries carry source service + target service + CapabilityGrant id + result
- Provenance Console UI shows cross-service flow

**Estimated:** 3-4 days.

### D.10 Secure Enclave attested capability tokens

**Source:** XPC_MASTERY §7.

**Acceptance:**
- Sovereign actions require Secure Enclave–attested CapabilityGrant
- Hardware attestation via `LAContext` + Touch ID re-auth for ≥sensitive class
- One-shot tokens (single use + time-limited)
- Integrates with existing `SovereignGate`

**Estimated:** 3-5 days.

### D.11 Process recycling

**Source:** XPC_MASTERY §8.

**Acceptance:**
- Each XPC service has bounded lifetime / call count
- Service restarts after threshold to limit blast radius
- launchd configuration per §13.2
- Source-guard test pins recycling threshold

**Estimated:** 2 days.

### D.12 In-process bundled MCP (`omega-mcp::inproc::*`)

**Source:** `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` §7.

**Acceptance:**
- `omega-mcp::inproc::*` namespace
- 6 inproc tools: `vault_ops`, `search`, `fetch`, `think`, `todo`, `calc`
- Bypasses XPC for read-only fast-path operations (still routed through capability check)
- Moves Pro-only bundled MCP into Core surface

**Estimated:** 2-3 days.

### D.13 Per-service test harness

**Source:** XPC_MASTERY §11.

**Acceptance:**
- Each service has dedicated test target
- Mock XPC client for unit tests
- Integration test that spawns service + sends real XPC messages
- CI runs all 5 service test targets

**Estimated:** 3-5 days.

---

## Phase E — V1 Submission + 5 Recursive Verification Passes

**Gate:** Phase A complete + Phase B (Wave A1, A4, A5 minimum) + Phase C (C.1, C.7, C.8 minimum) + Phase D Stage 1 (VaultXPC D.1) merged.

### E.1 5 consecutive Codex recursive passes

Codex runs 5 sessions, each:
1. Pulls latest main
2. Reads `RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` cover-to-cover
3. Scans for new issues introduced by recent commits
4. Verifies no new V1 blockers
5. Appends pass record to `CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md` Recursive Pass Log
6. If pass adds a NEW blocker, the counter resets

**Acceptance:** 5 consecutive passes with zero new blockers added.

**Estimated:** 5-7 days (1 pass per day, sometimes 2 if light).

### E.2 Final pre-submission verification

Re-run §4.1 commands from `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md`:
- Build green (Pro + MAS Release)
- All Rust + Swift tests green
- Bundle audits ZERO matches
- App Store scanner PASS
- Codesign confirms sandbox + App Group

### E.3 App Store Connect submission

1. Archive in Xcode Organizer
2. Validate App
3. Distribute App → App Store Connect → Upload
4. In App Store Connect: assign build to version → click Submit for Review

### E.4 Apple review wait

24-72 hours typical. Respond to any reviewer questions promptly.

---

## 2. Cross-reference: every audit register item by phase

| Item | Phase | Status before | Outcome |
|---|---|---|---|
| `V1-GATE-SWIFT-001..004` Swift/Xcode compile | (closed) | PASS after `fbcc0aabb` | already done |
| `V1-GATE-MAS-001..002` App Store artifact scanner + GGUF | (closed) | PASS after `60c3067cb`+`329a0c8b6` | already done |
| `V1-GATE-EPDOC-001` Swift 6 warning | (closed) | PASS | already done |
| `V1-GATE-VAULT-001..002` SwiftData crash + schema | (closed) | PASS scratch soak | already done |
| `V1-GATE-LIVE-MAS-001` MAS simple-rewrite | **A.3** | PATCHED PARTIAL | live smoke |
| `V1-GATE-LIVE-PRO-001` Pro cloud-agent | **A.2** | PATCHED PARTIAL | credential + smoke |
| `V1-GATE-GRAPH-001` graph first-open framing | **A.4** | REOPENED | approval or accept-as-is |
| `V1-GATE-CHAT-001` softer vault query | (closed) | PASS | already done |
| `V1-GATE-NOTES-001` TextKit clamp | (closed) | PASS | already done |
| `V1-GATE-PRO-001` Pro surfaces gating | (closed) | PASS (cloud-key blocked) | unblocked by A.2 |
| `V1-PARTIAL-001` PATCHED PARTIAL set | **C.1-C.22** | OPEN | Phase C |
| `V1-DEAD-001` stale/dead surfaces | (closed) | OPEN → CLOSED | already done in C.15 prior |
| `POSTV1-EXCL-001` post-V1 architecture | (deferred) | DEFERRED-POST-V1 | EXCLUDED |
| `RCA-P0-001` re-audit canonical floor | E.1 | PARTIAL | 5 recursive passes |
| `RCA-P0-002` DB fallback fault-injection | **C.13** | PATCHED PARTIAL | code + tests |
| `RCA-P0-003` hidden capture metadata | **C.1** | PATCHED PARTIAL | migration utility |
| `RCA-P0-004` credential leakage | (closed) | PATCHED PARTIAL → resolved | already done |
| `RCA-P1-001` editor asset reads off main | **C.3** | PATCHED PARTIAL | Brotli on background |
| `RCA-P1-003` launch path | **C.14** | PATCHED PARTIAL | deeper profile |
| `RCA-P1-011` graph scan N+1 | **C.2** | PATCHED PARTIAL | full off-main refactor |
| `RCA-P2-010` orphan candidates | **C.15** | PATCHED PARTIAL | quarantine sweep |
| `RCA-P2-016` SDF label glyph budget | (skip — graph) | PATCHED PARTIAL | C.18 observe only |
| `RCA10-P0-001` hidden capture | **C.1** | PATCHED PARTIAL | migration utility |
| `RCA10-P0-003` DB fallback | **C.13** | PATCHED PARTIAL | fault-injection |
| `RCA10-P1-006` AgentGrep I/O | **C.9** | PATCHED PARTIAL | off-main split |
| `RCA11-P1-002` graph fullscreen perf | (PROTECTED) | OPEN | needs graph approval |
| `RCA11-P1-007` direct code-file I/O | **C.9** | PATCHED PARTIAL | covered by C.9 |
| `RCA11-P2-005` SDF graph label | **C.18** | PATCHED PARTIAL | observe only |
| `RCA12-P1-003` `/image` truth | **C.11** | PATCHED PARTIAL | hide for V1 |
| `RCA12-P1-006` Current Access proof | **C.17** | PATCHED PARTIAL | operator smoke |
| `RCA12-P2-001` three-lane brain | DEFERRED | DEFERRED | excluded |
| `RCA2-P1-008` QueryEngine off-main | **C.2** | PATCHED PARTIAL | full refactor |
| `RCA2-P1-011` NotesSidebar cache | **C.5** | PATCHED PARTIAL | cache + lazy I/O |
| `RCA2-P1-014` `/image` slash | **C.11** | PATCHED PARTIAL | hide for V1 |
| `RCA2-P2-005` Vault Organizer drift | **C.6** | PATCHED PARTIAL | known limitation doc |
| `RCA3-P1-005` graph regression profile | (PROTECTED) | PARTIAL | needs graph approval |
| `RCA3-P2-003` MLX image generation | **C.11** | PATCHED PARTIAL | hide for V1 |
| `RCA4-P1-001` scoped credential delivery | **C.7** | PATCHED PARTIAL | FFI-only |
| `RCA4-P1-002` prose editor reparse | **C.4** | PATCHED PARTIAL | debounced incremental |
| `RCA5-P1-005` mic temp-file | **C.16** | PATCHED PARTIAL | operator smoke |
| `RCA5-P1-006` capture/audio provenance | **C.1** | PATCHED PARTIAL | migration utility |
| `RCA5-P1-007` QueryEngine off-main (dup) | **C.2** | PATCHED PARTIAL | covered by C.2 |
| `RCA5-P1-013` connected-vault to Halo | **C.12** | PATCHED PARTIAL | operator smoke |
| `RCA5-P2-002` ArenaBridge + ANEBackend | DEFERRED | DEFERRED | excluded (V2.4+) |
| `RCA7-P1-003` prose editor pileup | **C.4** | PATCHED PARTIAL | covered by C.4 + C.5 |
| `RCA7-P1-006` verified-write coverage | **C.8** | PATCHED PARTIAL | 5 path closure |
| `RCA9-P0-001` CodeFileService canonical | **C.10** | PATCHED PARTIAL | doc + test |
| `RCA9-P1-007` voice temp-file | **C.16** | PATCHED PARTIAL | operator smoke |
| `RCA12-P1-006` Current Access | **C.17** | PATCHED PARTIAL | operator smoke |
| `UIX-2026-05-09-001..009` UI items | **C.19-C.22** | PARTIAL | each addressed |

---

## 3. Dependency graph (parallel where possible)

```
[Phase A — V1 Ship Gates]
  A.1 MAS Release build verification  ──┐
  A.2 Provider credential smoke         ──┤
  A.3 MAS simple-rewrite smoke          ──┤───→ [Phase D gate]
  A.4 Graph framing decision            ──┤
  A.5 App Store Connect metadata        ──┤
  A.6 TestFlight soak                   ──┘

[Phase B — Wave A No-Compromise]
  B.1 Variant Ladder (vault.search)  ───────→ [Phase E recursive]
  B.2 PR-description sweep           ─┐
  B.3 escalate_on_empty default      ─┤
  B.4 reasoning token cap            ─┼─→ ...
  B.5 epistemos.*.v1 schemas         ─┤
  B.6 Cognitive Weight W1            ─┤
  B.7 Knowledge Sieve                ─┤
  B.8 clarify UI card                ─┤
  B.9 NightBrain task bodies         ─┘

[Phase C — Audit PARTIAL closure]
  C.1 hidden capture migration       ─┐
  C.2 QueryEngine off-main           ─┤
  C.3 Brotli off main                ─┤
  C.4 prose debounced reparse        ─┤
  C.5 NotesSidebar cache             ─┤
  C.6 Vault Organizer doc            ─┤
  C.7 FFI-only credentials           ─┼─→ ...
  C.8 verified-write coverage        ─┤
  C.9 AgentGrep I/O                  ─┤
  C.10 CodeFileService canonical     ─┤
  C.11 /image hide                   ─┤
  C.12-C.18 operator smokes          ─┤
  C.19-C.22 UIX                      ─┘

[Phase D — Wave F XPC Mastery]  (gated on A.1 + Pro signed build proven)
  D.1 VaultXPC ────→ D.2 CapabilityGrant ──┐
                D.3 mach-port signaling    ─┤
                D.4 AgentXPC               ─┤
                D.5 IOSurface              ─┼─→ [Phase E recursive]
                D.6 ProviderXPC            ─┤
                D.7 WASMExecXPC            ─┤
                D.8 trust attestation      ─┤
                D.9 audit trail            ─┤
                D.10 Secure Enclave        ─┤
                D.11 process recycling     ─┤
                D.12 in-proc MCP           ─┤
                D.13 test harness          ─┘

[Phase E — Submission]
  E.1 5 recursive passes  ──→ E.2 final verification ──→ E.3 submit ──→ E.4 review wait
```

---

## 4. Effort budget summary

| Phase | Item count | Est days (Codex single-threaded) | Est days (Codex 3-track parallel) |
|---|---|---|---|
| A — V1 Ship Gates (user) | 6 | 1-2 (user-driven, mostly admin) | same |
| B — Wave A | 9 | 25-35 | 10-15 |
| C — Audit PARTIAL | 22 | 35-50 | 15-20 |
| D — Wave F XPC | 13 | 40-55 | 20-25 |
| E — Submission | 4 | 5-7 | 5-7 |
| **TOTAL** | **54 items** | **~110-150 days** | **~50-70 days** |

**Realistic wall-clock target:** 8-12 weeks of focused Codex execution + user actions, assuming 3 parallel tracks (B, C, D) with C+D sometimes blocked on B's deterministic primitives.

**Faster path** if you want to ship MAS V1 in **3-5 weeks**:
- Phase A (1-2 days user)
- Phase B subset: just B.1 (Variant Ladder retrofit), B.4 (reasoning cap), B.5 (schemas)
- Phase C subset: just C.1 (hidden capture migration), C.7 (FFI credentials), C.8 (verified writes), C.11 (/image hide), C.12, C.16, C.17 (operator smokes)
- Phase D subset: just D.1 (VaultXPC) + D.2 (CapabilityGrant)
- Phase E (5 passes + submit)

Then ship V1, and the remaining B/C/D items become V1.1, V1.2, V1.3 incremental releases.

---

## 5. Acceptance bars summary

### To start Phase D (XPC Mastery)
- ✅ MAS Release build signs cleanly with paid Team
- ✅ App Group lands in both Pro + MAS Release signed bundles
- ✅ All Phase A user-action gates resolved

### To start Phase E (Submission)
- ✅ Phase A complete (all 6 sub-gates green)
- ✅ Phase B core items (B.1, B.4, B.5) merged
- ✅ Phase C core items (C.1, C.7, C.8, C.11, C.12, C.16, C.17) merged
- ✅ Phase D Stage 1 (D.1 VaultXPC + D.2 CapabilityGrant) merged
- ✅ All Rust + Swift tests green
- ✅ MAS bundle leak audits ZERO matches
- ✅ App Store scanner PASS

### To click Submit for Review
- ✅ Everything above
- ✅ 5 consecutive Codex recursive passes find zero new V1 blockers
- ✅ TestFlight internal soak passed
- ✅ App Store Connect metadata 100% complete + URLs live

---

## 6. The 8-question PR discipline (every PR in B/C/D)

Per `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §6:

1. **Stage / Wave** — which phase + sub-item?
2. **GenUI route** — new renderer? Through dispatcher per `COGNITIVE_GENUI_DOCTRINE` §6?
3. **Sovereign** — any destructive action? Through Sovereign Gate?
4. **Pro impact** — `#[cfg(feature = "pro-build")]` / `#if EPISTEMOS_APP_STORE` gated correctly? MAS symbol-clean?
5. **App Group** — touches `arena.dat` / shared container path?
6. **Variant Ladder** — new tool route? `## Variant Ladder` PR section per `COGNITIVE_VARIANT_LADDER_DOCTRINE` §4.1?
7. **Atlas update** — changes a concept in `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §2 Atlas? PR appends row?
8. **Disambiguation** — uses a polysemous term ("Shadow", "Helios", "Hermes", "WBO", "EML", "Tier", "Residency", "Variant Ladder", "VRM")? Cites which sense?

---

## 7. Cross-references

### Top floor
- `CLAUDE.md` · `AGENTS.md` · `docs/MAS_RELEASE_MANIFEST_2026_05_13.md` · `docs/MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md`

### Doctrines (every PR in B/C/D checks against these)
- `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` (Phase D primary source)
- `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` (B.1-B.4)
- `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` (B.6)
- `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` (B.8)
- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` (D.12)
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` (Phase 8.A-G LANDED; 8.H deferred)
- `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` (all FFI work)
- `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` (Pro/MAS gating discipline)
- `docs/fusion/LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` (NightBrain integration B.9)
- `docs/fusion/LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04.md` (all PRs)

### Audit registers
- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` (Phase C source of truth)
- `docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md` (recursive protocol)
- `docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md`
- `docs/CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md` (Codex's master audit)
- `docs/CODEX_V1_CLOSURE_VERIFICATION_2026_05_14.md` (Claude's verification)

### Research source library
Per `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §5 — 60+ docs across primary doctrines, audit registers, Helios chain, Jordan's executive-add research, Kimi deep research, kimi-latest, simulation canon, Quick Capture canon, GPT Research workspace, Substrate V2 closure.

---

## 8. Implementation Log

Codex/Claude append rows here as items ship. Required fields: date · phase · item · commit · acceptance evidence · WRV status.

| Date | Phase | Item | Commit | Acceptance evidence | WRV status |
|---|---|---|---|---|---|
| 2026-05-14 | A | Paid Apple Developer + App Group restoration end-to-end | `6ccb26068` + `cb4a38f8d` | Apple Developer paid + App Group registered + 3 entitlements files restored + Pro Debug signed bundle confirms App Group via codesign | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-14 | (urgent) | Tantivy LockBusy retry + stale-lock recovery + read-only fallback (RCA-VAULT-LOCKBUSY-001) | `f7f3c273a` | `cargo test --manifest-path agent_core/Cargo.toml --lib` => 1098 passed, 0 failed | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-14 | (urgent) | Local-agent: exclude Gemma 3/4 + Mistral from canActAsAgent (RCA-LOCAL-AGENT-GRAMMAR-001) | `930b86989` | `xcodebuild -scheme Epistemos build` => BUILD SUCCEEDED; agent-tier router now escalates Gemma/Mistral agent-intent queries to Qwen or cloud loop | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-14 | C.15 | Orphan/scaffold quarantine — KaTeXSnippets + KIVIQuantization + variant_ladder canonical SCAFFOLD-ONLY headers + RCA-P2-010 row closure | `06819a33a` | cargo build clean + xcodebuild BUILD SUCCEEDED + 3 surfaces marked + audit row updated | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-14 | C.6 | Vault Organizer V1 known-limitation tooltip (RCA2-P2-005) | `8547c0aa9` | xcodebuild BUILD SUCCEEDED + `.help(...)` tooltip on `.moveToFolder` row + audit row updated with V1.1 deferral note | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-14 | C.10 | CodeFileService canonical first-fix-pass collapse (RCA9-P0-001) | `504c2696d` | RCA9-P0-001 status flipped to PATCHED 2026-05-14 + canonical-owner pointer to RCA4-P0-001 + 5-test drift-gate suite cited by name | ✅ Wired+Reachable+Visible+Verified |

## 9. Atlas Drift Log

Append here only if `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §2 falls out of sync with main.

| Date | Atlas row | Stated status | Actual status | Action |
|---|---|---|---|---|
| — | — | — | — | — |

## 10. Compromises Recorded

Append here only when constraints force deferral — no silent compromises.

| Date | Item | Source doc | Compromise | Trigger to revisit |
|---|---|---|---|---|
| — | — | — | — | — |

---

*— End of MAS Complete Fusion Implementation Plan. 54 items across 5 phases. POSTV1 exclusions explicitly excluded. Every PATCHED PARTIAL / OPEN audit item not in exclusions has a phase + acceptance bar. Wave A + Wave F + all V1 ship gates + recursive audit closure all covered. No drift, no compromise except Pro-only-by-MAS-sandbox-rule.*
