# Wave 13 — Master Implementation Plan (with code snippets)

Synthesised from three parallel meta-advice research agents (Apple
FoundationModels patterns; sqlite-vec + petgraph + sidecars; launchd
+ FSRS-6 + SpeechAnalyzer). Each section contains the canonical code
the next implementation pass should paste in, plus the gotchas the
agents flagged. Pairs with `WAVE_9_POLISH_AND_NATIVE.md` (the high-
level plan) — this doc is the **how**.

> Status — 2026-04-26: DRAFT, awaiting further research drops per
> user instruction. Compass W10.4 + W10.10 fixes already shipped
> (ce798bcf, 121cec0e, f257dda3); the rest of this doc is sequenced
> for sustained implementation.

## Build order (compass artifact, 12-month plan)

| Months | Phase wave | Items |
| ------ | ---------- | ----- |
| 1–3    | Foundation | Phase 1 (AFM `@Generable` ontology) → Phase 8 (sqlite-vec + petgraph + Metal graph) → Phase 12 (sidecars + notify + ignore) → Phase 4 (bootstrap with cache padding ✅) → Phase 5 (hybrid brain orchestrator with thermal/battery/GPU-contention policy) |
| 4–6    | Sensory + structure | Phase 14 (intake valve <500 ms, explicit cancellation token) → Phase 15 (two-DB quarantine) → Phase 11 (SpeechAnalyzer + Metal waveform) → Phase 2 (FSRS-6 + candle Q-types tier cascade + launchd LaunchAgent ✅) |
| 7–9    | Orchestration + intelligence | Phase 3 (CLI bridge with pty-process) → Phase 6 (tool-use retrieval, NOT pause-and-inject) → Phase 9 (`@Generable SessionTelemetry`) → Phase 16 (real-time stenographer) |
| 10–12  | Defensibility + polish | Phase 7 (Hermes Chief of Staff via rmcp 0.16) → Phase 13 (apalis-sqlite ETL with xxh3) → Phase 10 (NightBrain LoRA — quietly, with in-context fallback always engaged) → ADA polish |

---

## Phase 1 — Intelligent semantic ontology (AFM `@Generable`)

### Recursive ontology classifier — flatten arrays to keep schema stable

The agent flagged that fully-recursive types with array fields generate
`undefined reference` schema errors in macOS 26.0–26.2. Use optional
single-level nesting OR an ID-based graph store; do not declare
`children: [OntologyNode]` directly.

```swift
@Generable
struct OntologyNode: Codable {
    @Guide(description: "Parent domain, e.g. 'Aeronautics' or 'Medicine'")
    var parentDomain: String

    @Guide(description: "Primary concept label, lowercase kebab-case")
    var childConcept: String

    @Guide(description: "Knowledge depth marker")
    var depth: DepthMarker

    @Guide(description: "Confidence 0.0-1.0")
    var confidence: Double

    // GOTCHA: keep children optional + flat to avoid schema drift across
    // macOS 26.0-26.4. Model fills scalar fields first, then arrays.
    var children: [OntologyNode]?
}

@Generable enum DepthMarker { case surface, synthesized, coreBelief }
```

**Use-case**: classification with guardrail false-positive filtering
(aviation/medical terms occasionally get refused with the default model
— `.contentTagging` use case is much friendlier).

```swift
let classifier = SystemLanguageModel(useCase: .contentTagging)
let session = LanguageModelSession(systemLanguageModel: classifier)
let response = try await session.send("Classify: 'vector thrust control system'")
let parsed = try JSONDecoder().decode(OntologyNode.self, from: response.data(using: .utf8)!)
```

### Streaming `T.PartiallyGenerated` into SwiftUI

Bind `@Observable` view models directly to `PartiallyGenerated`
snapshots. **Avoid debouncing** — let SwiftUI's view diffing handle
churn. Every snapshot is JSON-safe.

