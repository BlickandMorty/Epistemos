# MAS Final Stretch — No Nuance Lost
**Date:** 2026-05-14
**Trigger:** Paid Apple Developer Program activated → App Group restored → final stretch to MAS submission
**Author:** Claude (Opus 4.7, 1M context)
**Status:** WORKING DOC — promote to floor after first Codex verification pass

This doc is the **single congregated truth** for everything needed to submit Epistemos to the Mac App Store with no compromises (except Pro-only features which are excluded by MAS sandbox rule, not by deferral). Every concept from every relevant research/doctrine/audit doc is pinned here with status, source, and next move.

If a concept relevant to MAS shipping is in research and missing here, **this doc is wrong** — append a row.

---

## 0. The 4 immutable rules for the final stretch

1. **Graph is protected.** No camera / renderer / layout / edges / physics / hologram changes without explicit scoped approval. Chat composers inside the inspector are OK to modify per prior precedent.
2. **Vault is sensitive.** No reset / delete / casual migration. Vault fixes start with evidence, minimal rationale, rollback-safe plan.
3. **No Pro features bleed into MAS.** `mas-build` Cargo feature gates everything `#[cfg(feature = "pro-build")]`. Per-target Swift `#if EPISTEMOS_APP_STORE` gates Swift-side Pro-only files. Symbol-leak audits stay green.
4. **No silent fallbacks.** Defer is a first-class outcome. Every cap-gated thing has either a working implementation, a clear stub with denial copy, or a documented row here.

---

## 1. What's just landed (paid Apple Developer activation chain)

### 1.1 Entitlements restoration — VERIFIED
| File | App Group key | Verified in signed bundle |
|---|---|---|
| `Epistemos/Epistemos-AppStore.entitlements` (MAS Debug + Release) | ✅ `group.com.epistemos.shared` | Pending Release build completion |
| `Epistemos/Epistemos.entitlements` (Pro Release) | ✅ `group.com.epistemos.shared` | Same |
| `Epistemos/Epistemos-Debug.entitlements` (Pro Debug — easy-miss file) | ✅ `group.com.epistemos.shared` | **YES — codesign confirmed `application-groups` key with `group.com.epistemos.shared` value** |
| `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` §4.5 | ✅ promoted to RESTORED 2026-05-14 | Doc |

### 1.2 Apple Developer Portal — VERIFIED (per user)
- ✅ Membership Active
- ✅ App Group `group.com.epistemos.shared` registered
- ✅ App IDs `com.epistemos.appstore` + `com.epistemos.app` with App Groups capability configured

### 1.3 Xcode signing — VERIFIED
- ✅ New paid Team ID `3BNL2669SL` in `Epistemos.xcodeproj/project.pbxproj` (replaced `AL562BVF23` Personal Team)
- ✅ Both Epistemos and Epistemos-AppStore targets re-signed with paid Team
- ✅ Pro Debug build succeeds + App Group lands in signed bundle (`codesign -d --entitlements` confirms)

### 1.4 What this unlocks (Wave F — XPC Mastery)
The full Wave F (`docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md`) is now actionable:

| Sub-wave | Item | Source |
|---|---|---|
| **F1** | Pay $99 Apple Developer | ✅ DONE |
| **F2** | Restore App Group entitlement | ✅ DONE this commit chain |
| **F3** | 5-service XPC decomposition (Main + VaultXPC + AgentXPC + ProviderXPC + WASMExecXPC) | XPC_MASTERY §1 |
| **F4** | CapabilityGrant HMAC-SHA256 + bitflags + time-limited + caveat narrowing | XPC_MASTERY §4, `hermes_gateway_architecture.md` |
| **F5** | mach-port signaling + xpc_shmem / IOSurface / FD passing zero-copy data plane | XPC_MASTERY §9, `hermes.md` |
| **F6** | WASM exec service (Wasmtime + Pyodide-WASM + QuickJS-WASM, ~16 MB; Winch + pulley-interpreter fallback) | XPC_MASTERY §5, `COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` §6 |
| **F7** | In-process bundled MCP `omega-mcp::inproc::*` for vault_ops / search / fetch / think / todo / calc | `COGNITIVE_KERNEL_DOCTRINE` §7 |
| **F8** | Per-service entitlements (per `XPC_MASTERY` §2) — `VaultXPC.entitlements` (App Group + bookmarks), `AgentXPC.entitlements` (App Group + network.client), `ProviderXPC.entitlements` (App Group + network.client only, narrowest), `WASMExecXPC.entitlements` (App Group + allow-jit + cs.disable-library-validation) | `XPC_MASTERY` §2.1-2.5 |
| **F9** | Trust attestation between services (XPC_MASTERY §3) | XPC_MASTERY §3 |
| **F10** | Audit trail across XPC boundaries → AgentEvent + Provenance ledger | XPC_MASTERY §6 |
| **F11** | Secure Enclave hardware-attested capability tokens (sovereign actions) | XPC_MASTERY §7 |
| **F12** | Process recycling (limit blast radius) | XPC_MASTERY §8 |

**Estimated wall-clock:** 2-4 weeks for F3-F12. F2 was today's unlock.

### 1.5 What's STILL gated externally (not unlocked by App Group alone)

| Gate | Unblocks |
|---|---|
| **NousResearch licensing decision** | V2.6 brand assets — Inter + JetBrains Mono OFL fonts already public-domain-safe (✅ Inter survives), but Hermes wordmark + NR logo require written permission. **MAS does NOT need NR brand** — the architectural positioning from `hermes.md` survives; the Hermes UI overlay was already PURGED 2026-05-05. **NOT a MAS-shipping blocker.** |
| **TestFlight beta** | Internal/external testing before App Store submission. Recommended after Wave F4. |
| **Apple App Review** | Submission itself. Triggers only when you click "Submit for Review" in App Store Connect. |

---

## 2. Concept Atlas — every MAS-relevant primitive named, no drift

The atlas is the no-drift contract for MAS final stretch. Each row names the concept, where it came from, current status against `main`, and the code anchor if shipped.

### 2.1 Build identity (App Store target)

