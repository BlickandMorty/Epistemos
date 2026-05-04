# Epistemos View-Layer Pruning Audit
### 2026-03-26 — Scope: 19 Uploaded View Files

---

## Section 1: Highest-Value Findings

### 1.1 — CRITICAL REDUNDANCY: Triple-Duplicated Composer Reference Logic

**Files affected:** `ChatInputBar.swift`, `MiniChatView.swift` (MiniChatInputBar), `LandingView.swift`

Three separate views independently maintain identical @-mention / reference-popover state machines with nearly identical logic. Each one declares its own copies of:

```
@State showMentionDropdown
@State mentionFilter
@State mentionPickerAutofocus
@State referencePopoverStyle
@State referenceSearch (ComposerReferenceSearchState)
```

And each one implements its own copies of: `openNotePicker()`, `openChatPicker()`, `attachMentionReference()`, `dismissReferencePopover()`, `updateMentionReferenceSearch()`, `recentChats()`, and the `onChange(of: text)` handler that triggers the mention dropdown.

**Drift risk is real.** MiniChatInputBar's `attachMentionReference` additionally calls `persistMiniChatSession()`, while ChatInputBar's does not — this is *intentional* because MiniChat has independent persistence. But the shared logic around parsing, filtering, and popover lifecycle is identically duplicated 220+ lines across three files with zero shared extraction.

**Recommendation:** Extract a `ComposerReferenceCoordinator` (either @Observable class or a reducer-style value type) that encapsulates the mention-state machine. Each composer instantiates one and injects its own submit/persist hooks. This eliminates ~400 lines of duplicated state management and makes the mention UX consistent across all three surfaces.

**Priority: HIGH — fix now.** This is the single highest-leverage cleanup in the uploaded files.

---

### 1.2 — CONFIRMED BUG: Dead Computation in `makeChatTranscriptRows`

**File:** `ChatView.swift`, lines ~87-91

```swift
for message in messages {
    let displayContent = ChatPresentationFormatter.displayContent(for: message)  // ← computed here
    if message.role == .user {
        lastUserQuery = message.content
        rows.append(
            ChatTranscriptRow(
                ...
                displayContent: ChatPresentationFormatter.displayContent(for: message, chatTitle: chatTitle),  // ← computed AGAIN with different args
                ...
            )
        )
    }
```

The first `displayContent` (computed at the top of the loop) is **never used** when `message.role == .user`. The user branch calls `ChatPresentationFormatter.displayContent` a second time with the `chatTitle` parameter. For the assistant branch, `displayContent` is also recomputed with additional parameters. The top-level `let displayContent` is effectively dead for all paths.

**Impact:** Wastes CPU on every transcript rebuild (which happens on every new message and every `transcriptRevision` change). For a conversation with 50 messages, that's 50 redundant regex operations (`userModePrefixRegex` match + `UserFacingModelOutput.finalVisibleText`).

**Fix:** Remove the dead `let displayContent` at the top of the loop. Each branch already computes its own.

**Priority: HIGH — trivial fix, measurable waste.**

---

### 1.3 — PERFORMANCE: JSON Decoding on Every Render in WorkspaceSwitcherOverlay

**File:** `WorkspaceSwitcherOverlay.swift`, `WorkspaceRow`

Both `snapshotSummary` (line ~287) and `computeDrift()` (line ~357) are computed properties that call `JSONDecoder().decode(WorkspaceSnapshot.self, from: workspace.snapshotData)` every time the view's body is evaluated. Since `WorkspaceRow` has `@State private var isHovered`, hovering any row triggers body re-evaluation of *that* row, which re-decodes the snapshot JSON.

Additionally, `computeDrift()` calls `NoteWindowManager.shared.orderedPageIds()` and `MiniChatWindowController.shared.openChatIds` on every evaluation — these are live state queries that force fresh computation.

**Fix:** Decode the snapshot once in `onAppear` or compute it as a `@State` initialized from an `.task {}` block. Cache the summary string and drift string, not the raw JSON.

**Priority: MEDIUM-HIGH — noticeable with 10+ workspaces.**

---

### 1.4 — PERFORMANCE: Unbounded Full-Table Scans in SessionIntelligenceOverlay

**File:** `SessionIntelligenceOverlay.swift`