```swift
@Observable
class OntologyViewState {
    var partialNode: OntologyNode.PartiallyGenerated?
    var isGenerating = false
}

struct OntologyView: View {
    @State private var state = OntologyViewState()

    var body: some View {
        VStack {
            if let partial = state.partialNode {
                Text(partial.childConcept ?? "Thinking…").font(.headline)
                if let conf = partial.confidence { ProgressView(value: conf) }
            }
        }
        .task { await generate() }
    }

    private func generate() async {
        state.isGenerating = true
        defer { state.isGenerating = false }
        let session = LanguageModelSession(
            systemLanguageModel: SystemLanguageModel(useCase: .contentTagging)
        )
        do {
            let stream = try await session.generateAsStream(
                prompt: "Classify 'VTOL aircraft'",
                outputType: OntologyNode.self
            )
            for try await partial in stream { state.partialNode = partial }
        } catch { print("Generation failed: \(error)") }
    }
}
```

### Map-reduce chunking past the 4,096-token AFM ceiling

`SystemLanguageModel.tokenCount(for:)` is `@backDeployed(before: macOS 26.4)`
so it works on earlier OS versions but may be slower. Always wrap in
`exceededContextWindowSize` recovery.

```swift
let model = SystemLanguageModel.default
let contextWindow = try await model.contextSize  // 4096

func chunkSession(_ transcript: String, maxTokensPerChunk: Int = 2400)
    async throws -> [[String]]
{
    let total = try await model.tokenCount(for: transcript)
    guard total > contextWindow else { return [[transcript]] }
    var chunks: [[String]] = [], cur: [String] = [], curTok = 0
    for line in transcript.split(separator: "\n") {
        let lt = try await model.tokenCount(for: String(line))
        if curTok + lt > maxTokensPerChunk {
            chunks.append(cur); cur = [String(line)]; curTok = lt
        } else { cur.append(String(line)); curTok += lt }
    }
    chunks.append(cur); return chunks
}
```

### Verified canonical API (per `FoundationModels.swiftinterface` 2026-04-26)

The SDK headers at
`MacOSX.sdk/System/Library/Frameworks/FoundationModels.framework/...
arm64e-apple-macos.swiftinterface` confirm the following surface (line
numbers from that file):

```swift
// line 524-526
public struct UseCase : Swift.Sendable, Swift.Equatable {
    public static let general: SystemLanguageModel.UseCase
    public static let contentTagging: SystemLanguageModel.UseCase
}

// line 582
convenience public init(useCase: SystemLanguageModel.UseCase = .general,
                        guardrails: SystemLanguageModel.Guardrails = .default)

// LanguageModelSession init — line 339-342
convenience public init(
    model: SystemLanguageModel = .default,
    tools: [any Tool] = [],
    instructions: String? = nil
)

// respond(to:generating:) — line 378 (Prompt overload), 382 (String overload)
final public func respond<Content>(
    to prompt: String,
    generating type: Content.Type = Content.self,
    includeSchemaInPrompt: Bool = true,
    options: GenerationOptions = GenerationOptions()
) async throws -> Response<Content> where Content : Generable
```

**Canonical pattern** (verified 2026-04-26, used by `OntologyClassifier`):

```swift
let model = SystemLanguageModel(useCase: .contentTagging)  // friendlier guardrails
let session = LanguageModelSession(model: model, instructions: systemPrompt)
let response = try await session.respond(to: prompt, generating: OntologyNode.self)
return response.content   // already typed; no JSON round-trip needed
```

### `@Guide` constraint matrix — verified

| Constraint | Type | Notes |
| ---------- | ---- | ----- |
| `.count(0...8)` | Array | Works at all depths |
| `.range(0.0...1.0)` | Numeric | Soft constraint; model may violate edges |
| `.minimum(n)` / `.maximum(n)` | Numeric | Rare; prefer `.range` |
| `.anyOf(["a","b"])` | String enum | **Hard constraint**; strict |
| `.pattern(/regex/)` | String | macOS 26.2+ only |
| `.description("…")` | Any | Soft hint |

**Combination gotchas**: `.anyOf + .pattern` on same property fails
silently (model ignores the second). Multiple `@Guide` macros stack.

### Availability gating — three distinct failure modes

