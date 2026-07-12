# Canonical Dependency and Seam Map — 2026-07-11

PREPARATION ONLY — subordinate to the July 8 MAS master canon. This document does not change the active execution key or prove implementation.

Source of authority: canon 01 (thesis), 02 (build order), 04–08 (domains).
Repo state read: branch `feat/goose-surface`, HEAD `0c7123ba4`, dirty worktree
(471 porcelain entries at this read; the 2026-07-10 closeout recorded 546 with
`-uall`). All "current source" claims below are text-level reads from
2026-07-11, not compile or runtime proof.

## 1. Canonical dependency graph (execution-ID form)

```
EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08          [ACTIVE, INCOMPLETE]
  └─ blocks → EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08
                └─ blocks → EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08
                              └─ blocks → EPISTEMOS-MAS-CAPABILITY-RING-2026-07-08
Release evidence (canon 02 Phase 6) re-runs at the end of EVERY ID.
```

Why each edge holds (canon 02):

- June/MiniChat depends on KEELSTONE because approved tool effects and
  Epdoc-assist suggestion writes must land through `AtomicVaultWriter` /
  coordinated mutation, and because the release-gate/archive machinery that
  proves "no parked runtime in MAS archive" is a KEELSTONE deliverable.
- LUMENLENS/RECKONER depends on June/MiniChat because suggestions are staged
  and approved through the one June approval/provenance path (`Suggestion`
  schema, approval registry), and datasets are driven "through June tools".
- Capability Ring depends on all prior seams: ResearchHub saves through
  KEELSTONE, capture routes through KEELSTONE, agent-facing capabilities
  register in the one June tool registry, provenance lands in the one ledger.

KEELSTONE's own remaining bar is exclusively the evidence chain in
`docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`
(one serial archive + artifact gates + finite runtime matrix). No preparation
work below authorizes running it. Owner boundary (2026-07-11): resume
KEELSTONE through its existing exact evidence chain first. A preparation
finding may become implementation work only when a current focused test,
artifact gate, or runtime check proves the corresponding canonical defect.

## 2. The nine shared contracts — current source owners

### 2.1 Vault and artifact truth

Canonical rule (canon 04): user-visible vault files/artifacts are durable
truth; GRDB/FTS/embeddings/graph/`.epcache` are derived and rebuildable;
append-only journal explains but never outranks files.

| Role | Current owner (source text, 2026-07-11) |
|---|---|
| Atomic writes (text + binary) | `Epistemos/Sync/AtomicVaultWriter.swift` (~20 call sites across `Vault/`, `Engine/`, `App/`; recent commits routed artifact text exports and Experimental binary saves through it) |
| Coordinated mutation | `Epistemos/Sync/CoordinatedVaultFileMutation.swift` (NSFileCoordinator) |
| Reconciler (the ONLY one) | `Epistemos/Sync/VaultSyncService.swift` (FSEvents + coordination) |
| Derived index actors | `Epistemos/Sync/VaultIndexActor.swift`, `SearchIndexService.swift`, `ReadableBlocksIndex.swift`, shadow index (`Epistemos/Engine/RustShadowFFIClient.swift` + `ShadowVaultBootstrapper.swift`) |
| Rust-side vault store | `agent_core/src/storage/vault.rs` |
| Op-log / journal | `agent_core/src/oplog.rs`; Swift projection `Epistemos/Engine/MutationOpLogReplay.swift`, `MutationOpLogProjectionWorker.swift`, settings row `OpLogProjectionHealthRow.swift` |

### 2.2 Stable IDs

Canonical rule (canon 04): every durable object gets an ID that survives
rename/move/import/export/rebuild; conflicts surface a repair prompt.

Current state (CORRECTED 2026-07-11 per owner adjudication — see
`PREPARATION_PACKET_CORRECTION_LOG.md` §2): **PARTIALLY IMPLEMENTED.**
Existing ID carriers at source level: `SDPage.id`; frontmatter `id` import
restoration with collision handling for duplicated files
(`VaultSyncService.createPage` accepts `frontMatter:` — :4696); `_epdoc_id`
(`Epistemos/Engine/EpdocMarkdownWriteThrough.swift`,
`Epistemos/Sync/VaultIndexActor.swift`); `EpdocNotebookManifest` IDs; capture
`traceID`/`mutationID`/`noteID` (`TextCapturePipeline.swift:140,452,465`,
`mutationID: "capture-<traceId>"`, `pageId` from `createPage`).

