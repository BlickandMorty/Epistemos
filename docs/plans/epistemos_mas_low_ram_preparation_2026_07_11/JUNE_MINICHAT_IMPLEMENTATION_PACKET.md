# JUNE / MiniChat Implementation Packet

PREPARATION ONLY — subordinate to the July 8 MAS master canon. This document does not change the active execution key or prove implementation.

Execution ID prepared for: `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08`
Canon sources: 05_MAS_JUNE_AGENT_AND_MINICHAT.md, 03 Prompt 3, 02 Phase 2, 08.
Gate: may not begin until `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`
passes its exact archive + runtime evidence bar.

## 0. Naming reality check (read first)

There is **no `MiniChat` symbol in current source** (`rg MiniChat Epistemos` →
zero files). The canon term "Epdoc MiniChat / Epdoc Assist" maps to the
existing native seam:

- `Epistemos/Views/Epdoc/EpdocCopilotDockView.swift` (native dock; free-form
  prompt; `submitAssist` closure → `JuneEpdocAssistSubmissionResult
  .submitted(sessionID)/.busy(sessionID)`)
- `Epistemos/JuneAgent/JuneEpdocAssist.swift` (bounded selection/context
  packet, heading/dataset-ref/provenance extraction, suggestion JSON parser
  with stale/blind refusal, `JuneEpdocAssistBridge.submit`)
- wired through `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` and
  `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`

The canon's preferred option ("native shell + same June session") is the
architecture already present. This ID is therefore mostly a **close-the-gaps +
prove-it** phase, not a green-field build.

## 1. Requirements extracted from canon (with done bars)

| # | Requirement (canon 05 / Prompt 3) | Done bar |
|---|---|---|
| R1 | June frontend loads as bundled assets, not server/Tauri/Node | `JuneWebAssets.resolve()` bundle-only; fresh-archive gate shows current JuneWeb dist + shim |
| R2 | Bridge invokes in-process `agent_core`, not direct fake chat | one real cloud turn streamed through `agent_coreFFI` with matching logs |
| R3 | One tool registry, one approval path, one provenance ledger, one transcript authority | approved + denied tool call both produce registry/approval/ledger events; no second store touched |
| R4 | MiniChat/Assist is June-owned; same session or explicit child session linked to same ledger | assist turn visible in June session store; ledger links note ↔ session ↔ suggestion |
| R5 | Native shell owns selection, context, status, approval, provenance | dock UI shows status + approval affordances natively |
| R6 | Cloud lane: Keychain-only secrets; receipt/proxy only if monetized | Keychain proof test (exists); StoreKit branch = OWNER_DECISION_REQUIRED |
| R7 | Local lane honestly gated | GGUF row admissible only when runtime linkage present; honest unavailable state |
| R8 | No terminal/stdio MCP/subprocess/browser-use/sidecar in MAS archive | fresh-archive strings/nm scan clean |
| R9 | Literal owner prompt preserved; no Hermes/Prompt Forge rewrite on normal send | request/log proof of exact submitted text |
| R10 | Approval/provenance record fields: run ID, turn ID, tool name/schema version, scope, approval status, preview diff, ledger event, applied hash, rollback | one approved effect carries all fields |
| R11 | Required evidence set: 1 real June turn, 1 approved tool call, 1 denied tool call, 1 note-context assist path, no sidecar symbols, allowlist clean, Keychain-only, honest gating | the canon-05 evidence list, executed once on the exact archive |

## 2. Requirement → current source map + classification

Classifications: text-level reads on 2026-07-11 (branch `feat/goose-surface`,
HEAD `0c7123ba4`). Nothing here is compile/runtime proof.