```swift
enum ModelReadiness { case available, deviceNotEligible, intelligenceDisabled, modelLoading }

func checkModelReadiness() async -> ModelReadiness {
    switch SystemLanguageModel.default.availability {
    case .available: return .available
    case .unavailable(let reason):
        switch reason {
        case .deviceNotEligible: return .deviceNotEligible
        case .appleIntelligenceNotEnabled: return .intelligenceDisabled
        case .modelNotReady: return .modelLoading
        @unknown default: return .modelLoading
        }
    @unknown default: return .modelLoading
    }
}
```

`.deviceNotEligible` is **permanent** — never show a spinner.
`.appleIntelligenceNotEnabled` is **actionable** — link to Settings.

### References
- WWDC25 Session 286 (Meet the Foundation Models framework)
- WWDC25 Session 301 (Deep dive)
- TN3193: Managing the on-device foundation model's context window

---

## Phase 8 — sqlite-vec + petgraph + Metal graph

### sqlite-vec auto-extension before GRDB opens

The compass artifact's "code-sign the extension" guidance applies only
to the loose `.dylib` path; the Rust crate ships `vec0` statically.
Register `sqlite_auto_extension` BEFORE GRDB's `DatabasePool` opens any
connection — must fire in the UniFFI init function, not lazily.

```rust
use rusqlite::{Connection, ffi};
use sqlite_vec::sqlite3_vec_init;

unsafe {
    ffi::sqlite3_auto_extension(Some(std::mem::transmute(
        sqlite3_vec_init as *const ()
    )));
}
let conn = Connection::open(&db_path)?;
conn.execute_batch(r#"
    PRAGMA journal_mode=WAL;
    PRAGMA synchronous=NORMAL;
    CREATE VIRTUAL TABLE IF NOT EXISTS vec_nodes USING vec0(
        node_id INTEGER PRIMARY KEY,
        embedding FLOAT[768]
    );
"#)?;
```

### Hysteresis edge inference — two-pass mandatory

`τ_add = 0.80` cosine ≈ `distance ≤ 0.20`. `τ_remove = 0.65` ≈
`distance > 0.35`. **Don't try to express hysteresis in a single
query.**

```sql
-- Add candidates
SELECT v.node_id, v.distance
FROM vec_nodes v
WHERE v.embedding MATCH ?1 AND k = 10
  AND v.distance <= 0.20
  AND v.node_id != ?2
ORDER BY v.distance;

-- Remove decayed (separate pass)
DELETE FROM edges WHERE id IN (
  SELECT id FROM edges
  WHERE rel = 'similar_to' AND weight < 0.65
);
```

### petgraph `StableDiGraph` projection — but tombstones leak

`StableDiGraph` keeps `NodeIndex` valid across removals BUT memory
grows monotonically (tombstones never compact). Run
`g.retain_nodes(|_,_| true)` periodically OR rebuild from SQLite every
N hours.

```rust
use petgraph::stable_graph::{StableDiGraph, NodeIndex};
use std::collections::HashMap;

pub struct GraphProjection {
    g: StableDiGraph<NodeMeta, EdgeMeta>,
    by_id: HashMap<Uuid, NodeIndex>,
}
impl GraphProjection {
    pub fn upsert_edge(&mut self, src: Uuid, dst: Uuid, w: f32) {
        let a = *self.by_id.entry(src)
            .or_insert_with(|| self.g.add_node(NodeMeta::lazy(src)));
        let b = *self.by_id.entry(dst)
            .or_insert_with(|| self.g.add_node(NodeMeta::lazy(dst)));
        if let Some(e) = self.g.find_edge(a, b) { self.g[e].weight = w; }
        else { self.g.add_edge(a, b, EdgeMeta { weight: w, ts: now() }); }
    }
    pub fn decay(&mut self, days: f32) {
        let factor = 0.97_f32.powf(days);
        for ew in self.g.edge_weights_mut() { ew.weight *= factor; }
    }
}
```

### Metal force-directed graph — Verlet on UMA, no copies

