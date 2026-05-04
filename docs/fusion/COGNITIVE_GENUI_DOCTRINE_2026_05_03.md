# Epistemos Schema-First GenUI Doctrine — One Pipeline, Many Views — 2026-05-03

> **Substrate-foundational doctrine.** Every command, tool, agent
> response, mutation, and external system event in Epistemos has a
> *typed shape*. The renderer must be derivable from that shape, not
> hand-coded per call site. **No more per-command UI code.** This
> document is canon for the schema-first GenUI dispatcher and lives
> as the fourth sub-track of T0 Substrate Unification (alongside
> Cognitive Kernel, Cognitive DAG, and XPC Mastery).
>
> **Status as of 2026-05-03:** doctrine written; partial implementation
> via `ChatArtifactKind` + `Artifact` + `ArtifactBlockView` (chat-side
> only); full schema-first dispatcher NOT yet shipped. This doc exists
> so the work doesn't fall through the cracks again.

---

## 0. The thesis (and why this got missed)

Three previous sessions (Four-Model Advice Council 2026-04-22 onward)
agreed: every Hermes command, every tool result, every agent
side-effect, every mutation should produce a *typed payload* that the
view layer renders by schema lookup, not by switching on a tag.

The reason the work got lost: it's an *abstraction* improvement, not a
visible feature. Every time hackathon pressure hit, per-command renderers
got written by hand instead of going through the schema dispatcher,
because the dispatcher didn't exist yet, and writing it felt like a
prerequisite rather than a deliverable. **This doctrine ends that
cycle** — it's a deliverable, with phases, with a deliberate cost
ceiling, and a place in the Track Register so it can't be silently
deferred again.

---

## 1. The pipeline (target end state)

```
                    Producer (any side)
       ┌───────────────────────────────────────────┐
       │   Hermes command parser                   │
       │   Tool registry result                    │
       │   Agent loop emission                     │
       │   MutationEnvelope                        │
       │   Cloud provider response                 │
       │   System notification                     │
       └────────────────┬──────────────────────────┘
                        │ produces
                        ▼
              ┌─────────────────────┐
              │   GenUIPayload      │  typed sum (10–20 schema variants)
              │   { schema, body,   │  e.g. .keyValueTable, .table, .markdown,
              │     metadata }      │       .codeBlock, .fileEdit, .json,
              └────────────────────┬┘       .commandReceipt, .actionPanel,
                                   │        .errorReport, .chartSpec, ...
                                   ▼
              ┌──────────────────────┐
              │  GenUIDispatcher     │  static registry: schema → ViewType
              │  - register(schema,  │
              │      ViewType.self)  │  one register per schema
              │  - render(payload)   │  returns AnyView at call site
              └────────────────┬─────┘
                               │ renders
                               ▼
              ┌──────────────────────┐
              │  Concrete renderer   │  e.g. ArtifactBlockView for json/yaml
              │  views (canonical    │       ConfigPanelView for keyValueTable
              │  per schema)         │       ResultTableView for table
              └──────────────────────┘
```

**The pipeline IS the schema-first GenUI dispatcher.** Producers stop
caring how to render; the dispatcher routes by schema; renderers stop
caring where data came from.

---

## 2. The current partial implementation (what's already there)

`ChatArtifactKind` + `Artifact` + `ArtifactBlockView` already implement
this pipeline for **cloud model response content blocks** specifically:

| Layer                    | File                                                | What it does |
|---|---|---|
| Schema discriminator     | `Epistemos/Models/Artifact.swift` `ChatArtifactKind`| 7 kinds: json, yaml, csv, codeBlock, table, markdown, fileEdit |
| Typed payload            | `Epistemos/Models/Artifact.swift` `Artifact`        | id, kind, title, language, content, schemaName |
| Producer                 | `Epistemos/Engine/ArtifactExtractor.swift`           | parses cloud responses → emits Artifact instances |
| Renderer                 | `Epistemos/Views/Chat/ArtifactBlockView.swift`       | switches on `.kind`, renders correct view (json tree, code block, table, etc.) with collapse + copy + save-to-file via UTType |

**This is the seed.** The full schema-first GenUI dispatcher generalizes
this pattern to *every* producer (not just cloud responses) and *every*
renderer (not just chat blocks).

---

## 3. The gap (what's missing as of 2026-05-03)

| Gap                                              | Impact today                                                                      |
|---|---|
| No `GenUIDispatcher` static registry              | Each new producer must wire its own renderer (= per-command UI code)              |
| Schema set is chat-block-specific                 | `Artifact` only covers content blocks; can't represent `/status` panels, command receipts, action prompts, error reports |
| Producers outside cloud-response path don't emit  | Hermes parsers, tool registry, agent_core, MutationEnvelope all hand-roll their UX|
| No discoverable "render this schema" call site    | View code at every call site has its own switch statement                          |
| No serialization schema for cross-runtime payloads| Rust agent_core can't emit a GenUI payload that Swift renders; schema lives Swift-side only |

---

## 4. The plan (six phases, scoped + bounded)

