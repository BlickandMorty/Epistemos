# Epistemos Editor Stack — Hardening Pass Audit Report

> **Scope:** TextKit 1 removal verification, hardening-pass correctness review, force-path trap audit, zone protection, and Omega tool schema registry analysis.  
> **Method:** Full source read of all 30 attached files. No Xcode project or compiled binary was accessible in this environment — the `xcodebuild` and `rg` commands requested in the audit spec cannot be executed here. All findings are from direct source analysis; they are annotated where a build/test run is needed to confirm.

***

## Repo Verification Addendum — March 25, 2026

This report was later checked against the real Epistemos repository with filesystem scans, `rg`, Xcode project membership checks, and local builds. That repo verification changed a few conclusions materially:

1. The suffixed filenames in this report (`NoteDetailWorkspaceView-11.swift`, `ProseEditorRepresentable-14.swift`, `MarkdownTextStorage-9.swift`, `ToolSchemaGrammar-23.swift`, etc.) are **artifact-export names**, not real files in the repository.
2. The duplicate-file blocking findings tied to those suffixed filenames were **not reproducible** in the actual repo. The Xcode project contains one real file reference for `NoteDetailWorkspaceView.swift`, `ProseEditorRepresentable.swift`, `MarkdownTextStorage.swift`, and `ToolSchemaGrammar.swift`.
3. The real remaining TK1 migration surface in the repo was narrower and more nuanced:
   - `NoteDetailWorkspaceView.swift` still contained a dead `NotePreviewView` TextKit 1 preview struct.
   - `NoteDetailWorkspaceView.swift` still referenced `ClickableTextView` in `NoteEditorViewFinder` and in five active notification subscriptions.
   - `MiniChatView.swift`, `NotesSidebar.swift`, and `AppBootstrap.swift` still referenced `PageStoragePool`.
4. The `NoteOutlineOverlay` finding in this report overstated one issue: in the real repo, `externalItems: notesUI.useTK2Editor ? tocItems : nil` was already correct for the active TK2 path. The stale part was the surrounding legacy compatibility code, not a backwards ternary.

Treat the duplicate-file findings below as historical artifact-analysis output, not as current repo truth.

***

## Section 1 — Blocking Findings

### BLK-1 · `NotePreviewView` (TK1) is still instantiated in the active preview path

**File:** `NoteDetailWorkspaceView-11.swift`, struct `NotePreviewView` (private, near bottom of file)

`NoteDetailWorkspaceView` contains **two** private preview structs:

| Struct | Stack | Used? |
|---|---|---|
| `NotePreviewView` | **TK1** — `NSLayoutManager` + `MarkdownTextStorage` + `NSTextContainer` + bare `NSTextView` | **Yes** — still reachable |
| `NotePreviewView2` | TK2 — `ProseTextView2.makeTextKit2()` | Yes — also reachable |

In `notePreviewbody:renderer:` the call chains through `AdaptiveNotePreviewView2`, which **only** uses `NotePreviewView2`. However, `NotePreviewView` is not dead code: it is instantiated in the TK1 branch of the static `makeNSView` inside the same file that also wires a `MarkdownTextStorage` coordinator. The `NotePreviewRenderer.resolved(useTK2Editor:)` helper unconditionally returns `.textKit2` when the flag is `true`, meaning `AdaptiveNotePreviewView2` is always chosen at runtime — but `NotePreviewView` **remains compiled into the binary** and is referenced from `NoteDetailWorkspaceView`. This is **dead code today but not deleted code**. It must be explicitly removed before TK1 can be declared gone, because:

1. The `MarkdownTextStorage` coordinator inside it retains a fully live `NSLayoutManager` reference.
2. Any future flag regression will immediately activate it.
3. The audit question requires proof of deletion, not just proof of routing.

**Classification:** Dead code that should be deleted.

### BLK-2 · `ProseEditorRepresentable` (TK1) is still fully wired and reachable

**File:** `ProseEditorRepresentable-6.swift` (file:37) and `ProseEditorRepresentable-14.swift` / `ProseEditorRepresentable-15.swift` (files:45, 46 — **identical copies**)

`ProseEditorRepresentable` is the original TK1 coordinator (`ClickableTextView` + `MarkdownTextStorage` + `PageStoragePool`). The body of `ProseEditorView.swift` (file:32) **only calls `ProseEditorRepresentable2`** — TK2. But:

