# Goose Agent AppKit Follow-On Plan

> 🛑 **SUPERSEDED 2026-06-29 (owner — Option 1 + Unification; applies to this WHOLE doc, not just the route table).**
> This document's ENTIRE native-chat plan is DEAD: **Gate 7, Step 9, `useNativeChatPath`, the native hub / transcript
> / session-canvas / composer — ALL DELETED.** Chat + EVERY Goose feature stays in Goose's **reskinned WebView,
> PERMANENTLY** (retheme to look native; never rebuild a Goose feature in Swift). **NATIVE = the FRAME ONLY**
> (window / nav-rail / launcher / permission+elicitation pop-ups) **+ the Models picker** (the ONE native route,
> already built). **§7 is GREEN-LIT** → ignore any "wait for sign-off / Phase 0 not signed" text below. Wherever
> this doc says "native chat / Gate 7 / Step 9 / native transcript," it is HISTORICAL — DO NOT BUILD IT.
> Canon: `docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md` + `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

**Date:** 2026-06-26
**Branch context:** `feat/goose-surface` (WebView + ACP in flight; native Agent surface not started)
**Audience:** Owner + any building agent after Phase 0 proof gate
**Prerequisite docs (read in order):**
1. `docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` — Phase 0 (WebView + ACP) canon
2. `docs/handoffs/GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND1_2026_06_26.md` — native feasibility + Gates 0–7
3. `docs/handoffs/GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND2_2026_06_26.md` — REST vs ACP, OAuth, sessions, tool shapes, codegen
4. `docs/handoffs/GOOSE_APPKIT_SURFACE_MAPPING_2026_06_26.md` — 1:1 screen/component map

**Owner lock:** Finish **Phase 0 WebView/ACP** on `feat/goose-surface` first. **This document starts after that proof gate.** It does not replace mid-flight WebView work.

---

## Hybrid-by-route strategy (owner canon — 2026-06-26)

> ⛔ **CONSERVATIVE REVISION 2026-06-27 (owner) — this OVERRIDES the route table + charter below.** Native = the **FRAME ONLY** (window / nav rail / launcher + the permission/elicitation pop-ups). EVERY Goose feature — chat, transcript, composer, providers, models, settings, sessions, skills, recipes, extensions, scheduler, apps — stays in Goose's reskinned WebView, **PERMANENTLY**. There is **NO** "native flip later," **NO** "before ship," **NO** Gate-7 native chat. The route table's "Native flip phase" column and every "Native" assignment for a Goose FEATURE are **DELETED** — a feature only ever goes native via a SEPARATE future owner decision with its own 100%-parity proof, never on the agent's own. You never rebuild a Goose feature in Swift.

**Not** a mandate to map all 14 Goose routes to AppKit before ship. Epistemos ships **100% Goose capability** with **UI technology chosen per route** — native where the first-run path is obvious; hardened staged WebView where ACP + fixtures have not yet earned native parity.

### Principles

| Principle | Rule |
|-----------|------|
| **Capability** | 100% — no feature loss, no thin native stubs that hide power-user flows |
| **Shell** | One Agent window: native AppKit chrome + nav rail; **content area** switches native panel vs embedded WebView per route |
| **Native-first v1** | Landing entry → Agent window → hub → session chat → composer → transcript (thinking / answer / tools) → permission / elicitation → session header |
| **WebView long-tail** | Skills, Recipes, Extensions, Scheduler, MCP Apps, shared-session, and **unproven settings tabs** stay in hardened staged Goose WebView until each route passes its native gate (ACP coverage + golden fixtures + WRV) |
| **Gate 7 (revised)** | WebView retires as **primary for chat only**; WebView **remains intentional** for long-tail routes until each earns a per-route native flip — **not** "delete all WebView at Gate 7" |
| **Feature flags** | Native chat default after Gate 7 proof; per-route WebView fallback until gate passes (e.g. `useWebViewForSkills`, `useWebViewForRecipes`) |
| **Out of scope** | OpenChamber / Work federation — **do not reopen**. Goose-single unchanged. |

### Route disposition table

| Route | v1 UI | Native flip phase | Notes |
|-------|-------|-------------------|-------|
| `/` Hub | **Native** | 1 (Gate 2) | First-run entry; composer only |
| `/pair` Session canvas | **Native** | 1 (Gate 2) | Transcript, composer, session header |
| Permission / elicitation overlays | **Native** | 1 (Gate 2) | Port from `GooseWebNativePromptBridge` |
| `/settings` | **Hybrid** | 2–3 per tab | Proven tabs native (Models, Chat, Auth, App, Keyboard); unproven tabs WebView panel (Sharing, Prompts, Local Inference) |
| `/configure-providers` | **Native** | 2 (Gate 4) | Provider onboarding grid |
| `/permission` | **Native** | 2 | Tool rules editor |
| `/sessions` | **Native** | 2 | List + import/export via native panels |
| `/extensions` | **WebView panel** | 3+ | Flip when ext ACP + fixtures green |
| `/recipes` | **WebView panel** | 3+ | Flip when recipe run/edit WRV passes |
| `/skills` | **WebView panel** | 3+ | Flip when sources CRUD fixtures pass |
| `/schedules` | **WebView panel** | 3+ | Flip when scheduler ACP parity proven |
| `/apps` | **WebView panel** | 3+ | MCP Apps renderer; honest defer OK |
| `/shared-session` | **WebView panel** | 3+ | Deep-link import preview |
| `/standalone-app` | **WebView panel** | 3+ | Per-app MCP window host |
| `/launcher` | **Native shell** (optional) | 3 | Single Agent entry only |

### Owner charter (paste-ready for building agents)

```
GOOSE HYBRID-BY-ROUTE — OWNER CHARTER (2026-06-26)

