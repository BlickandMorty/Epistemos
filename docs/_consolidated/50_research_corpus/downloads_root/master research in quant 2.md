# Building Epistemos: a research blueprint for a world-class PKM application

**Epistemos sits at the intersection of the most important trends in developer tools: local-first AI inference, semantic knowledge retrieval, and native performance on Apple Silicon.** The research across seven domains reveals a clear pattern: billion-dollar tools succeed by delivering visceral speed, building extensible platforms (not features), and timing a paradigm shift perfectly. Epistemos has the technical foundations to exploit all three. This report synthesizes findings from product strategy analysis, academic research, systems engineering, ML inference benchmarks, UX psychology, search architecture, and go-to-market playbooks into a unified blueprint.

The core strategic insight: **the tools-for-thought space is undergoing an LLM-driven paradigm shift** from manual organization to AI-augmented synthesis. Gordon Brander (Subconscious founder, which shut down in May 2024) captured it precisely: "If I'm looking to amplify my intelligence today, what am I going to reach for? Probably Claude." The winner in this space will be the tool that makes personal knowledge *intelligent* — not just organized — while running locally, respecting privacy, and feeling impossibly fast.

---

## What separates billion-dollar tools from $10M tools

The gap between Notion ($100B valuation, September 2025) and Roam Research (~$200M peak, stalled) illustrates the most critical lesson in developer tools: **platforms beat features**. Notion built a composable block architecture where everything — text, databases, embeds, calendars — is a block that composes with other blocks. Roam built bidirectional linking, a feature. Notion now serves 100M+ users across 50% of the Fortune 500; Roam has 11 employees and minimal updates.

Five specific patterns separate transcendent tools from good ones:

- **Speed as identity.** Linear's custom sync engine (local IndexedDB → async sync → server) eliminates perceived latency entirely. Raycast's sub-100ms launcher responses. Cursor's tab predictions feel instantaneous. **Linear spent $35K total on marketing** to reach a $1.25B valuation because the speed delta versus Jira is visceral — users become evangelists. Linear has been profitable since 2021, just two years after founding, on roughly $100M revenue.
- **Extensibility as moat.** Obsidian's 2,700+ community plugins transform a markdown editor into anything: Kanban boards, spaced repetition, calendar views, AI integration. This lets an 18-person bootstrapped team serve infinite use cases. Raycast's 1,500+ open-source extensions create the same effect. Roam built zero extensibility — a direct contributor to stagnation.
- **PLG purity at scale.** Cursor reached $100M ARR with exactly $0 in marketing spend and a 36% free-to-paid conversion rate (industry average: 2–5%). From founding in 2022 by four MIT graduates to $500M ARR by May 2025, Cursor is the fastest-growing SaaS company ever recorded, running on ~40–60 employees. The lesson: if the product is transcendent, marketing is unnecessary.
- **The multiplayer gate.** Notion built real-time collaboration as core DNA — this is why it reached $100B. Obsidian deliberately chose personal-use only, capping growth but preserving identity. Roam offered only a public/private toggle. For billion-dollar scale, collaboration is not optional, but it must come *after* the single-player experience is transcendent.
- **AI as core versus AI as feature.** Cursor proves that AI-native products achieve unprecedented growth when timing is right. Notion uses AI to enhance existing value. Rewind.ai's pivot from local screen recording to a cloud-based AI pendant wearable (and eventual $610M Meta acquisition) shows that pivoting to AI without product-market fit is dangerous.

DevonThink offers a counterpoint worth studying: 23 years of sustainable operation with ~6 employees, zero VC funding, and one-time purchases at $99–$199. It proves you don't need unicorn status to build a great business serving professionals extraordinarily well.

## The academic frontier has shifted from structure to intelligence

The CHI 2025 "Tools for Thought" Workshop in Yokohama, co-organized by Microsoft Research, Harvard, CMU, and Stanford, marks the defining academic event of this period. Fifty-six researchers produced 34 papers mapping three research areas: understanding AI's impact on cognition, protecting cognition from AI dependency, and augmenting cognition with AI. The key empirical finding is sobering: **users self-report reduced critical thinking effort when using generative AI**, with confidence in AI inversely related to critical engagement.

Six design patterns emerged from the workshop for AI-augmented cognition. The most important for Epistemos is **provoking thinking through challenge** — AI as Socratic interlocutor rather than answer machine. Microsoft's "ExtendAI" pattern (user reasons first, AI augments) outperformed "RecommendAI" (AI decides) for financial decisions in controlled experiments. This has direct implications: Epistemos should default to extending user reasoning, not replacing it.