| Field | Value | Source |
|---|---|---|
| Scheme | `Epistemos-AppStore` | `MAS_RELEASE_MANIFEST_2026_05_13.md` |
| Bundle ID | `com.epistemos.appstore` | same |
| Swift compile flag | `EPISTEMOS_APP_STORE` set | same |
| `agent_core` Cargo features | `mas-build,lsp-runtime` (no defaults) | same |
| Sandbox | `app-sandbox = true` (Release) | `Epistemos-AppStore.entitlements` |
| App Group | `group.com.epistemos.shared` — **RESTORED 2026-05-14** | this doc + entitlements files |
| JIT | `allow-jit = true` (MLX shader compilation) | entitlements |
| File access | `files.user-selected.read-write` + `files.bookmarks.app-scope` | entitlements |
| Network | `network.client = true` (URLSession HTTPS only) | entitlements |
| Code Signing | Apple Distribution (paid Team `3BNL2669SL`) | pbxproj |

### 2.2 MAS shipping tool surface — 30 canonical names

Per `Epistemos/Bridge/ToolTierBridge.swift::coreAppStoreAllowedToolNames` and `MAS_RELEASE_MANIFEST_2026_05_13.md` §Tool surface:

**Vault + filesystem (vault-scoped)**: `vault.search` · `vault.read` · `vault.write` · `vault.list` · `file.read` · `file.write` · `file.patch` · `file.search`

**System**: `system.todo`

**Graph + memory**: `graph.query` · `graph.neighbors` · `graph.vault_navigate` · `memory.curated`

**Web (HTTPS via URLSession, no subprocess)**: `web.search` · `web.extract` · `web.crawl` · `web.fetch`

**Vault knowledge**: `knowledge.recall` · `knowledge.contradiction_check` · `knowledge.evidence_score` · `knowledge.session_search` · `knowledge.neural_recall`

**Note authoring**: `note.create` · `note.edit` · `note.research_digest` · `note.template` · `note.linker`

**Composer helpers**: `clarify.ask` · `research.collect_snippet` · `research.search_papers` · `citation.save` · `chunk.reduce`

**MAS preflight forbids** (`agent_core/src/tools/registry.rs::mas_forbidden_tool_name`): `action.bash` · `action.terminal` · `bash_execute` · `run_command` · `run_persistent` · `terminal` · `process` · `system.process` · `cronjob` · `system.cron`

**MAS bounded internal mutation allowlist** (`mas_allows_bounded_internal_mutation`): `memory` (add/replace/remove/read) · `ssm_resume` (save/load/list/prune) — everything else fails closed.

### 2.3 Features EXPLICITLY DENIED on MAS (with denial copy)

Per `MAS_RELEASE_MANIFEST_2026_05_13.md` §Features EXPLICITLY DENIED. Each returns the standardized denial string `"Native computer-use automation is unavailable in the App Store build."` or equivalent:

| Surface | Denial mechanism | Status |
|---|---|---|
| Subprocess execution (`bash`, `cli_passthrough`, `terminal`, `process`, `cronjob`) | `mas-build` Cargo feature `#[cfg]`-gates entire modules out | ✅ ZERO matches in `nm -gU` audit |
| Computer use (`computer`, `perceive`, `interact`, `screen_watch`) | Swift `AppStoreComputerUseStubs.swift` `#if EPISTEMOS_APP_STORE` returns denial constant | ✅ shipped |
| `checkPermissions()` | Returns `.denied` for accessibility + automation; `.unknown` for screen recording | ✅ shipped |
| Browser MCP | Not in MAS tool list; Chrome extension shim Pro-only | ✅ |
| iMessage outbound | Subprocess-based AppleScript, Pro-only | ✅ |
| Apple apps via osascript | Subprocess-based, Pro-only | ✅ |
| Python / MoLoRA / KnowledgeFusion training | `#if !EPISTEMOS_APP_STORE` gated; sandbox-forbidden anyway | ✅ |
| CLI discovery health row | Entire file gated `#if !EPISTEMOS_APP_STORE` 2026-05-13 | ✅ |
| Embodied capture (screencapture subprocess) | Wholesale `#if !EPISTEMOS_APP_STORE` | ✅ |
| GGUF llama runtime | App Store target no longer links `GGUFRuntimeBridge`; Pro keeps it | ✅ V1-GATE-MAS-002 |
| `_popen` from MLX | `scripts/patch_mlx_metal_warnings.sh` mitigates pre-Release | ✅ `edc7d5513` |

### 2.4 Hardening floor (re-verified live 2026-05-14)

| Defense | File | Status |
|---|---|---|
| `harden_cli_subprocess` + 10-var allowlist + 24-vector denylist + `kill_on_drop` + `process_group(0)` | `agent_core/src/security.rs` | ✅ MATCHES — applied at 10+ sites |
| `mas_runtime_preflight` | `agent_core/src/tools/registry.rs` line 76+ | ✅ MATCHES — forbids 10 dangerous tools + bounds mutating to memory/ssm_resume |
| `SanitizedEnvironment.build()` Swift subprocess scrubbing | 5 Swift Process launchers | ✅ MATCHES (RCA-P0-004 PATCHED 2026-05-14) |
| API keys in macOS Keychain | `SecItemAdd` / `SecItemCopyMatching` | ✅ MATCHES |
| Sandbox entitlement minimal | `Epistemos-AppStore.entitlements` | ✅ MATCHES (now with App Group restored) |
| OAuth callback loopback bind + forged-state rejection | `LocalOAuthCallbackServer` + live `lsof` test | ✅ MATCHES (RCA12-P1-007 PATCHED 2026-05-14) |
| AgentAuthority dispatch enforcement | `AgentAuthorityPersistenceTests` | ✅ MATCHES (RCA5-P2-003 PATCHED 2026-05-14) |
| File write denial without R.5 grant | `ResourceRuntimeToolPathE2ETests::fileWriteWithoutGrantIsRejectedAndPreservesDisk` + Rust `verified_write_bridge_denies_when_no_grant_covers_resource` | ✅ MATCHES (RCA10-P0-004 PATCHED 2026-05-14) |
| Child-process credential scrub (Rust side) | `omega-mcp/src/osascript.rs`, `omega-ax/src/shortcuts.rs` | ✅ MATCHES |

### 2.5 Agent runtime — both local and cloud work in MAS

**Local agent in MAS:**
- `LocalToolGrammar.supportsLocalAgentLoop` = `supportsStructuredToolCalling || supportsSoftGuidanceToolCalling`
- `supportsSoftGuidanceToolCalling` is always-on → MAS local agents drive the tool loop via soft-guidance fallback even when MLXStructured + CMLXStructured + JSONSchema not linked
- `LocalAgentLoop.liveLoop` reached from `PipelineService.runToolLoop` for Local Fast / Thinking / Pro
- Tool tier mapping: `.fast` / `.thinking` → `chat_lite` · `.pro` → `chat_pro` · `.agent` → `agent`

