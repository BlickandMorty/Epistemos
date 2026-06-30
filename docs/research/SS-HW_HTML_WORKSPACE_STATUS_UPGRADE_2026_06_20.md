# SS-HW — HTML Workspace: honest status + upgrade to a real web-app builder (2026-06-20)

Owner: *"the html workspace does not work as well but idk if its marked as such… don't forget the upgrades I wanted on
html workspace with DOM, the chat, etc. — all the best things you'd want on HTML/JS/CSS/Python preview, and being able
to create a full web app through the built-in pipeline using html workspace."* Code-grounded + web. MAS-safe (NO runtime
subprocess), license-gated, reuse-not-rebuild.

## ORIGINAL 2026-06-20 STATUS — compiled + rendered, but a one-way static renderer with DEAD seams, and NOT marked broken
**Works:** `com.epistemos.html-workspace` is a real `NSDocument` (`Engine/HTMLWorkspaceDocument.swift:62,74,140`, registered
in both Info.plists); multi-file HTML/CSS/JS/Data editing (`HTMLWorkspaceEditorView.swift:265-291,319`); WKWebView preview
(`HTMLWorkspacePreviewView.swift:8,25` rendering `HTMLWorkspacePreviewDocument.render` `HTMLWorkspacePackage.swift:837`
with CSP + theme-guard + `window.HTMLWorkspace` DOM helper `:895-947`); 220ms debounced live-ish preview (`:865`);
export/import/PDF/snapshot. **Agent/chat patch pipeline EXISTS + wired** — `HTMLWorkspacePatchRouter` parses
` ```epistemos-html-workspace-patch ` fences + applies (`:317,450,199`), invoked from chat (`MiniChatView.swift:2192,2425`),
context-packed (`ChatCoordinator.swift:4529`), with content-hash concurrency + unsafe-source rejection. DOM outline
(read-only text from source) `HTMLWorkspaceDOMOutline:466`.
**DEAD/limited (file:line):** (1) app-bridge handler is EMPTY — `HTMLWorkspacePreviewView.swift:145-149` receives messages,
does nothing. (2) `safeAPIEnabled` defaults false + hardcoded false at both call sites (`GraphWorkspaceContainer.swift:528`,
editor never passes it `:335`); header shows "Safe API"/"No bridge" for a no-op. (3) console panel (`:376-400`) can NEVER
show errors — no JS captures `window.onerror`/`console.error` to post back (the handler is the empty stub). (4) "DOM
inspection" is static regex of source HTML, not the live runtime DOM; no picker/styles. (5) NO Python. (6) CSP
`offlineDefault` (`HTMLWorkspacePackage.swift:265-277`) = `default-src 'none'; connect-src 'none'; script-src
'unsafe-inline'` → blocks WASM/connect/external libs. (7) persistence (localStorage/IndexedDB/messageHandlers) blanket-
banned by the patch validator (`HTMLWorkspacePatchRouter.swift:247`). (8) capability grid (`:453`) cosmetic.
**HONESTY GAP:** there is NO `HTMLWorkspaceGateStatus` — the codebase has the convention (`ActOsaurusGateStatus`,
`WorkBackendGateStatus`, `DeepResearchGateStatus`, etc.) but HTML workspace is shipped silently as if complete, with
T0/T1 dead seams. Per ARCHITECTURE PROMOTION CANON it should be honestly marked.

## 2026-06-30 implementation delta — do not regress these, but do not overclaim completion
- Honest status now lives in `HTMLWorkspaceCapabilityStatus`: renderer/editor/agent patches/data feed/PDF/local assets/live
  DOM outline are marked live; app bridge, DOM picker/style inspector, Python, and full regenerate UX remain deferred.
- Preview now serves package-local `assets/*`, `style.css`, `main.js`, and `data.json` through the local workspace scheme.
  PDF export inlines package asset references before the macOS `WebPage` render path.
- `data_feed` can opt into a Vault-backed `data.json` refresh with explicit stale/provenance metadata; failed feeds produce
  stale JSON rather than pretending to refresh.
- Console capture is wired but env-gated behind `EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0`. Safe API app commands are still not
  implemented; incoming Safe API messages are diagnostic-only and record a deferred-bridge console message.
- DOM outline is a live WebView snapshot when the preview is mounted, with source parsing as the fallback. Element picker,
  computed-style inspection, and targeted live style edits are still not implemented.
- `replaceDocument`/`regenerate` are source-quad patch operations with atomic batch staging, reversible pre-replace snapshots,
  manifest provenance, manifest content-hash refresh, current/stale provenance display, and chat-context provenance. This is
  not yet streaming regenerate UX, multi-route packaging, persistent app storage, or Python/Pyodide.

## UPGRADE PLAN (smallest first; MAS-safe; reuse Epdoc WKWebView/bridge/URL-scheme + build-time-bundle + GateStatus + provenance)
- **Step 0 — Honesty [S]:** add `HTMLWorkspaceGateStatus.swift` (mirror `ActOsaurusGateStatus`), mark app-bridge/Python/
  live-DOM `deferred`/`research`; stop rendering the dead "Safe API"/console affordances (`HTMLWorkspaceEditorView.swift:361,373`).
- **Step 1 — Real console + error bridge [S]:** implement the empty handler (`HTMLWorkspacePreviewView.swift:145-149`) —
  inject a userscript capturing `window.onerror`+`console.{error,warn}` → `postMessage` → `recordConsoleError`
  (`HTMLWorkspacePackage.swift:961`, already plumbed to UI); enable `safeAPIEnabled` for the editor's own diagnostics-only
  preview (`:335`). Reuse the Epdoc bridge (`EpdocEditorChromeView.swift:611-612`). Bonus: runtime errors feed back into
  chat → the agent self-corrects.
- **Step 2 — Live DOM + chat-edit hot-reload [M]:** replace static outline with a live `evaluateJavaScript` DOM query +
  element-picker; extend the patch router (`HTMLWorkspacePatchRouter.swift:450`) with a "live apply to WKWebView" fast
  path (no full doc round-trip).
- **Step 3 — Python via Pyodide/WASM, MAS-safe [M-L]:** run CPython in-browser via **Pyodide WASM in the existing WKWebView**
  (the ONLY MAS-safe Python path — no subprocess). VENDOR Pyodide into `Resources/` at build (never fetch at runtime;
  reuse the `build-tiptap-bundle.sh` model) + serve via a `WKURLSchemeHandler` (reuse `EpdocEditorChromeView.swift:630`
  `setURLSchemeHandler` — WKWebView blocks `.wasm` from `file://`). Add a 3rd `HTMLWorkspaceSandboxPolicy` "python" preset
  relaxing CSP to `script-src 'wasm-unsafe-eval' 'unsafe-eval'` + a `connect-src`/scheme entry for the local Pyodide URL.
  License-gate via the provenance pattern (`Vendor/Osaurus/OsaurusVendorProvenance.swift`; Pyodide = MPL-2.0/Apache-2.0/PSF).
- **Step 4 — "Build a full web app" scaffold pipeline [L]:** extend `HTMLWorkspacePackage` (`:320`) from the fixed
  index/style/main/data quad to a multi-file/multi-route model (it already has `assets:[String:Data]` `:326`); add scaffold
  templates (reuse `EpdocBlockTemplateStore`); add `addFile`/`addRoute` patch ops (extend `HTMLWorkspacePatchCommand`
  `:67`); relax the persistence ban per-sandbox-mode (`:247`) so generated apps use localStorage/IndexedDB. All edits flow
  through the existing in-process chat/patch pipeline — MAS-safe by construction.

Reuse: WKWebView+bridge+URL-scheme (Epdoc `EpdocEditorChromeView.swift:610-647`); build-time bundle (`build-tiptap-bundle.sh`);
GateStatus (`ActOsaurusGateStatus`); provenance (`OsaurusVendorProvenance`); agent edit pipeline (`HTMLWorkspacePatchRouter`,
exists — extend, don't rebuild). Cross-ref SS-EM/SS-O (Epdoc), SS-HGT (host inline in the graph tunnel). Sources: Pyodide
bundler/offline docs + CSP `wasm-unsafe-eval` (WKWebView local .wasm needs URL-scheme handler) + WKWebView CSP hardening.

---

## EXPANSION (owner 2026-06-20): chat fully REWRITES the surface into a website/explainer + which chat drives it
Owner: *"I want chat to literally completely redo the entire surface to look like a whole website/webpage — the DOM, the
live UI, animations, all of it. Even asking chat to explain something — I want it to explain using JSON/HTML streaming, by
literally creating a webpage / an explainer based on what it knows it can do on that surface. Make the surface flexible +
dynamic enough to do all of these. And I want to chat with it via the mini chat — and maybe the main chat. The mini chat
works for all surfaces but the main chat isn't automatically linked to all surfaces, so I'm not sure how that should go.
Research + document + deliberate."* Confirmed in code: NO whole-surface rewrite/regenerate or `streamHTML` path exists
today (grep clean); the patch router does incremental edits only.

### (5) FULL-SURFACE GENERATE / "Explainer mode" [M→L] — a regenerate op on top of the Step-4 scaffold
- Add a **`regenerate`/`replaceDocument` patch op** to `HTMLWorkspacePatchCommand` (`:67`) + `HTMLWorkspacePatchRouter`
  (`:450`) that swaps the ENTIRE multi-file package (index/style/main/data + assets/routes from Step 4) in one transaction,
  versioned + provenance-stamped (so it's undoable and obviously AI-authored — same trust principle as SS-IL's "obviously
  AI" separation). Chat says "make this a landing page about X" → the agent emits a full HTML/CSS/JS doc → it streams into
  the surface and the WKWebView hot-reloads (reuse Step 2's live-apply fast path; no jarring full teardown — diff+swap).
- **Streaming UX:** stream the generated doc with a skeleton/loading state; on completion, render. Animations/live DOM are
  just the generated page's own CSS/JS (already supported by the WKWebView) — no special engine needed once Step 1-4 land.
- **Explainer-from-knowledge:** "explain X" → the agent composes an HTML/JSON explainer grounded in vault/model knowledge
  (cross-ref SS-WL recall + SS-MV vault context) and renders it as a mini web-page on the surface. JSON path = a structured
  explainer schema the surface template renders (deterministic), HTML path = freeform doc. Honest provenance + a "generated
  by AI" chrome (SS-IL/SS-CLEAN separation principle) so the user never confuses it with hand-authored content.
- **Guardrails (SS-CLEAN, MAS-safe):** all generation flows through the in-process chat/patch pipeline (no runtime
  subprocess); CSP per sandbox mode; generated JS can't escape the WKWebView; every regenerate is versioned + reversible.

### (6) Which chat drives it — mini-chat (all surfaces) vs main-chat
- **Mini-chat is the right primary driver** — it already targets ANY surface via `MiniChatTarget` (`Models/DocumentSurface.swift:81-109`:
  carries `surfaceID`, `surfaceKind`, `pane`, `selectedRange`, `snippet`, `allowedOperations`). So "chat to rewrite/explain
  on this HTML surface" = a mini-chat session bound to the `htmlWorkspace` surface with `regenerate` in `allowedOperations`.
  This is the clean, already-architected path; lean on it.
- **Main-chat linking is the open question** — the main chat is NOT auto-bound to a surface. RECOMMENDATION (research
  verdict): do NOT auto-link the main chat to every surface (that's the muddiness the owner fears — ambiguous "which
  surface am I editing?"). Instead add an EXPLICIT, minimal "target this surface" affordance from the main chat (a surface
  picker / "send to HTML workspace" action that constructs the same `MiniChatTarget`). One deliberate gesture, not implicit
  global linking. Keeps the surface-routing model honest (`ArtifactRoute` decides the surface; chat targets it explicitly).
  Decision DEFERRED to owner if they want main-chat auto-link — flagged; default = explicit-target-only.
- Cross-ref: SS-2S (surface coexistence), SS-IL (AI-authored separation), SS-WL/SS-MV (knowledge for explainers), SS-HGT
  (host the HTML surface inline in the graph tunnel). Tests: regenerate swaps the whole package atomically + is reversible;
  mini-chat bound to htmlWorkspace can issue regenerate; main-chat requires an explicit target (no implicit global edit).