Three functions perform unbounded `FetchDescriptor<SDPage>()` fetches (no predicate, no fetchLimit) followed by linear scans:

- `findNoteByTitle(_:)` — line ~927: fetches ALL pages, linear search
- `findChatByTitle(_:)` — line ~934: fetches ALL chats, linear search  
- `extractAndFindNote(from:)` — line ~915: fetches ALL pages, checks if ANY title appears as substring in the AI response text

For a vault with 500+ notes, these are expensive on the main actor. The `extractAndFindNote` function is particularly concerning because it checks `text.localizedCaseInsensitiveContains(page.title)` for every page — O(n × m) where n is page count and m is average title length.

**Fix:** Use SwiftData predicates with `#Predicate { $0.title.localizedStandardContains(searchTerm) }` or at minimum add a `fetchLimit` after finding the first match. For `extractAndFindNote`, build a title→pageId dictionary once if needed.

**Priority: MEDIUM — scales poorly with vault size.**

---

### 1.5 — TWO INCOMPATIBLE BRACKET-COMMAND SYSTEMS

**Files:** `SessionIntelligenceOverlay.swift` vs `MiniChatView.swift`

SessionIntelligenceOverlay defines one command format:
```
[CREATE_NOTE: title], [OPEN_NOTE: title], [NAVIGATE_GRAPH: id], [CLOSE_NOTE: title], [SAVE_SESSION]
```

MiniChatView's `executeNoteActions(response:page:)` defines a different format:
```
[ACTION:TAG tag1, tag2], [ACTION:MOVE FolderName], [ACTION:CREATE Title]
```

Plus SessionIntelligenceOverlay has a legacy `[CMD: ...]` fallback parser that coexists with the primary bracket parser.

These are two completely separate regex-based action dispatch systems that overlap in capability (both can create notes) but use incompatible syntax. An LLM's response format depends on which surface it was prompted from, creating a fragile coupling between prompt engineering and view-layer parsing.

**Recommendation:** Unify into a single `ActionCommandParser` that both views share. Standardize on one bracket format. Remove the legacy `[CMD: ...]` path.

**Priority: MEDIUM — architectural debt, not a user-facing bug yet.**

---

## Section 2: Subsystems That Are Cleaner Than Expected

**ScrollStability.swift** — This is genuinely well-architected. The `ScrollAutoFollowState` value type with hysteresis thresholds (attach at 24px, detach at 72px) is a smart design that prevents scroll jitter. The separation between the state machine and the `ScrollStability` namespace of pure functions is clean. The streaming throttle of 250ms is well-chosen. No changes needed.

**TaggedMarkdownTextView.swift** — Despite its size (~670 lines), the separation between block parsing, inline rendering, and epistemic tag styling is well-layered. The block cache with LRU eviction is reasonable for its use case. The `TagMatch` abstraction that unifies primary and secondary tag regexes is elegant. The only concern is the NSLock-based static cache (covered in Section 4).

**LiquidGreeting.swift** — Tight, purposeful code. The `sharedPrefixLength` optimization for the typewriter effect (only erasing/retyping the differing suffix between phrases) is a nice touch. The `taskKey` pattern for driving `.task(id:)` reactivity is clean. No dead code.

**ChatComposerKeyHandling / ChatComposerInputMetrics** (in `ChatInputBar.swift`) — Well-factored enums with clear single responsibilities. The return-key behavior state machine is correct and handles all modifier combinations properly.

**TypewriterMarkdown.swift** — Small, focused. The `HapticHelper` enum is a good centralization of haptic patterns.

---

## Section 3: Dead Code / Redundancy Candidates

### 3.1 — Dead Function: `ChatPresentationFormatter.heading(forAssistantText:)`

**File:** `ChatView.swift`, line ~49

```swift
nonisolated static func heading(forAssistantText text: String) -> String? {
    return nil
}
```

This function always returns `nil`. It's called in `makeChatTranscriptRows` and its result is stored in every `ChatTranscriptRow.heading`, which is then passed to `MessageBubble` and conditionally rendered. Since it's always nil, the heading rendering path in `MessageBubble` is dead code too:

```swift
if let heading {
    Text(heading)
        .font(AppHeadingRole.h2.font)
        .foregroundStyle(theme.fontAccent)
}
```