Remaining work (tracked separately, per owning phase): prove note-ID survival
across rename, move, export, import, and cache rebuild; define dataset IDs
when RECKONER is implemented; define ResearchHub source ID + vault ID when
ResearchHub is implemented; ensure captures retain capture/mutation/note
identity and route-journal linkage. Do NOT introduce a new global stable-ID
framework unless those survival tests prove the current contracts
insufficient.

### 2.3 Editor save/writeback

Canonical rule (canon 06): minimal-diff writeback splices in memory, writes the
full buffer through KEELSTONE; load-vs-edit guard via epochs.

| Role | Current owner |
|---|---|
| Lens/session state machine (incl. `leaseHandoff` save reason, edit/document/preview/source lenses) | `Epistemos/Views/Notes/NoteSessionStateMachine.swift` |
| Workspace host (flush-before-switch, clean-owner handoff) | `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`, `MarkdownDocumentSurface.swift` |
| Epdoc chrome/bridge | `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`, `Epistemos/Engine/EpdocEditorBridge.swift`, `EpdocDocument.swift` |
| Markdown write-through | `Epistemos/Engine/EpdocMarkdownWriteThrough.swift` (tested by `EpistemosTests/EpdocMarkdownWriteThroughTests.swift`) |
| Lens fidelity disclosure | `Epistemos/Views/Notes/LensFidelityDisclosure.swift` |
| Lens-switch regression tests | `EpistemosAppStoreKeelstoneTests/MarkdownDocumentLensSwitchTests.swift` |

### 2.4 Provenance

Canonical rule (canon 04/05/06): one append-only ledger; suggestions/tool
effects produce run/turn/object IDs, approval state, applied hash.

| Role | Current owner |
|---|---|
| Claim ledger (Rust) | `agent_core/src/provenance/ledger.rs` |
| Replay bundles | `agent_core/src/provenance/replay.rs` |
| **Shared suggestion schema (prose + tabular)** | `agent_core/src/provenance/suggestion_schema.rs` — `Suggestion`, `RangePayload` (markdown offsets AND `TabularRange`), `AcceptState`, `Author`, `SuggestionLedgerEvent` (inserted/acceptStateChanged/revert/turnReverted/compacted), `requires_approval()` |
| Swift ledger client | `Epistemos/Engine/RustProvenanceLedgerClient.swift` |
| Provenance console | `Epistemos/Views/Settings/ProvenanceConsoleView.swift`, `Epistemos/Engine/ProvenanceConsoleProjectionService.swift` |
| Op-log replay/export | `Epistemos/Engine/MutationOpLogReplay.swift` |

The canon-06 "one schema for prose spans and tabular ranges" requirement is
**already modeled in Rust**. LUMENLENS/RECKONER work must consume this type,
not invent a Swift-side second schema.

### 2.5 June sessions and transcripts

Canonical rule (canon 05): one transcript/session authority.

| Store found | Role today |
|---|---|
| `Epistemos/JuneAgent/JuneSessionStore.swift` | June surface sessions + messages, JSON under Application Support, Hermes-shaped fields (mirrors June fork `tauri.ts` @ a626597); messages carry `answerPacketID` |
| `SDChat`/`SDMessage` (GRDB/SwiftData, `Epistemos/Models/`) | legacy chat surfaces (MiniChatView home, older rooms) |
| Vault `chats/**/*.json` | vault-indexed chat exports (shadow index crawls them) |

Canonical resolution for future phases: **JuneSessionStore is THE June
transcript authority.** MiniChat/Epdoc Assist must attach to it (same session
or explicit child session per canon 05), never to a new store. `SDChat` is
parked-legacy for the June lane; do not bridge June turns into it.

### 2.6 Tool registry and approvals

Canonical rule (canon 05): one capability registry, one approval path.

Chain proven in source text (single registry, single approval path):

1. Allowlist constant: `Epistemos/JuneAgent/JuneMASToolPolicy.swift`
   (`allowedAgentToolNames`, forbidden-fragment assertion).
2. Consumers: `Epistemos/Goose/GooseMASAgentCoreRunner.swift:73` and
   `Epistemos/Goose/GooseInProcessACPServer.swift:54` (both
   `= JuneMASToolPolicy.allowedAgentToolNames`).
3. Rust authority: `agent_core/src/tools/registry.rs`
   (`set_allowed_tool_names` at 675, equivalence check at 561,
   `mas_forbidden_tool_name` at 62, `mas_runtime_preflight` at 145 — refuses
   shell/terminal/process/destructive/unscoped-write tools with honest
   "available in Epistemos Pro" copy); installed via `agent_core/src/bridge.rs`
   (1151, 1347, 3612).