GOAL
- 100% Goose capability in one Agent window. Allocate UI tech per route — NOT "native everything" nor "WebView forever."

NATIVE — FIXED frame only (reimplements NO Goose feature)
- Landing tile / shortcut → AgentSurfaceWindowController (the app window + chrome)
- Native nav rail; content slot = Goose's reskinned WebView
- Permission sheet + elicitation form (already built + proven; the WebView forwards them)
- NO native hub / session-canvas / composer / transcript. Chat IS Goose's WebView.

GOOSE WEBVIEW — PERMANENT (every Goose feature; NO per-route gate)
- Skills, Recipes, Extensions, Scheduler, MCP Apps, shared-session
- Unproven settings tabs (Sharing, Prompts, Local Inference until WRV)
- Same window: AgentNavigationRailView + GooseWebSurfaceView (or route-scoped panel) in content area
- Hardened staged UI + boot shim; no feature loss vs Electron

GATE 7 — [DELETED 2026-06-27]
- There is NO native-chat flip. Chat stays Goose's WebView, permanently.
- No per-route WebView flags, no native gates. Every Goose feature stays in the WebView.
- Full-window WebView is not a "fallback" — it IS the product for all features.

FLAGS (examples)
- AgentSurface.useNativeChatPath          — default false until Gate 7; then true
- AgentSurface.useWebViewForSkills        — true until skills native gate
- AgentSurface.useWebViewForRecipes       — true until recipes native gate
- (same pattern for Extensions, Schedules, Apps, shared-session, settings tab IDs)

