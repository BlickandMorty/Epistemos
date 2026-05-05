# Epistemos Research Reference v2 — Complete Knowledge Base

**This document preserves ALL research for Claude to re-read at session start.**
**Updated March 31, 2026 — includes five engines, screen capture, UMA thesis, 60+ papers.**

---

## 1. Product Strategy Intelligence

### Billion-dollar patterns
- **Speed as identity.** Linear: $35K marketing → $1.25B. Cursor: $0 marketing → $500M ARR (May 2025), fastest SaaS ever, 36% free-to-paid. Raycast: sub-100ms.
- **Extensibility as moat.** Obsidian: 2,700+ plugins, 18 people. Roam: zero extensibility → stalled.
- **PLG purity.** Transcendent product = zero marketing needed.
- **AI as core.** Cursor proves AI-native timing. DevonThink counter-model: 23 years, $99-$199 one-time.

### Go-to-Market
- Target: PhD researchers + ML/AI engineers. Zotero integration critical.
- Price: Free → $79/yr Pro → $9/mo → $199 Lifetime → $39/yr Education
- Distribution: OUTSIDE Mac App Store. Lemon Squeezy + Sparkle 2 + DMG.
- Launch: Tue-Thu window — Product Hunt, HN Show HN, Twitter/X, r/macapps, Indie Hackers (23.1% conversion).
- Plugin ecosystem from day one.

---

## 2. Academic Research (CHI 2025 + Frontiers)

- CHI 2025 "Tools for Thought" Workshop: 56 researchers, 34 papers
- **Key finding:** Reduced critical thinking with AI. ExtendAI > RecommendAI.
- **NoTeeline:** 93.2% factual correctness, 47% less text. **LECTOR:** 90.2% success rate.
- **GraphRAG:** 72-83% comprehensiveness, 3.4x accuracy. Lightweight: NER → SQLite → recursive CTE.
- **Emerging:** Tana supertags, Heptabase spatial whiteboards, Mem 2.0, NotebookLM.

---

## 3. Five Engines

### Engine 1: ECS Graph (Rust + Metal)
- SVG collapses at ~400 nodes. WebGL: 400,000 at 50 FPS (Horak et al., 2018).
- SoA layout: 5.7-10× speedup over OOP (Mike Acton, CppCon 2014). 90% cache waste eliminated.
- ECS benchmarks: 262K entities, 7 systems = 3ms (abeimler/ecs_benchmark). 120Hz = 8.33ms budget.
- GPU force-directed: Barnes-Hut = 40× over CPU (Brinkmann et al., ICPP 2017).
- Pipeline: SoA arrays → MTLBuffer storageModeShared → zero-copy GPU physics → Metal rendering.

### Engine 2: Zero-Copy IPC (POSIX SHM)
- Shared memory: ~5M msg/sec vs ~130K for UDS = 36× throughput (goldsborough/ipc-bench).
- Latency: 1.4μs for 4KB messages.
- Apple Silicon: 128-byte cache lines (Lemire, Dec 2023). Pad metadata to 128B.
- macOS: shm_open permitted in App Groups. IOSurface for GPU buffer sharing (Chrome, OBS).
- Protocol: Write to `/dev/shm` → pass 90-byte SHM_REF JSON pointer → mmap on receiver.

### Engine 3: TurboQuant+ K8V4
- Walsh-Hadamard normalization → Asymmetric K8V4 (8-bit Keys, 4-bit Values).
- half4 vectorized butterfly ops on Metal GPU.
- 4.6× compression, 99.1% perplexity retention.