| Req | Current source | Classification |
|---|---|---|
| R1 | `JuneAgent/JuneWebAssets.swift` (bundle-only resolver, no env fallback); `build-june-web.sh` (service-worker refusal, unlicensed-font exclusion — Berkeley Mono/ABC Diatype/Martina Plantijn, June-identity string validation); `.june-web-stage/dist` + `tauri-internals-shim.js` (staged 2026-07-10); `bundle-app-runtime-assets.sh`; test "MAS June web bundle is required and bundle-only" (`JuneWorkspaceAgentSourceGuardTests:199`) | EXISTING AND REUSABLE (source); REQUIRES KEELSTONE for fresh-archive proof — retained archive had 7 stale JuneWeb findings |
| R2 | `JuneAgentGateway.swift` (`makeAgentCoreCloudStream`, `agent_coreFFI` import at 5–6, runner at 30); `Goose/GooseMASAgentCoreRunner.swift` (protocol + event enum: textDelta/thinkingDelta/toolStarted/…, permission handler); `agent_core/src/bridge.rs` | EXISTING AND REUSABLE + REQUIRES RUNTIME EVIDENCE |
| R3 | registry: `agent_core/src/tools/registry.rs` (`set_allowed_tool_names`, `mas_runtime_preflight`); allowlist: `JuneAgent/JuneMASToolPolicy.swift` → `GooseMASAgentCoreRunner:73`, `GooseInProcessACPServer:54`; approvals: `JuneAgent/JuneAgentApprovalRegistry.swift`; ledger: `agent_core/src/provenance/*`; transcripts: `JuneAgent/JuneSessionStore.swift` | EXISTING AND REUSABLE + REQUIRES RUNTIME EVIDENCE |
| R4 | `JuneEpdocAssist.swift` returns `submitted(sessionID)`; dock stores `assistSessionID`; test "epdoc dock routes free-form prompt through MAS June instead of parked runtimes" (`EpdocCopilotSurfaceTests:111`) | PARTIALLY IMPLEMENTED — child-session ↔ note ↔ ledger linkage fields not yet verified as explicit; see Batch J2 |
| R5 | `EpdocCopilotDockView.swift` (native SwiftUI dock, submit path, busy state); chrome mounts native bottom actions (test at `EpdocCopilotSurfaceTests:71`) | EXISTING AND REUSABLE; approval affordance inside dock not yet confirmed — see Batch J2 |
| R6 | `Engine/Keychain.swift`, `CloudProviderAuthService.swift`; tests "App Store cloud setup uses Keychain API keys only" (`AppStoreJuneSubstrateHardeningTests:145`), consent test (:124 — off by default, provider-specific, persistent, revocable); legacy receipt proxy parked behind `EPISTEMOS_LEGACY_RECEIPT_PROXY` (`JuneCloudEngine.swift:106`; test `JuneWorkspaceAgentSourceGuardTests:128`) | EXISTING AND REUSABLE; StoreKit/monetized branch = CONTRADICTED-BY-ABSENCE → OWNER_DECISION_REQUIRED (canon 09 §owner decisions) |
| R7 | `QuickChat/LocalGGUFQuickChatBackend.swift`, `GGUFModelCatalog.swift`, `LocalPackages/EpistemosLlama` (`project.yml:645`); tests: catalog honesty (:6), "catalog contains only the three selected permissive GGUF rows" (`JuneWorkspaceAgentSourceGuardTests:108`), "local rows do not fake function calling" (:73); release gate now rejects missing llama embedding/linkage | PARTIALLY IMPLEMENTED / REQUIRES KEELSTONE — retained archive physically lacks `llama.framework`; fresh archive + one Qwen3 4B turn are KEELSTONE runtime items 6–7 |
| R8 | gate `scripts/keelstone-release-gate.sh` + canon 08 strings scan | REQUIRES KEELSTONE + CONTRADICTED (naming): active runner symbols are `Goose*`; scan greps `-i "goose"`. See §5 risk 1 and Batch J0 |
| R9 | `JuneAgentGateway.swift:101–108` — `prompt.forge_preview` rejected with honest copy; `prompt.submit` forwards literal text; `JuneSystemPromptForge.swift` (system-prompt lane, separate from per-message text) | EXISTING AND REUSABLE (source-patched per closeout) + REQUIRES RUNTIME EVIDENCE (exact request/log) |
| R10 | `suggestion_schema.rs` (`Suggestion` has author/run/turn, object ID+type, range payload, accept state, events; `requires_approval()`); `JuneToolEventBounds.swift` (payload bounds + vault-root redaction); replay persistence test (:835 "persists reasoning and tool replay fields"); ReplayBundle export (`june_export_replay_bundle` bridge case; test :908 bounded + subprocess-free) | PARTIALLY IMPLEMENTED — applied-artifact hash + rollback/undo path for an APPLIED note suggestion not yet evidenced; see Batch J2 |
| R11 | runtime matrix machinery exists (gate + tests) | REQUIRES RUNTIME EVIDENCE — is the phase's exit bar |