FORBIDDEN
- Thin native versions that drop Goose power-user flows
- "Delete all WebView at Gate 7"
- Reopening OpenChamber / Work / Chat federation / AgentClone
- Claiming route-native without ACP fixtures + WRV for that route
```

---

## 1. Verification audit

Legend: **PASS** = verified against clone source + current `Epistemos/Goose/*`; **GAP** = incomplete or deferred by design; **FAIL** = factual error found (fixed in this pass where minor).

### 1.1 Per-document verdict

| Document | Verdict | Summary |
|----------|---------|---------|
| **Round 1** (`GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND1_2026_06_26.md`) | **PASS** (2 minor fixes applied) | Routes, settings tabs, shim ledger, ACP domains, Gates 0–7, capability matrix, and UniFFI reject align with clone + code. Fixed: nav count wording (7 + Settings = 8); R2 OAuth mitigation aligned with Round 2. |
| **Round 2** (`GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND2_2026_06_26.md`) | **PASS** | `goose serve` vs `goosed agent` distinction confirmed in clone (`cli.rs`, `goosed.ts`, `GooseRuntimeSupervisor.swift`). 84 extension methods counted in `acp-meta.json`. Session SQLite paths, tool card shapes, OAuth delegation, golden fixtures outline — all source-backed. |
| **AppKit mapping** (`GOOSE_APPKIT_SURFACE_MAPPING_2026_06_26.md`) | **PASS** (1 fix applied) | All 14 `App.tsx` routes mapped to `Agent*` components. Settings tabs, shim affordances, visual tokens, non-goals — complete. Fixed: Auth tab now says ACP authenticate v1 (not ASWebAuthenticationSession as default). |
| **WebView decision** (`SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md`) | **PASS** (historical sections correctly tombstoned) | §0/§15–§17 remain live for Goose-single + no-break rule. §9-C WebView+ACP directive matches current `feat/goose-surface` work. Round 1 correctly supersedes §0–§14 federation for **native planning** without invalidating Phase 0 WebView. |
| **Current code** (`Epistemos/Goose/*`) | **GAP** (Phase 0 in progress) | Supervisor, ACP client (standard methods only), WebView surface, boot shim (69 keys), native permission/elicitation overlays — present. Missing: extended ACP client, deferred shim OS affordances, `Epistemos/Agent/*`, Landing entry, golden fixtures. |

### 1.2 Cross-source spot checks (2026-06-26)

| Claim | Source check | Result |
|-------|--------------|--------|
| 14 React routes | `App.tsx` routes block (lines 664–713) | ✅ 14 routes |
| 8 rail nav destinations | `useNavigationItems.ts` — 7 `NAV_ITEMS` + `SETTINGS_NAV_ITEM` | ✅ |
| 9 settings tabs (8 + gated Local Inference) | `SettingsView.tsx` tab triggers | ✅ |
| 69 boot-shim keys | `GooseWebBootShim.dispositionLedger` grep count | ✅ 69 |
| 84 ACP extension methods | `acp-meta.json` | ✅ (Round 1 "80+" is approximate; use 84) |
| Loopback `:3284` | `GooseRuntimeSupervisor.defaultPort` | ✅ |
| Standard session update kinds in Swift | `GooseACPProtocol.swift` `GooseACPSessionUpdate` | ✅ 7 kinds + unknown |
| Extended `_goose/unstable/*` in Swift | grep `Epistemos/Goose` | ❌ not wired (expected Phase 0 gap) |
| `Epistemos/Agent/` module | glob | ❌ not started (expected) |

---

## 2. Contradiction table

| Doc A says | Doc B says | Resolution |
|------------|------------|------------|
| Round 1 R2: use `ASWebAuthenticationSession` for OAuth | Round 2 §2: **do not** reimplement OAuth in Swift v1; use ACP `providers/config/authenticate` | **Round 2 wins.** Round 1 R2 row updated. Native v1 = progress sheet + device-code copy; ASWebAuthenticationSession = optional v2 only. |
| Mapping §C Auth: `ASWebAuthenticationSession` | Round 2 OAuth matrix | **Fixed in mapping doc.** ACP authenticate primary. |
| Round 1: "80+ methods" | Round 2 / `acp-meta.json`: **84** methods | **Use 84** as canonical count; "80+" is acceptable shorthand. |
| Round 1 nav: "7 items + Settings" (ambiguous) | Mapping: "8 rail destinations" | **Same thing.** 7 `NAV_ITEMS` + Settings = 8. Round 1 + mapping wording aligned. |
| `GOOSE_SURFACE_CLAUDE_HANDOFF_2026_06_24`: "Do not make a Swift Goose shell" | Round 1/2/Mapping: greenfield **Agent** AppKit surface | **Time-ordered, not contradictory.** Handoff = **Phase 0** (WebView reskin). Native AppKit = **Phase 1+** after proof gate. Follow-on plan preserves both: WebView transitional, native target. |
| SURFACE §9-C: WebView hosts Goose UI | Round 1 Gate 7: "retire WebView path" | **Hybrid resolution (owner 2026-06-26).** Phase 0 ships full WebView. Phase 1+ native shell + **chat path** native. Gate 7 retires WebView as **primary for chat only**; long-tail routes keep embedded WebView until per-route native gate. Full-window WebView = regression compare, not long-tail product UI. See **Hybrid-by-route strategy** above. |
| Follow-on Step 9: "WebView regression fallback only" | Hybrid long-tail WebView for Skills/Recipes/etc. | **Both true, different scopes.** Gate 7 ends WebView-as-primary for **chat**; long-tail routes **intentionally** embed WebView in the Agent content area until flip. Regression fallback = optional full WebView window for parity diff. |
| Charter: "ship WebView as final UI → STOP" | Hybrid allows WebView for unproven routes | **Chat vs long-tail.** WebView is **not** final for chat/transcript/composer (Gate 7). WebView **is** allowed as **final hybrid UI** for a long-tail route until that route earns native gate — not a STOP condition. |
| Round 1 Gate 0: spawn `goosed` | Round 2: Epistemos spawns **`goose serve`**, not `goosed agent` | **Round 2 precision wins.** Code already uses `goose serve` on `:3284`. Electron's `goosed agent` REST stack is legacy reference only — **do not wire for native v1.** |
| SURFACE §14.5 (PARKED): federation stands | SURFACE §15: Goose-single retired Chat/Work | **§15 wins** (owner 2026-06-26). §14.5 is stale; ignore federation consolidation option. |
| Mapping: native Agent uses Keychain for provider secrets | Round 2: Goose owns provider token storage under `~/Library/Application Support/Block/goose/` | **Both true, different secrets.** Epistemos Keychain = `GOOSE_SERVER__SECRET_KEY` (loopback attestation). Provider OAuth/API keys = Goose config dir via ACP — **do not duplicate into UserDefaults.** |

---

## 3. Coverage checklist

### 3.1 Goose routes (14/14 mapped)

| Route | Mapping | v1 UI | Native flip phase |
|-------|---------|-------|-------------------|
| `/` Hub | `AgentHubView` | Native | 1 |
| `/pair` Session canvas | `AgentSessionCanvasView` | Native | 1 |
| `/settings` | `AgentSettingsView` | Hybrid | 2–3 per tab |
| `/extensions` | `AgentExtensionsView` | WebView panel | 3+ |
| `/apps` | `AgentAppsView` | WebView panel | 3+ |
| `/sessions` | `AgentSessionsView` | Native | 2 |
| `/schedules` | `AgentSchedulesView` | WebView panel | 3+ |
| `/recipes` | `AgentRecipesView` | WebView panel | 3+ |
| `/skills` | `AgentSkillsView` | WebView panel | 3+ |
| `/permission` | `AgentPermissionSettingsView` | Native | 2 |
| `/shared-session` | `AgentSharedSessionView` | WebView panel | 3+ |
| `/launcher` | `AgentLauncherPanelController` (optional) | Native shell | 3 |
| `/configure-providers` | `AgentProviderSetupView` | Native | 2 |
| `/standalone-app` | `AgentStandaloneAppView` | WebView panel | 3+ |

### 3.2 Settings tabs (9/9 mapped)

| Tab ID | AppKit section | Phase |
|--------|----------------|-------|
| `models` | `AgentSettingsModelsSection` | 2 |
| `local-inference` | `AgentSettingsLocalInferenceSection` (feature-gated) | 2 |
| `chat` | `AgentSettingsChatSection` | 2 |
| `sharing` | `AgentSettingsSessionSection` | 3 |
| `prompts` | `AgentSettingsPromptsSection` | 3 |
| `keyboard` | `AgentSettingsKeyboardSection` | 2 |
| `auth` | `AgentSettingsAuthSection` | 2 |
| `app` | `AgentSettingsAppSection` | 2 |

Deep-link `?section=` map preserved 1:1 (mapping §C).

### 3.3 ACP update types (standard + Goose extensions)

| Update / notification | Swift today | Native reducer | Phase |
|----------------------|-------------|----------------|-------|
| `user_message_chunk` | ✅ decoded | `AgentTranscript` `.user` | 1 |
| `agent_message_chunk` | ✅ decoded | `.answer` | 1 |
| `agent_thought_chunk` | ✅ decoded | `.thinking` (collapsible) | 1 |
| `tool_call` | ✅ decoded | `.tool` start | 1 |
| `tool_call_update` | ✅ decoded | `.tool` finish | 1 |
| `session_info_update` | ✅ decoded (opaque) | session header meta | 1 |
| `usage_update` | ✅ decoded (opaque) | status bar tokens | 2 |
| `_goose/unstable/session/update` | ❌ | side-effects (title, badges) | 1b |
| `_goose/unstable/session/recipe/request-params` (agent→client) | ❌ | `AgentRecipeParamsFormView` | 2 |
| `session/request_permission` | ✅ bridge | `AgentPermissionSheet` | 0 native overlay exists; port to Agent module in 1 |
| `elicitation/create` | ✅ bridge | `AgentElicitationFormView` | same |

### 3.4 Boot-shim affordances (69/69 classified; implementation status)

| Disposition | Count | Phase 0 (WebView) | Phase 1+ (native) |
|-------------|------:|-------------------|-------------------|
| `implemented-native` | 9 | ✅ | Reuse |
| `implemented-runtime` | 3 | ✅ | Reuse via supervisor |
| `hidden-shell` | 8 | ✅ omitted | N/A |
| `compatibility-preserved` | 28 | ✅ stubs | Replace with native window mgmt where needed |
| `deferred-with-visible-error` | 21 | ⚠️ **blocks** import/cwd/external links | **Gate 1 finish (Phase 0)** + native panels in Phase 1 |

**Critical deferred paths (must not stay on visible-error in native v1):** `showOpenDialog`, `showSaveDialog`, `directoryChooser`, `selectImportSessionFile`, `openExternal`.

---

## 4. Phase boundary — what Phase 0 finishes vs what follow-on starts

### Phase 0 — current `feat/goose-surface` (WebView + ACP proof)

**Finishes when** SURFACE §7 Goose proof gate + Round 1 Gate 0–1 pass:

| Deliverable | Status (2026-06-26) |
|-------------|----------------------|
| `goose serve` on loopback `:3284`, `/health` == `ok` | ✅ `GooseRuntimeSupervisor` |
| ACP WebSocket + token auth | ✅ |
| Swift ACP: `initialize`, `session/new`, `session/prompt`, `session/update`, permission, elicitation | ✅ partial |
| Goose Web UI staged (`stage-goose-web-ui.sh`) + boots in WebView | ✅ script; runtime depends on staging |
| Boot shim disposition ledger (69 keys) | ✅ |
| Native permission + elicitation overlays (WebView path) | ✅ `GooseWebNativePromptBridge` |
| Menu entry "Open Epistemos Goose" | ✅ `EpistemosApp.swift` |
| MAS honest Pro gate | ✅ `#if EPISTEMOS_APP_STORE` |
| **Deferred shim affordances** (file dialogs, openExternal) | ❌ Gate 0 blocker for recipes/sessions |
| **Goose extended ACP** (84 methods) | ❌ |
| **Golden ACP fixtures** | ❌ |
| Real Goose Electron as fallback baseline | ⚠️ manual verify required |

**Phase 0 explicitly does NOT:** build `Epistemos/Agent/*`, claim native parity, wire REST `goosed agent`, revive Chat/Work/AgentClone surfaces, or retire WebView.

### Phase 1+ — this follow-on program (native Agent AppKit)

**Starts only after** owner signs Phase 0 proof gate (checklist in §6 below).

| Phase | Round 1 gate | Scope |
|-------|--------------|-------|
| **1a** | Gate 0 completion | ACP ext codegen, golden fixtures F1–F5, finish deferred shims |
| **1b** | Gate 2 (native feel MVP) | `AgentTranscript`, hub, session canvas, composer, permission/elicitation, file dialogs, Landing entry |
| **2** | Gates 3–4 | Navigation parity, settings/providers (ACP auth delegation) |
| **3** | Gates 5–6 | Recipes, skills, schedules, Epistemos context bridge |
| **4** | Gate 7 | Native chat path default; per-route WebView flags for long-tail; full-window WebView for regression compare only |

**Hybrid note:** Phase 1 delivers a **native shell + native chat loop** in one Agent window. Long-tail rail destinations (Skills, Recipes, Extensions, Scheduler, Apps, shared-session, unproven settings tabs) **embed hardened WebView** in the content area until each route's native gate passes — this is product UI, not a Phase 0 holdover.

---

## 5. Sequential plan (after WebView ACP proof gate)

Execute in order. **Do not skip gates.** Each step has an exit criterion.

### Step 0 — Proof gate sign-off (owner)

- [ ] Pro build: new session → prompt → stream (thinking + answer + tools) → permission → result → end_turn
- [ ] Same flow in staged WebView with shim ledger showing no unexpected `deferred-with-visible-error` on the exercised path
- [ ] MAS build shows honest Pro gate (no subprocess)
- [ ] Real Goose Electron baseline still launches for comparison
- **Exit:** Owner explicitly approves starting Phase 1 native work

### Step 1 — ACP infrastructure (Gate 0 completion)

1. Add `Scripts/generate-goose-acp-swift.sh` — pin Goose revision; emit `Epistemos/Goose/Generated/GooseACPExt*.swift` from `acp-meta.json` / `acp-schema.json`
2. Wrap with `GooseACPExtClient` actor over existing `GooseACPClient.sendRequest`
3. Handle `_goose/unstable/session/update` notification + recipe param agent request in `GooseACPEventBridge`
4. Capture golden fixtures F1–F5 → `EpistemosTests/Fixtures/GooseACP/*.jsonl` + manifest
5. **Finish Phase 0 shim gap:** implement `NSOpenPanel`/`NSSavePanel`/`NSWorkspace.open` for the 21 deferred keys (shared `AgentNativeAffordances` service usable by WebView shim **and** future native UI)

**Exit:** `GooseACPClientTests` + new ext decode tests green; fixtures load; cwd picker + session import work in WebView path

### Step 2 — Transcript reducer + tests (Gate 2 foundation)

1. Create `Epistemos/Agent/AgentTranscript.swift` — pure reducer from `GooseACPSessionUpdate` (+ Goose custom notification)
2. Part kinds: `.user`, `.answer`, `.thinking`, `.tool`, `.error`; tool cards use Round 2 §4 shapes (**no unified diff assumption**)
3. `AgentTranscriptTests` against F1–F5 fixtures
4. Cap part size (200k chars); `seenSeq` de-dupe

**Exit:** 5 fixture tests pass; thinking ≠ answer; tool ≠ prose

### Step 3 — Native shell MVP (Gate 2 UI)

1. `AgentSurfaceWindowController` + `AgentSurfaceRootView` (mirror `GooseSurfaceWindowController` + `WindowThemeStyler`)
2. **Hybrid content router:** `AgentRouteContentView` — native panel for hub/session; embedded `GooseWebSurfaceView` (route-scoped) for long-tail destinations per disposition table
3. `AgentHubView` — clock, greeting, composer (no auto-submit on open)
4. `AgentSessionCanvasView` — `AgentTranscriptView` + `AgentComposerBar` + `AgentSessionHeaderView`
5. `AgentSessionController` actor — owns client, session id, stream task, cancel
6. Port permission/elicitation from `GooseWebSurfaceView` → `AgentPermissionSheet`, `AgentElicitationFormView`
7. Feature flags: `AgentSurface.useNativeChatPath` (default **false** until Step 9); per-route `useWebViewFor*` flags default **true** for long-tail routes

**Exit:** Pro build opens native Agent window; **full chat loop on native path** (hub → session → stream → permission → elicitation); long-tail nav rows open embedded WebView in same window; theme at first paint

### Step 4 — Entry + affordances

1. Landing tile + keyboard shortcut (e.g. ⌘⇧A) → `AgentSurfaceWindowController.open(draft:)` — **draft only, no auto-submit**
2. `AgentEnvironmentBadge` + native cwd picker
3. `AgentModelPickerPopover` (session model from meta)
4. Diagnostics row: supervisor health + ACP status

**Exit:** Landing → Agent handoff works; cwd change via native panel

### Step 5 — Navigation parity (Gate 3)

1. `AgentNavigationRailView` — 8 destinations + recent sessions (`AgentSessionRailSection`)
2. Inline rename, archive, streaming badges
3. Hub route as default; session canvas for active chat
4. Rail selection drives **hybrid content router**: native views for hub/session/settings (proven tabs); WebView panel for Skills, Recipes, Extensions, Scheduler, Apps, shared-session until per-route flip

**Exit:** Rail matches Goose nav semantics; LRU recent list; every destination reachable (native or embedded WebView) with no silent failure

### Step 6 — Settings + providers (Gate 4)

1. `AgentSettingsView` with tabs (start Models, Chat, Auth, App)
2. Provider list/config via `_goose/unstable/providers/*`
3. OAuth: ACP authenticate + spinner + device-code copy (Round 2 §2)
4. Keychain: loopback secret only; never UserDefaults for secrets

**Exit:** Provider list loads; one OAuth + one API-key provider configure successfully

### Step 7 — Feature views (Gate 5)

1. **Per-route native gates** — flip `useWebViewFor*` → false only when ACP + fixtures + WRV pass for that route
2. Priority native candidates: Sessions (import/export panels), Permission settings, proven settings tabs
3. Long-tail default stays WebView panel: Extensions, Recipes, Skills, Schedules, Apps, shared-session
4. Schedules run-now/kill UI can defer inside WebView until native gate

**Exit:** Each rail destination reachable; flipped routes use native panel; unflipped routes use full-capability WebView (not stub); primary actions reach ACP

### Step 8 — Epistemos bridge (Gate 6)

1. `epistemos.context.snapshot` — vault note paths, graph selection attach to composer
2. Optional: mirror session id + title to Landing recents (not blocking v1)

**Exit:** Attach note from vault → visible in prompt context

### Step 9 — Chat-primary flip + regression fallback (Gate 7)  🛑 [DELETED 2026-06-29 — Option 1: NO native chat. Do NOT build this step. Chat stays WebView, reskinned. See top banner.]

1. 🛑 [DELETED 2026-06-29 — Option 1: NO native chat. Do NOT flip `useNativeChatPath`; do NOT build a native hub/session/transcript/composer. Chat stays WebView, reskinned.] ~~Flip `AgentSurface.useNativeChatPath = true` by default~~
2. **Do not** bulk-disable per-route WebView flags — long-tail routes keep embedded WebView until Step 7 per-route gate passes
3. Keep full-window `GooseWebSurfaceView` behind "Open Goose (Web fallback)" for **regression compare only** (not long-tail product path)
4. Document chat-path WRV + per-route flip checklist (Round 1 §F; hybrid charter above)

**Exit:** Native chat is default primary path; long-tail WebView intentional where unflipped; full-window WebView parity compare documented

---

## 6. Anti-mistake charter (paste-ready for building agents)

```
GOOSE AGENT SURFACE — BUILD RULES (2026-06-26)

SCOPE
- ONE agent surface: Goose over ACP. Not Chat/Act/Work federation. Not AgentClone. Not OpenGUI/Work.
- Phase 0 (WebView) must reach proof gate BEFORE native AppKit work starts on feat/goose-surface.
- Native Agent lives in Epistemos/Agent/* — greenfield. Do NOT revive deleted ChatView/MiniChat/GraphChat/NoteChat.

TRANSPORT
- Agent traffic = ACP WebSocket to `goose serve` on loopback (:3284). NOT Electron IPC. NOT REST `goosed agent` for v1.
- Subprocess boundary is permanent: goose serve stays explicit child process (Pro/Developer-ID). NO UniFFI embed.
- Pin Goose revision; regenerate Swift ext client when acp-meta.json changes.

UI — HYBRID BY ROUTE
- One Agent window: native shell + nav rail always AppKit/SwiftUI. Content area = native panel OR embedded WebView per route (see disposition table).
- Native v1 path: hub, session canvas, composer, transcript, permission, elicitation, session header — NO WebView on chat path after Gate 7.
- Long-tail routes (Skills, Recipes, Extensions, Scheduler, Apps, shared-session, unproven settings tabs): hardened WebView in content slot until per-route native gate — intentional, full capability, not a stub.
- Gate 7 = native chat PRIMARY default; NOT "delete all WebView". Per-route useWebViewFor* flags flip individually.
- Full-window WebView = Phase 0 proof + regression compare only.
- Do NOT claim "route-native" for a long-tail screen until that route's ACP fixtures + WRV pass.
- Do NOT use legacy chat UI, CoworkChatMode landing confusion, or tri-surface RootView modes as templates.
- Do NOT reopen OpenChamber / Work federation.

DATA & SECRETS
- Provider OAuth/API keys: Goose config dir via ACP — NOT UserDefaults.
- Loopback attestation secret: Keychain only.
- Never log WebSocket URLs with tokens.

HONESTY
- MAS: show "Agent requires Epistemos Pro" — no fake streaming, no hidden spawn.
- MCP Apps interactive renderer: defer v3 with honest placeholder — do not fake UI.
- Tool cards: no unified diff hunks unless derived from rawInput/locations (Round 2 §4).

INTEGRATION
- Add-don't-edit across Goose seam: Epistemos wiring in Swift; reskin overlay on staged Web UI; no surgery on goose Rust core.
- Notes/Graph/Landing: unchanged except explicit Agent entry tile/shortcut.
- Goose must stay independently runnable (§17): app compile state never gates goose serve verification.

TESTS
- AgentTranscript: golden fixtures F1–F5 before shipping native transcript.
- Zero regression on GooseACPClientTests + GooseRuntimeSupervisorTests.
- Thinking blocks preserved in history — never merge thought into answer stream.

STOP CONDITIONS
- If tempted to "reuse old chat" for speed → STOP. Use AgentTranscript reducer + ACP only.
- If tempted to wire REST to match Electron → STOP. Use ACP ext methods.
- If tempted to ship WebView as final UI for CHAT → STOP. Chat path must go native by Gate 7.
- If tempted to build thin native long-tail screens that drop Goose flows → STOP. Keep WebView until native gate proves parity.
- If tempted to delete all WebView at Gate 7 → STOP. Long-tail routes flip per-route, not in one bulk cutover.
```

---

## 7. Definition of done — follow-on program

The native Agent program is **done** when all of the following hold:

1. **Runtime:** Pro build spawns `goose serve`; MAS shows honest gate; no silent failure.
2. **Transport:** All agent operations use ACP (standard + required `_goose/unstable/*` subset for v1–v2 features); no Electron IPC; no hidden non-loopback HTTP.
3. **UI (hybrid):** Agent window shell + nav rail are AppKit/SwiftUI; **chat path** (hub, session, transcript, composer, permission, elicitation) is native at default after Gate 7. Long-tail routes use embedded WebView **or** native panel per disposition table — zero capability loss.
4. **Loop:** Hub → new session → prompt → stream (thinking + answer + tools) → permission → elicitation → end_turn; cancel mid-stream — **on native chat path**, no WebView in loop.
5. **Coverage:** 100% Goose capability reachable from one Agent window. Every Round 1 Pass C row implemented native **or** full WebView panel **or** explicitly deferred with visible in-app message (not silent failure, not thin stub).
6. **Shim:** No `deferred-with-visible-error` on critical paths (file dialogs, external links, cwd, session import/export).
7. **Theme:** `EpistemosTheme` at first paint; mono nav/tool headers; flat borders (`GooseSurfaceStyle`).
8. **Isolation:** Notes, Graph, Landing unchanged except Agent entry; no AgentClone/Work/OpenGUI resurrection.
9. **Tests:** `AgentTranscriptTests` (F1–F5), `GooseACPExtClient` decode tests, permission round-trip; supervisor + client tests still green.
10. **Fallback:** Full-window WebView opens for regression compare; chat-path WRV documented. Per-route WebView flags documented with flip criteria.
11. **Per-route gates:** Each long-tail native flip has fixture + WRV evidence before `useWebViewFor*` → false.
12. **Docs:** This plan + mapping doc reflect shipped reality; Phase 0 handoff marked complete.

---

## 8. Open gaps — Round 3 research candidates

Round 1 listed 20 gaps; Round 2 closed most. **Remaining for Round 3** (research or build spikes — not blockers for Phase 1 Step 1–3):

| ID | Gap | Why Round 3 | Suggested spike |
|----|-----|-------------|-----------------|
| R3-1 | **Swift ACP codegen tool choice** | Round 2 recommends codegen but not which generator (`swift-openapi-generator` vs custom template) | Spike: generate 10 types from `acp-schema.json`; pick tool |
| R3-2 | **Accessibility map** | Round 2 mentions VoiceOver; no row-level spec | Audit `AgentTranscriptView` + rail with VoiceOver checklist |
| R3-3 | **Transcript performance budget** | 200k cap stated; no scroll/virtualization policy | Stress test 500 tool cards; pick `LazyVStack` vs `NSCollectionView` |
| R3-4 | **MCP Apps sandbox** | `/mcp-app-proxy` + REST sampling path | Decide v3 architecture: hosted WebView panel vs honest defer |
| R3-5 | **Extension binary bundling** | Which MCP servers ship in Pro bundle vs user-installed | Inventory Goose defaults + Epistemos bundle layout |
| R3-6 | **Deep link / Nostr share** | `goose://sessions/…` + Epistemos URL scheme | URL handler design doc only |
| R3-7 | **Dictation / local Whisper** | ACP dictation methods exist | Pro scope + ONNX vs Apple Speech |
| R3-8 | **CI: stage-goose-web-ui.sh** | Web fallback needs pinned UI hash in pipeline | Release audit integration |
| R3-9 | **Owner branding lock** | "Agent" vs "Forge" vs "Goose" user-visible | Owner decision — non-blocking |
| R3-10 | **Markdown vault watcher (§16)** | Required for Goose MCP + in-app editor coexistence | Separate from Agent UI but blocks safe note attach in Gate 6 |

**Not Round 3 — already closed in Round 2:** scheduler daemon (in-process), session persistence (ACP not SQLite direct), OAuth (ACP authenticate), tool diff shapes, git worktrees (IPC only — defer v3), `agent_core` boundary (out of scope).

---

## 9. Doc fixes applied in this pass

| File | Change |
|------|--------|
| `GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md` | **Hybrid-by-route strategy** (owner canon): disposition table, charter, Steps 3–5/7/9, Gate 7 scope, contradiction resolutions, definition of done. |
| `GOOSE_APPKIT_SURFACE_MAPPING_2026_06_26.md` | Hybrid rendering section; v1 UI column on route table; non-goals WebView policy; `AgentRouteContentView`. |
| `GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND1_2026_06_26.md` | Gate 7 cross-ref to hybrid canon; D.4 WebView role; R7 mitigation. |
| *(prior pass)* | Auth tab: ACP authenticate v1; ASWebAuthenticationSession optional v2. Nav row count clarified. R2 OAuth mitigation aligned with Round 2. |

---

## 10. Quick reference — current `Epistemos/Goose/` inventory

| File | Role | Phase |
|------|------|-------|
| `GooseRuntimeSupervisor.swift` | `goose serve` spawn, health, MAS gate | 0 ✅ |
| `GooseACPProtocol.swift` | Standard ACP types | 0 ✅ |
| `GooseACPClient.swift` | WebSocket JSON-RPC | 0 ✅ |
| `GooseACPEventBridge.swift` | Observable session updates + prompts | 0 ✅ |
| `GooseWebBootShim.swift` | 69-key disposition ledger + injection | 0 ✅ |
| `GooseWebNativePromptBridge.swift` | WKScriptMessageHandler permission/elicitation | 0 ✅ |
| `GooseWebSurfaceView.swift` | WebView host + diagnostics | 0 ✅ |
| `GooseWebUIResolver.swift` | Staged UI discovery | 0 ✅ |
| `GooseSurfaceStyle.swift` | Theme tokens | 0 ✅ → reuse in Agent |
| `GooseSurfaceWindowController.swift` | Utility window | 0 ✅ → parallel `AgentSurfaceWindowController` in Phase 1 |

**Tests:** `GooseRuntimeSupervisorTests.swift`, `GooseACPClientTests.swift`

---

*Follow-on plan complete 2026-06-26 (hybrid-by-route owner canon). Execute Phase 0 to proof gate first; then Step 0 sign-off → Steps 1–9.*