On the implementation frontier, several innovations are ready for production. **NoTeeline** (September 2024) demonstrates LLM-enhanced micronotes where users write minimal fragments and an LLM expands them to full notes matching the user's writing style, achieving 93.2% factual correctness with 47% less text written. **LECTOR** (2025) pushes spaced repetition forward by using LLMs to assess semantic similarity between concepts for confusion-aware scheduling, reaching 90.2% success rate versus 88.4% for prior state-of-the-art. A 2024 HSE University study provides the first controlled validation that combining Zettelkasten methodology with spaced repetition significantly improves learning outcomes.

The Knowledge Graph + LLM integration paradigm (GraphRAG) is now dominant. Microsoft's GraphRAG achieves **72–83% comprehensiveness versus traditional RAG** and 3.4x accuracy improvement on enterprise benchmarks. For personal scale, the recommended approach is lightweight: extract entities via NER during indexing, store relationships in SQLite (nodes + edges), use recursive CTEs for graph traversal, and combine graph-retrieved chunks with vector/FTS results via Reciprocal Rank Fusion.

Among emerging tools, **Tana's supertag system** (typed objects with AI auto-classification) and **Heptabase's spatial whiteboards** represent the most innovative production approaches. Mem 2.0 (October 2025) rebuilt around "zero-friction capture" with agentic AI that acts on notes. Google NotebookLM, powered by Gemini 2.0, represents the "AI-as-synthesis-partner" paradigm with its Audio Overview feature generating podcast-style discussions from uploaded sources.

## Rust FFI on Apple Silicon demands a hybrid bridging strategy

The single most important finding for the Rust layer: **metal-rs is officially deprecated**. The README directs all new development to `objc2-metal` (part of the `objc2` project by madsmtm), which provides full Metal API coverage including MTLBuffer, MTLTexture, MTLComputePipelineState, and heap management with proper safety semantics.