**Cloud agent in MAS:**
- `bridge.rs::run_agent_loop` is **NOT** `#[cfg(feature = "pro-build")]` gated → fully reachable in default mas-build
- USABILITY-001 fix chain (`15e0e2da8` + `951a74c38` + `3a43066df` + `f5f50d0ac`) routes Pro/Fast/Thinking + OpenAI/Anthropic through `runRustAgentPath` with tier-mapped tools
- Native cloud tools (web_search / web_fetch / code_execution / google_search) attach automatically per provider when user prefs enable (all default `true`)

**Honest gating:**
- Anthropic + OpenAI → `supportsAgentTier == true` → Rust agent loop
- Google / Z.AI / Kimi / MiniMax / DeepSeek → `supportsAgentTier == false` → direct stream + native cloud tools only (no app tools); composer banner nudges to switch to OpenAI for agent intent (commit `951a74c38`)

### 2.6 V6.2 substrate (target-only for MAS — already LIVE where it matters)

Per `docs/audits/V6_2_SESSION_PROGRESS_2026_05_12.md`:

| Item | Status for MAS | Anchor |
|---|---|---|
| Per-bubble `VRMLabelView` chip | ✅ LANDED via `LatestAnswerPacketSink` + `answerPacketId` binding | `Epistemos/Views/Chat/MessageBubble.swift` line 477 |
| `WBOSubstrateObserver` (TruthCache + retraction propagation) | ✅ LANDED 2026-05-12 | `Epistemos/Engine/InterruptScoreCpu.swift` |
| `SheafResidualSubstrateObserver` (contradicts_edge_count) | ✅ LANDED 2026-05-12 | same |
| `ConnectomeAlarmSubstrateObserver` (routing stats delta) | ✅ LANDED 2026-05-12 | same |
| Rust AnswerPacket production caller | ✅ LANDED 2026-05-12 | `agent_core/src/scope_rex/produce.rs` + `bridge::produce_answer_packet_json` |
| `InterruptScoreCpu` Swift CPU canonical | ✅ LANDED 2026-05-12 | `Epistemos/Engine/InterruptScoreCpu.swift` |
| 5 Helios Metal kernels (SemiseparableBlockScan / LocalRecallIsland / PageGather / ControllerKernelPack / PacketRouter1bit) | ⏳ research-tier target-only, NOT blocking MAS ship | `docs/fusion/helios v6.2.md` §1.4 |
| 30-task calibration corpus | ⏳ post-V1 | `helios v6.2.md` §1.5 |
| Lean stack (4.29.1 + mathlib v4.29.0-rc6) | ⏳ post-V1 | V6.1 intake |
| EML floor (oxieml + eml-lean + F-ULP-Oracle + morph_eval_reduced.metal v0.1) | ⏳ post-V1 | V6.1 intake |

### 2.7 Provenance ledger + Cognitive DAG (Phase 8.A-8.G LANDED)

| Item | Status | Anchor |
|---|---|---|
| `ClaimLedger` retraction propagation | ✅ MATCHES | `agent_core/src/provenance/ledger.rs` |
| `ReplayBundle` + `LedgerSnapshot` + `DagSnapshot` (schema v1/v2) | ✅ MATCHES | `agent_core/src/provenance/replay.rs` |
| `MutationEnvelope` end-to-end | ✅ MATCHES | `agent_core/src/mutations/` + `Epistemos/Models/MutationEnvelope.swift` |
| `LedgerEvent::RetractionPropagated` | ✅ MATCHES (commit c78deb17) | — |
| Provenance Console | ✅ MATCHES (shipped 2026-05-04 ad6280cf) | `Epistemos/Views/Provenance/` |
| `epistemos_trace verify | verify-replay` CLI | ✅ MATCHES | `agent_core/src/bin/epistemos_trace.rs` |
| Cognitive DAG: 10 NodeKinds, 10 EdgeKinds, BLAKE3 Merkle, redb store, macaroons (orphan-by-doctrine until 8.H), companions, 4 DagMirrors, dispatch, doctrine-lint CLI | ✅ Phase 8.A-8.G LANDED | `agent_core/src/cognitive_dag/` |
| Phase 8.H (ship + paper) | ⏳ post-V1 | — |

### 2.8 SCOPE-Rex substrate (partial; doesn't block MAS)

| Component | Status | Anchor |
|---|---|---|
| AnswerPacket | ✅ shipped | `agent_core/src/scope_rex/answer_packet.rs` |
| produce | ✅ shipped | `agent_core/src/scope_rex/produce.rs` |
| residency | ✅ scaffold | `agent_core/src/scope_rex/residency.rs` |
| witnessed_state | ✅ scaffold | `agent_core/src/scope_rex/witnessed_state.rs` |
| btm_semantic | ✅ scaffold | same dir |
| feature_observatory | ✅ scaffold | same dir |
| ontology | ✅ scaffold | same dir |
| kernels / kv / metal / retrieval | ✅ scaffold dirs | same dir |
| State vector S_t (h_t, z_t, g_t, p_t, m_t, w_t, ℓ_t, u_t) | ⏳ doctrine; partial via existing primitives | `scope rex omega.md` |
| 9-arm Kleene K3 classifier (currently 5-arm) | ⏳ Wave E5 post-V1 | `helios v5 first.md` §1.5 |
| 5 directional operators (Up/Down/Sideways/Inward/OnItself) | ⏳ Wave E4 post-V1 | `ternary_reconceptualization.md` |
| Sinkhorn-projected routing matrix | ⏳ Wave E2 post-V1 | `scope rex omega.md` |
| Brain(τ) reconstruction rule | ⏳ Wave E3 post-V1 | same |

### 2.9 Resonance Gate / Σ-signature

| Concept | Status | Anchor |
|---|---|---|
| 7-field Σ-signature {τ, δ, π, ρ, κ, η, λ} | ✅ MATCHES — full Rust seam | `agent_core/src/resonance/{tau,pi,lambda,delta,rho,kappa,eta,mod}.rs` |
| `compute_signature_core` FFI | ✅ MATCHES (commits 06230e8d + 07e33fed) | `agent_core/src/bridge.rs` |
| Knowledge Sieve + Gap Winner Rule + No-Later-Simpler-Composite | ⏳ Wave A7 post-V1 | `ternary_reconceptualization.md` |
| No τ=-1 reaches user invariant (cognitive immune system) | ✅ MATCHES — Resonance Gate principle | — |