### Engine 4: NightBrain (Temporal Memory Distillation)
- **Neuroscience:** CLS theory (McClelland/McNaughton/O'Reilly, 1995). Hippocampal replay (Wilson/McNaughton, 1994). Fragile without reactivation (Káli/Dayan, 2004).
- **Ebbinghaus:** R = e^(−t/S), S increments on recall. MemoryBank (AAAI 2024) validated.
- **Distillation:** Lewis (Mar 2026): 371→38 tokens (11×), 96% retrieval quality. Amazon Bedrock: 89-95% compression.
- **Scheduling:** FSRS (Ye, SIGKDD 2022): DSR model, 220M logs. NSBackgroundActivityScheduler for idle/AC/thermal checks.
- **Systems:** MemGPT (UC Berkeley) → Letta. A-Mem (2025): agentic memory with evolution/linking.

### Engine 5: Token Savior (AST Intelligence)
- Aider RepoMap: tree-sitter + PageRank → 1,024 tokens for entire repo (~97% reduction).
- CICADA: 82% reduction. Serena (LSP, 40+ languages): 70-80%. jCodeMunch: 95%+.
- cAST (EMNLP 2025): AST chunking +4.3 Recall@5. RPG/ZeroRepo: 36K LOC, 81.5% coverage.
- MCP tools: find_symbol, get_function_source, get_change_impact.

---

## 4. Screen Capture as Living Memory

- **Rewind.ai architecture:** 2-second captures via ScreenCaptureKit → Vision OCR (~99%) → SQLite FTS → H.264 at 0.5 FPS. 3,750× compression. 20-40% single core.
- **Microsoft Recall:** 3-5 sec snapshots, NPU processing, VBS Enclave encryption. Still captures sensitive data sometimes.
- **Apple Vision OCR:** Millisecond per image. FastVLM-0.5B: 85× faster first-token than LLaVA-OneVision.
- **Lineage:** Bush Memex (1945) → Bell MyLifeBits (60 years = 1TB) → Gurrin DCU (18M+ images).
- **ScreenCaptureKit:** GPU-backed IOSurface buffers, 120 FPS. screencapturekit-rs crate.

---

## 5. Rust FFI on Apple Silicon

- **metal-rs DEPRECATED → objc2-metal**
- **UniFFI 0.29.x:** Proc-macros. Async/Sendable issues (#2448, #2576). Batch/command pattern.
- **Zero-copy UMA:** MTLBuffer .storageModeShared → contents() pointer → Rust &mut [u8]. Zero copies.
- **1Password model:** Rust core + thin SwiftUI. typeshare for type generation.
- **Swift 6:** Sendable values → Send. Sendable refs → Sync. Arc<RwLock<T>>. @preconcurrency import.
- **Crates:** uniffi 0.29, objc2-metal, rusqlite 0.31+, tantivy 0.25.0, tokio 1.x, crossbeam 0.8+, parking_lot 0.12+, mimalloc, serde+bincode, tracing.
- **Compile:** target-cpu=apple-m1, opt-level=3, lto="fat", codegen-units=1.
- **GRDB 7.10.0:** SQLite extension loading → sqlite-vec integration.

---

## 6. Local Inference Architecture

- **MLX > llama.cpp by 20-30%.** M2 Pro: Qwen 8B Q4 = 45-58 tok/s (MLX) vs 38-48 (llama.cpp).
- **Ollama 0.19:** MLX-powered. 1,810 tok/s prefill on M5.
- **Router:** Qwen 3 4B (3GB, pinned). Outputs intent+reasoning_depth. mlx-swift-structured for JSON.
- **Embedding:** nomic-embed-text v1.5 (0.3GB, 768→384 Matryoshka).
- **Reasoner:** DeepSeek-R1-8B (5-6GB, cold-loaded, TTL).
- **RAG > long context.** Top-12 chunks, 2-4K context. No speculative decoding at this scale.

---

## 7. Apple Silicon UMA Thesis

- **Underexploited.** 148K Metal apps (2017 figure, never updated). AMX undocumented. ANE no utilization metric.
- **Zero-copy advantage:** CUDA wastes ~90% on transfers (Ingonyama benchmark). UMA eliminates entirely.
- **AMX:** Zhou MIT thesis — 1,348 FP32 GFLOPS, 14.9× per core. M4 → ARM SME (documented!).
- **Efficiency:** M4 GPU: >200 GFLOPS/Watt vs V100 ~52 GFLOPS/Watt.
- **MLX:** "Arrays live in shared memory." vllm-mlx: 21-87% higher throughput than llama.cpp.
- **Hardware symbiosis:** CPU+GPU+AMX+ANE = 4.3× over CPU alone (Turner M1 Max estimate).

---

## 8. A2UI (Agent-to-User Interface)

- **Generative UI preferred 82.8% over markdown** (Google Research). 92.6% for info-seeking.
- **A2UI protocol v0.8:** Flat adjacency-list JSON. Security-first. SwiftUI on 2026 roadmap.
- **AG-UI protocol (CopilotKit):** 16 event types. Google, LangChain, AWS, Microsoft adoption.
- **SwiftUI:** bipa-app/swiftui-json-render — 21 components, streaming partial JSON support.
- **Production:** Claude Artifacts, OpenAI Canvas (83% trigger rate), MCP Apps (SEP-1865).

---

## 9. Search Architecture

### Four Signals
1. **tantivy FTS:** ~2× Lucene, 6.5× Elasticsearch, sub-ms, NEON-accelerated.
2. **Vector (Stateful Rotor):** <4ms at 100K/384d quantized. USearch/LanceDB for >500K.
3. **Knowledge graph:** NER → SQLite → recursive CTE. GraphRAG: 72-83% comprehensiveness.
4. **Cross-encoder:** ms-marco-MiniLM-L-6-v2 (22MB), top-50 → top-10.

### Pipeline
RRF: `score(d) = Σ 1/(60 + rank_r(d))`. Contextual Retrieval: -67% failures. **<50ms total.**

---

## 10. Quantization Research (60+ Papers)

### Rotation: OPQ → QuIP → QuIP# → QuaRot → SpinQuant → OSTQuant → FlatQuant → ButterflyQuant → WUSH → RotorQuant

### KV Cache: KIVI → KVQuant → ZipCache → GEAR → QServe → KVTuner → PM-KVQ → ThinKV → Kitty → MixKVQ

### Key formulations preserved in Appendix A of master thesis.

### Open Problems
1. No formal rotation-quantization freshness interaction analysis
2. No fully fused Metal dequantize→scale→rotate→accumulate kernel
3. ANE blocked for dynamic mixed-precision

---

## 11. AGI Through Local Compute

- **JEPA:** ~5× fewer iterations (Assran et al., 2023). LeWorldModel: 15M params, single GPU, 48× faster planning.
- **Small models:** Phi-4-mini 3.8B matches Mixtral 8x7B. Qwen3 edge: "outperform baselines with more parameters."
- **Cognitive architecture:** SOAR/ACT-R prove intelligence from organized retrieval, not scale.
- **The thesis:** Fast organized retrieval + efficient local inference = qualitatively different intelligence.

---

*60+ papers, 8 research domains, 5 engines, 1 architecture. Re-read relevant sections at session start.*