## 3. Shared contracts touched (from seam map §2)

vault truth (apply-suggestion writes → `AtomicVaultWriter`); June
sessions/transcripts (`JuneSessionStore` only); tool registry + approvals (the
one chain); provenance (`suggestion_schema.rs` + ledger); routing (gateway +
catalog only); Keychain/consent; target membership (JuneWeb resources,
EpistemosLlama linkage).

## 4. Duplicate-authority traps specific to this ID

1. Assist dock keeping its own message array → must render from
   `JuneSessionStore` (or its session events), never a parallel transcript.
2. Assist "apply suggestion" writing note text directly from web/dock code →
   must go `EpdocMarkdownWriteThrough`/lens flow → `AtomicVaultWriter`.
3. A per-assist tool list → must stay `JuneMASToolPolicy.allowedAgentToolNames`.
4. A Swift-side suggestion struct diverging from `suggestion_schema.rs` →
   extend the Rust schema + FFI instead.
5. A second consent flag for assist turns → reuse the June cloud-consent
   preference (default-off, provider-specific).

## 5. Contradictions / risks to resolve inside this ID

1. **Parked-name symbols on the active lane** (`GooseMASAgentCoreRunner`,
   `GooseInProcessACPServer`, `GooseACPClient/Protocol`, event/type names
   `GooseMASAgentCore*`): canon 04/08 archive scans grep case-insensitive
   "goose". OWNER-CORRECTED resolution (evidence-first, 2026-07-11): run the
   exact current archive scan first; identify the exact offending
   symbols/resources; rename ONLY identifiers that make the current artifact
   gate fail; otherwise preserve internal compatibility and document narrowly
   justified exceptions. Broad renaming is NOT the default batch.
2. **`hermes_bridge_*` wire tokens** in `JuneAgentBridge.swift` and the June
   fork's `tauri.ts` (pinned a626597): protocol names from the vendored fork,
   not a Hermes runtime. Renaming breaks fork compatibility; keep, but document
   in App Review notes + gate policy as protocol tokens. (Canon scan list does
   not include "hermes"; repo doctrine memory says Hermes purged — record the
   nuance instead of churning the shim.)
3. **`tauri-internals-shim.js` filename** contains "tauri" while canon 08
   greps archives for "tauri" — the canon strings scan targets
   `Contents/MacOS/*` binaries (shim is a Resource), but the keelstone
   built-app gate scans resources too (7 stale JuneWeb findings on the
   retained artifact). OWNER-CORRECTED resolution (evidence-first): run the
   exact current scan; rename only if the current artifact gate fails because
   of this identifier; otherwise keep the name for fork compatibility and
   document the narrowly justified exception.
4. **Cloud consent preference absent** → first cloud turn must show the
   visible consent blocker (closeout expectation); assist path must inherit it.

## 6. Smallest implementation batches (dependency order)