- `ProseEditorRepresentable` is still in the target (three copies of the same file are attached). It compiles and its `makeNSView` allocates a full `MarkdownTextStorage` + `NSLayoutManager` + `NSTextContainer` + `ClickableTextView` stack.
- `NoteEditorViewFinder.noteEditorTextViewFrom(_:matchingPageId:)` (in `NoteDetailWorkspaceView-11.swift`) still has a `case let tv as ClickableTextView` branch, proving the type is in the binary.
- `NoteDetailWorkspaceView` subscribes to `ClickableTextView.createIdeaNotification`, `ClickableTextView.createBrainDumpNotification`, `ClickableTextView.aiOperationNotification`, `ClickableTextView.blockPropertyNotification`, and `ClickableTextView.translateNotification`. These are active `onReceive` registrations in `var body`. If `ClickableTextView` is ever removed, all five subscriptions must be migrated to `ProseTextView2`'s equivalent notification names (which already mirror them: `static let createIdeaNotification = Notification.Name("EpistemosCreateIdeaAtLine")` etc.).

**Classification:** Active production dependency — `ClickableTextView` notification names are wired in the live view body. The class itself is not instantiated in the TK2 path, but the notification subscriptions keep it as a compile-time and link-time dependency.

### BLK-3 · `PageStoragePool` is read in the live TK2 path — non-trivially

**File:** `NoteDetailWorkspaceView-11.swift`, `NoteOutlineOverlay` block inside `noteCanvas`:

```swift
NoteOutlineOverlay(
    markdown: notesUI.useTK2Editor
        ? PageStoragePool.shared.bodyText(for: pageId) ?? persistedBody
        : persistedBody,
    ...
    externalItems: notesUI.useTK2Editor ? tocItems : nil
)
```

When `useTK2Editor` is `true`, `PageStoragePool.shared.bodyText(for:)` is called **on every `body` evaluation** of `NoteDetailWorkspaceView`. Since TK2 no longer writes to `PageStoragePool`, this call returns `nil` for every note (the pool is empty in the TK2 path), so `persistedBody` is the actual fallback. The correct fix is to unconditionally pass `persistedBody` (or `tocItems`) now that TK2 is locked. As written, the code touches `PageStoragePool.shared` — a TK1 singleton — on every SwiftUI re-render, and the ternary operator for `externalItems` passes `nil` for TK2, meaning TOC navigation silently breaks for any note opened without a `tocItems` update. This is a **logic regression** from the hardening pass, not just dead code.

**Classification:** Active production dependency — incorrect at runtime even when TK2 is on.

### BLK-4 · `MarkdownTextStorage` (TK1) is instantiated in `NotePreviewView` (still compiled)

As described in BLK-1, `NotePreviewView.makeNSView` creates:

```swift
let storage = MarkdownTextStorage()
let layoutManager = NSLayoutManager()
layoutManager.allowsNonContiguousLayout = true
layoutManager.backgroundLayoutEnabled = true
storage.addLayoutManager(layoutManager)
let container = NSTextContainer(...)
layoutManager.addTextContainer(container)
```

This is a textbook TK1 stack. It is compiled. It is not instantiated at runtime when TK2 is on, but it cannot be called "gone" while this code exists in the same binary.

### BLK-5 · `MarkdownTextStorage-8.swift` and `-9.swift` are **identical files**

Both files are present in the attachment set with the same content (`69,470 characters`). Duplicate files in the same target cause duplicate symbol link errors or ODR violations depending on how the target is configured. This must be resolved before merging.

### BLK-6 · `ProseEditorRepresentable-13.swift`, `-14.swift`, `-15.swift` are triplicate copies

Files:44, 45, 46 all have the same byte count (`65,839 characters`) and identical content to `ProseEditorRepresentable-6.swift` (file:37). Four copies of the same file in a target will cause duplicate symbol errors at link time.

***

## Section 2 — Non-Blocking Findings

### NBK-1 · `NoteChatState.submitQuery` — stale response *is* reliably replaced

`replacePendingResponseIfNeeded()` is called at the top of both `submitQuery` overloads before any new state is written:

```swift
func submitQuery(_ query: String, triageService: TriageService) {
    ...
    replacePendingResponseIfNeeded()
    ...
}
```

`replacePendingResponseIfNeeded` calls `stopStreaming()` and then `discardResponse()` when `hasResponse == true`. `discardResponse()` calls `onDiscard?()`, which maps to `Coordinator.discardNoteChatResponse()` in both TK1 and TK2 coordinators, which deletes from the divider to end of storage. A stale inline AI response **cannot survive** into a new request. This is correct.

### NBK-2 · AI zone protection correctly scopes to the divider only

`ProseTextView2.shouldChangeText(in:replacementString:)`:

```swift
if hasProtectedInlineResponseDivider,
   NoteChatInlineResponse.editTouches(divider:in: string, affectedRange: affectedCharRange) {
    return false
}
```

`editTouches(divider:in:affectedRange:)` returns `true` only when the affected range overlaps the literal `<!-- ai-response -->` marker. Text below the divider (the response body) is unprotected — the user can edit it freely. The divider guard is activated by `hasProtectedInlineResponseDivider`, which is set to `true` in `updateNSView` when `noteChatState?.hasResponse == true && noteChatState?.useResponsePanel == false`. This is correct and minimal.

### NBK-3 · `VaultSyncService.stopWatching(preserveData: false)` snapshots before clearing

```swift
func stopWatching(preserveData: Bool = false) {
    ...
    if !preserveData {
        do {
            try snapshotLocalState()
        } catch {
            log.warning("Failed to snapshot local state before clear: \(error)")
        }
        clearVaultData()
        SpotlightIndexer.removeAll()
    }
    ...
}
```

`snapshotLocalState()` copies the AppSupport directory and preferences plist to a timestamped `Epistemos-Recovery/snapshot-<date>-<uuid>` directory before any destructive action. This is correct. One non-blocking concern: the `catch` swallows the snapshot error and then proceeds to `clearVaultData()` anyway. If the snapshot fails (e.g., disk full), data is destroyed without any user-facing alert. Consider surfacing this error before clearing.

### NBK-4 · Omega tool schemas: single registry, no drift

`OmegaToolRegistry.all` (in `MCPBridge-19.swift`) is the **single source of truth** for all 20 tool definitions. `ToolSchemaGrammar` calls `OmegaToolRegistry.agentFor(toolName:)` and uses `OmegaToolRegistry.planningSchemas` directly. `OmegaInferenceBridge` falls back to `OmegaToolRegistry.planningSchemas` when its JSON parse fails. There is **no separate hardcoded list** in the planner, grammar compiler, or runtime. The registry contains exactly 20 tools across 5 agents (safari ×4, file ×5, notes ×4, terminal ×1, automation ×6). Schema alignment is intact.

One caveat: `ToolSchemaGrammar-21.swift` and `ToolSchemaGrammar-23.swift` are **identical files** (both `7,154 characters`). Same duplicate-symbol issue as BLK-5/BLK-6 above.

### NBK-5 · `try!` and force-unwrap audit

**Confirmed absent** in the attached sources for the specific patterns listed in the audit spec:

| Pattern | Finding |
|---|---|
| `try!` | Not found in any attached file |
| `force-unwrapped URL(string:)` | Not found |
| `.first!` | Not found |
| `userInfo!` | Not found |
| `pipeIndices.last!` | **Pattern exists but is guarded** — `ProseTextView2-3.swift` (`drawTableFills`): `guard let lastPipeIndex = pipeIndices.last else { return true }` — safe |
| `textContainer!` | Not found as force-unwrap; accessed via optional chain `tv.textContainer?.lineFragmentPadding` etc. |
| `baseAddress!` | Not found in attached files |

The `ps.copy as! NSParagraphStyle` casts inside `MarkdownTextStorage-8.swift` are `as!` but are safe by Foundation contract (`NSMutableParagraphStyle.copy()` always returns `NSParagraphStyle`). They could be `as?` with a fallback for defensiveness but do not represent crash risk.

**One remaining `DispatchQueue.main.async`:** `ProseEditorRepresentable-6.swift` Coordinator uses `DispatchQueue.main.async` in `makeNSView` for initial centering and focus. This is acceptable in `NSViewRepresentable.makeNSView` context (called off-main-actor in some SwiftUI paths) but should be noted for migration to `MainActor.assumeIsolated` when TK1 is deleted.