Verlet hits 120 fps easily on M-series; Barnes-Hut is overkill
< 50 k nodes. Allocate the `MTLBuffer` first, let Rust write into its
`.contents()` via FFI (avoids the page-alignment trap of
`bytesNoCopy`).

```swift
// MTKView delegate
func draw(in view: MTKView) {
    let cmd = queue.makeCommandBuffer()!
    let enc = cmd.makeComputeCommandEncoder()!
    enc.setComputePipelineState(verletPipeline)
    enc.setBuffer(buf, offset: 0, index: 0)
    enc.dispatchThreadgroups(
        MTLSize(width: (n+63)/64, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1)
    )
    enc.endEncoding()
    cmd.present(view.currentDrawable!)
    cmd.commit()
}
```

`MTKView.preferredFramesPerSecond = 120` for ProMotion (OS still
throttles to 60 if the window is occluded). **Don't read positions
back to Rust every frame** — sync once per layout-converged
checkpoint, otherwise unified-memory bandwidth is murdered.

---

## Phase 12 — Sidecar files (`notify` + `ignore` + `schemars`)

### `ignore 0.4.25` — the compass snippet was inverted

`OverrideBuilder::add()` adds *inclusion* patterns by default; to
exclude, prefix with `!`. The compass artifact's snippet would only
walk `*.swift`/`*.rs`/etc — the inverse of what we want.

```rust
use ignore::{WalkBuilder, overrides::OverrideBuilder};

let mut ovr = OverrideBuilder::new(&root);
for ext in &[
    "!*.swift","!*.rs","!*.py","!*.json","!*.toml",
    "!target/**","!.build/**","!DerivedData/**","!node_modules/**",
] {
    ovr.add(ext)?;
}
let walker = WalkBuilder::new(&root)
    .overrides(ovr.build()?)
    .standard_filters(true)        // .gitignore + hidden + .ignore
    .add_custom_ignore_filename(".pkmignore")
    .git_ignore(true)
    .build();
for entry in walker.filter_map(Result::ok) {
    if entry.file_type().map_or(false, |ft| ft.is_file()) {
        ingest(entry.path());
    }
}
```

### `notify 8.2.0` + debouncer — handle FSEvents coalescing already done

macOS FSEvents coalesces BEFORE the Rust debouncer, so 400 ms is on
top of ~30 ms FSEvents latency — fine for sidecars, lethal for typing.

```rust
use notify::{RecommendedWatcher, RecursiveMode, EventKind, event::{ModifyKind, RenameMode}};
use notify_debouncer_full::new_debouncer;
use std::time::Duration;

let (tx, rx) = std::sync::mpsc::channel();
let mut deb = new_debouncer(Duration::from_millis(400), None, tx)?;
deb.watcher().watch(&vault, RecursiveMode::Recursive)?;
for res in rx {
    match res {
        Ok(events) => for e in events {
            match e.kind {
                EventKind::Modify(ModifyKind::Name(RenameMode::Both)) =>
                    handle_rename(&e.paths),
                EventKind::Create(_) => handle_create(&e.paths[0]),
                EventKind::Modify(_) => handle_modify(&e.paths[0]),
                EventKind::Remove(_) => handle_delete(&e.paths[0]),
                _ => {}
            }
        },
        Err(errs) => for e in errs { tracing::warn!("notify: {e:?}"); }
    }
}
```

**Sandbox gotcha**: sandboxed builds need security-scoped bookmarks;
resolve + `startAccessingSecurityScopedResource()` on Swift, then pass
the resolved path to Rust. Watch the **vault root**, never `~/` —
FSEvents perf collapses on large trees.

### `xxh3-128` change detection — APFS clone reality

APFS clones share `st_ino` AND `st_size` AND `st_mtime` until either
is mutated — you literally cannot detect a clone without hashing. For
signed exports use BLAKE3 (hash once, store both).

