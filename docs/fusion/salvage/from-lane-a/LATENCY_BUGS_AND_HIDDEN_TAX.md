# Latency Bugs and Hidden Tax

## Top Issues

### 1. Double-Debounced Reactive Query Updates

Files:
- `Epistemos/Graph/GraphStore.swift`
- `Epistemos/Engine/ReactiveQuery.swift`

Problem:
- `GraphStore.notifyChange()` used to wait 50ms before posting
- `ReactiveQuery` then used to wait another 100ms before re-running the plan

Impact:
- query/search UI used to sit stale for about 150ms after a graph mutation
- this was directly user-visible

Status:
- fixed in this pass
- the live path now posts immediately from `GraphStore` and uses a single `35ms` debounce in `ReactiveQuery`

### 2. Broad Notification Invalidation Instead of Dependency Keys

Files:
- `Epistemos/Engine/ReactiveQuery.swift`
- `Epistemos/Engine/QueryEngine.swift`

Problem:
- all reactive queries re-evaluate on `graphStoreDidChange` or `searchIndexDidUpdate`
- invalidation is not scoped to the query plan

Impact:
- irrelevant mutations still cause work
- scales poorly as query count grows

### 3. BTK Payloads Rehydrate Too Aggressively in Swift

Files:
- `Epistemos/Graph/GraphEngine.swift`

Problem:
- raw byte transport is efficient
- but every payload becomes `[BTKSubscriptionRow]`, with every string eagerly decoded

Impact:
- bridge is “zero-copy” only at the buffer boundary
- user-visible state still pays per-row/per-string allocation tax

### 4. Repeated Note Body Loads

Files:
- `Epistemos/Models/SDPage.swift`
- `Epistemos/Views/Notes/ProseEditorView.swift`
- `Epistemos/Graph/GraphBuilder.swift`
- `Epistemos/Graph/GraphState.swift`
- `Epistemos/Sync/VaultIndexActor.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Views/MiniChat/MiniChatView.swift`
- `Epistemos/Views/Notes/NoteBacklinksPanel.swift`
- `Epistemos/State/DailyBriefState.swift`

Problem:
- many surfaces call `page.loadBody()` directly
- each call builds a fresh `String`

Impact:
- repeated disk/String churn
- body-heavy surfaces become slower than they need to be

### 5. Structural Graph Rebuild Scans Full Page Bodies

Files:
- `Epistemos/Graph/GraphBuilder.swift`

Problem:
- structural rebuild scans every page body for block references

Impact:
- okay as a cold-path rebuild
- too expensive to treat as a frequent update mechanism

### 6. Main-Actor Query Runtime

Files:
- `Epistemos/Engine/QueryRuntime.swift`
- `Epistemos/Engine/QueryEngine.swift`

Problem:
- the query runtime is `@MainActor`
- it performs filtering, sorting, and some full scans on the main actor

Impact:
- query cost competes directly with UI work

### 7. Search Index Notification Storm Potential

Files:
- `Epistemos/Sync/SearchIndexService.swift`

Problem:
- every `upsert`, `delete`, `upsertBlock`, `deleteBlock` posts `searchIndexDidUpdate`

Impact:
- `ReactiveQuery` coalesces reevaluation, but NotificationCenter still sees all posts

### 8. JSON/Data Tax in SwiftData Models

Files:
- `Epistemos/Models/SDMessage.swift`
- `Epistemos/Models/SDPage.swift`
- `Epistemos/Models/SDNoteInsight.swift`
- `Epistemos/Models/SDGraphNode.swift`

Problem:
- arrays and metadata are stored as JSON blobs and decoded eagerly in some flows

Impact:
- acceptable for cold persistence in some cases
- too expensive when reused in visible list/chat surfaces

### 9. Unused BTK Polling State

Files:
- `Epistemos/Graph/GraphEngine.swift`

Problem:
- `BTKSubscriptionState.startPolling(interval: .milliseconds(150))` exists but is not wired anywhere

Impact:
- dead scaffolding adds confusion to the live architecture story

### 10. Task-Sleep Layering Across UI

Files:
- `Epistemos/Views/Landing/CommandPaletteOverlay.swift`
- `Epistemos/Views/Landing/LandingView.swift`
- `Epistemos/Views/Chat/NotesMentionDropdown.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`

Problem:
- many surfaces rely on `Task.sleep` for UI timing and debounce

Impact:
- hidden responsiveness tax
- easy to stack accidental delays

## Hidden Serialization / Copy Tax

### FFI-Adjacent

- `GraphEngine.decodeBTKPayload()` converts borrowed slices into owned Swift strings
- `QueryRuntime.pageIdsToQueryResult()` receives newline-delimited C string results and splits them into Swift arrays
- `BlockEditTranslator.initIfNeeded()` duplicates block content through `strdup`

### Non-FFI

- `SDMessage` attachment/context arrays are JSON-encoded blobs
- `SDNoteInsight` stores multiple JSON strings and decodes on access
- several note tools build large prompt/context strings with repeated `loadBody()` calls

## Full-Rebuild / Whole-View Risks

- `ReactiveQuery` reruns whole plans on any graph or search notification
- structural graph refresh falls back to full rebuilds when incremental shape checks fail
- many note-derived AI and organization tools build whole-note strings instead of using projections/snippets

## What Is Not Actually the Problem

- GRDB/FTS5 itself is not the main latency villain; it is the correct simpler search backend for text search
- tiny graph control FFI calls are not where the app is losing time
- the staged `knowledge-core` transport is not the current production bottleneck because the live UI barely uses it