This `if let heading` block never executes.

**Recommendation:** Delete the function, remove the `heading` field from `ChatTranscriptRow`, and remove the dead rendering branch in `MessageBubble`. If heading extraction is planned for the future, it can be re-added when implemented.

**Priority: LOW — no harm, but it's noise.**

---

### 3.2 — `LandingShortcutDisplay.label(_:)` is an Identity Function

**File:** `LandingView.swift`, line ~12

```swift
static func label(_ text: String) -> String {
    text
}
```

This function takes a string and returns it unchanged. It's called in `CommandHintLabel` and elsewhere. Presumably this was a localization or formatting hook that was never implemented.

**Recommendation:** Inline-eliminate. Replace `LandingShortcutDisplay.label(spec.label)` with `spec.label`.

**Priority: TRIVIAL.**

---

### 3.3 — `TypewriterASCIIRippleText` May Be Orphaned

**File:** `TypewriterASCIIRippleText.swift`

This component wraps `ASCIIRippleText` with a typewriter reveal animation. It references `ASCIIRippleConfiguration` and several ASCIIRippleText parameters. However, it's not referenced by any of the other 18 uploaded files. If the broader codebase doesn't use it (particularly if the landing page greeting switched to `LiquidGreeting` exclusively), this is dead code.

**Recommendation:** Grep the full codebase for `TypewriterASCIIRippleText`. If unused, delete.

**Priority: LOW — needs codebase-wide grep to confirm.**

---

### 3.4 — `ChatModelChoice` Enum in SessionIntelligenceOverlay is Stale

**File:** `SessionIntelligenceOverlay.swift`, line ~34

```swift
enum ChatModelChoice: String, CaseIterable {
    case local = "Qwen 2B"
    case appleAI = "Apple AI"
```

The display name "Qwen 2B" is hardcoded. The audit pack notes that the model-tier stack is changing to "1B nano / 3B base / 8B pro", which will make this label incorrect. More importantly, this enum duplicates provider-selection logic that likely exists in the inference/model layer.

**Recommendation:** This is in the "deferred model stack" exclusion zone per the audit pack, so flag but don't fix now.

---

### 3.5 — `ProviderBadge` in ChatInputBar May Be Dead

**File:** `ChatInputBar.swift`, line ~725

The `ProviderBadge` struct is defined at the bottom of the file but is never referenced within any of the uploaded files. If `LocalModelToolbarMenu` handles model display, this badge may be orphaned.

**Recommendation:** Grep the full codebase. If unused, delete.

---

## Section 4: Performance / Consistency / Safety Opportunities

### 4.1 — Static Mutable Cache in TaggedMarkdownTextView

**File:** `TaggedMarkdownTextView.swift`, lines ~80-85

```swift
private static let blockCacheLock = NSLock()
private static var blockCache: [String: [MarkdownBlock]] = [:]
private static var blockCacheOrder: [String] = []
```

The cache key is the **entire content string**. For a 10KB assistant response, this means storing the full string as a dictionary key and comparing it on every cache lookup. The `blockCacheOrder` array implements manual LRU eviction.

**Concerns:**
1. String hashing of large messages is O(n) per lookup.
2. The cache is global and shared across all `TaggedMarkdownTextView` instances — streaming messages during typing cause rapid cache churn because each partial text is a different key.
3. The NSLock is fine for correctness but the double-check pattern (unlock, parse, relock, check again) has a theoretical race where two threads parse the same content simultaneously. Not a bug (both will produce the same result), but wasted work.

**Recommendation:** Consider hashing the content string once and using the hash as key, or use an actor-based cache. For streaming messages, consider a "stable prefix" cache strategy instead of keying on the full mutable string.

**Priority: MEDIUM — works correctly, but scales poorly with long conversations.**

---

### 4.2 — NSCursor.unhide() in ChatSidebarView.onHover

**File:** `ChatSidebarView.swift`, line ~76

```swift
.onHover { inside in
    if inside {
        NSCursor.unhide()
        NSCursor.arrow.set()
    }
}
```

The comment says "Force cursor visible — landing page may have hidden it via NSCursor.hide()." This is a workaround for cursor visibility management leaking across view boundaries. Every hover entry on the sidebar forces an unhide + set, which could interfere with custom cursor states set by other views (e.g., the graph view or text editors).