4. Approval: permission callback `GooseMASAgentCorePermissionRequest` →
   `Epistemos/JuneAgent/JuneAgentApprovalRegistry.swift` (pending map keyed by
   session, `awaitDecision`/`deliver`/`denyPendingApprovals`).

Note: `agent_core/src/tools/` still contains parked-lane tool files
(`terminal.rs`, `stdio_mcp.rs`, `browser*.rs`, `computer_use.rs`,
`cli_passthrough.rs`, `imessage.rs`). MAS safety currently rests on the
allowlist + `mas_runtime_preflight`, not on excluding the code from the build.
That is acceptable per canon only if archive scans stay clean; see
CONTRADICTION_AND_PROVENANCE_MAP.md §2.

### 2.7 Model/provider routing

| Role | Current owner |
|---|---|
| June lane selection (cloud/local), provider slugs | `Epistemos/JuneAgent/JuneAgentGateway.swift` (1,307 lines; `GooseMASAgentCoreProviderSlug.resolve`, `makeAgentCoreCloudStream`) |
| June model rows | `Epistemos/JuneAgent/JuneAgentModelCatalog.swift` |
| Local GGUF lane | `Epistemos/QuickChat/LocalGGUFQuickChatBackend.swift`, `GGUFModelCatalog.swift`, `LocalPackages/EpistemosLlama` (target at `project.yml:645`) |
| Apple FM lane | `Epistemos/QuickChat/AppleFMQuickChatBackend.swift` |
| Legacy/System-G routing (NOT the June path) | `Epistemos/LocalAgent/RuntimeRouter.swift`, `ConfidenceRouter.swift`, `Epistemos/Engine/RuntimeExecutor.swift` |
| Parked cloud proxy | `JuneCloudEngine.swift` legacy receipt-proxy path behind `EPISTEMOS_LEGACY_RECEIPT_PROXY` (line 106 comment: MAS June cloud turns use in-process agent_core) |

Rule for future phases: June routing lives in the gateway + catalog; do not
extend `RuntimeRouter`/`ConfidenceRouter` for June features.

### 2.8 Keychain and consent

| Role | Current owner |
|---|---|
| Keychain primitives | `Epistemos/Engine/Keychain.swift` |
| Provider auth | `Epistemos/Engine/CloudProviderAuthService.swift` |
| Cloud consent | `Epistemos/AgentWorkspace/AgentCloudConsent.swift` (closeout: no consent preference existed → visible pre-send blocker expected) |
| June gateway usage | `Epistemos/JuneAgent/JuneAgentGateway.swift` |

### 2.9 Target membership and MAS packaging