- **J0 — archive-scan adjudication (evidence-first, per owner correction
  2026-07-11):** run the exact current archive scan/gate; enumerate the exact
  offending symbols/resources; rename ONLY identifiers proven to fail the
  gate; document narrowly justified exceptions for the rest (wire tokens,
  shim name). A current archive exists only through KEELSTONE's own evidence
  chain — a preparation finding becomes implementation work only when a
  current focused test, artifact gate, or runtime check proves the
  corresponding canonical defect.
- **J1 — transcript authority hardening:** assert dock renders from
  `JuneSessionStore`; add explicit child-session fields
  (`parentSessionID`/`originNoteID` or equivalent) if absent. Touches:
  `JuneSessionStore.swift`, `JuneEpdocAssist.swift`, dock view.
- **J2 — approval/provenance completeness for assist:** applied suggestion
  produces ledger event with applied-artifact hash + undo path; dock shows
  approval state natively; denied path leaves note untouched. Touches:
  `JuneEpdocAssist.swift`, `EpdocEditorChromeView.swift`, possibly
  `suggestion_schema.rs` FFI surface in `bridge.rs`.
- **J3 — consent + honest-lane UX pass:** assist inherits June cloud consent;
  local-unavailable state honest in dock. Touches: gateway + dock.
- **J4 — evidence run (no code):** canon-05 evidence list on the exact fresh
  archive (extends the KEELSTONE runtime matrix items 7–9 with the assist
  path). Produces the phase's release evidence + App Review notes.

StoreKit/monetization: parked until owner decision; do not scaffold.

## 7. Proposed regression tests (names only — no code written)

Full assertions/fixtures in `TEST_FIXTURE_AND_ACCEPTANCE_MATRIX.md`.

- `EpistemosTests/AppStoreJuneSourceGuard.swift` →
  `@Test("parked-name scan exceptions are enumerated and justified")` (J0)
- `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift` →
  `@Test("June Epdoc assist sessions are explicit child sessions linked to note and ledger")` (J1)
- `EpistemosTests/EpdocCopilotSurfaceTests.swift` →
  `@Test("assist suggestion apply requires approval and routes through the vault writer")` (J2)
- `EpistemosTests/EpdocCopilotSurfaceTests.swift` →
  `@Test("denied assist suggestion leaves the note byte-identical")` (J2)
- `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift` →
  `@Test("assist cloud turns inherit the June consent blocker")` (J3)

## 8. Manual/runtime evidence required after implementation

On the exact fresh archive only: one real cloud turn; one local turn or honest
unavailable state; one approved + one denied tool call (ledger rows shown);
one note-context assist round trip (select → prompt → suggestion → approve →
applied hash → undo); literal-send request/log pair; strings/nm scan clean;
Keychain-only proof; consent blocker screenshot.

## 9. External facts requiring later official-source validation

- StoreKit 2 / App Store Server API flow (only if monetization decided) —
  developer.apple.com/documentation/storekit + appstoreserverapi.
- WKWebView content-loading policies for bundled-asset scheme handlers
  (current WebKit docs) if `JuneSchemeHandler` changes.
- Apple Foundation Models availability/entitlement status on the shipping SDK
  (canon 05 marks local-FM lane SAFE/RESEARCH NEEDED).
- Anthropic/OpenAI current API terms for BYO-key apps (retention, key
  handling), before App Review notes are finalized.

## 10. Older research: salvage vs reject

- SALVAGE: June fork pin (a626597) + shim architecture notes from Plan 1-MAS
  (`PROMPT_PLAN_1_MAS_JUNE`), the perf doctrine's instant-open recipe
  (perf-budgets), June ontology/token notes — as specification appendices.
- REJECT (stale execution order/architecture): PROMPT_PLAN_10_EXPERIMENTAL /
  EXPERIMENTAL_R (1Code embed), OpenChamber dossiers, Goose-runtime migration
  docs, Kindred presence — parked provenance per canon 00/09; any tRPC/ws/
  Node-backend embedding shape is FORBIDDEN_FOR_MAS.
