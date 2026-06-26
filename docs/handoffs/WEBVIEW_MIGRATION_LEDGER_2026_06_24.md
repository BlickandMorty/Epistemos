# WebView Migration Ledger — WKWebView → macOS-26 SwiftUI WebView/WebPage (2026-06-24)

> Owner directive (2026-06-24): apply the NEW macOS-26 `WebView`/`WebPage` API to ALL places that still use
> the OLD `WKWebView` — "no legacy." SPECIAL CASE: the **Epdoc code editor must KEEP its exact look** — swap
> the API only, do not redesign. Tracked here as a standing tangent so it isn't missed/ignored while the Work
> build proceeds. Reference implementation already shipped: `Epistemos/Work/WorkWebSurfaceView.swift` (the
> spike) is the NEW-API template (WebPage + `WebView(page)` + theme + curved box).
>
> GUARDRAILS: read before edit; build-verify each surface (swiftc -parse fast gate + a BACKGROUND xcodebuild
> checkpoint); **NEVER run xcodegen** (synchronized folders auto-include files; xcodegen wipes signing — see
> memory `feedback_epistemos_dont_run_xcodegen_sync_folders`); no commits unless owner asks; preserve look +
> behavior; visual proof (screenshot/preview) required for any look-bearing surface (Epdoc especially).

## API mapping (WKWebView → WebPage/WebView)
- `WKWebView` (NSViewRepresentable) → SwiftUI `WebView(page)` + `@State WebPage` (no NSViewRepresentable).
- `WKWebViewConfiguration` / `WKWebpagePreferences` → `WebPage.Configuration`.
- `WKUserContentController` + `WKScriptMessageHandler` → `WebPage` message handling / JS bridge (verify exact
  new-API surface against the 26.4 SDK as each is migrated).
- `evaluateJavaScript` → `WebPage.callJavaScript(...)`.
- `WKNavigationDelegate` → `WebPage` navigation deciding (`NavigationDeciding`) + the `load(...)`
  AsyncSequence of `NavigationEvent`.
- custom `WKURLSchemeHandler` → `WebPage.urlSchemeHandlers` (confirmed in SDK) / `URLSchemeHandler`.
- theme injection (CSS-var) + `drawsBackground=false`/white-flash handling → new-API equivalents
  (`webViewContentBackground` etc. — verify).

## VERIFICATION PASS (2026-06-24) — rg counts include COMMENTS; real sites re-verified
A code-vs-comment pass found the original `rg WKWebView` counts conflated COMMENT mentions of the
Epdoc/HTMLWorkspace WebViews with real usage. **VERIFIED-REAL WKWebView hosts (actual code → migrate these):**
- **A (Epdoc editor):** `EpdocEditorChromeView.swift` (`private final class EpdocEditorWebView: WKWebView` :53),
  `WebKitCodeEditorView.swift`, `EpdocEditorBridge.swift`, `EpdocKaTeXPreview.swift`.
- **B (HTMLWorkspace):** `HTMLWorkspacePreviewView.swift`, `HTMLWorkspacePDFExporter.swift`,
  `HTMLWorkspaceEditorView.swift` (spot-verify).
- **C: EMPTY.** ALL category-C entries + several A/B low-hit entries are **FALSE POSITIVES** (the only
  `WKWebView` token is in a `//`/`///` comment, no actual usage): MarkdownTextView, ProseTextView2,
  NoteDetailWorkspaceView, HaloEditorBridge, RopeFFIClient, EditorBundleHealthRow, BrowserCapabilityStatus,
  EpdocDocument, EpdocBubbleMenuView, EpdocSlashMenuView, EpdocEditorToolbar, KaTeXSnippets,
  HTMLWorkspaceHealthRow, HTMLWorkspaceCapabilityStatus.
**NET: the real migration is ~6-7 files (Epdoc cluster + HTMLWorkspace cluster), not ~23.** Revised order:
**B (HTMLWorkspace, less look-critical) FIRST to set the new-WebView pattern → then A (Epdoc, KEEP the look +
visual proof).** `WorkWebSurfaceView` is the new-API template. (The A/B/C tables below are superseded by this
pass for the false-positive rows.)