This is Phases G.1 through G.6, fitting as the **fourth sub-track of T0
Substrate Unification** alongside Cognitive Kernel (Phases 1-7),
Cognitive DAG (Phase 8), and XPC Mastery (Phases X.1-X.5).

### Phase G.1 — Generalize the schema (week 1)

Promote `Artifact` from "chat content block" to the universal payload.
Rename to `GenUIPayload` or keep `Artifact` and grow its `kind` enum.

```swift
// Epistemos/Models/GenUIPayload.swift (new) or extend Artifact

nonisolated enum GenUISchema: String, Codable, Sendable, CaseIterable {
    // existing chat-block variants stay
    case json, yaml, csv, codeBlock, table, markdown, fileEdit

    // new variants for the broader pipeline
    case keyValueTable     // /status, /config show — column1=key, column2=value
    case commandReceipt    // /calc =, /clear, simple terse echoes
    case actionPanel       // a row of buttons with optional payloads
    case errorReport       // structured error: title, detail, hint, recoveryOptions
    case progressIndicator // streaming inference, long-running task
    case capabilityList    // /help, /model list — token + tier + description
    case searchResultSet   // /search — title + snippet + score + entityRef
    case provenanceTrace   // AgentEvent chain, replay summary
}

nonisolated struct GenUIPayload: Identifiable, Codable, Sendable {
    let id: String
    let schema: GenUISchema
    let title: String
    let body: GenUIBody    // typed envelope; serializes to JSON
    let metadata: [String: String]
    let createdAt: Date
}

indirect nonisolated enum GenUIBody: Codable, Sendable {
    case raw(String)                                          // for json/yaml/markdown/codeBlock
    case keyValues([(String, String)])                        // for keyValueTable
    case rows(headers: [String], cells: [[String]])           // for table, capabilityList, searchResultSet
    case actions([GenUIAction])                               // for actionPanel
    case error(title: String, detail: String, hint: String?, options: [GenUIAction])
    case progress(label: String, total: Double, value: Double)
    case provenanceChain([GenUIPayload])                      // recursive
}

nonisolated struct GenUIAction: Codable, Sendable, Identifiable {
    let id: String
    let label: String
    let kind: ActionKind
    let payload: String?                                      // serialized command or args
    enum ActionKind: String, Codable, Sendable {
        case rerun, copy, save, open, dismiss, custom
    }
}
```

### Phase G.2 — Build the dispatcher (week 1-2)

```swift
// Epistemos/Engine/GenUIDispatcher.swift

@MainActor
final class GenUIDispatcher {
    static let shared = GenUIDispatcher()

    private var registry: [GenUISchema: any GenUIRendererType.Type] = [:]

    func register<R: GenUIRendererType>(_ schema: GenUISchema, _ renderer: R.Type) {
        registry[schema] = renderer
    }

    @ViewBuilder
    func render(_ payload: GenUIPayload) -> some View {
        if let rendererType = registry[payload.schema] {
            AnyView(rendererType.makeView(payload: payload))
        } else {
            FallbackGenUIView(payload: payload)  // raw JSON dump + copy button
        }
    }
}

protocol GenUIRendererType {
    associatedtype RenderView: View
    static func makeView(payload: GenUIPayload) -> RenderView
}
```

App bootstrap registers the canonical renderers at launch:

```swift
// AppBootstrap
GenUIDispatcher.shared.register(.json, JSONRenderer.self)
GenUIDispatcher.shared.register(.keyValueTable, KeyValueTableRenderer.self)
GenUIDispatcher.shared.register(.commandReceipt, CommandReceiptRenderer.self)
GenUIDispatcher.shared.register(.searchResultSet, SearchResultSetRenderer.self)
// ... 15 more
```

### Phase G.3 — Migrate existing producers (week 2-3)

Every existing per-command renderer in
`HermesExpertModeRunner.renderXxxInline` becomes a single line:

```swift
// before:
state.append(.init(kind: .systemResponse, text: "── status ──"))
state.append(.init(kind: .info, text: "model       \(model)"))
// ... 6 more lines

// after:
state.append(.payload(GenUIPayload(
    schema: .keyValueTable,
    title: "status",
    body: .keyValues([
        ("model", model),
        ("mode", opMode),
        ("panel", panel),
        // ...
    ])
)))
```

The view automatically picks up the dispatcher and renders via
`KeyValueTableRenderer` — collapse, copy, save-to-file, all free.

Migrate in this order (lowest risk first):
1. `/status` → `keyValueTable`
2. `/config show` → `keyValueTable`
3. `/calc` → `commandReceipt`
4. `/help` → `capabilityList`
5. `/model list` → `capabilityList`
6. `/search` → `searchResultSet`
7. `/tokens`, `/cost` → `keyValueTable`
8. Errors anywhere → `errorReport`

### Phase G.4 — Cross-runtime payload serialization (week 3-4)