**UniFFI v0.29.x** remains the best default FFI framework, with proc-macros now the recommended approach over UDL files. Critical limitations to know: async code does not yet fully conform to Swift 6's `Sendable` (tracked in issue #2448), `async_runtime="tokio"` doesn't work on trait async methods (issue #2576), and there is no built-in cancellation support. UniFFI's serialization overhead is real — `Record` types cross the boundary via binary serialization, creating copies for large hierarchies. The recommended mitigation is a **batching/command pattern**: minimize FFI crossings by designing coarse-grained operations (`search(query, filters, limit) → [Result]`) rather than chatty APIs.

For performance-critical paths, specifically Metal buffer sharing, use **manual C FFI or swift-bridge** (v0.1.36, zero-copy design). The recommended zero-copy UMA pattern:

1. Swift creates `MTLBuffer` with `.storageModeShared`
2. Swift extracts `contents()` pointer (`UnsafeMutableRawPointer`)
3. Pointer + length passed to Rust via FFI
4. Rust wraps as `&mut [u8]` slice and processes in-place
5. Zero copies — both CPU and GPU share the same physical memory on Apple Silicon

The **1Password architecture** is the closest production model to Epistemos: a Rust core containing all business logic, crypto, and database operations, with thin native UI (SwiftUI) communicating via an "invocation" pattern — Swift sends serialized requests through channels, Rust processes asynchronously on tokio, and calls back with results. They use their `typeshare` crate to generate matching Swift types from Rust struct definitions.

For Swift 6 strict concurrency compliance, the key mapping is: Swift `Sendable` on value types maps to Rust `Send`; `Sendable` on reference types (classes) maps to `Sync`. Ensure all Rust types exposed via UniFFI implement `Send + Sync` by wrapping mutable state in `Arc<RwLock<T>>`. Use `@preconcurrency import` for UniFFI modules during the transition period. Swift 6.2's "Approachable Concurrency" will make `@MainActor` the default, simplifying the model.

The battle-tested crate stack: `uniffi` 0.29.x for FFI, `objc2-metal` for Metal, `rusqlite` 0.31+ for SQLite, `tantivy` 0.25.0 for FTS, `tokio` 1.x for async, `crossbeam` 0.8+ for lock-free concurrency, `parking_lot` 0.12+ for faster Mutex/RwLock, `mimalloc` for the global allocator (excellent on Apple Silicon UMA), `serde` + `bincode` for high-performance serialization, and `tracing` for structured logging. Compile with `target-cpu=apple-m1` (applies to all Apple Silicon generations), `opt-level = 3`, `lto = "fat"`, `codegen-units = 1`.

GRDB v7.10.0 (February 2026) supports loading SQLite extensions, which is critical for sqlite-vec integration. The recommended hybrid search architecture runs tantivy entirely in Rust for FTS (exposed via UniFFI async), sqlite-vec via GRDB on the Swift side for vector operations, with Reciprocal Rank Fusion in Rust combining results before returning to Swift.

## Local inference architecture must be ruthlessly memory-aware

**MLX consistently outperforms llama.cpp by 20–30% on Apple Silicon**, with the gap widening at larger model sizes. On an M2 Pro with 16GB, a Qwen 8B model at Q4_K_M quantization achieves 45–58 tok/s on MLX versus 38–48 tok/s on llama.cpp. The authoritative benchmark paper (arXiv 2511.05502) on an M2 Ultra shows MLX reaching ~230 tok/s on Qwen-2.5 3B versus ~150 tok/s for llama.cpp. As of March 2026, **Ollama 0.19 is now powered by MLX on Apple Silicon**, achieving 1,810 tok/s prefill and 112 tok/s decode on Qwen3.5-35B-A3B with NVFP4 on M5 chips.

The multi-model orchestration architecture should follow a strict memory residency hierarchy on 16GB:

| Component | Memory | Policy |
|-----------|--------|--------|
| macOS + App UI | ~4 GB | Always resident |
| Qwen 3 4B Router (4-bit, in-process MLX-Swift) | ~3 GB | Pinned hot — every interaction gateway |
| nomic-embed-text v1.5 (ONNX Runtime) | ~0.3 GB | Resident — continuous embedding |
| KV cache budget | ~2–3 GB | Managed via rotating 4K window |
| DeepSeek-R1-Distill-8B Reasoner (sidecar) | ~5–6 GB | Cold-loaded with TTL eviction |

The critical design decision: **the router must output intent + reasoning_depth, not target_model**. The Swift orchestrator evaluates against the current hardware memory snapshot. Never let the LLM route itself — it doesn't know available memory. Use strict JSON schema with constrained decoding (via `mlx-swift-structured` from MacPaw) for all router output.

**Speculative decoding is not recommended for 16GB M2 Pro** with 8B main models. User reports show that Llama 3.1 8B + Llama 3.2 1B draft actually *decreased* speed from 38 to 33.9 tok/s on M1 Pro. The draft model overhead outweighs benefits at this scale — it only helps with very large main models on high-end hardware.

**RAG is strongly preferred over long context** on 16GB. Retrieve top-12 relevant chunks and fit them in 2–4K context. Long context (>8K) causes throughput collapse on llama.cpp (~1.2 tok/s at 32K). MLX handles it better with its rotating cache but remains memory-limited. Keep context ≤4–8K tokens for interactive speed.

For embedding, **nomic-embed-text v1.5** (137M parameters, 768 dimensions with Matryoshka truncation to 256 or 384 for storage) is the recommended model — it outperforms OpenAI ada-002, supports 8192-token context, runs efficiently on CPU via ONNX Runtime, and its Matryoshka property allows flexible dimension/quality tradeoffs. For audio transcription, FluidAudio CoreML achieves 0.19s for test clips using the Neural Engine, the fastest option available.

## Hidden depth requires composable primitives, not accumulated features

The most enduring insight from studying Vim, Emacs, Blender, Ableton, and Excel is that **multiplicative complexity from additive learning** is the hallmark of transcendent tools. Vim's "verb + noun" grammar (operators × motions × text objects) creates hundreds of commands from a small vocabulary — learning one new operator multiplies with all existing motions. The dot command (`.`), which repeats the last compound action, is the single most-cited "aha moment" in Vim's history. Unix pipes create the same effect: trivial individual tools (`cat`, `grep`, `sort`) compose via a universal text interface into arbitrarily sophisticated pipelines.

For Epistemos, this translates to a **progressive depth ladder**:

1. **Day 1** — Simple notes: create, write, save. Markdown formatting. Clean, distraction-free editor.
2. **Week 1** — Linked notes: `[[backlinks]]`, backlinks panel, basic search.
3. **Month 1** — Graph exploration: visual knowledge graph, clusters, orphan detection, tags.
4. **Month 2–3** — Custom queries: Dataview-style querying, dynamic dashboards, templates.
5. **Month 3–6** — Automation: dynamic templates with logic, periodic notes, web clipping pipelines.
6. **Month 6+** — AI-augmented research: semantic search, AI-suggested connections, synthesis, gap detection.

The **command palette** is the single most important UX primitive for power-user tools. Superhuman's engineering principles: make it available everywhere via one shortcut, centralize ALL commands (don't split across multiple palettes), support fuzzy matching and synonyms, and display keyboard shortcuts next to every command so users naturally learn shortcuts while searching. Every action in the UI must also be a palette command.