| Fact | Source |
|---|---|
| App targets | `project.yml`: `Epistemos-LegacyDev` (53), `Epistemos-AppStore` (189), `EpistemosWidgets` (354), tests (397, 571), packages incl. `EpistemosLlama` (645), schemes at 648–687 incl. `Epistemos-Experimental` |
| MAS macros | `EPISTEMOS_APP_STORE MAS_SANDBOX` at `project.yml:287,292` (+ 619/621); Experimental configs carry `EPISTEMOS_EXPERIMENTAL KINDRED_ENABLED` (118/125/137) |
| MAS prebuild | `project.yml:295` — builds rust/syntax/omega-mcp/epistemos-core/agent-core/shadow/code-index/substrate-rt/tiptap/coreeditor/**june-web** |
| Entitlements (MAS) | `Epistemos/Epistemos-AppStore.entitlements`: app-sandbox, app group `group.com.epistemos.shared`, audio-input, app-scope bookmarks, user-selected read-write, network.client. **No `network.server`** — matches canon expectation |
| Privacy manifest | `Epistemos/Resources/PrivacyInfo.xcprivacy` (tracking=false; collected: OtherUserContent + UserID, linked, purpose AppFunctionality; accessed-API list starts FileTimestamp). NOTE: retained-archive gate reported 2 collected-data findings — reconcile at next gate run |
| Release gate | `scripts/keelstone-release-gate.sh` (1,940 lines; source gate green 827 PASS on 2026-07-10; built-app gate RED on retained archive with 12 findings) |
| Keelstone lane tests | `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`, `MarkdownDocumentLensSwitchTests.swift`; June substrate tests `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift` |

## 3. Duplicate-authority risk map (canon item 5)

Where independent feature work would accidentally mint a second authority, and
what to reuse instead:

| Risk | Where it would creep in | Reuse instead |
|---|---|---|
| Second storage authority | RECKONER "working store" for grids; ResearchHub item DB; capture inbox DB | Vault artifacts + GRDB-as-derived via `VaultSyncService`/`AtomicVaultWriter`; `.dataset.md` sidecar pattern already recognized by `VaultIndexActor` |
| Second agent/session authority | MiniChat keeping its own message array; dataset tab chat; ResearchHub "ask about paper" | `JuneSessionStore` session or explicit child session; `JuneAgentGateway` for turns |
| Second tool registry | Per-feature "mini tools" invoked directly from Swift bypassing agent_core registry | Register in `agent_core/src/tools/*` + admit via `JuneMASToolPolicy.allowedAgentToolNames` (one place) |
| Duplicate provenance | LUMENLENS Swift-side suggestion structs; RECKONER tabular-change log; ResearchHub retrieval trace | `agent_core/src/provenance/suggestion_schema.rs` (`RangePayload` already covers prose + tabular) + `ledger.rs`/oplog |
| Duplicate editor serialization | MiniChat writing note text directly; RECKONER exporting markdown itself | `EpdocMarkdownWriteThrough` + `NoteSessionStateMachine` lens flow; datasets via artifact writes through `AtomicVaultWriter` |
| Competing reconciliation | Sync feature adding its own FSEvents watcher; ResearchHub polling folder state | `VaultSyncService` events; subscribe, don't fork |
| Incompatible artifact schemas | New dataset metadata format; second capture note shape | `.dataset.md` refs (already parsed by `JuneEpdocAssist.extractDatasetRefs` and `LensFidelityDisclosure`); Quick Capture note shape in `Epistemos/Views/Capture/` |

## 4. Cross-ID dependency notes

- **June/MiniChat needs from KEELSTONE:** proven archive machinery (gate green
  on a fresh archive), vault write path for approved effects, honest
  local-GGUF linkage (`llama.framework` embedding — currently the retained
  archive's red finding), JuneWeb bundle freshness checks.
- **LUMENLENS/RECKONER needs from June/MiniChat:** stable suggestion staging →
  approval → ledger path exercised end-to-end at least once (the
  `JuneEpdocAssist` parser + `suggestion_schema.rs` + approval registry chain),
  and the June event-frame vocabulary for editor/dataset status.
- **Capability Ring needs from all:** tool registration pattern (registry +
  allowlist + approval + provenance), KEELSTONE capture/save routes, and the
  release-evidence loop (entitlements/privacy/App Review notes) per adapter.

## 5. Parallelization analysis — NOT AUTHORIZED (historical planning information only)

Owner correction 2026-07-11: the owner selected one-agent sequential work.
This section is retained solely as historical planning information and grants
no authorization to parallelize. Original analysis follows:

- Safe to prepare/execute in parallel WITHIN June/MiniChat later: JuneWeb
  asset refresh vs. approval-UX polish vs. Goose→June symbol rename (disjoint
  files) — but the canon still sequences IDs; parallelism is only inside an ID.
- LUMENLENS batches (epoch guard, serializer tiers) touch `Views/Notes` +
  `Engine/Epdoc*`; RECKONER batches touch new `Reckoner*`/dataset files. The
  only genuinely shared surface is the suggestion schema (already in Rust) and
  `LensFidelityDisclosure` — safe to parallelize after batch LR-1 defines the
  shared adapter.
- Capability Ring features (ResearchHub, Quick Capture hardening, Sync
  coexistence, PDF/Vision/Speech) are mutually disjoint at file level; each
  is individually gated on the June tool-registration pattern.

## 6. REQUIRES LOCAL VERIFICATION (cheap, at next safe window)

1. `xcodebuild -scheme Epistemos-AppStore -showBuildSettings | rg "SWIFT_ACTIVE_COMPILATION_CONDITIONS|CODE_SIGN_ENTITLEMENTS"` — confirm macro/entitlement truth beyond project.yml text.
2. Whether `Epistemos-Experimental`/`Epistemos-LegacyDev` targets still compile parked surfaces into ANY MAS-shipped product (expectation: no; they are separate targets).
3. Privacy-manifest collected-data findings from the retained-archive gate log (`/tmp/keelstone-retained-app-gate-20260710.log`) vs. current `PrivacyInfo.xcprivacy` — tmp log may have been purged; regenerate at next gate run.
4. `JuneSessionStore` persistence location on disk and relaunch-survival (runtime item 2 of the KEELSTONE matrix).