**Recommendation:** The proper fix is to ensure that whatever hides the cursor also restores it on its own boundary exit, rather than having every downstream view defensively unhide. This is a systemic cursor-management issue that should be centralized.

**Priority: LOW — cosmetic, but indicates architectural leak.**

---

### 4.3 — SettingsView Auto-Save Picker Tag Mapping is a Maintenance Trap

**File:** `SettingsView.swift`, VaultDetailView, lines ~921-926 and ~939-958

The picker tags are arbitrary integers that don't correspond to seconds:

```swift
Text("Off").tag(0)
Text("Every 5 seconds").tag(5)    // tag 5 = 5 seconds (coincidental)
Text("Every 15 seconds").tag(1)   // tag 1 = 15 seconds (????)
Text("Every 30 seconds").tag(2)   // tag 2 = 30 seconds
Text("Every 60 seconds").tag(3)   // tag 3 = 60 seconds
Text("Every 5 minutes").tag(4)    // tag 4 = 300 seconds
```

The `autoSaveOption(from:)` and `autoSaveSeconds(from:)` functions maintain this mapping with a switch statement. If anyone adds a new interval, they need to update both functions and pick a non-colliding arbitrary integer.

**Fix:** Use the actual `TimeInterval` value as the picker tag directly:

```swift
Text("Off").tag(TimeInterval(0))
Text("Every 5 seconds").tag(TimeInterval(5))
Text("Every 15 seconds").tag(TimeInterval(15))
// etc.
```

This eliminates both mapping functions entirely.

**Priority: LOW — correct but fragile.**

---

### 4.4 — MiniChatView.swift is 1360 Lines with Mixed Concerns

**File:** `MiniChatView.swift`

This single file contains: `MiniChatView`, `MiniChatThread`, `MiniChatBubble`, `MiniChatAssistantBubbleChrome`, `MiniChatInputBar` (with its own full composer, mention system, action parser, persistence logic, streaming handler), `MiniChatRecentChatsList`, `MiniChatRecentRow`, `QuickActionChip`, and the `executeNoteActions` action parser.

The `MiniChatInputBar` alone is ~500 lines and contains a complete NSViewRepresentable text editor, streaming logic, SwiftData persistence, and bracket-command parsing.

**Recommendation:** After extracting the shared composer-reference logic (Finding 1.1), split this file into at least:
- `MiniChatView.swift` (shell + header)
- `MiniChatThread.swift` (message list + streaming)
- `MiniChatInputBar.swift` (composer + persistence)
- `MiniChatActionParser.swift` (bracket-command parsing, shared with SessionIntelligence)

**Priority: MEDIUM — not urgent but significantly improves navigability.**

---

### 4.5 — NotesMentionDropdown.swift is 1123 Lines

**File:** `NotesMentionDropdown.swift`

Contains `NoteMentionChoice`, `ComposerReferenceHelpers`, `ComposerReferenceChoice`, `ComposerReferencePopoverLayout`, `ComposerReferenceSearchState`, `ComposerReferencePopoverStyle` (enum), and the giant `ComposerReferencePopover` view.

The `ComposerReferenceHelpers` enum is a utility namespace used by all three composers. The `ComposerReferencePopoverLayout` is a pure geometry calculator. The `ComposerReferencePopover` view is ~400 lines of rendering.

**Recommendation:** Split into:
- `ComposerReferenceHelpers.swift` (utility functions)
- `ComposerReferenceSearchState.swift` (the @Observable search coordinator)
- `ComposerReferencePopover.swift` (the view)

**Priority: LOW — organizational, not correctness.**

---

## Section 5: Stale Tests / Stale Docs / False Narratives

This audit is scoped to the 19 uploaded view files and the audit pack document. The audit pack lists tests in Batch 9-11 that exercise some of these views, but since those test files were not uploaded, I cannot verify test/production consistency directly.

However, based on the code I can see, here are contradictions worth verifying:

**5.1** — The audit pack states "TK1 production files were removed from disk and Xcode membership." The uploaded view files contain no TK1 references, which is consistent. However, `TaggedMarkdownTextView` still has a comment referencing "web v2 brainiac's colored badges" — this is stale naming if the product has moved past "brainiac" branding.

