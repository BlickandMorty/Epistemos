# App Intents beyond ten shortcuts on macOS 26

The 10-AppShortcut cap is not your real ceiling — it's only the limit on **`AppShortcutsProvider`**, which controls the curated zero-config voice/Spotlight surface. Every plain `AppIntent` you ship is automatically harvested at install time by `linkd` and appears in the Shortcuts editor, in macOS 26 Spotlight's Actions pane, and (with the right schema) in Apple Intelligence's toolbox. Tahoe also opens four genuinely new surfaces: third-party Control Center widgets on Mac, `SnippetIntent` rich-result UI, `IntentValueQuery` for Visual Intelligence schema routing, and `AppIntentsPackage` distribution from Swift packages and static libs. Below is the full surface map, the macOS 26 deltas, and an ROI-ranked plan for Epistemos.

## The full surface beyond AppShortcutsProvider

| Surface | macOS 26 | Protocol / API | Notes |
|---|---|---|---|
| Shortcuts editor (any registered intent) | ✅ | `AppIntent` (auto-discovered) | Cap = 10 only for `AppShortcutsProvider` |
| Spotlight inline action | ✅ NEW | `IndexedEntity` + `OpenIntent` | Spotlight runs `perform()` from result row |
| `SnippetIntent` (rich result) | ✅ NEW | `SnippetIntent` returns `ShowsSnippetView` | Re-rendered, must be pure |
| Donations / proactive | ✅ | `IntentDonationManager.shared.donate(intent:)` | Replaces `INInteraction` |
| `WidgetConfigurationIntent` | ✅ | + `AppIntentConfiguration` (WidgetKit) | All `@Parameter` must be optional |
| `ControlWidget` + `ControlConfigurationIntent` | ✅ **NEW on Mac** | `AppIntentControlConfiguration` | Tahoe brought 3rd-party Control Center to Mac |
| Apple Intelligence routing | ✅ | `@AppIntent(schema:)` (supersedes `@AssistantIntent`) | New umbrella macro |
| Visual Intelligence schema | partial | `@AppIntent(schema: .visualIntelligence.semanticContentSearch)` + `IntentValueQuery` | Trigger surface still iPhone-only Sep 2025; safe to ship for forward compat |
| `FocusFilterIntent` / `SetFocusFilterIntent` | iOS-primary | reliable on iOS; Mac behavior thin | Skip for v1 |
| `LiveActivityIntent` | ❌ Mac-native | Mac shows iPhone-mirrored ones only | Skip unless iOS companion |
| Services / Finder Quick Actions | bridge only | Wrap `AppIntent` in a Shortcut, drag into Quick Actions sidebar | No native `@QuickAction` |
| Watch complications | n/a here | `WidgetConfigurationIntent` (watchOS) | Only relevant if Watch target ships |

## What's new in macOS 26 vs. macOS 15

**`@AppIntent(schema:)` replaces `@AssistantIntent`.** WWDC25 #275 explicitly: *"the new AppIntent macro … replaces AssistantIntent macro because we've expanded schemas to features outside of the assistant, like visualIntelligence."* No verified `.notes` schema namespace exists for PKM; verified namespaces include `.books`, `.browser`, `.journal`, `.photos`, `.mail`, `.camera`, `.spreadsheets`, `.visualIntelligence`. **Use plain `AppIntent`+`IndexedEntity` for Epistemos's notes/theses model**; bolt on `.visualIntelligence.semanticContentSearch` only.

**`SnippetIntent`** — inline UI in Spotlight/Siri results:

```swift
struct NoteSnippet: SnippetIntent {
    static let title: LocalizedStringResource = "Note Preview"
    @Parameter var note: NoteEntity
    @Dependency var store: NoteStore
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let body = await store.body(for: note.id)
        return .result(view: NotePreviewView(title: note.title, body: body))
    }
}
```
Re-runs on dark-mode/state changes — **must not mutate**. Pair other intents with `ShowsSnippetView & ProvidesDialog`. New `requestChoice(between:dialog:view:)` lets you confirm with rich UI.

**`@ComputedProperty` / `@DeferredProperty`** on `AppEntity`. Prefer `@ComputedProperty` (sync, free) for derived fields; `@DeferredProperty` is async, only invoked when system requests it — perfect for MLX-summary fields.

**`IntentModes`** supersedes `openAppWhenRun`:
```swift
static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]
// inside perform():
if systemContext.currentMode.canContinueInForeground {
    try await continueInForeground(alwaysConfirm: false)
}
```

**`UndoableIntent`** — system supplies the right `undoManager` even when running in an extension; UI undo and intent undo share one stack. Wire `DeleteNoteIntent`, `ArchiveThoughtIntent` to it.

**`TargetContentProvidingIntent` + `.onAppIntentExecution`** — declarative SwiftUI navigation:
```swift
extension OpenNoteIntent: TargetContentProvidingIntent {}
WindowGroup { RootView() }
    .handlesExternalEvents(matching: [OpenNoteIntent.persistentIdentifier])
// inside view:
.onAppIntentExecution(OpenNoteIntent.self) { intent in path.append(intent.note) }
```
Closure runs **just before** foregrounding — replaces the global-Navigator-in-`@Dependency` pattern that fights Swift 6 isolation.

**`AppIntentsPackage`** now works in **Swift packages and static libraries** (previously frameworks/dylibs only). Move Epistemos's intents into a `EpistemosIntents` package.

**`@Property(indexingKey:)` / `@Property(customIndexingKey:)`** — bind an entity property to a Spotlight key so Shortcuts auto-generates Find/Filter actions and so semantic search hits it without writing a predicate.