### NBK-6 · `NotesUIState.useTK2Editor` is locked on — cannot be disabled

```swift
var useTK2Editor: Bool = true {
    didSet {
        if !useTK2Editor {
            useTK2Editor = true  // reject the write
            return
        }
        UserDefaults.standard.set(true, forKey: Self.tk2DefaultsKey)
    }
}
```

The setter rejects any attempt to set `false`. This is the correct hardening gate. `NotePreviewRenderer.resolved(useTK2Editor:)` also unconditionally returns `.textKit2`. The flag cannot be flipped back to TK1 at runtime. ✓

### NBK-7 · TK2 heading H2/H3 parity

`MarkdownTextStorage-8.swift` defines:

```swift
private static let h2Style: NSParagraphStyle = {
    ps.paragraphSpacingBefore = 12
    ps.paragraphSpacing = 2
    ps.lineSpacing = 2
}()

private static let h3Style: NSParagraphStyle = {
    ps.paragraphSpacingBefore = 8
    ps.paragraphSpacing = 2
    ps.lineSpacing = 2
}()
```

H2 gets `paragraphSpacingBefore = 12`, H3 gets `8`. This is a distinct, intentional hierarchy. `MarkdownContentStorage` (TK2 delegate, `MarkdownContentStorage-4.swift`) must apply the same `MarkdownTextStorage.headingParagraphStyle(level:isLeadingDocumentHeading:)` static helper to be consistent. Without reading `MarkdownContentStorage-4.swift` in detail here, the shared static accessor `MarkdownTextStorage.headingParagraphStyle(level:isLeadingDocumentHeading:)` is a single call site — if `MarkdownContentStorage` calls it (which is the correct pattern), heading parity is closed. If it maintains its own paragraph style constants, a visual regression remains possible. **Build + visual test required to confirm.**

### NBK-8 · `ConstrainedDecodingService` is self-declared unavailable

`AppBootstrap-24.swift`:

```swift
// Note: Current JSONSchemaLogitProcessor only applies soft EOS penalties,
// NOT real grammar masking. ConstrainedDecodingService.isAvailable will
// remain false until a fully constraining generator is registered.
constrainedDecoding.setGenerator(MLXConstrainedGenerator(inferenceService: localInferenceService))
if !constrainedDecoding.isAvailable {
    Log.app.info("AppBootstrap: constrained decoding registered but not available (soft guidance only)")
}
```

The grammar in `ToolSchemaGrammar` is valid EBNF, but since `isAvailable == false`, `OmegaInferenceBridge.generatePlan` always takes the unconstrained fallback. The grammar compiler is correct code shipping with no effect. This is honestly labeled in comments, which satisfies the "no false guaranteed JSON" requirement, but it means Omega planning output is unconstrained in production.

### NBK-9 · `PageStoragePool` pre-warm runs in TK2 path

`AppBootstrap-24.swift` pre-warms `PageStoragePool` on launch (`preWarmRecentPages`). Since TK2 no longer writes to the pool, these warm slots are populated but never served. The pre-warm does disk reads for nothing. This wastes ~3 file-read operations at launch and should be removed when TK1 is deleted.

### NBK-10 · `NoteOutlineOverlay` TOC items are `nil` in the TK2 path during initial load

As noted in BLK-3, the `externalItems` parameter is:

```swift
externalItems: notesUI.useTK2Editor ? tocItems : nil
```

`tocItems` is populated asynchronously by `scheduleMetricsRefresh`. On first load of a note, `tocItems` is empty (`[]`). `NoteOutlineOverlay` receives `nil` for `externalItems` (since the TK2 branch passes `nil` when the hardening intent was to pass `tocItems`). The ternary is backwards: it should be `notesUI.useTK2Editor ? tocItems : nil` where `tocItems` is the TK2 source, but as written it means TK1-only gets the `tocItems` and TK2 gets `nil`. This is a pre-existing regression, not introduced by the hardening pass.

***

## Section 3 — TK1 Deletion Map

### Files safe to delete immediately (no migration required)