### 2.10 Sovereign Gate

| Concept | Status | Anchor |
|---|---|---|
| 5 action classes: Trivial / Reversible / Sensitive / Destructive / Sovereign | ✅ MATCHES | `Epistemos/Engine/SovereignGate.swift` |
| Single LAContext owner | ✅ MATCHES | SovereignGate singleton |
| Session Authority Token (5 verdicts) | ✅ MATCHES | SovereignGate state machine |
| Touch ID + Secure Enclave + `kSecAccessControlBiometryCurrentSet` | ✅ MATCHES (CVE-2025-31191 mitigation) | Keychain bridges |

### 2.11 Halo / Shadow / Contextual Shadows

| Concept | Status | Anchor |
|---|---|---|
| Tantivy 0.22 BM25 + usearch 2.24 HNSW + RRF k=60 | ✅ MATCHES | `epistemos-shadow` crate |
| Honest-handle FFI (`shadow_handle_open_at`) | ✅ MATCHES | `Epistemos/Engine/RustShadowFFIClient.swift` |
| `HaloController`, `ShadowSearchService`, `ShadowIndexingService` | ✅ MATCHES | `Epistemos/Engine/` |
| 6-state FSM (dormant → watching → encoding → searching → available → open) | ⏳ Wave D1 post-V1 | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.3 |
| Model2Vec encoder | ⏳ Wave D2 post-V1 | doctrine §4.3 |
| Non-activating NSPanel surface | ⏳ Wave D3 post-V1 | doctrine §4.3 |
| Eidos companion pairing | ⏳ Wave D4 post-V1 | doctrine + CANON_GAPS C9 |

### 2.12 Variant Ladder (hyper-deterministic schemas) — DRIFTED, Wave A1

| Concept | Status | Anchor |
|---|---|---|
| `LadderTier` enum (Deterministic / Embedding / Classical / SmallLLM / MidLLM / Cloud) | ✅ seam LANDED | `agent_core/src/variant_ladder/mod.rs` |
| `LadderVariant<I,O>` trait | ✅ seam LANDED | same |
| `VariantLadder<I,O>` struct + `LadderError::OutOfOrder` | ✅ seam LANDED | same |
| **Live callers in production tool routes** | ❌ ZERO — orphan seam | dispatcher.rs |
| Route-capture reference impl | ✅ shipped (narrow domain only) | `agent_core/src/route/variant_{a,b,c,b_classifiers,c_providers}.rs` |
| FLOOR_T1 / T2 / T3 confidence thresholds | ⏳ Wave A1 | `deterministicapp.md` §2.0 |
| `escalate_on_empty: false` default + opt-in gate | ⏳ Wave A3 | `COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` §6 |
| LadderLog → Provenance Console | ⏳ Wave A | doctrine §5 |

### 2.13 GBNF / structured output

| Concept | Status | Anchor |
|---|---|---|
| `LocalToolGrammar` + MLXStructured + CMLXStructured + JSONSchema | ✅ MATCHES | `Epistemos/LocalAgent/LocalToolGrammar.swift` |
| Soft-guidance fallback always-on | ✅ MATCHES | same |
| Per-tool `&'static str` GBNF at registration | ⏳ DRIFTED-but-equivalent (compiled per call) | — |
| `reasoning` field ≤256 token cap (≤32 for Qwen 7B) | ⏳ Wave A4 NOT-ENFORCED | `deterministicapp.md` §1, `helios v3.md` |

### 2.14 GenUI dispatcher

| Concept | Status | Anchor |
|---|---|---|
| Schema-first dispatcher with typed GenUIPayload | ✅ MATCHES (Stage A.4 2026-05-04) | `Epistemos/GenUI/` |
| 7 base schemas + 8 new (keyValueTable / commandReceipt / actionPanel / errorReport / progressIndicator / capabilityList / searchResultSet / provenanceTrace) | ✅ PARTIAL — 7 base shipped, 8 new partial | dispatcher registry |
| Determinism contracts (content-based equality, sorted-keys canonical JSON, exhaustive switch test) | ✅ MATCHES (Stage A.2) | tests |
| `GENUI-DEFER:` markers | ✅ 0 today | — |
| `clarify` tool UI card | ⏳ Wave A8 — `clarify.ask` is on MAS allowed list but UI renders generic message | MAS Release Manifest §Composer helpers |

### 2.15 Cognitive Weight Class (W1)

| Concept | Status | Anchor |
|---|---|---|
| 4 tiers (Soft / Preferred / Strong / Policy-grade) seam | ✅ seam LANDED | `agent_core/src/cognitive_weight/mod.rs` |
| W1 read-only metadata (Halo + composer badge) | ⏳ Wave A6 NOT-LIVE | doctrine §3 |
| W2 Wave 7 policy_grade ENFORCEMENT | ⏳ Wave 7 post-V1 | `LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` integration |

### 2.16 Skill / procedural memory / self-evolution / NightBrain

| Concept | Status | Anchor |
|---|---|---|
| Skills / procedural / self-evolution / tool-call parsing | ✅ LANDED | `agent_core/src/agent_runtime/` |
| NightBrain: 10 task names registered | ✅ shipped | `agent_core/src/nightbrain/live.rs` |
| NightBrain: task bodies (currently NoOp placeholders) | ⏳ Wave A9 | same |
| Live File Compiler (Wave 7) | ⏳ post-V1; seam at `agent_core/src/live_files/mod.rs` | `LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` |

### 2.17 LSP runtime (V2.3 LANDED)

| Concept | Status | Anchor |
|---|---|---|
| In-process Rust LSP runtime (tower-lsp + tree-sitter) | ✅ LANDED 2026-05-05 | `agent_core/src/lsp_runtime/` |
| Swift `RustLSPTransport` | ✅ LANDED | `Epistemos/Engine/RustLSPTransport.swift` |
| Subprocess `LSPServerProcess` deleted (V2.3 Stage E) | ✅ LANDED commit 813c15dd | — |
| Richer semantic LSP (cross-file symbol index, scope-aware resolution, diagnostics, completion, references, rename, DAG symbol mirroring) | ⏳ V2.3 queued (autonomous) | `SUBSTRATE_V2_FINAL_CLOSEOUT_2026_05_05.md` |

---

## 3. The complete V1 ship readiness matrix (post-paid-Developer)