```rust
use twox_hash::XxHash3_128;
use std::fs::File;
use memmap2::Mmap;

fn fingerprint(p: &Path) -> Result<u128> {
    let meta = std::fs::symlink_metadata(p)?;
    if p.extension().map_or(false, |e| e == "icloud") { return Ok(0); }
    let f = File::open(p)?;
    if meta.len() < 64 * 1024 {
        let mut buf = Vec::with_capacity(meta.len() as usize);
        f.take(meta.len()).read_to_end(&mut buf)?;
        Ok(XxHash3_128::oneshot(&buf))
    } else {
        let mmap = unsafe { Mmap::map(&f)? };  // SAFETY: read-only mmap
        let mut h = XxHash3_128::new();
        h.write(&mmap);
        Ok(h.finish_128())
    }
}
```

### `schemars 0.8` JSON Schema — compass `$dynamicRef` claim was wrong

`$dynamicRef` is JSON Schema 2020-12 — `schemars 0.8` emits draft-07
by default. Either upgrade to `schemars 1.0` (breaking API change) or
use `oneOf` discriminator on `schema_version`. Ship `oneOf` today;
revisit when 1.x stabilises.

```rust
use schemars::{JsonSchema, schema_for};

#[derive(JsonSchema, Serialize, Deserialize)]
#[serde(tag = "schema_version")]
enum NoteSchema {
    #[serde(rename = "1")] V1(NoteV1),
    #[serde(rename = "2")] V2(NoteV2),
}

let schema = schema_for!(NoteSchema);
std::fs::write("schemas/note.schema.json",
               serde_json::to_string_pretty(&schema)?)?;
```

For consumption, compile schemas ONCE at startup. Recompiling per-read
is a 10-100× regression.

```rust
let compiled = jsonschema::JSONSchema::compile(&schema_value)?;
// reuse `compiled` per-read
```

---

## Phase 11 — SpeechAnalyzer + Metal waveform

### Transcriber skeleton (macOS 26+)

```swift
import Speech
import AVFoundation

@available(macOS 26, *)
actor LiveTranscription {
    private let transcriber = SpeechTranscriber(
        locale: .current,
        preset: .conversational  // verify enum case in current SDK
    )
    private lazy var analyzer = SpeechAnalyzer(modules: [transcriber])
    private let engine = AVAudioEngine()

    func start(onText: @escaping (String, Bool) -> Void) async throws {
        if let req = try await AssetInventory.assetInstallationRequest(
            supporting: [transcriber]
        ) {
            try await req.downloadAndInstall()  // surfaces .progress for UI
        }
        let (stream, cont) = AsyncStream<AVAudioPCMBuffer>
            .makeStream(bufferingPolicy: .bufferingNewest(64))
        let fmt = engine.inputNode.outputFormat(forBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buf, _ in
            cont.yield(buf)
        }
        try engine.start()
        Task { for await buf in stream { try? await analyzer.analyze(audio: buf) } }
        Task {
            for try await r in transcriber.results {
                onText(String(r.text.characters), r.isFinal)  // volatile vs final
            }
        }
    }
}
```

### Lock-free SPSC FFT ring → Metal compute → CAMetalLayer

Write from audio thread, read on render thread.

```swift
final class SpectrumRing {
    private let buf: UnsafeMutablePointer<Float>
    private let mask: Int
    private var head = ManagedAtomic<Int>(0)
    private var tail = ManagedAtomic<Int>(0)

    init(bins: Int) {
        mask = bins - 1
        buf = .allocate(capacity: bins)
        buf.initialize(repeating: 0, count: bins)
    }

    func push(_ bins: UnsafeBufferPointer<Float>) {
        let h = head.load(ordering: .relaxed)
        for (i, v) in bins.enumerated() { buf[(h &+ i) & mask] = v }
        head.store(h &+ bins.count, ordering: .releasing)
    }

    func snapshot(into mtl: MTLBuffer) {
        let h = head.load(ordering: .acquiring)
        memcpy(mtl.contents(), buf, (h & mask) * MemoryLayout<Float>.stride)
    }
}

let layer = CAMetalLayer()
layer.device = MTLCreateSystemDefaultDevice()
layer.pixelFormat = .bgra8Unorm
layer.framebufferOnly = true
layer.displaySyncEnabled = true        // 60/120 Hz match ProMotion
layer.maximumDrawableCount = 3
let amplitudes = device.makeBuffer(
    length: 256 * 4, options: .storageModeShared
)!
// MSL compute: y_t = 0.7 * prev[i] + 0.3 * incoming[i]; bloom via Gaussian taps
```

