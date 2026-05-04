# Epistemos App Intents research for macOS 26

For a native PKM app, the move is **not more App Shortcuts**. It is **a dense App Intents substrate**: indexed entities for Spotlight, discoverable non-shortcut intents for Shortcuts, targeted Siri/Apple Intelligence schemas, WidgetKit controls, view-controlled navigation, and an App Intents extension so work can happen without foregrounding the app. citeturn31search6turn11search3turn14search3turn19search2

## Full surface area beyond App Shortcuts

App Shortcuts are only the preconfigured, no-setup layer; your ordinary discoverable `AppIntent`s still appear in the Shortcuts editor, and Apple’s docs explicitly say people can build custom shortcuts from the intents your app exposes. The 10-shortcut cap applies to **App Shortcuts**, not to the general intent catalog in Shortcuts. citeturn11search3turn3search2turn11search0

Use these surfaces:

- **Spotlight content**: `struct NoteEntity: IndexedEntity { ... }` plus `struct OpenNoteIntent: OpenIntent { @Parameter var target: NoteEntity }`. Spotlight indexes `DisplayRepresentation` by default and can index explicit properties via `@Property(indexingKey:)` / `@ComputedProperty(indexingKey:)`. citeturn31search0turn0search5turn31search5
- **Shortcuts editor**: any discoverable `AppIntent` or `SnippetIntent`; App Shortcuts are optional sugar. `static var isDiscoverable = true`. citeturn11search0turn11search3turn7search0
- **Siri suggestions / proactive**: donate high-value intents after direct in-app use with `try await intent.donate()`. Use `PredictableIntent` / relevant intents if you need stronger proactive hinting. citeturn4search1turn4search2
- **Focus filters**: the real protocol is `SetFocusFilterIntent`, not `FocusFilterIntent`. citeturn18search0turn18search1
- **Widgets / watch complications**: `AppIntentConfiguration` + `WidgetConfigurationIntent`; on watch complications, preconfigure with `AppIntentRecommendation`. citeturn22search8turn2search6turn2search3
- **Live Activities**: `struct StartFocusSession: LiveActivityIntent { ... }`; Activities surface on iPhone/iPad and also on a paired Mac in the menu bar. citeturn17search5turn17search4turn17search0
- **macOS Control Center / menu-bar quick actions**: this is the **Controls** surface in WidgetKit, using `StaticControlConfiguration` or `AppIntentControlConfiguration`; on Mac, controls can appear in Control Center **or as menu bar items**. citeturn16search1turn29search0turn16search2
- **Visual Intelligence**: `struct NoteVisualQuery: IntentValueQuery { func values(for input: SemanticContentDescriptor) async throws -> [...] }`, plus an `OpenIntent` for taps. Apple documents this for camera/screenshot flows. citeturn1search1turn30search6turn20search2
- **Apple Intelligence / Siri schemas**: public macros are `@AppIntent(schema:)`, `@AppEntity(schema:)`, and `@AppEnum(schema:)`. Apple explicitly says **don’t adopt `AssistantIntent` directly**. I found no public `@AssistantIntent` or `@AssistantSchema` macro in the current docs. citeturn8search8turn9search0turn7search1turn24search6

## Entity plumbing for Spotlight and intelligence

Apple’s guidance allows direct `AppEntity` conformance, but also says it is often a good idea to create **shadow entity types** rather than making your app model itself the intent object. For SwiftData, that means: keep `@Model Note`, then bridge it to `NoteEntity` with a stable ID, `DisplayRepresentation`, and queries. citeturn8search0turn21search2

```swift
@Model final class Note { var id: UUID; var title: String; var body: String }

struct NoteEntity: IndexedEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note")
    static var defaultQuery = NoteQuery()

    let id: UUID
    @Property(title: "Title", indexingKey: \.title) var title: String
    @ComputedProperty(indexingKey: \.textContent) var body: String { source.body }

    var displayRepresentation: DisplayRepresentation {
        .init(title: "\(title)", subtitle: "\(body.prefix(80))")
    }
}
```

For “open by name”, implement `EntityStringQuery.entities(matching:)`. For filterable fields in Shortcuts, add `EntityPropertyQuery` and declare `QueryProperties` for tags, created date, thesis, project, and pinned/favorite state. For Spotlight, donate with `CSSearchableIndex.default().indexAppEntities(...)`, or associate existing `CSSearchableItem`s if you already have Core Spotlight plumbing. citeturn12search0turn12search1turn12search2turn31search0

## Speed patterns that actually matter

`openAppWhenRun = false` is now legacy phrasing. In the macOS 26 SDK surface, Apple deprecates it in favor of `supportedModes`; the exact replacement for “no UI, background only” is `.background`. For “start background, foreground only if needed”, use `[.background, .foreground(.dynamic)]` or `.foreground(.deferred)` depending on whether you need runtime escalation vs guaranteed later foregrounding. citeturn6search0turn22search2

Also use an **App Intents extension**. Apple documents it as the registration point that lets the system discover and perform intents **without launching your app**. That is the closest thing to “super native” latency on Mac. Donate repeated actions after direct use to improve proactive surfacing, and use assistant schemas when your action matches a system-understood domain like search, journaling, whiteboard, reader, files, or word processor. citeturn14search3turn25search11turn4search1turn23search0turn24search6turn27search7