Codex's audit (`docs/CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md`) recorded 187 PATCHED, 23 PATCHED PARTIAL, 1 OPEN, 2 DEFERRED, 0 TODO. The remaining work:

### 3.1 GREEN (verified live 2026-05-14)

| Item | Evidence |
|---|---|
| Swift/Xcode test compile (`SDPageQueryDescriptorTests` + `ThemePairTests` + `RuntimeValidationTests`) | ✅ commit `fbcc0aabb` |
| MAS artifact scanner | ✅ commit `60c3067cb` |
| MAS GGUF llama exclusion | ✅ commit `329a0c8b6` Release wrapper clean |
| Epdoc Swift 6 sending warning | ✅ actor-safe URL scheme |
| RCA8-P0-003 SwiftData/vault crash | ✅ `VaultIndexActor` primitive snapshot before async; MAS+Pro scratch soak PASS |
| ZWIKILINKREFERENCESCANSIGNATURE schema repair | ✅ additive idempotent SQLite repair |
| MAS bundle leak audit (`strings` + `nm`) | ✅ ZERO matches (re-verified 2026-05-13 + 2026-05-14) |
| 3,059 Rust tests | ✅ agent_core mas-build 1098 + pro-build 1311 + omega-mcp 145 + omega-ax 13 + epistemos-research 492 — all green |
| Native cloud tools (Anthropic web_search/web_fetch/code_execution + OpenAI web_search + Google google_search) | ✅ defaults TRUE per `InferenceState` lines 3286-3321 |
| OAuth callback loopback + forged-state rejection | ✅ live `lsof` test |
| Provider diagnostics detect account sessions | ✅ Settings → APIKeysHealthRow surfaces OAuth, not just keys |
| Visual/theme work (Platinum default + readable fonts + sidebar glass + graph note transparency) | ✅ commits `07e5f7a50` + `4b040a8e8` + `c82707faf` |
| Per-tool Sovereign Gate routing | ✅ `RCA5-P2-003` PATCHED |
| File write denial without R.5 grant | ✅ `RCA10-P0-004` PATCHED |
| Child-process credential scrub (Swift + Rust) | ✅ `RCA-P0-004` PATCHED |
| Note ask-bar TextKit line-range clamp | ✅ `RCA-NOTES-001` PATCHED |
| Chat intent classifier softer vault queries | ✅ `RCA-CHAT-001` PATCHED |

### 3.2 USER-ACTION REQUIRED (this is the final stretch)

| Item | What you do | Estimated time |
|---|---|---|
| **V1-GATE-LIVE-PRO-001 cloud-agent smoke** | Add **one provider credential** (OpenAI or Anthropic OAuth or API key) in Pro Settings → diagnostics shows account session → run one cloud chat with vault tool query | 5-10 min |
| **First-run web-approval live smoke** | Same credential unblock; trigger web_search via a query like "search the web for 'state space models'" → approve the native approval card | 2 min (same session as above) |
| **V1-GATE-LIVE-MAS-001 simple rewrite smoke** | In MAS audit bundle: create scratch note "Test note" → ready a local model OR add cloud credential → in note ask bar: "rewrite this in one shorter sentence" → confirm response renders | 5 min |
| **V1-GATE-GRAPH-001 first-open framing** | EITHER approve Codex to patch initial graph camera/bootstrap framing path (touching `GraphCamera.swift` or equivalent, NOT renderer/physics/edges/layout) — OR accept "click Zoom to Fit on first open" as the known behavior with a one-line UI tip | varies |

### 3.3 CODEX-ACTIONABLE NOW (paid Developer + App Group unlocked these)

| Wave | Item | Source | Time estimate |
|---|---|---|---|
| **F3** | Implement first XPC service: VaultXPC (narrowest entitlements, scoped to vault root + bookmarks) | XPC_MASTERY §2.2 + §1.4 | 3-5 days |
| **F4** | CapabilityGrant HMAC-SHA256 + bitflags structure (in-process first, then wire to XPC) | XPC_MASTERY §4 | 2-3 days |
| **F5** | mach-port signaling skeleton (no IOSurface yet — text/JSON payload first) | XPC_MASTERY §9 | 2 days |
| **F6** | WASMExecXPC scaffold + Wasmtime integration first | XPC_MASTERY §5 | 5-7 days |
| **F7** | `omega-mcp::inproc::*` namespace for vault_ops / search / fetch / think / todo / calc | COGNITIVE_KERNEL_DOCTRINE §7 | 2-3 days |
| **F11** | Secure Enclave attested capability tokens (start with Touch ID re-auth integration) | XPC_MASTERY §7 | 3-5 days |

### 3.4 CODEX-ACTIONABLE IN PARALLEL (Wave A — no Developer cert dependency)

These tighten the no-compromise architecture without needing any external unlock:

| Wave | Item | Source | Status |
|---|---|---|---|
| **A1** | Variant Ladder dispatcher retrofit on `vault.search` (proof-of-concept route) | `COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` | Highest-ROI no-compromise win; ~200 LOC |
| **A2** | `## Variant Ladder` PR-description sweep on all 30 MAS-allowed tools | doctrine §4.1 | doc-only |
| **A3** | `escalate_on_empty: false` default + `// VARIANT-LADDER-DEFER:` markers | doctrine §6 | small |
| **A4** | Enforce `reasoning` field ≤256 tokens at GBNF compile (≤32 for Qwen 7B) | `deterministicapp.md` §1, `helios v3.md` | grammar tweak |
| **A5** | Add `epistemos.{soul,skill,episode,semantic}.v1` JSON schemas; schema-validated MutationEnvelope writes | `deterministicapp.md` §5 | schema work |
| **A6** | Cognitive Weight Class W1 read-only metadata in Halo + composer 4-tier badge | `COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` W1 acceptance | UI |
| **A7** | Knowledge Sieve + Gap Winner Rule + No-Later-Simpler-Composite curriculum for ClaimLedger ranking | `ternary_reconceptualization.md` | algorithm |
| **A8** | `clarify` tool surface UI card (GenUI schema + dispatcher + renderer) | MAS Release Manifest, `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` | UI + GenUI |
| **A9** | NightBrain 10 task bodies (replace NoOp placeholders) | `LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` integration | algorithm |

### 3.5 OPERATOR-ONLY (live UI smoke, no code)

