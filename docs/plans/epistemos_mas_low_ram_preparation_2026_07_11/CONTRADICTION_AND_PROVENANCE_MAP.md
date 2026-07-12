# Contradiction and Provenance Map

PREPARATION ONLY — subordinate to the July 8 MAS master canon. This document does not change the active execution key or prove implementation.

## 1. Execution-key consistency check

The July 8 canon defines five keys; this task named four. Consistent:
`EPISTEMOS-MAS-PROGRAM-DIRECTOR-2026-07-08` is recorded **complete for
alignment/static truth** in `docs/prompts/MAS_EXECUTION_STATUS_2026_07_10.md`;
the four IDs in this preparation task are the active key plus the three
future keys, in the same strict order the status doc mandates.
`docs/prompts/MASTER_PLAN_INDEX_2026_07_03.md` carries an explicit
"SUPERSEDED FOR DAILY EXECUTION — 2026-07-08" banner naming the canon and all
keys — verified 2026-07-11. No stale-order authority found in the two control
docs.

## 2. Contradiction register

| # | Contradiction | Severity | Evidence | Resolution owner |
|---|---|---|---|---|
| C1 | Active MAS June runner is `Goose`-named (`Epistemos/Goose/GooseMASAgentCoreRunner.swift`, `GooseInProcessACPServer.swift`, `GooseACP*` types, `GooseMASAgentCore*` event/type names) while canon 04/08 archive scans grep case-insensitive "goose" | HIGH (scan honesty) | `JuneAgentGateway.swift:30`; scan commands in canon 04 §Local verification and 08 §Release evidence; retained-archive gate already shows one "parked account/backend marker" finding | OWNER-CORRECTED 2026-07-11 (evidence-first): run the exact current archive scan; rename ONLY identifiers that make the current artifact gate fail; otherwise preserve internal compatibility with narrowly documented exceptions. Broad rename is NOT the default batch |
| C2 | `agent_core/src/tools/` still compiles parked-lane tool sources (`terminal.rs`, `stdio_mcp.rs`, `browser*.rs`, `computer_use.rs`, `cli_passthrough.rs`, `imessage.rs`); canon expects "no forbidden tools in MAS archive" | MEDIUM | tools dir listing; MAS defense = `JuneMASToolPolicy` allowlist + `mas_forbidden_tool_name` + `mas_runtime_preflight` (registry.rs:62,145) | KEELSTONE archive gate is the arbiter: binary strings will contain module names even when unregistered; confirm gate policy distinguishes symbol residue from reachable tool surface. If the gate flags them, June phase adds compile-time exclusion (feature-gate parked tool modules for MAS agent_core build) |
| C3 | `hermes_bridge_*` wire tokens in `JuneAgentBridge.swift` vs. repo doctrine "Hermes namespace fully purged 2026-05-05" | LOW | bridge cases at lines 350–416; June fork tauri.ts pin a626597 | Keep: they are the vendored fork's protocol names, not a runtime; document in App Review notes + gate policy; do not churn the shim for cosmetics |
| C4 | Bundled `tauri-internals-shim.js` filename contains "tauri"; canon 08 scan token list includes "tauri" | LOW-MED | `.june-web-stage/tauri-internals-shim.js`; `JuneWebAssets.resolve()` expects that exact name; canon strings scan targets `Contents/MacOS/*` (binaries) but the keelstone built-app gate also scans resources (7 JuneWeb findings on retained artifact) | OWNER-CORRECTED 2026-07-11 (evidence-first): scan first; rename only if the current artifact gate fails on this identifier; otherwise keep the name for fork compatibility with a documented exception |
| C5 | WITHDRAWN 2026-07-11 — the original claim relied on the stale header comment at `TextCapturePipeline.swift:15`. Current source persists via `TextCapturePipeline.swift:779` → `bootstrap.vaultSync.createPage(...)`; `VaultSyncService.createPage` (:4696) creates the `SDPage` and exports vault-backed Markdown through the current vault/index write path | LOW (evidence pending, not a route defect) | call site verified 2026-07-11 (`rg` on both files) | Reclassified: EXISTING VAULT-BACKED ROUTE AT SOURCE LEVEL + RUNTIME CRASH/RESTORE/PROVENANCE EVIDENCE PENDING. T-CR-2/3 retained; no source-route rewrite unless a failing focused test proves a canonical defect |
| C6 | Two suggestion/provenance representations: Swift `EditorProvenanceStore` vs Rust `suggestion_schema.rs`; canon 06 F5 forbids parallel provenance schemas | MEDIUM | both files + 12 Swift tests; Rust schema already prose+tabular | LUMENLENS Batch LL-2: declare Rust schema canonical, prove Swift store is a lossless projection (T-LL-6a/6b) BEFORE RECKONER stages tabular suggestions |
| C7 | Three message stores (June App-Support JSON, `SDChat` GRDB, vault `chats/*.json`) vs "one transcript authority" | MEDIUM | `JuneSessionStore.swift` header; Models/; shadow crawler | Resolution recorded in seam map §2.5: `JuneSessionStore` is THE June authority; `SDChat` legacy-parked for the June lane; vault chat JSONs are export artifacts. June Batch J1 enforces; no migration of legacy stores is authorized by this doc |
| C8 | Older Plan 9 doc says "in-tab agent chat" + "GRDB truth" for datasets; canon 06 forbids data chat and makes GRDB derived | resolved by canon | `PROMPT_PLAN_9_DATA_TABLES.md` (provenance appendix) vs canon 06 | Already resolved: canon wins; T-RK-7 guards it |
| C9 | `PrivacyInfo.xcprivacy` declares 2 collected-data types (OtherUserContent, UserID); retained-archive gate reported exactly 2 privacy collected-data findings | OPEN (needs one gate run to interpret) | manifest head read 2026-07-11; closeout gate log `/tmp/keelstone-retained-app-gate-20260710.log` (may be purged) | KEELSTONE evidence run: reconcile whether the findings ARE these two declarations (needing App Review justification) or a mismatch |
| C10 | NARROWED 2026-07-11 — stable-ID system is PARTIALLY IMPLEMENTED, not missing (the original sweep used the wrong token). Existing carriers: `SDPage.id`; frontmatter `id` import restoration + duplicate-file collision handling; `_epdoc_id`; manifest IDs; capture `traceID`/`mutationID`/`noteID` | LOW-MED | `EpdocMarkdownWriteThrough.swift` + `VaultIndexActor.swift` (`_epdoc_id`); `TextCapturePipeline.swift:140,452,465`; `VaultSyncService.createPage(frontMatter:)` :4696 | Remaining, per owning phase: survival proofs (rename/move/export/import/rebuild); dataset IDs at RECKONER; ResearchHub source+vault IDs at ResearchHub; capture route-journal linkage. No new global framework unless survival tests prove current contracts insufficient |
| C11 | `project.yml` still defines `Epistemos-LegacyDev`, `Epistemos-Experimental` configs with `EPISTEMOS_EXPERIMENTAL KINDRED_ENABLED`, plus `SwiftTerm` local package | LOW (separate targets) | project.yml lines 53, 118–137, 633 | Allowed while MAS ships only `Epistemos-AppStore`; the KEELSTONE pruning inventory (canon 04 §Base-app pruning) decides what is deleted vs. parked; archive scans prove the MAS product is clean |
| C12 | Agent-memory/older repo docs (OpenChamber/1Code/Goose-surface plans, `feat/goose-surface` branch name itself) predate the July 8 canon | LOW (hygiene) | MEMORY.md entries marked superseded; branch name is historical | Future agents: treat those as provenance appendices per canon 00; branch rename is cosmetic and NOT worth dirtying the tree for |