## Migration inventory (build-verify + status per surface)

### A. Epdoc CODE EDITOR cluster — KEEP THE LOOK, API-only (highest coupling, do carefully + visual proof)
| File | WKWebView hits | Status |
|---|---:|---|
| `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` | 20 | not started |
| `Epistemos/Views/Notes/WebKitCodeEditorView.swift` | 13 | not started |
| `Epistemos/Engine/EpdocEditorBridge.swift` | 12 | not started |
| `Epistemos/Views/Epdoc/EpdocKaTeXPreview.swift` | 9 | not started |
| `Epistemos/Engine/KaTeXSnippets.swift` | 2 | not started |
| `Epistemos/Views/Epdoc/EpdocEditorToolbar.swift` | 2 | not started |
| `Epistemos/Views/Epdoc/EpdocBubbleMenuView.swift` | 1 | not started |
| `Epistemos/Views/Epdoc/EpdocSlashMenuView.swift` | 1 | not started |
| `Epistemos/Engine/EpdocDocument.swift` | 1 | not started |

### B. HTMLWorkspace cluster
| File | hits | Status |
|---|---:|---|
| `Epistemos/Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift` | 10 | not started (write-ready; rebuild-on-config-change design) |
| `Epistemos/Engine/HTMLWorkspacePDFExporter.swift` | 8 | ✅ **MIGRATED + BUILD SUCCEEDED** (b47s8vl7j) — `WebPage` + `NavigationDeciding` + `exported(as:.pdf(region:.rect))`; PDF-output proof OWED (owner) |
| `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift` | 2 | FALSE POSITIVE — `Text("WKWebView")` label + teardown comment; hosts no WKWebView |
| `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceHealthRow.swift` | 1 | not started |
| `Epistemos/Engine/HTMLWorkspaceCapabilityStatus.swift` | 1 | not started |

### C. Notes / Markdown / misc web surfaces (lower coupling — good FIRST migrations to set the pattern)
| File | hits | Status |
|---|---:|---|
| `Epistemos/Views/Shared/MarkdownTextView.swift` | 1 | not started |
| `Epistemos/Views/Notes/ProseTextView2.swift` | 1 | not started |
| `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | 1 | not started |
| `Epistemos/Engine/HaloEditorBridge.swift` | 1 | not started |
| `Epistemos/Engine/RopeFFIClient.swift` | 2 | not started |
| `Epistemos/Views/Settings/EditorBundleHealthRow.swift` | 2 | not started |
| `Epistemos/Engine/BrowserCapabilityStatus.swift` | 1 | **FALSE POSITIVE — no migration** (the only "WKWebView" is a COMMENT: "nonPersistent() on 5 WKWebView hosts"; the file is a static capability-status enum, zero actual WKWebView usage) |

### Already on the NEW API (reference templates — NOT to migrate)
`Epistemos/Work/WorkWebSurfaceView.swift`, `Epistemos/Work/WorkRuntimeSupervisor.swift`.

## Recommended order (REVISED by the 2026-06-24 verification pass — category C is empty)
1. **B (HTMLWorkspace)** FIRST — real but less look-critical; harden the new-API pattern + bridging helpers
   here. Real files: `HTMLWorkspacePreviewView`, `HTMLWorkspacePDFExporter`, `HTMLWorkspaceEditorView` (verify).
2. **A (Epdoc editor)** LAST — most coupled + look-critical; KEEP the look exactly + visual proof. Real files:
   `EpdocEditorChromeView` (`EpdocEditorWebView: WKWebView`), `WebKitCodeEditorView`, `EpdocEditorBridge`,
   `EpdocKaTeXPreview`.
3. **C: nothing to do** — all entries are comment-only false positives (see verification pass above).
Each surface: migrate → swiftc -parse → BACKGROUND xcodebuild checkpoint → (look-bearing) visual proof →
mark status. NEVER xcodegen.

## Log
- 2026-06-24: ledger created from a full WKWebView inventory (owner directive). Not started; Work spike
  (`WorkWebSurfaceView`) is the new-API reference. Tangent to the Work foundation build — interleave.
- 2026-06-24: VERIFICATION PASS — code-vs-comment classification of every 1-2-hit site. ALL of them
  (14 files incl. the whole category C) are FALSE POSITIVES: the `WKWebView` token appears only in `//`/`///`
  comments. Real migration narrowed to ~6-7 files (Epdoc cluster + HTMLWorkspace cluster); `EpdocEditorChromeView`
  spot-confirmed real (`private final class EpdocEditorWebView: WKWebView` :53). Order revised to B → A.