| Item | What you do |
|---|---|
| `RCA5-P1-005` + `RCA9-P1-007` voice temp-file MIC smoke | Voice input + completion + verify temp files deleted |
| `RCA-P0-002` fault-injection DB matrix | Corrupt-store scenarios on scratch vault |
| `RCA11-P1-007` large-file profile | Open 5MB+ note + Instruments trace |
| `RCA12-P1-006` Current Access runtime proof | Sample 3 attachment grants + verify dispatcher enforces |
| `RCA11-P2-005` SDF graph label budget | Fullscreen graph + frame hitch observation (graph PROTECTED — observe only, no fix) |
| Hidden-capture metadata existing-note migration (`RCA-P0-003` + `RCA5-P1-006` + `RCA10-P0-001`) | Manual sweep + verify export/share migration on real notes |

### 3.6 POST-V1 EXCLUSIONS (do NOT start before MAS ship)

Per `POSTV1-EXCL-001`:

- Wave B (V6.1 EML floor — oxieml / eml-lean / F-ULP-Oracle / morph_eval_reduced.metal v0.1)
- Wave C (V6.2 6 Metal kernels — research-tier target-only)
- Wave E (SCOPE-Rex V2 — Sinkhorn / Brain Time Machine / 5 directional operators / 9-arm Kleene K3)
- Wave I (A2UI catalog 24 remaining components)
- Wave J entire research tier (ternary, KV implantation, ACS, multi-claw, OFTv2/QDoRA, ANE direct, Sherry/E8/Leech)
- All `Helios/V6.2 migration` work
- All Lean verification stack work
- Donor-distillation training ramp

---

## 4. App Store submission checklist (the actual ship gate)

Synthesized from `APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` §App Store-Compatible Work Still To Finish + manifest verification commands:

### 4.1 Build + bundle audits (re-run before EVERY submission)

```bash
cd /Users/jojo/Downloads/Epistemos

# 1. Build MAS Release (real signing, paid Team)
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' \
  -configuration Release build

APP=$(find ~/Library/Developer/Xcode/DerivedData/Epistemos-*/Build/Products/Release \
  -name "Epistemos.app" 2>/dev/null | head -1)

# 2. Bundle identity check
defaults read "$APP/Contents/Info.plist" CFBundleIdentifier  # → com.epistemos.appstore
codesign -d --entitlements - "$APP" 2>&1 | grep -A3 "app-sandbox"
# Expected: app-sandbox = true
codesign -d --entitlements - "$APP" 2>&1 | grep -A3 "application-groups"
# Expected: group.com.epistemos.shared

# 3. Subprocess path string scan — MUST return ZERO matches
find "$APP" -type f -print0 | xargs -0 strings 2>/dev/null | \
  grep -E '^(/usr/local/bin/(claude|codex|gemini|kimi)|/usr/bin/osascript|/bin/bash|/bin/sh|/usr/local/bin/docker)$'

# 4. Rust dylib symbol audit — MUST return ZERO matches
nm -gU "$APP/Contents/Frameworks/libagent_core.dylib" 2>/dev/null | \
  grep -iE 'osascript|bash_execute|cli_passthrough|stdio_mcp|browser_subprocess|imessage_send|cronjob|cli_(claude|codex|gemini|kimi)|computer_use|screencap'

# 5. App Store official scanner
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-audit-gate \
  scripts/scan_appstore_bundle.sh "$APP"
```

Expected outcomes: BUILD SUCCEEDED · 0 matches at steps 3 + 4 · scanner PASS.

### 4.2 Test suite (re-run before submission)

```bash
# Swift tests
xcodebuild -scheme Epistemos -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO

# Rust mas-build
cargo test --manifest-path agent_core/Cargo.toml --lib

# Rust pro-build (Pro target verification)
cargo test --manifest-path agent_core/Cargo.toml --features pro-build --lib

# omega-mcp + omega-ax
cargo test --manifest-path omega-mcp/Cargo.toml --lib
cargo test --manifest-path omega-ax/Cargo.toml --lib

# Research crate
cargo test --manifest-path epistemos-research/Cargo.toml --features research --lib
```

Expected: all green. Current baseline: 3,059 Rust tests + Swift suite, all PASS as of 2026-05-14.

### 4.3 Live manual workflow matrix (dogfood checklist)

Per `APP_STORE_RELEASE_COMPLETION_STATUS` §6:

- [ ] First launch — landing greeting hero loop renders
- [ ] No-model setup path — Settings → Inference shows "Install Local Model" path; cloud-key missing path shows account onboarding
- [ ] Local chat — `hi` → response streams without errors
- [ ] Cloud-key missing path — Pro/cloud route shows credential nudge banner (not silent fall-through)
- [ ] Model install/detection — download a small local model + verify it routes
- [ ] Note read — open vault note from sidebar
- [ ] Note search — search vault returns results
- [ ] Note AI accept/discard — note ask bar query → response → accept (text commits) or discard (text clears)
- [ ] Attachment grant — drag note into chat → grant prompt → tool call honors grant
- [ ] File attachment — drop image / PDF / text → model sees content inline
- [ ] Export — File menu → export note as `.md` or `.epdoc`
- [ ] History — Chat sidebar shows prior chats; restore works
- [ ] Vault import rollback — switch vault → old vault restoration works
- [ ] Settings privacy/permissions — every diagnostic row renders + makes sense
- [ ] Accessibility basics — VoiceOver navigates main surfaces; reduce-motion respected
- [ ] Quit / reopen — relaunch picks up last state cleanly

### 4.4 App Store Connect metadata + compliance

Per `APP_STORE_RELEASE_COMPLETION_STATUS` §5:

- [ ] **Privacy manifest** (`PrivacyInfo.xcprivacy`) — declares no required-reason-API tracking; lists `NSPrivacyAccessedAPIType` for diagnostics
- [ ] **App Privacy answers** in App Store Connect — Data Not Collected (you store everything locally; cloud calls are user-initiated)
- [ ] **Privacy policy URL** — must be live + accessible
- [ ] **Support URL** — must be live + accessible
- [ ] **Review notes** — describe what reviewers see on first launch (no auto cloud calls); provide test credential if any feature gates on it
- [ ] **Screenshots** — at least 1 macOS screenshot per device class; recommended 5+
- [ ] **TestFlight setup** — internal testers added; build uploaded; tested before public release
- [ ] **Export-compliance answers** — "No" to encryption if you only use HTTPS / system crypto; "Yes" + ECCN otherwise
- [ ] **Sandbox file-access language** in review notes — describe how user-selected file access works

### 4.5 Code signing for submission