### Route changes — AirPods connect/disconnect mid-stream

```swift
NotificationCenter.default.addObserver(
    forName: AVAudioEngine.configurationChangeNotification,
    object: engine, queue: .main
) { _ in
    Task { @MainActor in
        self.engine.stop()
        self.engine.inputNode.removeTap(onBus: 0)
        try? await self.start(onText: self.onText)  // formats may have changed
    }
}
```

**Volatile-result gotcha**: `SpeechTranscriber.results` yields
*volatile* segments that mutate in place — diff by `range` not by
string equality, or your UI flickers on every partial.

### WhisperKit fallback (macOS 14/15 or custom vocab)

```swift
let useSA = ProcessInfo.processInfo.isOperatingSystemAtLeast(
    .init(majorVersion: 26, minorVersion: 0, patchVersion: 0)
)
let transcript: any LiveTranscriptionProtocol = useSA
    ? LiveTranscription()
    : WhisperKitTranscription(model: .largeV3Turbo)
```

---

## Phase 2 — FSRS-6 decay engine

### SQLite schema + nightly pass

```sql
CREATE TABLE fsrs_state (
    note_id        TEXT PRIMARY KEY,
    last_reviewed  INTEGER NOT NULL,         -- unix seconds
    difficulty     REAL    NOT NULL,         -- D ∈ [1,10]
    stability      REAL    NOT NULL,         -- S in days
    retrievability REAL    NOT NULL,         -- R(t) at last_reviewed
    last_grade     INTEGER NOT NULL,         -- Again=1 Hard=2 Good=3 Easy=4
    reviews        INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX fsrs_due ON fsrs_state(retrievability);
```

```rust
use fsrs::{FSRS, MemoryState};

pub fn nightly_decay(conn: &Connection, params: &[f32; 21])
    -> Result<Vec<HighRisk>>
{
    let fsrs = FSRS::new(Some(params))?;
    let now = chrono::Utc::now().timestamp();
    let mut risky = Vec::new();
    let mut stmt = conn.prepare(
        "SELECT note_id, last_reviewed, difficulty, stability FROM fsrs_state"
    )?;
    for row in stmt.query_map([], |r| Ok((
        r.get::<_,String>(0)?, r.get::<_,i64>(1)?,
        r.get::<_,f32>(2)?, r.get::<_,f32>(3)?,
    )))? {
        let (id, last, d, s) = row?;
        let elapsed = (now - last) as f32 / 86_400.0;
        let r = fsrs.current_retrievability(
            MemoryState { stability: s, difficulty: d }, elapsed
        );
        conn.execute(
            "UPDATE fsrs_state SET retrievability=?1 WHERE note_id=?2",
            params![r, id]
        )?;
        if r < 0.80 { risky.push(HighRisk { note_id: id, r, days: elapsed }); }
    }
    risky.sort_by(|a, b| a.r.partial_cmp(&b.r).unwrap());
    risky.truncate(25);
    Ok(risky)
}
```

### Bayesian cold-start blend (defaults dominate until ~50 reviews)

```rust
fn blended_params(user: &[f32;21], reviews: usize) -> [f32;21] {
    let alpha = (reviews as f32 / 50.0).min(1.0);
    let mut out = fsrs::DEFAULT_PARAMETERS;
    for i in 0..21 {
        out[i] = (1.0 - alpha) * out[i] + alpha * user[i];
    }
    out
}
```

### Tier cascade quantisation (compass-recommended; irreversible — keep f16 ≥ 90 d)

```rust
use candle_core::{Tensor, quantized::{GgmlDType, QTensor}};

fn quantize_for_age(t: &Tensor, age_days: f32) -> Result<QTensor> {
    let dtype = match age_days {
        d if d <=  7.0 => GgmlDType::F16,
        d if d <= 30.0 => GgmlDType::Q8_0,
        d if d <= 90.0 => GgmlDType::Q4K,
        _              => GgmlDType::Q2K,  // floor; below this → summarize-and-delete
    };
    QTensor::quantize(t, dtype)
}
```