Blender 2.8's redesign offers the key lesson for balancing accessibility with power: **provide multiple entry points to the same functionality** — visual handles for beginners, keyboard shortcuts for experts — without ever removing either path. Ableton Live's Session View (creative jamming) versus Arrangement View (structured composition) shows how **distinct modes for different cognitive states** create natural progressive complexity.

Csikszentmihalyi's flow research applies directly: the tool must maintain a "flow channel" where challenge slightly exceeds current skill. The ideal learning curve is not a cliff or a gentle slope — it's a **staircase with plateaus**: quick initial payoff, plateau of competence, "aha moment" revealing a deeper layer, new plateau, repeat indefinitely. Obsidian achieves this through its plugin ecosystem: the core is a simple markdown editor, but users who invest deeply build a personal operating system.

## The semantic search pipeline must combine four retrieval signals

The recommended architecture combines tantivy FTS, sqlite-vec vectors, a lightweight entity graph in SQLite, and cross-encoder reranking. Here are the specific performance characteristics and recommendations:

**sqlite-vec** (v0.1.0, August 2024) is brute-force only — no ANN indexes yet (tracked in GitHub issue #25). At 100K × 384-dim float32 on M1 Pro, queries take ~68ms. With quantization and preloading, a newer competitor (sqlite-vector) achieves **3.97ms** — 17x faster with perfect recall. For >500K vectors, supplement with **USearch** (Rust crate, HNSW algorithm, claims 10x faster than Faiss in many scenarios, used by Ente Photos for on-device search) or **LanceDB** (embedded, serverless, built entirely in Rust on Lance columnar format, achieving 3ms latency for >0.9 recall on GIST-1M).

**tantivy** v0.25.0 (maintained by Quickwit) delivers **~2x faster performance than Lucene** and 6.5x faster than Elasticsearch, with sub-millisecond query latency, <10ms startup time, and 20% faster execution on ARM via NEON instructions. It should be the primary FTS engine, with SQLite FTS5 as fallback for simple metadata queries.

The **hybrid search pipeline** should follow this architecture:

1. **Query expansion**: Optional HyDE (Hypothetical Document Embedding) — generate a hypothetical answer via local LLM, embed that for retrieval
2. **Parallel retrieval**: tantivy BM25 → top-100; sqlite-vec/USearch vector search → top-100; entity extraction → graph traversal → related chunks
3. **Fusion**: Reciprocal Rank Fusion with formula `score(d) = Σ 1/(60 + rank_r(d))`, weighted 0.5 FTS / 0.5 vector
4. **Reranking**: Cross-encoder (`cross-encoder/ms-marco-MiniLM-L-6-v2`, 22MB) scores top-50 candidates → returns top-10
5. **Context expansion**: Parent document retrieval — index small chunks (200–400 tokens) for precision, return parent chunks (1,000–2,000 tokens) for LLM context

**Anthropic's Contextual Retrieval** is the single highest-impact indexing innovation: prepending LLM-generated context to each chunk before embedding reduces retrieval failures by **67%** when combined with hybrid search and reranking. At index time, for each chunk, call the local LLM with full document context to generate a 50–100 token situating prefix. This is computationally expensive but transformative for retrieval quality.

Target latency budget for the complete pipeline: single embedding generation <20ms, FTS query <2ms, vector search <10ms (100K, quantized brute-force), RRF fusion <1ms, cross-encoder reranking <20ms, **total query-to-results <50ms**. Memory budget for 1M quantized vectors + tantivy index + SQLite: approximately 1.5–3.5GB, fitting comfortably within the 16GB budget alongside the AI models.

For embedding dimensions, use the **Matryoshka strategy**: generate at 768 dimensions with nomic-embed-text v1.5, store at 384 dimensions (67% savings, <2% quality drop), use 128 dimensions for initial shortlisting if needed.

## Go-to-market should target PhD researchers first at $79/year

The recommended pricing model balances accessibility with premium positioning:

| Tier | Price | Rationale |
|------|-------|-----------|
| Free | $0 | Core note-taking, limited vaults — build adoption |
| Pro (Annual) | $79/yr | All features, AI, advanced search — positions above Bear ($30/yr) |
| Pro (Monthly) | $9/mo | Captures commitment-averse users |
| Lifetime | $199 | Captures "pay once, own forever" demand |
| Education | $39/yr | 50% off — volume play in universities |

Distribute outside the Mac App Store to avoid the 30% commission and sandboxing limitations that restrict file system access critical for local-first PKM. Use **Lemon Squeezy** (acquired by Stripe, July 2024) for payment processing with built-in license key management at 5% + $0.50 per transaction. Implement auto-updates via **Sparkle 2**, the 15-year standard for macOS app distribution. Distribute as DMG (not zip) for professional drag-to-Applications UX.

**Target PhD researchers and ML/AI engineers first.** They have the highest pain point (managing hundreds of papers alongside notes), appreciate native performance over Electron, are vocal on academic Twitter and Hacker News, and serve as credibility anchors for broader adoption. **Zotero integration is the critical integration** — it's the dominant open-source reference manager in academia. Build first-class Zotero import/sync, BibTeX citation key support, and PDF annotation import.

The launch should be multi-platform over a Tuesday–Thursday window: Product Hunt (Tuesday, aim for Product of the Day), Hacker News Show HN (Tuesday, lead with the Rust/Metal/Apple Silicon technical story), Twitter/X launch thread with GIFs (Tuesday–Thursday), Reddit in r/macapps and r/PKM (Wednesday), and Indie Hackers with real numbers (Thursday). According to OpenHunts' analysis of 387 launches, Indie Hackers delivers **23.1% conversion rate per engaged post** versus Product Hunt's 3.1% per launch.

Build community via Discord as the primary hub, GitHub Discussions for technical issues, and a blog for announcements. The plugin/extension ecosystem should be designed from day one — Obsidian's community plugins are its definitive moat. Start with a well-documented API, 5–10 example plugins, and a plugin template repository. Create a "Catalyst" early-access program (Obsidian charges $25 one-time) to nurture the initial 20–50 power users who will become evangelists.

Realistic revenue trajectory for an indie macOS tool: $5K–$15K MRR is achievable within 12–18 months with strong execution. The path to $1M ARR typically requires expanding beyond the initial niche or adding team features. Cursor's $0-to-$100M-ARR-in-12-months trajectory is an AI-era anomaly driven by timing a paradigm shift — instructive for ambition but not a planning baseline.

## Conclusion: the convergence that creates a billion-dollar opportunity

Three converging forces create the window for Epistemos. First, **local AI inference on Apple Silicon has crossed the production threshold** — MLX delivers 45–58 tok/s on 8B models at Q4 quantization on M2 Pro, sufficient for interactive use. Second, **the tools-for-thought space is mid-paradigm-shift** from manual organization to AI-augmented synthesis, with no clear winner yet. Third, **native macOS development is a defensible moat** — the Swift 6 + Rust + Metal stack delivers performance that Electron-based competitors cannot match, while Apple Silicon's unified memory architecture enables zero-copy buffer sharing between CPU, GPU, and AI models that is architecturally impossible on other platforms.

The engineering priorities that emerge from this research, in order: (1) make the hybrid search pipeline (tantivy + sqlite-vec + RRF + cross-encoder reranking) feel instant at <50ms end-to-end; (2) implement the multi-model orchestration with a pinned 4B router + cold-loaded 8B reasoner + cloud fallback; (3) build the command palette and composable primitives that create hidden depth; (4) ship Contextual Retrieval at index time for dramatically better search quality; and (5) design the plugin API that lets the community multiply the tool's capability beyond what any team can build alone.

The strategic positioning is clear: **"The research tool that's as fast as your thinking."** Local-first for privacy. Native for speed. AI-augmented for intelligence. Extensible for longevity. Every technical decision in the stack — from crossbeam-epoch lock-free concurrency to MLX-Swift in-process inference to zero-copy UMA buffer sharing — serves this positioning. The question is not whether the technology is ready. It is. The question is whether Epistemos can deliver the visceral, instant, "this-is-magic" experience that turns users into evangelists. That's what separates billion-dollar tools from $10M tools, and it's an execution problem, not a technology problem.