```bash
# Archive (creates the .xcarchive)
xcodebuild -scheme Epistemos-AppStore -destination 'generic/platform=macOS' \
  -configuration Release -archivePath build/Epistemos-AppStore.xcarchive archive

# Open Xcode Organizer to validate + distribute
open build/Epistemos-AppStore.xcarchive
# In Organizer: Validate App → fix any errors → Distribute App → App Store Connect → Upload
```

---

## 5. The complete research source index (for Codex's reference)

Every doc that has a concept in §2:

### Primary doctrines + manifests
- `CLAUDE.md` — project rules + non-negotiable constraints
- `AGENTS.md` — Codex-specific guardrails
- `docs/MAS_RELEASE_MANIFEST_2026_05_13.md` — authoritative MAS feature inventory + verification commands
- `docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` — ship readiness checklist
- `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` — module-by-module Pro-gating audit
- `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` — TEMP-FREE-TIER → RESTORED (this commit chain)
- `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` — 17 sections, the masterclass for F3-F12
- `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` — Arc<T> handle pattern
- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` — Phases 1-7 + ABI
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` — Phase 8 (LANDED 8.A-8.G)
- `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` — typed payload dispatcher
- `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` — No-LLM-First
- `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` — 4 tiers + Policy Authority
- `docs/fusion/LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` — Wave 7 LivePlan.v1
- `docs/fusion/LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04.md` — anti-drift discipline
- `docs/fusion/FIVE_LAWS_AND_PHASE_I_2026_05_04.md` — measure-before-cut + EntityID + AppAction

### Audit registers + closure docs
- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` (14,680L) — the big research-driven audit
- `docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md` — Codex's recursive-fix protocol
- `docs/audits/V6_2_SESSION_PROGRESS_2026_05_12.md` — V6.2 substrate status (LANDED items)
- `docs/audits/V6_2_LAPTOP_MANUAL_AUDIT_CHECKLIST_2026_05_07.md` — M2 Pro 16GB verification
- `docs/audits/V1_RELEASE_AUDIT_2026_05_07.md`
- `docs/audits/V1_DEEP_INTERACTION_AUDIT_2026_05_08.md`
- `docs/audits/PERFORMANCE_CONCURRENCY_AUDIT.md`
- `docs/audits/PRIVACY_APP_STORE_AUDIT.md`
- `docs/audits/USER_WIRING_CAPABILITY_MAP.md`
- `docs/audits/DATA_PERSISTENCE_INDEXING_AUDIT.md`
- `docs/CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md` (820L) — Codex's master audit
- `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md`
- `docs/CODEX_V1_CLOSURE_VERIFICATION_2026_05_14.md` — my verification on top
- `docs/CODEX_HANDOFF_2026_05_13_CHAT_TOOL_PARITY.md` — chat-tool-parity handoff

### Master fusion (post-V1 backlog)
- `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` (734L) — Waves A-J + 32-domain concept atlas

### Helios canon chain
- `docs/fusion/jordan's research/helios v3.md` — 5 Pillars + WBO-6 + 6-tier memory + KV-Direct gate
- `docs/fusion/jordan's research/helios v5 first.md` / `helios v5 updated.md` — SCOPE-Rex tier + 9 Residency variants + 9 π Kleene K3
- `docs/fusion/jordan's research/helios v6.2.md` — M2 Pro 16 GB hardware lock + 6 falsifiers + InterruptScore
- `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` — EML floor sequence
- `docs/fusion/EPISTEMOS_V6_2_CANON_INTAKE_2026_05_07.md` — strict V6.2 delta + hardware lock

### Jordan's executive-add research
- `docs/fusion/jordan's research/deterministicapp.md` (977L) — variant ladder + GBNF + hybrid MD+JSON + minimal UX
- `docs/fusion/jordan's research/scope rex omega.md` — SCOPE-Rex 8 components + State Witness
- `docs/fusion/jordan's research/mac store edition.md` — 5-service XPC + capability lattice
- `docs/fusion/jordan's research/hermes.md` — L7 Cloud Gateway positioning (UI overlay purged)
- `docs/fusion/jordan's research/ternary kernel.md` — 3 backends + decode-first + 3-layer ternarity
- `docs/fusion/jordan's research/compass_artifact_wf-*.md` — Helios Shadow Memory + WBO-5

### Kimi deep research (donor depth — concept references only)
- `EPISTEMOS_NO_COMPROMISE_ARCHITECTURE.md` — 3-tier release model (Core / Pro / Research)
- `EPISTEMOS_MASTER_ARCHITECTURE.md` — 7-layer cognitive substrate + 6 mathematical pillars
- `EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md` — KV implant + Glass Pipe + Weight Surgery
- `EPISTEMOS_GAP_ANALYSIS.md` — wave % completion
- `EPISTEMOS_RESEARCH_LANDSLIDE.md` — 10 research dimensions
- `EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md` — honest ANE observability bounds
- `scope_rex_final_architecture.md` — 8-layer + 5 claim types + 5-tier verification
- `hermes_gateway_architecture.md` — L7 + zero-copy mmap CloudArena + ResonanceSignature
- `acs_meta_layer.md` — ACS recursion + 4 homeostatic loops + Hyper-Dynamic Schemas
- `osft_psoft_coso_fusion.md` — corrected continual learning (OFTv2 for 4-bit NF)
- `ternary_spectral_architecture.md` + `ternary_code_scaffolds.md` + `ternary_reconceptualization.md` — 6 math pillars + 5 directional operators
- `research/eml_universal_operator.md` — Odrzywolek EML + 3-factor plasticity
- `research/meta_homeostasis.md` — MAPE-K + MRAC + Lyapunov
- `research/meta_resonance.md` — Kuramoto + SOC
- `research/macos_vault_system.md` — security-scoped bookmarks + CVE-2025-31191
- `research/mas_architecture_research.md` + `mas_gate_upgrade.md` — 6-factor agent model + GodMode

### Kimi-latest
- `docs/fusion/research/kimi-latest/epistemos_capstone_unified.md` — Uniphics → Epistemos mapping + Helios crate stack
- `docs/fusion/research/kimi-latest/epistemos_definitive_master.md` — WBO-6 6-term + Five Pillars
- `docs/fusion/research/kimi-latest/epistemos_final_master_specification.md` — Universal Plasticity Gate
- `docs/fusion/research/kimi-latest/epistemos_mas_release.md` — VaultGatedSwarm
- `docs/fusion/research/kimi-latest/helios_shadow_memory.md` — ShadowPage triple representation
- `docs/fusion/research/kimi-latest/hermes_gateway_architecture.md`
- `docs/fusion/research/kimi-latest/SIMULATION_MODE_V16_SUMMARY.md` — v1.6 Slice 3 LANDED