### Scheduler — in-process tokio-cron (replaces launchd when foreground)

```rust
let sched = tokio_cron_scheduler::JobScheduler::new().await?;
sched.add(
    tokio_cron_scheduler::Job::new_async("0 0 3 * * *", |_, _| Box::pin(async {
        let _ = nightly_decay(&pool.get().unwrap(), &load_params());
    }))?
).await?;
sched.start().await?;
```

**API stability gotcha**: the `fsrs` crate's `MemoryState { stability, difficulty }` field names have churned across 4.x → 5.x. Verify against `cargo doc --open --package fsrs` before pasting. The algorithm shape is stable; the API surface is not.

---

## Phase 10 — NightBrain LaunchAgent (✅ shipped 121cec0e + f257dda3)

Already implemented. The plist + `SMAppService.agent(plistName:)`
wrapper + `PowerGate` cross-cutting predicate + AppBootstrap fallback
are live. Outstanding follow-up: xcodegen wiring of the
`NightBrainHelper` separate executable target inside the .app bundle's
`Contents/MacOS/`. Once that target exists the SMAppService.register
call stops returning "Operation not permitted" silently.

---

## Cross-cutting — UniFFI status as of 2026-04-26

**Verified 2026-04-26:** the codebase currently pins `uniffi = "0.28"`
across all Rust crates (`agent_core`, `epistemos-core`, `omega-mcp`,
`omega-ax`). `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` IS active
(`project.yml:11`). Issue #2818 (open since Feb 11, 2026) **is already
mitigated** by `patch-uniffi-bindings.py` — a 4-fix post-processor that:

1. Marks the rustCall `pointer` as `nonisolated(unsafe)`
2. Snapshots the object pointer into a nonisolated(unsafe) local before deinit free
3. Marks `errorDescription` (`LocalizedError` conformance) as `nonisolated`
4. Marks generated wrapper declarations as `nonisolated` / `nonisolated(unsafe)`

Compass recommended bumping to 0.29.5 for the
`experimental_sendable_value_types` flag. The bump itself is a
high-risk change (0.29 has API surface changes vs 0.28); risk
assessment + bindings re-test should be a dedicated session.

## Cross-cutting — UniFFI 0.29.5 + Issue #2818 (Swift 6.2 / Xcode 26)

The compass artifact pinned `uniffi = "0.29.5"`. Issue #2818 (open
since Feb 11, 2026; no fix shipped) means generated bindings fail to
compile under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26
default) because `deinit` cannot be MainActor-isolated.

**Mitigation**: place generated bindings in a separate SwiftPM target
with `defaultIsolation(nil)` (nonisolated). The app target keeps
MainActor isolation; the bindings target opts out.

```swift
// Package.swift
.target(
    name: "EpistemosFFI",
    path: "build-rust/swift-bindings",
    swiftSettings: [
        .defaultIsolation(nil),   // opt out of Xcode 26 MainActor default
    ]
),
.target(
    name: "Epistemos",
    dependencies: ["EpistemosFFI"],
    swiftSettings: [
        .defaultIsolation(MainActor.self),
    ]
)
```