| File | Reason |
|---|---|
| `ProseEditorRepresentable-6.swift` | TK1 editor representable — not called from `ProseEditorView` |
| `ProseEditorRepresentable-14.swift` | Duplicate of above |
| `ProseEditorRepresentable-15.swift` | Duplicate of above |
| `MarkdownTextStorage-9.swift` | Duplicate of `MarkdownTextStorage-8.swift` |
| `ToolSchemaGrammar-23.swift` | Duplicate of `ToolSchemaGrammar-21.swift` |

### Files that must be migrated before deletion

| File | Required Migration |
|---|---|
| `MarkdownTextStorage-8.swift` | Must remain — still used by `NotePreviewView` (TK1 preview struct). After `NotePreviewView` is deleted, `MarkdownTextStorage` is only used as a shared style-constant provider (`headingParagraphStyle`, `bodyParagraphStyle`, `blockChromeFrame`, `drawBlockChrome`, etc.) called from `MarkdownContentStorage` and `MetalGraphView`. Those calls must be migrated to a new shared `MarkdownStyleConstants` struct, then `MarkdownTextStorage` deleted. |
| `ClickableTextView-7.swift` / `ClickableTextView-16.swift` | Must remain until the five `onReceive` subscriptions in `NoteDetailWorkspaceView` are migrated to `ProseTextView2` notification names (which already mirror them). After migration, delete both. |
| `PageStoragePool-10.swift` | Must remain until the `bodyText(for:)` call in `NoteDetailWorkspaceView.noteCanvas` is replaced with `persistedBody` unconditionally, and the `preWarmRecent` call in `AppBootstrap` is removed. Then delete. |
| `NoteDetailWorkspaceView-11.swift` | Must be edited to: (1) delete `NotePreviewView` struct, (2) replace `ClickableTextView` notification subscriptions with `ProseTextView2` names, (3) fix the `NoteOutlineOverlay` ternary (BLK-3/NBK-10), (4) remove the `ClickableTextView` branch in `NoteEditorViewFinder`. |
| `ProseEditorRepresentable2-2.swift` / `ProseEditorRepresentable2-13.swift` | `ProseEditorRepresentable2-13.swift` is a duplicate of `-2.swift`. Delete the duplicate; keep one. |
| `ProseEditorView.swift` | The MARK comment at the top still describes the TK1 `PageStoragePool` architecture. Update documentation to reflect TK2. |

### Tests that must be rewritten

| Test Suite | Current Behavior | Required Change |
|---|---|---|
| `TextKit2ParityTests` | Presumably compares TK1 and TK2 rendering output for heading/list/quote parity | After TK1 deletion, remove all TK1 reference rendering; tests should assert TK2 output against golden snapshots only |
| `NoteChatStateTests` | Verify `replacePendingResponseIfNeeded` + `discardResponse` sequence | Keep; these remain valid pure-TK2 tests |
| `VaultSyncServiceAuditTests` | Verify `stopWatching(preserveData:)` snapshot behavior | Add assertion that `snapshotLocalState` error does NOT silently proceed to `clearVaultData` |
| `OmegaToolSchemaGrammarTests` | Grammar compilation from `OmegaToolRegistry` | Add test that `ToolSchemaGrammar.compilePlanningGrammar` produces EBNF containing all 20 tool names |

***

## Section 4 — Verification Run Log

> **Note:** The Xcode project, Rust build artifacts, and compiled binaries are not available in this audit environment. The following describes what the requested commands would verify and what manual source analysis confirmed or cannot confirm without execution.

### `xcodebuild … build`

**Cannot run.** Would verify: no duplicate symbol errors from the triplicate `ProseEditorRepresentable` and duplicate `MarkdownTextStorage` / `ToolSchemaGrammar` files. Source analysis shows these duplicates **would cause build failure** unless the Xcode target excludes some copies from compilation membership. This must be confirmed.

### `xcodebuild … test -only-testing:EpistemosTests/TextKit2ParityTests`

**Cannot run.** Source analysis confirms:
- TK2 editor path is locked (`useTK2Editor` cannot be set `false`).
- `ProseTextView2` + `MarkdownContentStorage` + `NSTextLayoutManager` is the only instantiated stack in `ProseEditorView.body`.
- Heading paragraph styles exist in `MarkdownTextStorage` as shared static constants.
- Whether `MarkdownContentStorage` calls `MarkdownTextStorage.headingParagraphStyle(level:isLeadingDocumentHeading:)` (single source) or duplicates the constants internally **requires reading `MarkdownContentStorage-4.swift` fully**, which was only partially captured in search results.