## 3. Provenance of packet requirements

| Packet | Canonical source of each requirement | Older sources salvaged (spec appendix only) |
|---|---|---|
| Seam map | canon 01 §thesis, 02 §graph, 04 §truth table | `VAULT_STATE_SCHEMA.md`, perf handoffs |
| June/MiniChat | canon 05 (whole), 03 Prompt 3, closeout steers (2026-07-10 handoff) | `PROMPT_PLAN_1_MAS_JUNE.md`, June fork pin notes, perf doctrine instant-open recipe |
| LUMENLENS/RECKONER | canon 06 (whole), 03 Prompt 4, 04 writeback deps | `PROMPT_PLAN_9_DATA_TABLES.md` (+`_RESEARCH`), `PROMPT_PLAN_2_EDITOR.md`, editor lens canon |
| Capability Ring | canon 07 (whole), 03 Prompt 5, 08 legality matrix | `PROMPT_PLAN_8_RESEARCHHUB.md` dossier, `PROMPT_PLAN_6_QUICKCAPTURE.md`, `PROMPT_PLAN_7_SYNC.md`, `PROMPT_PLAN_3_CAPABILITIES.md` |

Everything in `docs/prompts/PROMPT_PLAN_*` and the pre-pivot memory canon is
provenance/spec appendix — it contributes requirements detail but never phase
names, order, or architecture (canon 00 §Never, MASTER_PLAN_INDEX banner).

## 4. Owner decisions still open (corrected 2026-07-11)

1. StoreKit/proxy/cloud monetization shape.
2. ResearchHub v1 provider subset.
3. Salvage of `files (5).zip` storage code after local verification.

REMOVED from this list: "local models ship or deferred." A later explicit
owner steer superseded canon-09 uncertainty: preserve the selected local GGUF
models; keep them June-owned; keep OpenAI/Anthropic cloud choices; prove
linkage, memory admission, cancellation, teardown, and actual output; do not
broaden the selected model catalog.

C1/C4 are no longer decisions to pre-answer: they resolve evidence-first from
the exact current archive scan (rename only what fails the gate; document the
rest as narrow exceptions).