**`IntentValueQuery<SemanticContentDescriptor, Entity>`** — the bridge for Visual Intelligence's image+label payload.

## Indexing notes/theses for Spotlight semantic search

Don't conform `@Model` directly to `AppEntity` under Swift 6 — class-Sendable conflicts and donation brittleness bite. Use a value-type mirror:

```swift
@Model final class Note { @Attribute(.unique) var id: UUID; var title: String; var body: String
    init(id: UUID = .init(), title: String, body: String) { self.id = id; self.title = title; self.body = body } }

struct NoteEntity: AppEntity, IndexedEntity, Sendable {
    let id: UUID
    @Property(indexingKey: \.displayName)        var title: String
    @Property(indexingKey: \.contentDescription) var snippet: String
    @Property(indexingKey: \.keywords)           var tags: [String]
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Note"
    var displayRepresentation: DisplayRepresentation {
        .init(title: "\(title)", subtitle: "\(snippet)", image: .init(systemName: "note.text"))
    }
    static let defaultQuery = NoteQuery()
    var attributeSet: CSSearchableItemAttributeSet {           // EXTEND, do not replace
        let a = defaultAttributeSet; a.contentType = UTType.text.identifier; return a
    }
}
// Index: try await CSSearchableIndex.default().indexAppEntities(notes.map(NoteEntity.init))
```
For the query, conform to `EntityQuery`, then `EntityStringQuery`, then `EntityPropertyQuery` (in that order of effort) so Shortcuts gets free Find/Filter actions. Inject `ModelContainer` via `AppDependencyManager.shared.add(...)`. **Critical Spotlight gotcha**: never construct a fresh `CSSearchableItemAttributeSet(itemContentType:)` — items vanish from index. Mutate `defaultAttributeSet`.

## Performance, concurrency, codesigning

**Default `perform()` to `nonisolated`** (no annotation). Hop to `@MainActor` only for navigation. Make every entity and parameter `Sendable` (value types + Sendable members). With `supportedModes = [.background, .foreground(.dynamic)]`, capture-style intents stay headless. Use `.foreground(.immediate)` only for "Open X" navigators.

**No special entitlement is required for App Intents.** App Store and Developer ID notarized have parity for App Shortcuts, Shortcuts.app, Spotlight semantic search, Apple Intelligence, snippets, and donations. For sandboxed MAS builds add `com.apple.security.application-groups` to the main app **and** the App Intents extension so they share the SwiftData/GRDB store. Open SQLite/GRDB in WAL mode (multi-process readers). Don't cache row IDs across `perform()` calls.

**App Intents extension target.** Lighter than the main app; cold-starts faster; runs in its own process. Setting `openAppWhenRun = true` on an intent that lives in the extension target crashes — keep open-the-app intents in the main app.

**UniFFI / Rust.** Ship the Rust core as `EpistemosCore.framework` at the app level (`Contents/Frameworks/`); both the main app and `EpistemosAppIntents.appex` link it via `@rpath`. Sign the dylib with **the same Team ID** under hardened runtime — library validation rejects mismatches and `disable-library-validation` is banned on MAS. Avoid eager Rust init in module load; do `dlopen`-time work lazily inside `perform()` to keep extension cold-start under ~300 ms. Treat the legacy SiriKit ~10 s budget as the practical ceiling for any single intent — Apple has not republished a number for App Intents.

**Quotas.** 10 App Shortcuts / app, 1,000 trigger phrases total, every phrase must contain `\(.applicationName)`. No documented cap on `AppEntity` count, indexed item count, or donation rate (system de-dupes). The macOS 26 compile-time metadata extractor means **Spotlight can index many AppEntities without the app launching** (forum 768274) — large knowledge graphs are tractable.

## Top 5 recommended additions

1. **Spotlight semantic indexing of `NoteEntity` / `ThoughtEntity` / `ThesisEntity` via `IndexedEntity` + `@Property(indexingKey:)`.** Effort **M** (4–8 h). Win: every note becomes a first-class Spotlight result with snippet UI and an Open action — no AppShortcut budget consumed. Highest ROI by far; also auto-generates Shortcuts Find/Filter actions for free.

2. **`SnippetIntent` (`NoteSnippet`, `ThesisSnippet`) + `requestChoice` on destructive intents.** Effort **S** (2–4 h). Win: rich preview cards in Spotlight/Siri without launching the app, and "Archive or Delete?" confirmations with a thumbnail.

3. **`ControlWidget` + `ControlConfigurationIntent` for `QuickCapture` and `OpenRawThoughtSandbox`.** Effort **S** (2–3 h). Win: Tahoe Control Center buttons + menu-bar Control Center pull-down trigger capture in <100 ms — the only new system-wide hardware-key-free surface added in macOS 26.

4. **Migrate intents to `supportedModes = [.background, .foreground(.dynamic)]` + adopt `TargetContentProvidingIntent` / `.onAppIntentExecution` for navigation.** Effort **M** (6–10 h, includes refactoring the global Navigator). Win: cold-start drops dramatically for `CaptureBrainDump`, `AttachThoughtToContext`, `RecallActiveThesis`; Swift 6 isolation warnings go away; navigation becomes declarative.

5. **`@AppIntent(schema: .visualIntelligence.semanticContentSearch)` + `IntentValueQuery<SemanticContentDescriptor, NoteEntity>` and `UndoableIntent` on every destructive op.** Effort **S** (3–4 h combined). Win: zero-cost forward compatibility — your notes appear in Visual Intelligence search the moment Apple ships it on Mac (rumored in 26.x); meanwhile every delete/archive becomes Cmd-Z-able from the system undo stack even when invoked from Spotlight or an extension.