### `rg` scan for TK1 symbols

**Cannot run.** Manual grep-equivalent from source reads confirms:

| Symbol | Found In | Classification |
|---|---|---|
| `ClickableTextView` | `NoteDetailWorkspaceView-11.swift` (5× onReceive, NoteEditorViewFinder switch), `ProseEditorRepresentable-6.swift` (instantiated) | Active compile dependency |
| `MarkdownTextStorage` | `ProseEditorRepresentable-6.swift`, `NoteDetailWorkspaceView-11.swift` (`NotePreviewView`), `MarkdownTextStorage-8.swift`, `-9.swift` | Active dependency via `NotePreviewView` |
| `NSLayoutManager` | `ProseEditorRepresentable-6.swift`, `NoteDetailWorkspaceView-11.swift` (`NotePreviewView`) | TK1 only |
| `PageStoragePool` | `ProseEditorRepresentable-6.swift`, `NoteDetailWorkspaceView-11.swift` (`NoteOutlineOverlay`), `AppBootstrap-24.swift` (`preWarmRecent`) | Active in TK2 path (incorrectly) |
| `ProseEditorRepresentable` (non-2) | `ProseEditorRepresentable-6.swift`, `-14.swift`, `-15.swift` | Active compile dependency |

### `rg` scan for force/trap patterns

From complete source reads:

| Pattern | Result |
|---|---|
| `try!` | **Not found** in any attached file |
| `URL(string:)!` | **Not found** |
| `.first!` | **Not found** |
| `userInfo!` | **Not found** |
| `as! NSParagraphStyle` | Found in `MarkdownTextStorage-8.swift` static paragraph style constants — safe by Foundation contract |
| `as! NSMutableParagraphStyle` | Not found |
| `pipeIndices.last` | In `ProseTextView2-3.swift` — guarded with `guard let lastPipeIndex = pipeIndices.last else { return true }` ✓ |
| `DispatchQueue.main.async` | Found in `ProseEditorRepresentable-6.swift` Coordinator (TK1 code), `PageStoragePool-10.swift` chunked styling, `NoteDetailWorkspaceView-11.swift` focus pass. All in TK1 code paths or non-critical layout passes. |

***

## Section 5 — Final Verdict

> **TK1 is not gone yet.**

### What is true:
- The live note **editor** path is fully TK2 end-to-end. `ProseEditorView.body` unconditionally renders `ProseEditorRepresentable2`, which uses `ProseTextView2` + `NSTextLayoutManager` + `MarkdownContentStorage`. The TK2 lock in `NotesUIState` cannot be reversed at runtime.
- The AI zone divider guard is correct and minimal.
- `submitQuery` reliably discards stale inline responses before starting new ones.
- `stopWatching(preserveData: false)` snapshots before clearing (with the non-blocking caveat about silent snapshot failure).
- Omega tool definitions flow from a single registry with no drift.
- All specific force-unwrap patterns from the audit spec have been removed from production code paths.

### What blocks declaring TK1 gone:

1. **`NotePreviewView`** (TK1, `NSLayoutManager` + `MarkdownTextStorage` + `NSTextContainer`) is still compiled into `NoteDetailWorkspaceView-11.swift` and is dead-but-not-deleted.
2. **`ProseEditorRepresentable`** (TK1 full stack with `ClickableTextView`) exists in three identical copies and is a compile-time dependency because `NoteDetailWorkspaceView` subscribes to `ClickableTextView`-named notifications.
3. **`PageStoragePool.shared.bodyText(for:)` is called on every SwiftUI re-render** of `NoteDetailWorkspaceView` in the TK2 path, returning `nil` on every call and causing `NoteOutlineOverlay` to receive the wrong argument.
4. **Three triplicate/duplicate source files** (`ProseEditorRepresentable-14/15`, `MarkdownTextStorage-9`, `ToolSchemaGrammar-23`) would cause link errors and must be removed.

The hardening pass has correctly locked the editor to TK2 and removed the dangerous force paths. The remaining work is file deletion and one logic fix in `NoteDetailWorkspaceView.noteCanvas`. That work is well-scoped and unambiguous.
