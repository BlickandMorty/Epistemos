# SS-PERF2 — Remaining non-invasive performance wins (2026-06-20)

Owner (verbatim): *"truly get as much deep research as you can — deep optimizations, performance upgrades… but don't
damage anything."* Code-grounded. The app already has MATURE perf hygiene (verified excluded below); these are the
remaining additive, test-backable wins — mostly per-call allocator/serialization waste + a few render-path formatter
allocations. NON-INVASIVE; behind patterns the codebase already uses; never touch vault/graph or dual-brain files.

## Already optimized — DO NOT re-report
No `DispatchQueue.main.sync` anywhere; substrate-health rows fully on `SubstrateHealthClock` (0 self-timers, SS-SH);
`ChatView` transcript = `LazyVStack` + stable `.id` + cached `transcriptRows` + nonisolated row builder; MLX path =
container reuse + KV-cache persist/inject + idle-unload + memory caps + SSM session reuse; Rust event ring = zero-copy
batched FFI, no JSON; SwiftData `@Query` all filtered/`fetchLimit`-bounded; `NotesSidebar` reads nonisolated static +
shared decoder; 2026-04 perf wave (WKWebView process-pool, tantivy heap cuts, lazy bootstrap, memory-pressure FFI).

## Prioritized remaining wins (all NON-INVASIVE, test-backable)
| # | win | file:line | what | impact | risk |
|---|---|---|---|---|---|
| 1 | **Compact tool-schema JSON in the LLM prompt** | `App/ChatCoordinator.swift:3499` (`encodedToolDefinitionsJSON`, called per-turn :2710/:2786) | uses `.prettyPrinted` for the tool-defs JSON EMBEDDED IN THE PROMPT → whitespace = extra INPUT TOKENS every tool turn (slower prefill + higher cost). Drop `.prettyPrinted`, keep `.sortedKeys`; snapshot-test parsed JSON identical. | **Med-High** (per-turn, scales w/ tool count) | Low |
| 2 | Shared `JSONDecoder` on `SDMessage` accessors | `Models/SDMessage.swift:82,93,104,115,126,137,148,177` | fresh `JSONDecoder()` per `decodedDualMessage/Attachments/ContentBlocks/…`, called per-message in chat-list preview (`ChatTypes.swift:589,640`). Hoist to `static let` (pattern already used `RustShadowFFIClient.swift:255`). | Med | Low |
| 3 | Memoize `RawThoughtsSection.groupedByDate` + hoist formatter | `Views/RawThoughts/RawThoughtsSection.swift:128-130` | allocates a `DateFormatter()` + re-buckets all runs EVERY render; sibling `RawThoughtRow:157` already uses `static let`. Make formatter static; cache grouping on `scopedRuns` identity. | Med (render-path while panel open during runs) | Low |
| 4 | Shared `JSONEncoder` on `SDMessage` setters | `Models/SDMessage.swift:162,186,…` | fresh encoder per `setContentBlocks/setArtifacts/updateAnalysis`. `static let`. | Low-Med | Low |
| 5 | Hoist `ISO8601DateFormatter` in MessageBubble export | `Views/Chat/MessageBubble.swift:762` | inline alloc per export-filename. `static let`. | Low | Low |
| 6 | `MessageBubble` Equatable (row payload only) | `Views/Chat/MessageBubble.swift:130` | not Equatable → every transcript change re-evals unchanged bubbles' body (siblings already `.equatable()`). | Med (long transcripts, streaming) | **HIGHER** — body reads many env/theme/state; wrong `==` drops updates. Gate on a tight payload Equatable + streaming/theme UI test. Schedule with care. |
| 7 | Off-main settings health-row disk reads | `UasAcsHealthRow.swift:157,191`, `FalsifierArtifactsHealthRow.swift:152`, `LocalAgentDiagnosticsHealthRow.swift:1564`, `SettingsView.swift:2923` | sync `Data(contentsOf:)`+decode building gate rows; if from a MainActor body, blocks Settings open. Move into the `SubstrateHealthClock` async tick or `.task` (verify call-site isolation first). | Low (Settings-only) | Low-Med |
| 8 | Reuse decoder `RustCognitiveDagClient.stats()` | `Engine/RustCognitiveDagClient.swift:127` | fresh decoder per polled `stats()`. `static let`. | Low | Low |
| 9 | Reuse decoder `ChatState` snapshot loads | `State/ChatState.swift:497,1423` | inline decoder on snapshot/brain-snapshot decode. `static let`. | Low | Low |
| 10 | `CodeEditorView` analysis timer cadence | `Views/Notes/CodeEditorView.swift:1402` | `Timer.scheduledTimer(repeats:)` wakes + MainActor-hops each tick even when editor not frontmost (has a `hashValue` guard). Pause/invalidate on disappear / window-not-key. | Low-Med (bg wakeups) | Low |
| 11 | `AIPartnerService` analysis timer | `Views/Notes/AIPartnerService.swift:441` | same shape — periodic analysis regardless of focus (gated only by isEnabled). Gate on editor focus/visibility. | Low-Med | Low |
| 12 | Compact pretty-JSON on frequently-rewritten stores | `KnowledgeFusion/KnowledgeProfileStore.swift:119`, `Harness/ProgressStore.swift:167,202,226` | `.prettyPrinted` on machine-read metadata/progress rewritten repeatedly. Drop where machine-read; keep `.sortedKeys`. SKIP human-inspected artifacts. | Low | Low |

## Order for the build loop
**First three (highest value / lowest risk):** #1 (tool-schema compact JSON — only one touching the inference prompt;
cuts input tokens every tool turn), #2+#4 (shared coders on `SDMessage` — highest call frequency; consistency with
existing pattern), #3 (RawThoughts formatter+grouping — clear render-path alloc during runs). Then #5/#8/#9 (trivial
coder/formatter hoists), #7/#10/#11 (off-main / timer-focus gating), #12 (compact stores). #6 (Equatable) LAST + behind
a focused test (only higher-risk item). Each: cargo --lib/swift test where applicable; perf is a standing gate. Cross-ref
SS-SH, SS-ALIVE (don't animate hot/expensive paths).