## New macOS 26 era API that matters

I could not directly inspect the local `/Applications/.../AppIntents.framework` swiftinterface from this environment, so this inventory is based on Apple’s published Xcode 26 / macOS 26 docs and WWDC25 material. The highest-confidence additions or newly emphasized APIs are: `SnippetIntent`; `IndexedEntity` Spotlight indexing via `@Property(indexingKey:)` and `@ComputedProperty(indexingKey:)`; `IntentValueQuery` for Visual Intelligence; onscreen-content handoff with `NSUserActivity.appEntityIdentifier` and `Transferable`; `supportedModes` / `IntentModes`; `TargetContentProvidingIntent` + SwiftUI `onAppIntentExecution`; and `DeferredProperty`. citeturn19search2turn7search0turn31search0turn1search1turn9search0turn6search0turn20search2turn22search5turn21search0

Based on your inventory, Epistemos is **clearly not yet using**: indexed entities for Spotlight, Focus filters, controls, widget configuration intents, Visual Intelligence, assistant-schema macros, `TargetContentProvidingIntent`, `SnippetIntent`, and likely an App Intents extension. Live Activities and watch complications remain unclear from your description. citeturn31search6turn19search2turn14search3

## Epistemos recommendations

**Spotlight-first note and thesis entities** — **Yes**. Effort **M**. Biggest win: open-by-name, semantic findability, native Mac search feel.  
Code shape: `NoteEntity: IndexedEntity`, `ThesisEntity: IndexedEntity`, `OpenNoteIntent: OpenIntent`. citeturn31search0turn31search5

**Schema-backed system search** — **Yes**. Effort **S**. Your existing `SystemSearch` should adopt `ShowInAppSearchResultsIntent` and likely `@AppIntent(schema: .system.search)`. citeturn23search0turn27search5

```swift
@AppIntent(schema: .system.search)
struct SystemSearchIntent: ShowInAppSearchResultsIntent {
    static var searchScopes: [StringSearchScope] = [.general]
    @Parameter var criteria: StringSearchCriteria
    static var supportedModes: IntentModes = .foreground(.deferred)
    func perform() async throws -> some IntentResult { .result() }
}
```

**View-controlled open intents** — **Yes**. Effort **S**. Removes navigation logic from `perform()`, which is cleaner and less race-prone on macOS multiwindow apps. citeturn20search2turn20search0turn22search1

```swift
struct OpenNoteIntent: OpenIntent { @Parameter var target: NoteEntity }
extension OpenNoteIntent: TargetContentProvidingIntent {}

NavigationStack { ... }
.onAppIntentExecution(OpenNoteIntent.self) { intent in
    router.openNote(id: intent.target.id)
}
```

**Control Center / menu-bar quick capture** — **Yes**. Effort **M**. Excellent for “brain dump now” and “start focus session”. citeturn16search1turn29search0

```swift
struct CaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "capture") {
            ControlWidgetButton(action: QuickCaptureIntent()) {
                Label("Capture", systemImage: "bolt.text.clipboard")
            }
        }
    }
}
```

**Interactive snippets** for recall/summarize/delegate — **Yes**. Effort **M**. Best new UX surface in the 26 cycle. Keep these result-focused and side-effect-free. citeturn7search0turn7search3turn19search2

```swift
struct RecallSnippetIntent: SnippetIntent {
    @Parameter var thesis: ThesisEntity
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: RecallCard(thesis: thesis))
    }
}
```

## Gotchas and reality checks

App Intents extensions are separate bundles and separate processes. If you want shared SwiftData/cache/state, use **App Groups**. On macOS, `group.` App Group identifiers must be present in the provisioning profile; Apple’s docs call out entitlement validation issues here. citeturn15search0turn15search1turn15search5

Permission prompts are **not per intent**. They’re driven by protected capabilities; App Intents exposes `AppIntentError.PermissionRequired.*` for things like contacts, location, photos, local network, and Siri. citeturn28search2turn28search7

The only explicit quota I found is the **10 App Shortcut** cap. I did **not** find an Apple-documented equivalent cap for general discoverable intents or indexed entities. Also, if UI is involved, remember Apple’s sample notes that `perform()` may run off the main actor, and `supportedModes`/view-controlled navigation are safer than mixing app launch and async UI mutation in `perform()`. citeturn3search2turn31search1turn6search0

## Top recommended additions ranked by ROI

1. **Indexed `NoteEntity` + `ThesisEntity` + `OpenIntent`**  
2. **Convert `SystemSearch` to `ShowInAppSearchResultsIntent` with `.system.search` schema**  
3. **Add an App Intents extension + `.background` / `.foreground(.deferred)` modes**  
4. **Add a Mac control for `QuickCapture` in Control Center / menu bar**  
5. **Add `SnippetIntent` results for `RecallActiveThesis`, `SummarizeNote`, and `DelegateToAgent`**

**TL;DR:** The highest-ROI path is: **Spotlight entities, schema-backed search, App Intents extension, Mac controls, and snippets**. That stack makes Epistemos feel fast because the system can find, route, and execute your core actions before the user ever fully “opens the app.”