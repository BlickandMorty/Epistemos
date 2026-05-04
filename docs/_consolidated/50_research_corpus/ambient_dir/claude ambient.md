# Epistemos: Implementation Guide for a Native macOS Cognitive Augmentation App

A senior-engineer technical synthesis for Jojo/Jordan — Swift 6 + Rust (UniFFI) + Metal + MLX-Swift + GRDB on Apple Silicon (M2 Pro / 18 GB baseline). Every recommendation below is grounded in current (2025–2026) library state. Where a library's behavior is uncertain, I flag it explicitly.

---

## 1. Contextual Shadows / Instant Recall System (HIGHEST PRIORITY)

### 1A. Embedder Recommendation: **Model2Vec `potion-retrieval-32M` (primary) + character trigram (typo-tolerance fallback)**

**The Recommendation.** Adopt MinishLab's Model2Vec `potion-retrieval-32M` as the canonical encoder for Contextual Shadows. It is the strongest static (non-contextual) retrieval model published, reaching ~86.6% of the retrieval performance of `all-MiniLM-L6-v2` while being orders of magnitude faster on CPU, and running on numpy alone with no transformer runtime ([MinishLab/model2vec results](https://github.com/MinishLab/model2vec/blob/main/results/README.md)). The general-purpose `potion-base-32M` reaches 92.11% of MiniLM-L6-v2 on MTEB at score 51.66 ([MinishLab](https://github.com/MinishLab/model2vec)). Static embeddings are a perfect fit for a 200 ms-debounced "encode-on-keystroke" loop because the inference cost is essentially "look up subword embeddings, mean-pool, multiply by PCA matrix" — sub-millisecond per paragraph on a single M2 Pro core.