**Cancellation** (Issue #2771): Swift `Task.cancel()` does NOT cancel
Rust futures. Ship explicit `CancellationToken` handle objects:

```rust
#[derive(uniffi::Object)]
pub struct ClassifyHandle {
    cancel: tokio_util::sync::CancellationToken
}

#[uniffi::export(async_runtime = "tokio")]
impl KnowledgeCore {
    pub async fn classify_paste(
        self: Arc<Self>, handle: Arc<ClassifyHandle>, ...
    ) -> Result<()> {
        tokio::select! {
            r = run_pipeline(...) => r,
            _ = handle.cancel.cancelled() => Err(KnowledgeError::Cancelled),
        }
    }
}
```

Swift must call `handle.cancel()` explicitly in
`continuation.onTermination`.

---

## Cross-cutting — PowerGate (✅ shipped 121cec0e)

Already implemented at `Epistemos/State/PowerGate.swift`. Used by all
background subsystems so a single thermal/battery pressure event
throttles the whole stack uniformly:

- NightBrain LaunchAgent (W10.10) ✅
- FSRS-6 daily decay (W10.2)
- SpeechAnalyzer always-on transcription (W10.11)
- MLX subconscious dispatch (W10.5)

---

## Apalis-SQLite cron (Phase 13 ETL)

```rust
use apalis::prelude::*;
use apalis_sql::sqlite::{SqliteStorage, SqlitePool};
use apalis::layers::retry::RetryPolicy;
use tower::ServiceBuilder;

#[derive(serde::Serialize, serde::Deserialize)]
struct DecayJob { vault: PathBuf }

async fn decay_handler(j: DecayJob) -> Result<(), Error> { Ok(()) }

let pool = SqlitePool::connect(&db_url).await?;
SqliteStorage::setup(&pool).await?;        // creates jobs table
let storage: SqliteStorage<DecayJob> = SqliteStorage::new(pool);

Monitor::new()
    .register({
        WorkerBuilder::new("decay")
            .layer(ServiceBuilder::new().retry(RetryPolicy::retries(3)))
            .backend(storage.clone())
            .build_fn(decay_handler)
    })
    .run().await?;
```

**Pin EXACTLY** `apalis = "=1.0.0-rc.7"` — the 1.0 RC API has churned
across `1.0.0-rc.4..7` and semver-loose specs will break overnight.
Cron is a separate `apalis-cron` feature; register
`CronStream::new(schedule)` as the backend.

---

## Adoption order (operational, paste-ready)

1. **sqlite-vec + GRDB** (foundation substrate)
2. **`ignore` + `notify`** (ETL plumbing)
3. **xxh3 fingerprinting** (idempotency)
4. **petgraph projection** (queries)
5. **schemars + JSON Schema sidecars** (sidecar contract)
6. **apalis cron** (background decay)
7. **Metal viz** (the demo)
8. **AFM `@Generable` ontology** (cognitive layer)
9. **SpeechAnalyzer + Metal waveform** (sensory layer)
10. **FSRS-6 decay state** (memory hygiene layer)

## Compass-artifact discrepancies flagged by meta-advice agents

| Compass claim | Agent verdict |
| ------------- | ------------- |
| `OverrideBuilder::add(ext)` excludes patterns | **INVERTED** — adds INCLUSIONS by default; must prefix `!` to exclude |
| `$dynamicRef` works in `schemars 0.8` | **FALSE** — `$dynamicRef` is 2020-12; `schemars 0.8` emits draft-07. Use `oneOf` discriminator instead. |
| `code-sign sqlite-vec extension` | **MISLEADING** — only applies to loose `.dylib` path; the Rust crate ships `vec0` statically (no signing concern) |
| `fsrs` API stable | **API churned 4.x → 5.x** — verify field names against `cargo doc` |
| `SpeechTranscriber.preset: .conversational` exact case | **UNCONFIRMED** — preset enum has shifted between betas; verify against current SDK headers |
| Apple-Silicon equivalent of Power Nap | **NOT PUBLICLY DOCUMENTED** — treat the 36 h fallback as load-bearing not as a backstop |

## Three-things-to-do-this-week (compass)

1. ✅ **Pad the W10.4 BootstrapPacket to ≥1,100 tokens** — done (commit ce798bcf).
2. ✅ **Land NightBrain launchd plist + scheduler + PowerGate** — done (commits 121cec0e, f257dda3).
3. **Pin `uniffi = "0.29.5"`** + stand up Issue #2818 mitigation. Pending — Cargo.toml audit + Package.swift target separation.
4. **Build benchmark harness** — AFM `@Generable` round-trip latency, MLX Qwen3 0.6B 4-bit tok/s under thermal pressure, sqlite-vec KNN at 100 k vectors, UniFFI callback throughput. Numbers in compass are estimates; measure the actual stack.