- 2026-06-24: B-CLUSTER recon + SDK-resolved migration spec. `HTMLWorkspaceEditorView.swift` is ALSO a FALSE
  POSITIVE (its 2 hits = a `Text("WKWebView")` label + a teardown comment; it embeds the preview, hosts no
  WKWebView). REAL B sites = **`HTMLWorkspacePreviewView.swift`** (NSViewRepresentable WKWebView host, 223 lines)
  + **`HTMLWorkspacePDFExporter.swift`** (headless WKWebView→PDF, 154 lines).

  ### HTMLWorkspacePreviewView — migration spec (API mappings RESOLVED against the 26.4 WebKit.swiftinterface)
  The new SwiftUI WebKit API lives in the `WebKit` module (`WebKit.framework/.../WebKit.swiftmodule/
  arm64e-apple-macos.swiftinterface`). Mappings (✅ = confirmed in the interface; ⚠️ = name/location to confirm):
  - ✅ `WKWebViewConfiguration` → `WebPage.Configuration` (`@MainActor struct`, :125). Its props carry over NEAR-1:1:
    - ✅ `configuration.websiteDataStore = .nonPersistent()` → `WebPage.Configuration.websiteDataStore: WKWebsiteDataStore` (:127) — UNCHANGED.
    - ✅ `configuration.userContentController.add(handler, name:)` + `addUserScript(WKUserScript(...))` →
      `WebPage.Configuration.userContentController: WKUserContentController` (:128) — **UNCHANGED**. The safeAPI +
      console-bridge `WKScriptMessageHandler` + injection `WKUserScript` machinery migrates AS-IS (biggest risk retired).
    - ✅ `configuration.defaultWebpagePreferences.allowsContentJavaScript` → `configuration.defaultNavigationPreferences.allowsContentJavaScript: Bool` (:130/:380).
    - ⚠️ `configuration.preferences.javaScriptCanOpenWindowsAutomatically = false` — no `preferences`/WKPreferences on the new
      Configuration in the grep; likely dropped/relocated. Minor hardening default — confirm or drop.
  - ✅ `WKWebView` host (NSViewRepresentable) → SwiftUI `WebView(page)` + `@State var page = WebPage(configuration:navigationDecider:)`
    (inits at :451/:453; bare `WebPage()` per the `WorkWebSurfaceView` reference). The NSViewRepresentable wrapper is
    REPLACED by a SwiftUI view; `updateNSView`'s reload-on-change → `.onChange`/`.task` calling `page.load(html:)`.
  - ✅ `webView.loadHTMLString(rendered, baseURL: nil)` → `page.load(html: rendered)` (:517, default baseURL `about:blank`).
  - ✅ navigation policy: `Coordinator: WKNavigationDelegate.webView(_:decidePolicyFor:decisionHandler:)` →
    a `NavigationDeciding` conformer (:325) `mutating func decidePolicy(for action: WebPage.NavigationAction,
    preferences: inout) async -> WKNavigationActionPolicy` (:326). NOTE: ASYNC return (no `decisionHandler` callback) —
    the scheme-allowlist logic (about→allow; !allowNetwork→cancel; non-http/https→cancel) maps directly to a returned
    `.allow`/`.cancel`. Passed via `WebPage(configuration:navigationDecider:)`.
  - ✅ `WKScriptMessageHandler.userContentController(_:didReceive:)` (console capture) → UNCHANGED (still WKUserContentController).
  - ✅ `webView.setValue(false, forKey:"drawsBackground")` (KVC transparency hack) → `.webViewContentBackground(.hidden)`
    (SwiftUI modifier, takes `SwiftUICore.Visibility`). Confirmed in the `_WebKit_SwiftUI` cross-import overlay
    (`.../System/Cryptexes/OS/System/Library/Frameworks/_WebKit_SwiftUI.framework/.../arm64e-apple-macos.swiftinterface:48`).
  - ✅ `allowsBackForwardNavigationGestures = false` → `.webViewBackForwardNavigationGestures(.disabled)` (:16, enum :100-103);
    `allowsLinkPreview = false` → `.webViewLinkPreviews(.disabled)` (:26, enum :116-119). Same overlay.
  NOTE: the SwiftUI `WebView` (`struct WebView: View`, `init(_ page: WebPage)` :85-86) + ALL its modifiers live in the
  `_WebKit_SwiftUI` CROSS-IMPORT overlay — auto-imported when a file does BOTH `import SwiftUI` + `import WebKit` (exactly
  what HTMLWorkspacePreviewView already does). No explicit import needed.
  - ✅ `dismantleNSView`/`detach` (stopLoading + remove handlers) → handled by WebPage lifecycle / `.onDisappear`;
    handler removal still via `configuration.userContentController.removeScriptMessageHandler(forName:)`.
  NET: HTMLWorkspacePreviewView migration is HIGHLY feasible — the config + script-handler core is near-unchanged; only
  the host wrapper (NSViewRepresentable→WebView), nav-policy (delegate→async NavigationDeciding), and ~3 cosmetic SwiftUI
  modifiers change. **BLOCKERS: NONE — all API mappings RESOLVED against the 26.4 SDK; the migration is WRITE-READY.**
  (Only owed item is VISUAL PROOF — look-bearing, owner runs.) Write approach: a SwiftUI `struct` wrapping `WebView(page)`
  with a small `@Observable`/coordinator holding the `WebPage` + `NavigationDeciding` decider + the WKUserContentController
  handler wiring; `.onChange(of: package)`/`.task` drives `page.load(html:)`; apply `.webViewContentBackground(.hidden)`
  + `.webViewBackForwardNavigationGestures(.disabled)` + `.webViewLinkPreviews(.disabled)`. `HTMLWorkspacePDFExporter` is simpler (headless: `loadHTMLString`
  → `page.load(html:)`; `evaluateJavaScript` → `page.callJavaScript` :533; `didFinish` delegate → the `page.navigations`
  AsyncSequence :458 / awaiting `load(...)`'s returned sequence).
- 2026-06-24: **FIRST REAL MIGRATION DONE** — `HTMLWorkspacePDFExporter.swift` legacy WKWebView → macOS-26 `WebPage`.
  BUILD SUCCEEDED (b47s8vl7j, app target). Used: `WebPage.Configuration` (nonPersistent dataStore +
  `defaultNavigationPreferences.allowsContentJavaScript`); `WebPage.NavigationDeciding` struct for the scheme
  allowlist (async `decidePolicy`, returns `.allow`/`.cancel`); `page.load(html:)` driven to `NavigationEvent.finished`
  ON THE MAIN ACTOR with a `ContinuousClock` deadline; `page.callJavaScript("return …")` for documentHeight;
  `page.exported(as: .pdf(region: .rect(NSRect(0,0,960,height))))` (preserves exact 960×bounded-height output).
  Source-guard test updated in lockstep. GOTCHAS for the next migrations: (1) `WebPage.NavigationDeciding` is NESTED in
  `WebPage` — spell it `WebPage.NavigationDeciding`, not bare. (2) NEVER hand the @MainActor `WebPage` to a
  task-group/child closure — it trips the region-based isolation checker ("pattern the checker does not understand");
  iterate its async sequences on the main actor. PDF-output correctness (size/pagination) is RUNTIME-PROOF-OWED.