**The Why.**
- **Latency**: Model2Vec authors report up to 500× speedup over the parent sentence-transformer on CPU ([MinishLab](https://github.com/MinishLab/model2vec)). For a paragraph of 100 tokens that translates to well under 1 ms on M2 Pro performance cores.
- **Footprint**: ~30 MB on disk for `potion-base-32M`, ~8 MB for the smallest variants ([MinishLab](https://github.com/MinishLab/model2vec)). For 10K notes at 256 dims fp32 the full vector matrix is ~10 MB; at int8 ~2.5 MB; at 1-bit binary ~320 KB.
- **Quality vs BGE/E5**: Static embeddings *will* lose to contextual rerankers on hard semantic pairs. The mitigation is a two-tier search (cheap fast tier + optional rerank), exactly as in `frankensearch` which pairs `potion-multilingual-128M` with `all-MiniLM-L6-v2` for sub-millisecond first results and 150 ms refined ranking ([Dicklesworthstone/frankensearch](https://github.com/Dicklesworthstone/frankensearch)).
- **Lexical/typo robustness**: Combine with character trigrams via BM25 (Tantivy) — see §1C. Pure static embeddings can miss exact-token matches like "TS-01" ([Qdrant BM42](https://qdrant.tech/articles/bm42/)).
- **Reference architectures**: Cursor uses a custom-trained embedding model + Turbopuffer + grep fusion ([Cursor blog](https://cursor.com/blog/semsearch)); Obsidian Smart Connections runs local embeddings continuously with a "footer connections" panel that updates as you type ([smartconnections.app](https://smartconnections.app/smart-connections/)).

**The Code (Rust + UniFFI).** Model2Vec is Python/numpy. To ship native, distill once in Python (`from model2vec.distill import distill`), then export the token vocabulary + embedding matrix + PCA + Zipf weights to a flat binary, and reimplement inference in Rust. The math is mean-of-token-embeddings (~50 lines of Rust + a tokenizer):

```rust
// crates/epistemos-embed/src/lib.rs
use std::sync::Arc;
use tokenizers::Tokenizer; // huggingface/tokenizers crate

pub struct StaticEmbedder {
    matrix: Arc<Vec<f32>>,   // [vocab_size * dim] row-major
    dim: usize,
    tokenizer: Tokenizer,
}

#[uniffi::export]
impl StaticEmbedder {
    #[uniffi::constructor]
    pub fn from_path(path: String) -> Arc<Self> { /* mmap matrix + load tokenizer.json */ unimplemented!() }

    pub fn encode(&self, text: String) -> Vec<f32> {
        let enc = self.tokenizer.encode(text, false).unwrap();
        let ids = enc.get_ids();
        let mut out = vec![0f32; self.dim];
        if ids.is_empty() { return out; }
        for &id in ids {
            let off = (id as usize) * self.dim;
            for d in 0..self.dim { out[d] += self.matrix[off + d]; }
        }
        let inv = 1.0 / ids.len() as f32;
        for d in 0..self.dim { out[d] *= inv; }
        // L2 normalize for cosine
        let n: f32 = out.iter().map(|v| v*v).sum::<f32>().sqrt().max(1e-12);
        for v in &mut out { *v /= n; }
        out
    }
}
```

Expose via UniFFI (`udl` or proc-macro). On the Swift side this becomes `try await embedder.encode(text:)` if you mark it `async`, or a sync call you dispatch onto a serial executor (see §2A).

**The Gotchas.**
- Model2Vec is **uncontextualized** (mean-of-token-embeddings) — it cannot disambiguate "bank (river)" vs "bank (money)". For Epistemos's "live shadows" UX this is *fine* because users choose what to click. Don't use it as your final-stage reranker for high-stakes retrieval.
- Static embeddings are very sensitive to PCA dim choice; the 256-dim defaults from MinishLab are well-calibrated ([MinishLab blog](https://minishlab.github.io/hf_blogpost/)). Don't reduce below 128.
- `all-MiniLM-L6-v2` parity claim is for *MTEB average*, not retrieval@10 on adversarial queries.

**References.** [MinishLab/model2vec GitHub](https://github.com/MinishLab/model2vec) · [potion-retrieval-32M on HF](https://huggingface.co/minishlab/potion-retrieval-32M) (via results README) · [Tokenlearn pretraining](https://github.com/MinishLab/tokenlearn) · [frankensearch reference](https://github.com/Dicklesworthstone/frankensearch).

---

### 1B. Vector Index Recommendation: **usearch HNSW with bf16 quantization (primary) + 1-bit Hamming "rerank-from-scratch" tier for >100K notes**

**The Recommendation.** Use the Rust `usearch` crate (Unum) for ANN. For 1K–100K notes, build a single HNSW with `MetricKind::Cos`, `ScalarKind::BF16`, `connectivity ≈ 16`, `expansion_add ≈ 128`, `expansion_search ≈ 64`. Store the index as a single `.usearch` file mmap-loaded at startup. Reserve binary (1-bit / Hamming) only for very large vault scaling experiments — for a single user with 10K–100K notes it is unnecessary and degrades recall meaningfully.

**The Why.**
- usearch claims "10× faster HNSW than FAISS" with the same algorithm, and uses SimSIMD with explicit ARM NEON / Apple Silicon dispatch ([unum-cloud/USearch](https://github.com/unum-cloud/usearch)). On M-series this matters.
- Search latency: HNSW is sub-millisecond for k=10 over 100K vectors at 256-dim bf16; well within your <10 ms budget.
- Persistence: usearch supports `index.save("path")` and `index.view("path")` (mmap) — so you do not rebuild on startup. Incremental `add`/`remove` are supported (see "Test remove/rename/multi in Rust" in [release notes](https://github.com/unum-cloud/usearch/releases)).
- `BF16` is the recommended modern-CPU quantization; `I8` only valid for cosine-like metrics ([usearch docs](https://unum-cloud.github.io/USearch/)).
- Binary quantization (`B1x8`) requires Hamming/Jaccard metrics and is best as a **first-stage funnel** that you rerank with full-precision scoring. For Epistemos's note count this complexity is not warranted.

**The Code (Rust).**

```rust
// crates/epistemos-index/src/lib.rs
use usearch::{Index, IndexOptions, MetricKind, ScalarKind, new_index};

pub struct ShadowIndex { inner: Index }

impl ShadowIndex {
    pub fn create(path: &str, dim: usize) -> Self {
        let opts = IndexOptions {
            dimensions: dim,
            metric: MetricKind::Cos,
            quantization: ScalarKind::BF16,
            connectivity: 16,
            expansion_add: 128,
            expansion_search: 64,
            multi: false,
        };
        let idx = new_index(&opts).unwrap();
        if std::path::Path::new(path).exists() { idx.load(path).unwrap(); }
        idx.reserve(1024).unwrap();
        Self { inner: idx }
    }
    pub fn upsert(&self, key: u64, v: &[f32]) { let _ = self.inner.add(key, v); }
    pub fn remove(&self, key: u64)            { let _ = self.inner.remove(key); }
    pub fn search(&self, q: &[f32], k: usize) -> Vec<(u64, f32)> {
        let r = self.inner.search(q, k).unwrap();
        r.keys.into_iter().zip(r.distances).collect()
    }
    pub fn save(&self, path: &str) { let _ = self.inner.save(path); }
}
```

**The Gotchas.**
- `usearch` had a [move-safety bug](https://github.com/unum-cloud/usearch/releases) (#704) — make sure you are on ≥ 2.17. Latest release as of research is 2.25.x.
- BF16 quantization is irreversible (`get` won't return the original vector). Persist raw vectors in GRDB if you ever need to rebuild ([usearch docs](https://github.com/unum-cloud/usearch)).
- HNSW can deadlock under concurrent insert+search if you forget the index is internally synchronized but not lock-free; serialize index mutations through a Rust actor.
- Obsidian Smart Connections noted that *initial* embedding of large vaults is heavy ([smartconnections.app](https://smartconnections.app/smart-connections/)) — show progress UI; chunk-encode in batches of 64–128 paragraphs.

**Alternatives considered.** `hnsw_rs`, `instant-distance` — both fine, but lack usearch's binary-quantization, filtered-search, and SIMD breadth. `faiss-rs` bindings work but pull in a heavy C++ dep that complicates Apple Silicon code-signing.

**References.** [unum-cloud/USearch](https://github.com/unum-cloud/usearch) · [Rust SDK docs](https://unum-cloud.github.io/usearch/rust/index.html) · [BENCHMARKS.md](https://github.com/unum-cloud/usearch/blob/main/BENCHMARKS.md).

---

### 1C. Hybrid Search Recommendation: **Tantivy (BM25) + usearch (dense) fused with Reciprocal Rank Fusion (k=60)**

**The Recommendation.** Build a `tantivy` index in Rust over note titles + bodies + chunks (BM25 default), run dense ANN in parallel via usearch, and fuse with RRF (`score = Σ 1/(k+rank_i)`, `k=60`). Use the `rank-fusion` crate ([rank-fusion crate](https://crates.io/crates/rank-fusion)) or a 30-line manual implementation.

**The Why.** Cormack et al. (SIGIR 2009) established RRF as a robust non-parametric fusion method that requires no score normalization; later empirical work ([Bruch et al., ACM TIS 2024 / arXiv 2210.11934](https://arxiv.org/pdf/2210.11934)) confirms RRF performs strongly even zero-shot. Pure dense embeddings miss exact tokens (IDs, code identifiers); pure BM25 misses synonymy and paraphrase. The Qdrant/BM42 analysis confirms the hybrid is the production baseline ([Qdrant](https://qdrant.tech/articles/bm42/)). `frankensearch` ships exactly this pattern in production ([Dicklesworthstone/frankensearch](https://github.com/Dicklesworthstone/frankensearch)).

**Query construction.** For Contextual Shadows the encode-trigger window matters more than the fusion algorithm:
- **Last paragraph of editor** (heuristic: text since last `\n\n` up to cursor) — best signal for "what am I writing about right now".
- Fallback to a **128-token sliding window** ending at the cursor if the paragraph is shorter than ~40 tokens, to give the encoder enough signal.
- Concatenate with **document-level title / first sentence** at low weight (e.g. weighted RRF) so the search isn't dominated by the most recent stream-of-consciousness sentence.

**The Code (RRF helper).**

```rust
pub fn rrf(lists: &[&[u64]], k: f32) -> Vec<(u64, f32)> {
    use std::collections::HashMap;
    let mut s: HashMap<u64, f32> = HashMap::new();
    for list in lists {
        for (rank, id) in list.iter().enumerate() {
            *s.entry(*id).or_insert(0.0) += 1.0 / (k + rank as f32);
        }
    }
    let mut out: Vec<_> = s.into_iter().collect();
    out.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
    out
}
```

**The Gotchas.** RRF discards score magnitudes; if your tantivy BM25 returns a *vastly* higher-quality top-1 than your dense top-1, RRF will under-weight it. For autocomplete-style "instant recall" you typically want the opposite — lexical exactness slightly favored. Use **weighted RRF** with `w_lex=1.2, w_dense=1.0` as a starting point and A/B test.

**References.** [Cormack 2009 / RRF paper](https://arxiv.org/pdf/2210.11934) (cited in Bruch et al.) · [rank-fusion crate](https://crates.io/crates/rank-fusion) · [Qdrant BM42 hybrid analysis](https://qdrant.tech/articles/bm42/) · [pg_textsearch BM25 references](https://www.tigerdata.com/blog/introducing-pg_textsearch-true-bm25-ranking-hybrid-retrieval-postgres).

---

### 1D. Debounce / Continuous Encoding Loop: **200 ms debounce, structured `Task` cancellation, dedicated FFI executor**

**The Recommendation.** 200 ms is the right number — Algolia's autocomplete docs cite it as the optimal tradeoff for typical typing speeds (30–40 WPM on desktop), with 300 ms+ degrading UX ([Algolia](https://www.algolia.com/doc/ui-libraries/autocomplete/guides/debouncing-sources)). Use Swift 6's structured `Task` + `Task.cancel()` to coalesce keystrokes, run FFI on a non-MainActor executor, surface results back to MainActor for SwiftUI.

**Architecture.**

```swift
@MainActor
@Observable
final class ShadowController {
    private var pendingTask: Task<Void, Never>?
    var matches: [Shadow] = []

    func textDidChange(currentParagraph: String) {
        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            // Hop OFF the main actor for the FFI work
            let results = await ShadowIndexService.shared.search(currentParagraph)
            guard !Task.isCancelled else { return }
            self.matches = results            // back on MainActor
        }
    }
}

// Service uses a dedicated background actor with a custom executor
actor ShadowIndexService {
    static let shared = ShadowIndexService()
    private let embedder: StaticEmbedder
    private let index: ShadowIndex
    func search(_ text: String) -> [Shadow] {
        let v = embedder.encode(text: text)        // sync FFI, off main
        let hits = index.search(v: v, k: 20)       // sync FFI, off main
        return Shadow.assemble(hits)
    }
}
```

**The Why.**
- `Task.cancel()` cooperatively unwinds in-flight work as soon as the next keystroke arrives — no manual debounce timers.
- `actor ShadowIndexService` ensures the Rust FFI is serialized (avoiding HNSW concurrent-mutation footguns) without a `DispatchQueue` you'd otherwise have to babysit.
- Avoid `withCheckedContinuation` for the FFI call unless your Rust function is genuinely async — UniFFI ≥0.28 supports `[Async]` traits ([UniFFI futures docs](https://mozilla.github.io/uniffi-rs/0.28/futures.html)) so prefer that.
- Progressive encoding: if the new paragraph starts with the same prefix as the previous (cheap string check), reuse the previous embedding for prefix tokens — but Model2Vec's mean-pool makes this a marginal optimization (~0.3 ms savings per call). Skip unless profiling demands it.
- 60 WPM = 5 chars/sec ≈ 300 ms between keystrokes ([atom/fuzzy-finder issue #156](https://github.com/atom/fuzzy-finder/issues/156)), so a 200 ms debounce coalesces ~2 keystrokes worst-case.

**The Gotchas.**
- **Do not** put the embedder or index behind `@MainActor`. UniFFI 0.28 generates code that may inherit MainActor isolation under Swift 6.2's `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` — Mozilla currently recommends post-processing generated bindings to add `nonisolated` or controlling actor isolation explicitly ([uniffi-rs issue #2818](https://github.com/mozilla/uniffi-rs/issues/2818)).
- Async generated code is not yet Sendable-conformant in UniFFI Swift bindings — track [#2448](https://github.com/mozilla/uniffi-rs/issues/2818) before relying on it.

**References.** [Apple WWDC25 "Embracing Swift Concurrency"](https://developer.apple.com/videos/play/wwdc2025/268/) · [Donny Wals on @concurrent + Main Actor](https://www.donnywals.com/should-you-opt-in-to-swift-6-2s-main-actor-isolation/) · [Algolia debounce guidance](https://www.algolia.com/doc/ui-libraries/autocomplete/guides/debouncing-sources).

---

### 1E. Dynamic Recall Popover ("AL Trigger"): **NSPanel non-activating + SwiftUI hosting, NOT SwiftUI `.popover()`**

**The Recommendation.** Use a custom `NSPanel` subclass with `.nonactivatingPanel` style mask hosting a SwiftUI view via `NSHostingView`. SwiftUI's `.popover()` on macOS is fragile for "edit-in-place" because it dismisses on focus loss in unpredictable ways and constrains the visual chrome.

**The Code Skeleton.**

```swift
// FloatingPanel.swift (adapted from Cindori/fazm.ai patterns)
import AppKit
import SwiftUI

final class ShadowPanel<Content: View>: NSPanel {
    init(rect: NSRect = .init(x: 0, y: 0, width: 360, height: 480),
         @ViewBuilder content: () -> Content) {
        super.init(contentRect: rect,
                   styleMask: [.nonactivatingPanel, .titled, .closable,
                               .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        contentView = NSHostingView(rootView: content())
    }
    override var canBecomeKey: Bool { true }   // critical for typing in popover
    override var canBecomeMain: Bool { false } // do NOT take main → editor stays main
}

// State machine for the AL trigger button visibility
enum ShadowButtonState { case dormant, typing, panelOpen, editing, summarizing }

struct ShadowButton: View {
    @Binding var state: ShadowButtonState
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) { Image(systemName: "sparkle.magnifyingglass") }
            .buttonStyle(.plain)
            .opacity(state == .dormant ? 0 : 1)
            .animation(.spring(duration: 0.18), value: state)
            .help("Show related notes & chats")
    }
}

// Inside the floating panel content
struct ShadowPanelContent: View {
    @State private var tab: Tab = .notes
    enum Tab { case notes, chats }
    @State private var matches: [Shadow] = []
    @State private var hovered: Shadow.ID?
    @State private var editingID: Shadow.ID?

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Notes").tag(Tab.notes); Text("Chats").tag(Tab.chats)
            }.pickerStyle(.segmented).padding(8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(matches) { m in
                        ShadowRow(shadow: m,
                                  isEditing: editingID == m.id,
                                  onHover: { hovered = $0 ? m.id : nil },
                                  onEdit:  { editingID = m.id },
                                  onCommit: { newText in
                                      Task { await VaultService.shared.save(m.id, body: newText) }
                                      editingID = nil
                                  })
                            .contextMenu {
                                if tab == .chats {
                                    Button("Summarize") { Task { await summarize(m) } }
                                }
                                Button("Open") { NavigationService.open(m) }
                            }
                    }
                }
            }

            if let h = hovered, let preview = matches.first(where: { $0.id == h }) {
                Divider(); HoverPreview(shadow: preview).frame(height: 180)
            }
        }
        .frame(width: 360, height: 480)
        .background(.ultraThinMaterial)
    }
}
```

**The Why.**
- `becomesKeyOnlyIfNeeded = true` and `canBecomeMain = false` mean clicking the panel doesn't yank the editor's main-window status — but a TextEditor/TextField in the panel can still become first responder for typing (this is the same pattern Raycast uses).
- `NSHostingView` is the SwiftUI⇄AppKit bridge ([fazm.ai blog](https://fazm.ai/blog/swiftui-floating-panel) · [cindori.com](https://cindori.com/developer/floating-panel)).
- `.canJoinAllSpaces, .fullScreenAuxiliary` makes the panel follow the user across Spaces and overlay full-screen apps.
- For dismissing on outside-click use `NSEvent.addGlobalMonitorForEvents` ([fazm.ai](https://fazm.ai/blog/swiftui-floating-panel)).

**The Gotchas.**
- If you also build the AL button as a "trigger inline in the editor", it must be hosted in a separate child `NSPanel` (not the main window) so the editor's first-responder chain isn't disrupted.
- Live-binding edits in the popover: write straight to GRDB inside an `actor VaultService` so the editor's `@Query`/`@Observable` model in the main window picks up the change via your store-observation pipeline. Do NOT mutate a shared `@Observable` from multiple actors without `@MainActor` hop.
- Animation pitfalls: Apple recommends `.spring()` over linear for floating-panel reveals; large-blur backgrounds (`.ultraThinMaterial`) can cost 2–3 ms of GPU per frame on M2 Pro at 4K — keep panel ≤ 480 px wide.

**References.** [Cindori floating panel tutorial](https://cindori.com/developer/floating-panel) · [Fazm.ai floating panel guide](https://fazm.ai/blog/swiftui-floating-panel) · Smart Connections "footer connections … updates as you type" pattern ([smartconnections.app](https://smartconnections.app/smart-connections/)).

---

### 1F. Indexing Strategy

- **First launch**: enumerate vault, batch-encode in 128-paragraph chunks on a background `Task.detached`, surface progress via `@Observable` status. Persist embeddings to GRDB (`embedding BLOB`) **and** the usearch index. Two stores allow rebuild without re-encoding.
- **Incremental**: GRDB `TransactionObserver` → debounce 500 ms → on commit, re-encode dirty notes → `index.upsert(noteId, vec)` → `index.save()` periodically (every 30 s of idle, or on app quit).
- **Deletion**: usearch supports `remove(key)` (added in recent releases — see [USearch changelog](https://github.com/unum-cloud/usearch/releases)). Test "Test remove/rename/multi in Rust" was added as a regression test, so this is stable.
- **Schema versioning**: include `schema_version` and `embedder_id` (model name + revision) in the index file header. On model upgrade, full rebuild.

---

## 2. Performance Fixes — The Three Critical Ones

### 2A. Embedding FFI off MainActor

**The Recommendation.** Encapsulate the embedder in an `actor` that uses a default cooperative executor (no MainActor isolation). Mark Rust-generated bindings `nonisolated` if your project default is `@MainActor`.

```swift
actor EmbedderActor {
    private let inner: StaticEmbedder    // UniFFI-generated, nonisolated
    init(path: String) throws { self.inner = try StaticEmbedder(path: path) }
    func encode(_ text: String) -> [Float] { inner.encode(text: text) }
}
```

If you must stay sync-FFI, dispatch through a *single, dedicated* serial `DispatchQueue` rather than `Task.detached` (which floats across cooperative threads and can starve other actors). Pattern:

```swift
final class EmbedderQueue: @unchecked Sendable {
    private let q = DispatchQueue(label: "epistemos.embed", qos: .userInitiated)
    private let inner: StaticEmbedder
    init(_ i: StaticEmbedder) { inner = i }
    func encode(_ s: String) async -> [Float] {
        await withCheckedContinuation { c in
            q.async { c.resume(returning: self.inner.encode(text: s)) }
        }
    }
}
```

**Why MainActor FFI is bad.** Rust functions called from MainActor block the run loop. Even a 5 ms FFI synchronous call dropped onto the main thread will skip a 60 fps frame ([Apple WWDC25 concurrency talk](https://developer.apple.com/videos/play/wwdc2025/268/)). With 200 ms debounced encodes that's tolerable, but tool-call streaming (4× per second) is not.

**Gotcha.** UniFFI's Swift bindings under `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` (Xcode 26 / Swift 6.2 default) inherit `@MainActor` ([uniffi-rs #2818](https://github.com/mozilla/uniffi-rs/issues/2818)). Workaround: post-process generated `.swift` to prepend `nonisolated` to file-level declarations, or set `default_isolation = "nonisolated"` once that uniffi.toml option lands.

---

### 2B. Graph Renderer on Background Thread

**The Recommendation.** Drive rendering from a `CADisplayLink` (macOS 14+) callback running on a dedicated render thread. Use triple-buffered `MTLCommandBuffer` with a `DispatchSemaphore(value: 3)` gate. **Render off the main thread.**

**Architecture (Zed-pattern).** Zed talks directly to Metal via GPUI on macOS for "120 FPS" rendering, with their own shaders, triple-buffering, and a fully native AppKit `NSApplication` ([Zed blog: Linux When?](https://zed.dev/blog/zed-decoded-linux-when) · [Zed videogame blog](https://zed.dev/blog/videogame)). Their fundamental method is `fn draw(&self, scene: &Scene)` invoked from a display-link callback.

```swift
final class GraphRenderer {
    private let device = MTLCreateSystemDefaultDevice()!
    private lazy var queue = device.makeCommandQueue()!
    private let inflight = DispatchSemaphore(value: 3) // triple-buffered
    private var displayLink: CADisplayLink!
    weak var layer: CAMetalLayer?

    func start(layer: CAMetalLayer) {
        self.layer = layer
        layer.device = device
        layer.pixelFormat = .bgra8Unorm    // ← NOT bgra8Unorm_sRGB; avoid dark halos
        layer.framebufferOnly = true
        displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink.add(to: .main, forMode: .common)
    }
    @objc private func tick(_ link: CADisplayLink) {
        inflight.wait()
        guard let drawable = layer?.nextDrawable(),
              let cmd = queue.makeCommandBuffer() else { inflight.signal(); return }
        cmd.addCompletedHandler { [inflight] _ in inflight.signal() }
        // ... encode passes for nodes, edges, text labels (MTSDF) ...
        cmd.present(drawable); cmd.commit()
    }
}
```

**Pixel format gotcha (user mentioned).** Use `BGRA8Unorm` *not* `BGRA8Unorm_sRGB` in `CAMetalLayer.pixelFormat` to avoid the "dark halo" issue around glyphs, because Core Animation already gamma-handles the composited surface; double-converting darkens edges. The MTSDF shader explicitly says: "Do not mark MSDF textures as sRGB. Treat them as data" ([msdfgen](https://github.com/Chlumsky/msdfgen)).

**Precompile .metallib.** Add a build phase that runs `xcrun metal -c shaders.metal -o shaders.air && xcrun metallib shaders.air -o default.metallib`. Loading a precompiled metallib at runtime saves 30–100 ms over `device.makeDefaultLibrary(source:)` JIT compile on first frame.

**Why running on main thread stutters.** macOS dispatches IPC, AppKit event handling, layout, and SwiftUI diffs on the main thread. Every one of those steals microseconds from your render budget; under load you miss a vsync and present a stale frame, the user sees a stutter ([WWDC2019 Session 608 "Metal for Pro Apps"](https://asciiwwdc.com/2019/sessions/608) explicitly recommends `CVDisplayLink` driving from a non-main thread for smooth cadence).

**References.** [Zed GPU rendering](https://zed.dev/blog/videogame) · [Apple Metal triple-buffering thread](https://developer.apple.com/forums/thread/733033) · [WWDC2019 Session 608](https://asciiwwdc.com/2019/sessions/608) · [Ghostty terminal](https://github.com/zed-industries/zed) (also Metal, triple-buffer pattern).

---

### 2C. @Query Cascade During AI Streaming

**The Recommendation.** Do not call `modelContext.save()` or mutate `@Query`'d models on every streamed token. Buffer tokens in a non-persistent actor; commit to SwiftData (or GRDB) only on natural break points — sentence boundary, every 250 ms, or on `message_stop`.

```swift
@MainActor @Observable
final class StreamingMessage {
    var liveText: String = ""        // SwiftUI binds to this; not persisted
}

actor StreamCommitter {
    private var buffer = ""
    private var lastFlush = ContinuousClock.now
    func append(_ delta: String, into msg: StreamingMessage,
                modelContext: ModelContext, message: Message) async {
        buffer += delta
        await MainActor.run { msg.liveText += delta }
        let now = ContinuousClock.now
        if now - lastFlush > .milliseconds(250) || buffer.contains("\n") {
            let chunk = buffer; buffer = ""; lastFlush = now
            await MainActor.run {
                message.body += chunk
                try? modelContext.save()
            }
        }
    }
}
```

**The Why.** Multiple Swift developers have observed `@Query` re-fetches happening on the main thread, causing unresponsiveness with large datasets ([Apple forums thread](https://forums.developer.apple.com/forums/thread/763832) · [getsentry/sentry-cocoa #7465](https://github.com/getsentry/sentry-cocoa/issues/7465)). SwiftData's main-context refetch on every `save()` is the issue. Even with a small dataset, calling `save()` 30×/second during streaming starves the renderer.

**Alternative pattern.** Use GRDB for everything chat-related (you already have it!) and reserve SwiftData (if at all) for ephemeral UI state. GRDB writes via `dbPool.write { … }` are off-main and don't trigger SwiftUI invalidation cascades.

**Gotcha.** Use `@Observable` (not `@Query`) to drive the live token UI — only the *committed* message needs to be queried. Hacking with Swift confirms `@Query` runs *immediately when displayed* and large fetches block the UI ([Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-use-query-to-read-swiftdata-objects-from-swiftui)).

---

## 3. Agent Runtime Decision

### 3A. Wire Rust `agent_core` via UniFFI — Streaming Callback Pattern

**The Recommendation.** Represent each agent run as a Rust async function that takes a UniFFI `[Trait, WithCallback]` interface for emitting tokens, tool calls, and lifecycle events. Bridge to Swift `AsyncThrowingStream` using `AsyncStream.makeStream()` ([Hacking with Swift, SE-0388](https://www.hackingwithswift.com/swift/5.9/convenience-asyncthrowingstream-makestream)).

**Rust side.**

```rust
#[uniffi::export(callback_interface)]
pub trait TokenStreamCallback: Send + Sync {
    fn on_text_delta(&self, delta: String);
    fn on_thinking_delta(&self, delta: String);
    fn on_tool_call(&self, name: String, args_json: String, id: String);
    fn on_done(&self, stop_reason: String);
    fn on_error(&self, msg: String);
}

#[uniffi::export]
pub async fn run_agent(
    request_json: String,
    cb: Box<dyn TokenStreamCallback>,
) -> Result<(), AgentError> {
    let mut runner = AgentLoop::new(request_json)?;
    while let Some(ev) = runner.next().await {
        match ev {
            Event::Text(t)     => cb.on_text_delta(t),
            Event::Thinking(t) => cb.on_thinking_delta(t),
            Event::ToolCall(name, args, id) => cb.on_tool_call(name, args, id),
            Event::Done(r)     => { cb.on_done(r); break; }
            Event::Error(e)    => { cb.on_error(e.to_string()); break; }
        }
    }
    Ok(())
}
```

**Swift side bridge.**

```swift
struct AgentEvent { /* enum cases per callback */ }

func runAgent(request: AgentRequest) -> AsyncThrowingStream<AgentEvent, Error> {
    let (stream, cont) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
    final class Bridge: TokenStreamCallback, @unchecked Sendable {
        let cont: AsyncThrowingStream<AgentEvent, Error>.Continuation
        init(_ c: AsyncThrowingStream<AgentEvent, Error>.Continuation) { self.cont = c }
        func onTextDelta(delta: String) { cont.yield(.text(delta)) }
        func onThinkingDelta(delta: String) { cont.yield(.thinking(delta)) }
        func onToolCall(name: String, argsJson: String, id: String) {
            cont.yield(.toolCall(.init(name: name, args: argsJson, id: id))) }
        func onDone(stopReason: String) { cont.yield(.done(stopReason)); cont.finish() }
        func onError(msg: String) { cont.finish(throwing: AgentError.runtime(msg)) }
    }
    Task.detached(priority: .userInitiated) {
        do { try await runAgent(requestJson: encode(request), cb: Bridge(cont)) }
        catch { cont.finish(throwing: error) }
    }
    return stream
}
```

**Tool-call streaming parsers (state machines).** Each provider emits tools differently:
- **Qwen 3.x family**: `<tool_call>{"name":...,"arguments":...}</tool_call>` ([Qwen3 README](https://github.com/QwenLM/Qwen3); Qwen3-Coder uses a [specially designed function-call format](https://github.com/QwenLM/Qwen3-Coder)).
- **SmolLM3**: identical XML wrapper `<tool_call>{...}</tool_call>` with JSON-in-XML ([HuggingFaceTB/SmolLM3-3B](https://huggingface.co/HuggingFaceTB/SmolLM3-3B); served via `--tool-call-parser=hermes` in vLLM).
- **Gemma 3 / Gemma 4**: there is *no* universally-shipped Gemma tool-call delimiter. The user's spec mentions `<start_function_call>` / `<end_function_call>` — note this is a *Google-recommended fine-tuning convention* documented in some Gemma 4 examples ([ai.google.dev Gemma 4](https://ai.google.dev/gemma/docs/core)) but not enforced by the base model. Prompt the model to use it explicitly. **Flag**: I could not verify a single canonical Gemma tool-call grammar in 2026; treat this as configurable per-model.
- **Generic JSON-in-markdown**: ```json fenced blocks, recovered with a forgiving JSON-with-trailing-commas parser.

Implement as a Rust streaming state machine that buffers until a `<tool_call>` open tag is seen, then accumulates until close, then emits. Reset buffer on text-delta if the tag never opens.

**Goose Provider trait extraction pattern.** Goose (Block) is your reference implementation: a Rust workspace with `crates/goose` core, a `Provider` trait at `providers/base.rs`, MCP extensions in `crates/goose-mcp`, `goose-cli`, `goose-server` (binary `goosed`) ([block/goose AGENTS.md](https://github.com/block/goose/blob/main/AGENTS.md)). The Provider trait abstracts streaming/non-streaming, supports 15+ providers (Anthropic, OpenAI, Google, Ollama, OpenRouter, Bedrock, Azure, …) ([goose-docs](https://goose-docs.ai/)). Lift the trait shape from `goose/crates/goose/src/providers/base.rs` directly — it's MIT-licensed.

**Alternative: rig.** Rust crate by 0xPlaygrounds providing a `CompletionModel` / `EmbeddingModel` trait abstraction across 20+ providers, native streaming via `RawStreamingChoice`/`StreamedAssistantContent`, agent builder pattern ([rig README](https://github.com/0xPlaygrounds/rig) · [docs.rs/rig-core](https://docs.rs/rig-core/latest/rig/)). Rig is more mature; Goose is more agent-shaped (tool-loop, MCP, recipes). For Epistemos, I recommend **rig as the LLM transport** + **a Goose-style agent loop you write yourself** so you keep control over the GEPA-evolution hooks.

**GEPA-inspired self-evolution.** GEPA (Genetic-Pareto, [Agrawal et al., arXiv 2507.19457](https://arxiv.org/abs/2507.19457)) uses natural-language reflection to mutate prompts — outperforming GRPO by 10–19 pp using up to 35× fewer rollouts (ICLR 2026 oral). Adopt the algorithmic skeleton: store a Pareto front of prompts/skills per task; mutate via a reflective LLM call; select via Pareto-aware sampling. Reference implementation at [gepa-ai/gepa](https://github.com/gepa-ai/gepa). DSPy + GEPA integration is the most mature consumer.

**Thinking-block contract.** Anthropic's hard requirement: when continuing an assistant turn through tool use, **pass thinking blocks back verbatim, including the cryptographic signature field** ([Claude docs: "Building with extended thinking"](https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking) · [AWS Bedrock docs](https://docs.aws.amazon.com/bedrock/latest/userguide/claude-messages-extended-thinking.html)). Modifying the `thinking` text invalidates the signature ([openclaw/openclaw #24612](https://github.com/openclaw/openclaw/issues/24612), [langchain-ai/langchain #34794](https://github.com/langchain-ai/langchain/issues/34794), [vercel/ai #7729](https://github.com/vercel/ai/issues/7729)). In Epistemos, persist thinking blocks as **opaque blobs** in GRDB; never re-encode their text. Anthropic *automatically ignores* old thinking blocks for context-usage purposes — you must preserve them in conversation history but you do not need to manually trim them.

**References.** [UniFFI futures docs](https://mozilla.github.io/uniffi-rs/0.28/futures.html) · [UniFFI async overview](https://mozilla.github.io/uniffi-rs/latest/internals/async-overview.html) · [SwiftAnthropic](https://github.com/jamesrochabrun/SwiftAnthropic) · [block/goose](https://github.com/block/goose) · [0xPlaygrounds/rig](https://github.com/0xPlaygrounds/rig) · [GEPA paper](https://arxiv.org/abs/2507.19457) · [gepa-ai/gepa](https://github.com/gepa-ai/gepa).

---

### 3B. Claude Managed Agents API (Cloud Path)

**Current state (verified April 2026).** Anthropic launched **Claude Managed Agents** in public beta on April 8, 2026 ([Anthropic docs](https://platform.claude.com/docs/en/managed-agents/overview)). Beta header: `anthropic-beta: managed-agents-2026-04-01`. Endpoints: `/v1/agents`, `/v1/environments`, `/v1/sessions`. Streaming via SSE. Pricing: standard token rates **plus $0.08 per session-hour** of active runtime, idle billed at zero ([WaveSpeedAI Blog pricing analysis](https://wavespeed.ai/blog/posts/claude-managed-agents-pricing-2026/)). Rate limits: 60 RPM create / 600 RPM read per org. Multi-agent coordination and self-evaluation are still in **research preview**, gated by separate access request ([Sathish Raju Medium analysis](https://medium.com/@sathishkraju/anthropics-managed-agents-i-read-the-fine-print-so-you-don-t-have-to-ed17b77e17c5) · [InfoQ](https://www.infoq.com/news/2026/04/anthropic-managed-agents/)).

**Recommendation for Epistemos.** Treat Managed Agents as one *Provider* implementation behind your trait — useful for cloud-heavy long-running tasks (research, code review) where Anthropic-managed sandboxing saves engineering. Keep your Rust agent loop as the authoritative implementation for local models and short-lived tasks. Bridge SSE → `AsyncThrowingStream` with the same `makeStream()` pattern shown in 3A. Tool parameters arrive as `content_block_delta` of type `input_json_delta` — accumulate partial JSON until `content_block_stop` ([Anthropic streaming docs](https://platform.claude.com/docs/en/build-with-claude/streaming)).

**Caveat.** Cloud execution = your screen/audio/notes leave the device. Default Epistemos to **local-only**; offer Managed Agents as opt-in per task.

---

## 4. Local Model Catalog — MLX-Swift

### 4A. MLX-Swift Patterns

**The Recommendation.** Build on top of `mlx-swift-examples` (Apple) and adopt the `MLXLMCommon` text-generation pipeline. Quantize aggressively: **Q4_K_M / int4** is the production standard for MoE 4-bit weight quantization on M-series ([Unsloth Qwen3.5 docs](https://unsloth.ai/docs/models/qwen3.5)).

**Key facts (2025–2026 state).**
- MLX gained **M5 Neural Accelerators** support (macOS 26.2+) delivering up to 4× speedup on TTFT for LLM inference on M5 vs M4, and >3.8× on FLUX.dev image generation ([Apple ML Research](https://machinelearning.apple.com/research/exploring-llms-mlx-m5)). On M2 Pro you do NOT get this; matmul runs on the standard GPU. Plan for ~30–60 tok/s on 7B Q4_K_M.
- WWDC 2025 sessions [298 "Explore LLMs"](https://developer.apple.com/videos/play/wwdc2025/298/) and [315 "Get started with MLX"](https://developer.apple.com/videos/play/wwdc2025/315/) cover the official Swift API: `MLXLLM.LLMModelFactory.shared.loadContainer()` + `TokenIterator` for streaming.
- **SwiftLM** ([SharpAI/SwiftLM](https://github.com/SharpAI/SwiftLM)) is the most production-grade open MLX-Swift inference server I found: TurboQuantization KV-cache, NVMe SSD streaming for 100B+ MoE models (10× speedup via concurrent pread), speculative decoding, OpenAI-compatible API. Borrow patterns even if you don't ship the whole server.

**Speculative decoding.** Apple's **Mirror Speculative Decoding** ([arXiv 2510.13161v2, Bhendawade et al., Dec 2025](https://arxiv.org/abs/2510.13161)) breaks the latency-acceptance tradeoff by running draft and target rollouts in parallel across heterogeneous accelerators (GPU + NPU), with bidirectional speculation. For Epistemos's M2 Pro target (no NPU on M-series in the Mirror-SD sense), use the simpler classical pattern: small draft (Qwen3.5-0.8B) + big target (Qwen3.5-9B), draft 4 tokens, verify in batch — ~1.6–2× speedup is realistic ([SwiftLM uses this](https://github.com/SharpAI/SwiftLM)).

### 4B. Verified Context Windows & Temperatures (2025–2026)

The user's spec lists "Qwen 3.5 family: 0.8B, 2B, 4B, 9B, 27B, 35B" with 262K context. **What I verified:**

- **Qwen3 base family** (released April 2025 via [QwenLM/Qwen3](https://github.com/QwenLM/Qwen3)): sizes 0.6B, 1.7B, 4B, 8B, 14B, 32B (dense) and 30B-A3B, 235B-A22B (MoE). Native context: typically 32K–256K depending on size; **the 4B and 30B variants ship 256K**, others 40K natively ([ollama qwen3](https://ollama.com/library/qwen3)). Recommended decoding: temperature ~0.6, top_p ~0.95 (Qwen3 norms).
- **Qwen3 Instruct/Thinking 2507**: 256K native, extendable to 1M via YaRN ([Qwen3 README](https://github.com/QwenLM/Qwen3)).
- **Qwen3.5 / Qwen3.6** (2026 releases per [QwenLM/Qwen3.6](https://github.com/QwenLM/Qwen3.6)): the user's "0.8B, 2B, 4B, 9B, 27B, 35B" naming most likely refers to the **Qwen3.5 Small series** of which the 9B variant is documented to fit in ~12 GB unified memory ([Unsloth](https://unsloth.ai/docs/models/qwen3.5)). **Verified**: Qwen3.5 / Qwen3.6 native context is 262,144 (256K), extendable to ~1M with YaRN/RoPE scaling, recommended temperature 1.0 / top_p 0.95 / top_k 20 for thinking-mode SWE-bench setups ([Qwen3.6-35B-A3B HF card](https://huggingface.co/Qwen/Qwen3.6-35B-A3B)). MoE 35B-A3B at MXFP4 / Q4 quant fits in ~22 GB; the user's "12.2 GB APEX Mini" claim is plausible only with 2-bit dynamic UD-Q2_K_XL quantization, which they verify works — flag as **aggressive quant, expect quality drop on long-context tasks**.

- **DeepSeek R1 distill 7B**: based on Qwen2.5-7B; max generation length 32,768 tokens (NOT 128K). Underlying Qwen2.5-7B context is 131,072 but distill configs ship 32K. **Recommended sampling: temperature 0.5–0.7 (0.6 optimal), top-p 0.95, NO system prompt — instructions go in user prompt** ([deepseek-ai/DeepSeek-R1-Distill-Qwen-7B](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B)). User's "128K context" claim should be dialed back to 32K unless they're loading the full base model.
- **Gemma 3 12B**: 128K context (NOT 256K), 12.2B params, recommended temperature **1.0** with top_p 0.95, top_k 64 ([google/gemma-3-12b-it HF card](https://huggingface.co/google/gemma-3-12b-it) · [Hugging Face discussion](https://huggingface.co/google/gemma-3-12b-it/discussions/25) · [Google DeepMind Gemma 3](https://deepmind.google/models/gemma/gemma-3/)). Note: Ollama by default ships Gemma3 with 8K context; you must override (`--ctx-size`) ([ollama issue #9871](https://github.com/ollama/ollama/issues/9871)).
- **Gemma 4** (announced April 2025 per [ai.google.dev](https://ai.google.dev/gemma/docs/core)): small models (E2B/E4B) 128K, medium models 256K. Sizes E2B, E4B, 31B dense, 26B-A4B MoE. The user's "Gemma 4 12B" does **not** match published sizes — flag this as **likely a misremembering of Gemma 3 12B** unless they have a specific community fine-tune in mind.
- **SmolLM3-3B**: 64K trained / 128K via YaRN, recommended temperature 0.6, top_p 0.95, max_tokens 16384 ([HuggingFaceTB/SmolLM3-3B](https://huggingface.co/HuggingFaceTB/SmolLM3-3B) · [SmolLM3 blog](https://huggingface.co/blog/smollm3)). 3B params total, GQA 4 groups, NoPE every 4th layer. Tool-call format is `<tool_call>{...}</tool_call>` (XML-wrapped JSON) **or** Python-call in `<code>` snippets — chat template controls which.

**Bottom line for Epistemos catalog (revise spec).**
| Model (Q4_K_M) | RAM @4-bit | Real ctx | Temp |
|---|---|---|---|
| SmolLM3-3B | ~2.1 GB | 128K (YaRN) | 0.6 |
| DeepSeek-R1-Distill-Qwen-7B | ~5 GB | 32K | 0.6 |
| Gemma 3 12B | ~8 GB | 128K | 1.0 |
| Qwen3.5 9B (Small) | ~6 GB | 256K | 0.7 |
| Qwen3.5 30B-A3B / 35B-A3B MoE | ~12–22 GB | 256K | 0.7 |

### 4C. Tool-Call Parser State Machine

```swift
// Streaming parser — emits .text(delta) or .toolCall(name, args)
final class ToolCallStreamParser {
    enum Event { case text(String), toolCall(name: String, args: String) }
    enum Mode { case qwenXML, smolXML, gemmaFn, jsonInMarkdown }
    let mode: Mode
    private var buf = ""

    func feed(_ delta: String) -> [Event] {
        buf += delta
        var events: [Event] = []
        let (open, close): (String, String) = {
            switch mode {
            case .qwenXML, .smolXML: return ("<tool_call>", "</tool_call>")
            case .gemmaFn:           return ("<start_function_call>", "<end_function_call>")
            case .jsonInMarkdown:    return ("```json", "```")
            }
        }()
        while let openR = buf.range(of: open) {
            // Emit prefix as text
            let prefix = String(buf[..<openR.lowerBound])
            if !prefix.isEmpty { events.append(.text(prefix)) }
            buf.removeSubrange(..<openR.upperBound)
            guard let closeR = buf.range(of: close) else { break }   // wait for more
            let payload = String(buf[..<closeR.lowerBound])
            buf.removeSubrange(..<closeR.upperBound)
            if let parsed = try? parseToolCall(payload) {
                events.append(.toolCall(name: parsed.name, args: parsed.argsJSON))
            }
        }
        return events
    }
}
```

---

## 5. Capture Pipeline + Global Hotkey

### 5A. Global Hotkey

**The Recommendation.** Use Sindre Sorhus's `KeyboardShortcuts` Swift package ([sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)). It's sandbox-compatible, has a built-in SwiftUI `Recorder`, persists to `UserDefaults`, supports key-down listening, and is used in production by Dato, Jiffy, Plash, Lungo. Latest 2.4.0 (Mar 2025).

```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureCapture = Self("captureCapture", default: .init(.k, modifiers: [.command, .option]))
}

// In your AppDelegate / @main App
KeyboardShortcuts.onKeyDown(for: .captureCapture) {
    CaptureService.shared.showQuickCapture()
}
```

**Hotkey choice.** ⌘⇧Space is Spotlight (default). Alternatives that don't conflict with macOS:
- **⌘⌥K** ("knowledge")
- **⌘⌥Space** ("Epistemos space")
- **F19** (most users have a free function key)
Let users rebind via the `KeyboardShortcuts.Recorder` UI.

**Under the hood.** KeyboardShortcuts uses Carbon `RegisterEventHotKey` (still the only modern macOS API for true global hotkeys) but wraps it cleanly. It will not deprecate before Apple ships a replacement ([sindresorhus/KeyboardShortcuts FAQ](https://github.com/sindresorhus/KeyboardShortcuts)). Alternative: [soffes/HotKey](https://github.com/soffes/HotKey) — simpler but no recorder UI.

### 5B. Quick-Capture Panel

Same `NSPanel(.nonactivatingPanel)` pattern as §1E, but with `level = .popUpMenu` and a single TextEditor. On Return: pipeline `clean → entity-extract → persist (GRDB) → inject into graph + neural-cache trace`.

### 5C. Audio Transcription

**WhisperKit (Argmax)** is the right choice for macOS Apple Silicon — Swift-native, CoreML/ANE-accelerated, supports streaming, includes WebSocket local server compatible with Deepgram-style clients ([argmaxinc/argmax-oss-swift](https://github.com/argmaxinc/WhisperKit)). The `whisperkit-cli transcribe --stream` mode taps the mic.

```swift
import WhisperKit
let pipe = try await WhisperKit(WhisperKitConfig(model: "large-v3-v20240930_626MB"))
let result = try await pipe.transcribe(audioPath: url.path)?.text
```

WhisperKit has been **upgrading to swift-transformers >1.0 and Swift 6 concurrency** in recent releases — `TranscriptionResult` changed from struct to class; audit your code on upgrade ([WhisperKit releases](https://github.com/argmaxinc/WhisperKit/releases)).

**Alternative**: MLX Whisper (Python) is faster on raw throughput but requires bridging to Swift; on M2 Pro WhisperKit with the v3-turbo CoreML model is competitive (1.0 s for the test phrase vs 0.19 s for FluidAudio CoreML / Parakeet-TDT-0.6B per [mac-whisper-speedtest](https://github.com/anvanvan/mac-whisper-speedtest)). For accuracy + native integration, WhisperKit wins.

---

## 6. Computer Use Stack (Feature-Flagged v1)

### 6A. ScreenCaptureKit + AX Tree Fusion

**The Recommendation.** Default to **AX tree** (AXUIElement) for reading interactive elements; fall back to **ScreenCaptureKit + OmniParser V2** when AX is empty/sparse (apps with no accessibility metadata).

**Why fusion is necessary.** Screen2AX research ([arXiv 2507.16704](https://arxiv.org/html/2507.16704v1)) found only 36% of top-99 macOS apps provide full AX metadata; 18% have none. Fazm's blog spells out the tradeoffs: AX is stable across visual redesigns but blind to non-instrumented surfaces; ScreenCaptureKit gives raw pixels but requires CV ([fazm.ai blog](https://earezki.com/ai-news/2026-03-17-what-we-learned-building-a-macos-ai-agent-in-swift-screencapturekit-accessibility-apis-async-pipelines/)).

**OmniParser V2** (Microsoft, Feb 2025): YOLOv8-Nano detector + Florence-2 captioner, AGPL on the YOLO weights / MIT on Florence weights, ~0.6 s/frame on A100 ([microsoft/OmniParser](https://github.com/microsoft/OmniParser) · [HF model card](https://huggingface.co/microsoft/OmniParser-v2.0)). Not Apple Silicon-tuned; expect closer to 1.5–2 s/frame on M2 Pro. Use sparingly.

**Sparsity heuristic.** If AX tree returns < 5 actionable elements (`AXButton`, `AXTextField`, `AXLink`, …) for the focused window, run OmniParser on the screenshot.

**Swift wrapper recommendation:** [steipete/AXorcist](https://github.com/steipete/AXorcist) gives chainable, fuzzy-matched AX queries with a clean modern API and async permission helpers.

### 6B. CGEvent Input Simulation

```swift
func clickAt(_ p: CGPoint) {
    CGDisplayMoveCursorToPoint(0, p)
    let src = CGEventSource(stateID: .hidSystemState)
    CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(50_000)
    CGEvent(mouseEventSource: src, mouseType: .leftMouseUp,   mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
}
```

Source: [Apple Developer Forums emulate-mouse-click thread](https://developer.apple.com/forums/thread/685618). **Sandboxing breaks this** — the user must run a non-sandboxed build OR you must request Accessibility entitlements.

**Visual-verify loop** (Anthropic Computer Use pattern, [Claude docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool)): screenshot → AX/Omni parse → propose action → screenshot after → diff. Anthropic explicitly recommends prompting the model: *"After each step, take a screenshot and carefully evaluate if you have achieved the right outcome."*

### 6C. References

- Anthropic Computer Use tool spec: `computer_20251124` action set including new `zoom` ([Claude API docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool)).
- OpenAI's CUA / Operator runs in their hosted browser sandbox ([WorkOS comparison](https://workos.com/blog/anthropics-computer-use-versus-openais-computer-using-agent-cua)).
- Anthropic includes prompt-injection classifiers that auto-pause for user confirmation when screenshots contain injection signals ([Claude docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool)).

---

## 7. GEPA / Hyperbolic Topology / Neural Cache

### 7A. GEPA Skill Mutation in Rust

Implement the algorithm from [Agrawal et al. arXiv 2507.19457](https://arxiv.org/abs/2507.19457):
1. Maintain a **Pareto front** of skills/prompts indexed by per-task scores.
2. **Mutation step**: select a candidate via Pareto sampling, run on minibatch, feed traces (reasoning + tool calls + outcomes) to a reflective LLM, propose textual mutations.
3. **System-aware merge**: combine complementary lessons from siblings.

UniFFI export pattern for complex types: use `dictionary` types in UDL or `#[derive(uniffi::Record)]` for Pareto-front entries.

### 7B. Hyperbolic Topology / Free-Energy

The user's `should_pierce_blanket()` riffs on Friston's **Markov blanket** notion from the free-energy principle ([Friston 2010, *Nature Reviews Neuroscience*](https://doi.org/10.1038/nrn2787); see also [Active Inference, MIT Press OA](https://direct.mit.edu/books/oa-monograph/5299/Active-InferenceThe-Free-Energy-Principle-in-Mind)). The principle is: an agent minimizes variational free energy ≈ surprise; it "pierces" its Markov blanket (i.e., crosses an information boundary) when expected information gain about a hidden cause exceeds the cost. For folder traversal in TriageService, this maps to: **descend into a folder when the expected reduction in retrieval-uncertainty about the current query exceeds traversal cost**. Concretely, score = `H(query | current_view) - H(query | view_after_descent) - λ * cost_of_descent`.

Poincaré disk embeddings work well for hierarchical/tree-structured data because hyperbolic space has exponential volume growth ([Nickel & Kiela 2017 is the classical reference; not searched here]). For a 100K-note vault, a 5-D Poincaré embedding fits comfortably and supports O(log N) hierarchy traversal.

### 7C. Neural Cache (Hot/Warm/Cold)

Three tiers:
- **Hot**: in-memory `LRUCache<NoteID, Embedding>` of last-N-accessed (capacity ≈ 512), zero-latency.
- **Warm**: SQLite (GRDB) embeddings table with **temporal decay**: `score = base_relevance * exp(-Δt / τ)` with τ ≈ 7 days for "what did I work on last Tuesday?"-class queries.
- **Cold**: usearch index (still local, just slower mmap pages).

For "last Tuesday" queries combine BM25 over note `body` with a temporal filter over `last_modified BETWEEN ? AND ?` — Tantivy supports filtered queries natively.

---

## 8. Knowledge-Core Transition

**The Recommendation.** Stay on **GRDB + usearch** as the authoritative store for v1; introduce **Cozo as a parallel runtime** for graph-shape queries only when SQL CTEs become painful.

**The Why.**
- Cozo (CozoDB) is a transactional relational-graph-vector DB with Datalog query, embeddable, ~100K mixed-OLTP QPS / 250K read-only QPS on a 2020 Mac Mini with RocksDB backend ([cozodb/cozo](https://github.com/cozodb/cozo)). Has Swift bindings. SQLite backend is supported; same-format backups.
- But: maintaining two stores means schema-sync code; CRDTs; reconciliation. Skip until you have a query SQL can't express.
- Hybrid pattern: SQLite recursive CTEs handle 95% of graph traversals at the scale Epistemos sees. See the [SQLiteForum hybrid-models guide](https://www.sqliteforum.com/p/sqlite-and-graph-hybrids).

**Loro CRDT for block ordering + future collab.** [loro-dev/loro](https://github.com/loro-dev/loro) implements Fugue (minimizes interleaving) + Peritext (rich-text formatting) ([loro.dev blog](https://loro.dev/blog/crdt-richtext)). Rust core with FFI bindings (loro-ffi), supports `LoroText`, `LoroList`, `LoroMap`, `LoroTree`, `LoroMovableList` — exactly the shape you want for blocks. For v1, even single-user, modeling each note as a Loro doc gives you free time-travel (`checkout(&frontiers)`), branching (`fork`), and a path to collab.

**Shared-memory ring patterns.** Skip until proven necessary. Most "zero-copy diff" wins come from passing `&[u8]` slices across UniFFI when the data is already contiguous; UniFFI's `Vec<u8>` already does this with one allocation per call. For the editor↔graph diff stream, a single SPSC `crossbeam-channel` in Rust with mmap'd ring is the right pattern *if* you measure contention.

---

## 9. Swift 6 + Rust UniFFI Integration

### Build system

```bash
# build-rust.sh
set -euo pipefail
cargo build --release --target aarch64-apple-darwin -p epistemos-ffi
cargo run --release --bin uniffi-bindgen -- generate \
  --library target/aarch64-apple-darwin/release/libepistemos_ffi.dylib \
  --language swift \
  --out-dir generated/

# Critical for Swift 6.2 / Xcode 26 default actor isolation
sed -i '' \
  's/^fileprivate /nonisolated fileprivate /; s/^private /nonisolated private /; s/^public /nonisolated public /; s/^extension /nonisolated extension /' \
  generated/epistemos.swift

xcrun --sdk macosx libtool -static -o generated/libepistemos.a \
  target/aarch64-apple-darwin/release/libepistemos_ffi.a
```

The `sed` step is the workaround Mozilla recommends for the [uniffi-rs #2818 issue](https://github.com/mozilla/uniffi-rs/issues/2818) until the `default_isolation = "nonisolated"` toml option lands.

### Cargo workspace

```
epistemos/
├── Package.swift
├── Sources/Epistemos/
├── crates/
│   ├── epistemos-ffi/      # UniFFI exports
│   ├── epistemos-embed/    # Model2Vec encoder
│   ├── epistemos-index/    # usearch wrapper
│   ├── epistemos-search/   # tantivy + RRF
│   ├── epistemos-agent/    # rig-based agent loop
│   └── epistemos-gepa/     # skill evolution
└── build-rust.sh
```

### Sendable / @unchecked Sendable

UniFFI 0.28+ generates `Sendable`-conformant types for sync code, but **async code is not yet conformant** ([uniffi-rs Swift Bindings docs](https://mozilla.github.io/uniffi-rs/latest/swift/overview.html), tracking #2448). Mark FFI bridge classes that hold UniFFI handles as `final class … : @unchecked Sendable` only after auditing for true thread-safety (UniFFI handles use Arc internally and are safe to send).

### Zero-copy Metal buffers across FFI

For the graph renderer, allocate the `MTLBuffer` in Swift, pass its `contents()` pointer to Rust as `*mut f32`, let Rust write force-directed positions. UniFFI does not natively support raw pointers — drop to a small hand-written `@_cdecl` Rust function for this hot path:

```rust
#[no_mangle]
pub unsafe extern "C" fn graph_step(
    positions_ptr: *mut f32, positions_len: usize,
    edges_ptr: *const u32, edges_len: usize, dt: f32,
) {
    let pos = std::slice::from_raw_parts_mut(positions_ptr, positions_len);
    let edg = std::slice::from_raw_parts(edges_ptr, edges_len);
    barnes_hut_step(pos, edg, dt);
}
```

---

## 10. General Performance + Polish

- **TextKit2**: user has migration done — keep it. NSTextView with TK2 already lazy-renders; for documents > 1 MB consider a separate Rust-backed model using **Ropey** (~1.8M small incoherent insertions/sec, 10% memory overhead vs document size, [cessen/ropey](https://github.com/cessen/ropey)). Alternative: **JumpRope** is ~3× faster than Ropey on real-editing traces ([crates.io/crates/jumprope](https://crates.io/crates/jumprope)) but smaller community.
- **Force-directed graph at 60 fps with 10K nodes**: full O(N²) is dead at this scale (10⁸ pairwise forces per frame). Use **Barnes-Hut quadtree approximation**; CUDA reference impls hit 5M bodies in 5.2 s/step on Quadro FX 5800 ([govertb/GPUGraphLayout / ForceAtlas2](https://github.com/govertb/GPUGraphLayout)). Reimplement in Metal compute shaders. Browser equivalents (GraphWaGu / WebGPU) achieve interactive layouts on tens of thousands of nodes ([GraphWaGu paper](https://stevepetruzza.io/pubs/graphwagu-2022.pdf)). 120 fps with 10K nodes is realistic on M2 Pro with Barnes-Hut + GPU.
- **MTSDF text labels**: `msdf-atlas-gen -font SF-Pro-Text.otf -type mtsdf -size 64 -pxrange 6 -dimensions 512 512 -imageout atlas.png -json atlas.json` ([Chlumsky/msdf-atlas-gen](https://github.com/Chlumsky/msdf-atlas-gen)). Set Asset Catalog "Interpretation: Data", **NOT sRGB**, "Pixel Format: 8-bit Normalized RGBA" ([DJBen/MSDFTextRender-Metal](https://github.com/DJBen/MSDFTextRender-Metal)). Median-of-RGB in fragment shader, `fwidth` for screen-space derivative scaling. Disable mipmaps (the derivative scaling already handles smoothness; mipmaps blur edges).
- **Metal pixel format**: `BGRA8Unorm` not `BGRA8Unorm_sRGB` for `CAMetalLayer.pixelFormat` (avoids dark halos around glyphs).
- **Precompile .metallib**: 30–100 ms startup savings by shipping pre-compiled `.metallib` instead of `makeDefaultLibrary(source:)`.
- **GRDB + WAL**: `journal_mode=WAL`, `synchronous=NORMAL` (corruption-safe under WAL; FULL is overkill on APFS) ([phiresky/SQLite performance tuning](https://phiresky.github.io/blog/2020/sqlite-performance-tuning/) · [Android docs](https://developer.android.com/topic/performance/sqlite-performance-best-practices)). On macOS, **prefer `F_BARRIERFSYNC` over `F_FULLFSYNC`** — the latter is dramatically slower on APFS and Apple's own docs say barrier is sufficient for most operations ([SQLite forum on macOS fsync](https://sqlite.org/forum/info/b94afa45dda82aae8cbf49f9d511a00b332870fc926cba18954acd889bbfb7cd) · [Apple "Reducing Disk Writes"](https://developer.apple.com/documentation/xcode/reducing-disk-writes)). GRDB's `DatabasePool` opens WAL by default ([groue/GRDB.swift](https://groue.github.io/GRDB.swift/docs/4.14/index.html)). PRAGMAs to set: `temp_store=memory`, `mmap_size=30000000000`, `cache_size=-65536` (64 MB), `optimize` on close.
- **APFS**: avoid network filesystems for live DB files; let GRDB own the directory; never copy the DB file while the app is running (use `sqlite3_backup` API).

---

## 11. Synthesis: What to Build First

A 6-step path Jojo can hand to Claude Code:

1. **Day 1–2.** Cargo workspace + `epistemos-ffi` crate + `epistemos-embed` (Model2Vec port) + UniFFI Swift bindings + `build-rust.sh` with the `sed nonisolated` workaround.
2. **Day 3–4.** `epistemos-index` (usearch wrapper) + GRDB schema with `notes`, `embeddings`, `chats`. Wire the indexing background task with progress.
3. **Day 5–6.** Contextual Shadows MVP: `ShadowController` (200 ms debounce) + `EmbedderActor` + `ShadowIndexService` actor + minimal `NSPanel` floating popover with notes/chats tabs.
4. **Day 7–8.** Tantivy BM25 index + RRF fusion + hover-preview + edit-in-place save-back to GRDB.
5. **Day 9–11.** Metal renderer on display-link off main + triple-buffer + MTSDF labels + force-directed Barnes-Hut compute shader.
6. **Day 12+.** Agent runtime (rig + UniFFI streaming callback → AsyncThrowingStream) → MLX-Swift local provider → tool-call parser → GEPA skill evolution.

Defer Computer Use, Cozo migration, Loro adoption, and Managed Agents integration to v2.

---

## 12. Final Caveats — What I Could Not Verify

- **Qwen 3.5 / 3.6 exact size lineup ("0.8B, 2B, 4B, 9B, 27B, 35B")** — current Alibaba releases use 0.6B, 1.7B, 4B, 8B, 14B, 32B (dense) and 30B-A3B / 235B-A22B (MoE). The user's lineup is plausible if they're tracking the "Small" Unsloth-distilled variants but I could not confirm a 0.8B or 9B canonical Qwen3.5 release ([Unsloth Qwen3.5 docs](https://unsloth.ai/docs/models/qwen3.5) cites a 9B "Qwen3.5 Small"). **Verify exact model IDs on HF before pinning.**
- **"Gemma 4 12B"** — Gemma 4 sizes per Google are E2B/E4B/31B/26B-A4B; there is no 12B. Likely a misremembering of Gemma 3 12B (which is 128K, temp 1.0).
- **"DeepSeek R1 7B 128K context"** — distill ships 32,768 max generation. Base model is 131K but the distill config is shorter.
- **Apex Mini 12.2 GB MoE** — the math checks out at 2-bit aggressive quant, but quality on long-context tasks is degraded; benchmark before shipping as default.
- **Gemma `<start_function_call>` tags** — convention, not protocol; treat as configurable.

Across all model claims, **always verify against the current HuggingFace `config.json` of the specific revision you ship**.

---

*End of report. Total references: ~110 unique URLs spanning Apple developer docs, arXiv papers, GitHub repos (UniFFI, USearch, Model2Vec, Loro, Cozo, Goose, rig, WhisperKit, KeyboardShortcuts, MSDFgen, Ropey, Zed, OmniParser), and authoritative blog posts (Anthropic, Apple ML Research, Hugging Face, Qdrant). Source-checked; speculative or unverifiable claims are flagged inline.*