**5.2** — The audit pack mentions `EpistemosTests/MiniChatViewAuditTests.swift`. Given the complexity of MiniChatView (1360 lines with embedded action parsing), verify that the audit tests cover the bracket-command parser edge cases (malformed brackets, nested brackets, empty arguments, Unicode in titles).

**5.3** — `SessionIntelligenceOverlay.ChatModelChoice` lists "Qwen 2B" and "Apple AI". If the model stack has already changed, this UI is presenting stale model names to users.

---

## Section 6: Fix-Now vs Defer Matrix

| Finding | Severity | Fix Now? | Estimated Effort | Risk if Deferred |
|---------|----------|----------|-----------------|-----------------|
| 1.1 Triple-duplicated composer reference logic | High | **Yes** | 3-4 hours | Drift between surfaces will cause UX inconsistency |
| 1.2 Dead computation in makeChatTranscriptRows | High | **Yes** | 5 minutes | Wasted CPU on every message |
| 1.3 JSON decoding on every render in WorkspaceRow | Medium-High | **Yes** | 30 minutes | Jank with 10+ workspaces |
| 1.4 Unbounded fetches in SessionIntelligenceOverlay | Medium | **Yes** | 30 minutes | Scales poorly with vault growth |
| 1.5 Two incompatible command systems | Medium | Defer | 2-3 hours | Manageable — they operate in separate surfaces |
| 3.1 Dead heading function + rendering branch | Low | **Yes** | 10 minutes | Noise only |
| 3.2 Identity function LandingShortcutDisplay.label | Trivial | **Yes** | 2 minutes | None |
| 4.1 Static mutable cache key strategy | Medium | Defer | 1-2 hours | Only matters for very long conversations |
| 4.3 Settings auto-save picker tags | Low | **Yes** | 15 minutes | Maintenance confusion |
| 4.4 MiniChatView file splitting | Medium | Defer | 1-2 hours | Navigation difficulty |

---

## Section 7: Exact Recommended Cleanup Sequence

**Phase 1: Quick Wins (30 minutes total)**

1. Delete the dead `let displayContent` computation at the top of the `for` loop in `makeChatTranscriptRows` (ChatView.swift).
2. Delete `ChatPresentationFormatter.heading(forAssistantText:)` and the `heading` field from `ChatTranscriptRow`. Remove the `if let heading` branch in MessageBubble.
3. Inline-eliminate `LandingShortcutDisplay.label(_:)`.
4. Replace the arbitrary picker tags in VaultDetailView with `TimeInterval` values, eliminating `autoSaveOption(from:)` and `autoSaveSeconds(from:)`.
5. Grep codebase for `TypewriterASCIIRippleText` and `ProviderBadge` — delete if unused.

**Phase 2: Performance Fixes (1 hour total)**

6. In `WorkspaceRow`, decode the snapshot once in `.onAppear` / `.task {}` and store as `@State`. Make `snapshotSummary` and drift computation reference the cached decode.
7. In `SessionIntelligenceOverlay`, add `fetchLimit: 1` to `findNoteByTitle`, `findChatByTitle`, and `extractAndFindNote`, or rewrite with SwiftData predicates.

**Phase 3: The Big Extraction (3-4 hours)**

8. Create `ComposerReferenceCoordinator` — an `@Observable` class that encapsulates: mention state, reference search state, popover style, filter text, autofocus flag, and the standard lifecycle methods (openNotePicker, openChatPicker, attachReference, dismiss, updateSearch).
9. Refactor `ChatInputBar` to use `ComposerReferenceCoordinator`.
10. Refactor `MiniChatInputBar` to use `ComposerReferenceCoordinator` with a persistence hook.
11. Refactor `LandingView` to use `ComposerReferenceCoordinator`.
12. Verify all three surfaces behave identically.

**Phase 4: File Organization (deferred, 1-2 hours)**

13. Split `MiniChatView.swift` into 3-4 files.
14. Split `NotesMentionDropdown.swift` into 3 files.
15. Unify bracket-command parsers (SessionIntelligence + MiniChat) into a shared `ActionCommandParser`.

---

*Audit performed against 19 uploaded Swift view files from the Epistemos macOS application. Findings are scoped to the view layer only — engine, graph, sync, and model subsystems were not in scope for this pass.*