### Simulation canon
- `docs/fusion/simulation/DOCTRINE.md` (1982L; 16 invariants) — Landing Farm + Graph Live Theater + Notes Sidebar Skin
- `docs/fusion/simulation/IMPLEMENTATION.md` (2597L)
- `docs/fusion/simulation/SESSION_KICKOFF.md`
- `docs/fusion/simulation/character-dna/{block_compact,block_wide,orb,sage,hermes_snake}.md` — pixel-precise specs

### Quick Capture canon
- `/Users/jojo/Documents/Epistemos-QuickCapture/PLAN.md`
- `/Users/jojo/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md`
- `docs/fusion/salvage/from-vigorous-goldberg/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md`

### GPT Research workspace
- `docs/fusion/jordan's research/GPT Research/` — Cargo workspace skeleton + 24 .md (RESONANCE_GATE / WBO6_INEQUALITY / VAULT_GATED_SWARM / HERMES_GATEWAY / METAL_KERNELS / SECURITY_AUDIT / PLATFORM_GATES / VERIFICATION_REPORT etc.)

### Substrate V2 closure
- `docs/SUBSTRATE_V2_FINAL_CLOSEOUT_2026_05_05.md` — what's gated externally (now mostly unlocked)
- `docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` — V2.1-V2.7 + V3.1-V3.3

### Cross-doc disambiguations (do not collapse)
- "Shadow" — Classical Shadows / ShadowKV / Helios L2 Shadow Sketch / Halo Shadow vault search (4 distinct meanings)
- "Helios" — architecture canon / KV-Direct literature / GPT-research workspace skeleton / Lane 5 classifier / `HELIOSInvariantSourceGuard` (5)
- "Hermes" — Function Calling fine-tunes / Hermes-4-405B model / gateway agent positioning / UI overlay (PURGED) / `agent_runtime` (5)
- "Holographic" — HRR-Sealed Memory / Boneh-Sahai-Waters cryptographic primitive (2 — do NOT conflate)
- "WBO" — WBO-5 (compass) / WBO-6 (helios v3) / WBO-7 reserved (helios v5) — same ½ across all
- "Residency" — L0-L7 ladder / λ field / 9 Residency variants / MTLResidencySet — never confuse
- "Variant Ladder" — single-tool A→B→C→D / doctrine 6-tier escalation / route-capture impl
- "VRM" — product mode / 4 UI labels chip / ρ value (3 distinct)
- "EML" — Odrzywolek operator / EML Neuron / eml-lean / EML-IR W1 floor work
- "Tier" — ToolTier / DeploymentTier / LadderTier / verification tier T0-T4 (4 distinct)

---

## 6. Final stretch protocol — 8-question PR discipline

Every PR in the final stretch answers:

1. **Stage / Wave**: Which Wave (A/F/operator-runtime) does this PR target?
2. **GenUI route**: New renderer? Must go through `GenUIDispatcher` per `COGNITIVE_GENUI_DOCTRINE` §6 (else `// GENUI-DEFER:` + audit row).
3. **Sovereign**: Any destructive action class? Must route through canonical Sovereign Gate.
4. **Pro impact**: Feature-gated via `#[cfg(feature = "pro-build")]` / `#if EPISTEMOS_APP_STORE`? MAS bundle symbol-clean?
5. **App Group**: Touches `arena.dat` / shared container path? Uses `URL.containerURL(forSecurityApplicationGroupIdentifier:)`?
6. **Variant Ladder**: New tool route? PR includes `## Variant Ladder` section per `COGNITIVE_VARIANT_LADDER_DOCTRINE` §4.1.
7. **Atlas update**: PR adds/changes a concept named in §2 of this doc? PR appends a row here.
8. **Disambiguation**: PR uses a polysemous term ("Shadow", "Helios", "Hermes", "WBO", "EML", "Tier", "Residency", "Variant Ladder", "VRM")? PR cites which §5 sense.

---

## 7. The acceptance bar for MAS submission

Do not click "Submit for Review" until:

- ✅ All builds green (Pro Debug + MAS Release)
- ✅ All Rust + Swift tests green (3,059+ tests as of 2026-05-14)
- ✅ Bundle audits return ZERO matches (`strings` + `nm`)
- ✅ App Store scanner PASS
- ✅ `app-sandbox = true` confirmed in MAS Release bundle
- ✅ `application-groups = group.com.epistemos.shared` confirmed in MAS Release bundle
- ✅ Manual workflow matrix (§4.3) all green
- ✅ App Store Connect metadata complete (§4.4)
- ✅ At least one round of TestFlight internal testing
- ✅ Live MAS smoke (§3.2 user-action items) complete
- ✅ 5 consecutive Codex recursive passes find zero new V1 blockers

After acceptance bar met, the submission flow:

1. Validate App via Xcode Organizer
2. Distribute App → App Store Connect → Upload
3. Wait for processing (5-30 min)
4. In App Store Connect: build appears → assign to version → submit for review
5. Apple review: 24-72 hours typical

---

## 8. Implementation Log (Codex/Claude append rows here as Wave items ship)

| Date | Wave # | Commit | Acceptance evidence | WRV status |
|---|---|---|---|---|
| 2026-05-14 | F1+F2 | (this commit chain) `cb4a38f8d` + Debug entitlements edit | Apple Developer paid + App Group registered + entitlements restored in all 3 files + signed bundle confirms App Group landed | ✅ Wired+Reachable, ✅ Visible in codesign output, ✅ Verified by codesign + diff |

## 9. Atlas Drift Log (append here if §2 falls out of sync with `main`)

| Date | Atlas row | Stated status | Actual status | Action |
|---|---|---|---|---|
| — | — | — | — | — |

## 10. Compromises Recorded (append here only when forced — no silent deferrals)

| Date | Item | Source doc | Compromise | Trigger to revisit |
|---|---|---|---|---|
| — | — | — | — | — |

---

*— Master MAS final-stretch doc. Every concept across deterministicapp / Helios v2-v6.2 / SCOPE-Rex / ACS / Halo / Quick Capture / EML / Kimi research / GPT research / Codex audit / paid Apple Developer chain is referenced in §2 or §5. No drift, no compromise except Pro-only-by-MAS-sandbox-rule features.*