Add a Rust-side mirror of `GenUIPayload` in `agent_core::genui::payload`
so the Rust kernel can emit GenUI payloads that Swift renders directly.
This unifies the Hermes-in-Rust runtime (kernel doctrine Phase 2) with
the GenUI dispatcher: a Rust-side tool returns a `GenUIPayload`, the
Swift side renders it without any per-tool view code.

```rust
// agent_core/src/genui/payload.rs
#[derive(Serialize, Deserialize, Clone)]
pub struct GenUIPayload {
    pub id: String,
    pub schema: GenUISchema,
    pub title: String,
    pub body: GenUIBody,
    pub metadata: HashMap<String, String>,
    pub created_at: i64,
}
```

UniFFI bridges the type. Swift consumes the same struct.

### Phase G.5 — DAG integration (Phase 8 follow-up)

When the Cognitive DAG (Phase 8) ships, every `GenUIPayload` becomes a
typed node in the DAG. Renderers query the DAG by schema; users replay
sessions by replaying GenUI payload chains. This closes the loop:
*the renderer derives from the schema; the schema is in the DAG; the
DAG is the substrate*.

### Phase G.6 — Doctrine + linter (week 4-5)

A Rust crate `epistemos-genui-doctrine-lint` rejects PRs that:
- Add a per-command renderer instead of registering with the dispatcher
- Hand-write a switch on `GenUISchema` outside the dispatcher itself
- Emit unstructured `Text(...)` rows for results that should be typed

Compile-time enforcement of the doctrine.

---

## 5. The cost ceiling (so it doesn't expand into a swamp)

| Phase | Effort estimate | Hard ceiling |
|---|---|---|
| G.1 schema generalization | 1-2 days | 3 days |
| G.2 dispatcher | 1-2 days | 3 days |
| G.3 producer migration   | 3-5 days | 7 days |
| G.4 Rust-side payload    | 2-3 days | 5 days |
| G.5 DAG integration      | 1-2 days | 3 days (after Phase 8) |
| G.6 doctrine linter      | 1-2 days | 3 days |
| **Total**                | **9-16 days** | **24 days hard cap** |

**If a phase exceeds its ceiling, stop and revisit the doctrine.** No
silently expanding scope.

---

## 6. The deferral discipline (this is where it got lost before)

Every PR that adds a per-command renderer must include either:

1. **A GenUIDispatcher migration alongside it** (preferred), OR
2. **A `// GENUI-DEFER:` comment + a row appended to
   `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md`** explaining why
   the schema route was deferred and when it'll be reverted

No third option. No "I'll get to it later" without the trail.

The hackathon Hermes Expert Mode work (slices 1-8 committed
2026-05-03) added per-command renderers under explicit `// GENUI-DEFER:
hackathon-2026-05-03 — schema-first GenUI dispatcher not yet shipped` —
when the dispatcher lands (G.2), every renderer migrates per the
priority order in G.3.

---

## 7. The single sentence

> **Every command, tool, mutation, and event in Epistemos produces a
> typed `GenUIPayload`; the `GenUIDispatcher` routes payload schemas to
> registered renderers; renderers know nothing about producers and
> producers know nothing about renderers.**

Six words a developer can say: *typed payload, schema, dispatcher,
renderer*.

---

## 8. Cross-references

```
docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md     ← this doc (canon)
docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md    (Phases 1-7 — kernel)
docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md       (Phase 8 — DAG)
docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md         (Phases X.1-X.5 — XPC)
docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md     (T0 sub-track 4)
docs/fusion/EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md
docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md                (Four-Model Advice Council
                                                        consensus on schema-first
                                                        GenUI — original mention)
Epistemos/Models/Artifact.swift                        (current partial implementation)
Epistemos/Views/Chat/ArtifactBlockView.swift           (current partial renderer)
CLAUDE.md                                              (NON-NEGOTIABLE constraints)
```

## 9. The deferral list (current)

Things known to use per-call-site UI code instead of GenUIDispatcher.
Update on every commit that adds another. Clear when migration ships.

| Surface                                          | Files / call sites                                            | Migration phase |
|---|---|---|
| Hermes Expert Mode renderers                     | `Epistemos/Views/Landing/Hermes/HermesExpertModeRunner.swift` (slices 1-8 / 2026-05-03) | G.3 priority 1 |
| Daily Brief render path                          | `Epistemos/Views/Landing/LandingView.swift` `dailyBriefContent` | G.3 priority 4 |
| Welcome Back render path                         | `Epistemos/Views/Landing/LandingView.swift` `welcomeBackContent` | G.3 priority 4 |
| Approval modal payload                           | `Epistemos/Views/Approval/ApprovalModalView.swift`             | G.3 priority 2 |
| Provenance Console (when shipped)                | not yet built — must use GenUIDispatcher from day 1            | G.3 day-1 |
| All Phase X.1-X.5 XPC service responses          | not yet built — emit GenUIPayload via UniFFI bridge            | G.4 day-1 |

Whenever a new producer joins this list and ships before G.3, add it
here. Whenever a producer migrates, remove it from the list. The
list-being-empty IS the doctrine being met.
