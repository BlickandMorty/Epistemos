# Six cognitive computing capabilities for a local-first macOS knowledge system

The strongest personal knowledge tools don't just store information — they simulate the associative, temporally-aware, friction-sensitive retrieval patterns of expert human memory. This report maps the complete interdisciplinary landscape for building six capabilities into a Swift + Rust + Metal + MLX system, covering the cognitive science that justifies each feature, the competitive products that have attempted similar ideas (and what they got right or wrong), the specific technical patterns that work with HNSW/usearch, Model2Vec, AXUIElement, and Metal compute shaders, and the UX failure modes that separate tools people love from tools people disable after a week.

The overarching thesis across all six capabilities: **the system should function as a prosthetic for the recognition-primed decision making that experts develop over decades** — surfacing relevant prior knowledge involuntarily, tracking conceptual evolution over months, detecting cognitive difficulty in real time, and maintaining a spatial thinking medium that treats node manipulation as an epistemic act. Every capability below is grounded in specific cognitive science research that explains *why* it works, not just how to build it.

---

## 1. Contextual Shadows: why ambient retrieval simulates expert memory

### The cognitive science case is stronger than most builders realize

Gary Klein's Recognition-Primed Decision (RPD) model, developed from field studies of fireground commanders, found that **87% of expert decisions are made through pattern recognition** rather than comparative analysis of options. Experts don't evaluate alternatives — they recognize a situation, match it against thousands of stored prototypes, and instantly generate a viable action. The Contextual Shadows panel computationally replicates this pipeline: current writing acts as the retrieval cue, Model2Vec encoding performs the pattern matching, and HNSW search surfaces the prototypical prior notes that an expert's memory would surface involuntarily.

Endel Tulving's synergistic ecphory model formalizes this further. Memory traces can be *available but inaccessible* — they exist in the vault but natural retrieval cues are insufficient to activate them. Neurophysiological research shows that ecphory triggers reactivation of memory traces within **100–200ms** after a retrieval cue appears, which maps almost exactly to the 200ms debounce target. The system implements Tulving's ecphory computationally: the current paragraph is the probe, embeddings are the encoding, and HNSW search produces what Tulving called "ecphoric information" — the product of cue-trace interaction.

For display capacity, **Cowan's 4±1 limit** (not Miller's 7±2, which has been superseded) defines how many items the focus of attention can hold. Since the user is simultaneously writing — already consuming working memory — the panel should default to **3–4 results**, expandable on demand.

### What the competitors got right and wrong

**Obsidian Smart Connections** is the closest existing implementation. Its v4 offers real-time sidebar updates using local embeddings (TaylorAI/bge-micro-v2, 384-dimensional) with zero setup. It works, but it's limited by Electron's performance ceiling, uses no temporal weighting, shows too many results, and updates per-note rather than per-paragraph. **Mem.ai's "Heads Up"** feature updates dynamically on "meaningful changes" and organizes results by topic, but it's cloud-dependent and reports roughly 85% accuracy for cross-note synthesis. **Reflect** offers "Similar Notes" via client-side embeddings with end-to-end encryption, but it's per-note, not per-paragraph-as-you-type. **Notion AI** doesn't do ambient retrieval at all — it's generation-focused and page-scoped.

The critical gap across all competitors: **no product combines paragraph-level real-time granularity, temporal context weighting, native Metal/Rust performance, and calm-technology design principles**. Most panels show 10–20 results (exceeding working memory capacity by 3–5×) with no temporal decay, and none apply Ishii's peripheral display principles.

### Technical pipeline: 200ms debounce to panel update

The latency budget is generous. The pipeline — **200ms debounce + ~1ms Model2Vec encoding + ~1–5ms HNSW search + ~1ms re-ranking** — totals roughly 203–207ms from last keystroke to panel update, well under the threshold for ambient displays. USearch is concurrent by design, supporting thread-safe `add` and `search` operations. The recommended architecture uses Swift's `AsyncChannel` with the `debounce(for:)` operator from Apple's Async Algorithms package, feeding into a dedicated `SearchIndexActor` that wraps the Rust/usearch index. Panel updates dispatch back to `@MainActor` for AppKit rendering.

For temporal re-ranking, Howard and Kahana's Temporal Context Model (TCM) shows that temporal and semantic factors interact synergistically — they aren't independent channels. The ranking formula should use **power-law decay** rather than exponential: `temporal_weight = (1 + t/τ)^(-b)`. Power-law decay better models human memory (Wixted & Ebbesen, 1991) and is gentler on older valuable content. Combine this with semantic similarity and access frequency: `score = α × semantic_similarity + β × temporal_weight + γ × access_frequency`.

### The UX pitfall that kills this feature: the Clippy problem

The canonical failure mode is Microsoft's Clippy, which violated every principle of calm technology: it interrupted without permission, offered help nobody asked for, and couldn't be permanently dismissed. Byron Reeves at Stanford summarized it: *"The worst thing about Clippy was that he interrupted."*

The antidote comes from Mark Weiser's calm technology principles and Hiroshi Ishii's ambientROOM work at MIT: **the panel must exist in the periphery while writing occupies the center of attention**. Information updates silently. Transitions from periphery to focus are user-initiated — hover to preview, click to open. The panel uses lower contrast than the editor, no animations that attract attention, no badges or urgency markers. Results fade in over ~300ms rather than snapping. The cardinal rule from Weiser: *"The individual, not the environment, must be in charge of moving things from center to periphery and back."*

An empty panel is always better than a noisy one. Set a meaningful similarity threshold and show nothing when confidence is low.

---

## 2. Ambient cross-app capture: the AX tree is better than you think (and OCR covers the rest)

### From Memex to MyLifeBits to the curation problem

Vannevar Bush's 1945 Memex concept envisioned a desk storing all of a person's records with **associative indexing** — any item linked to any other, forming persistent "trails." Gordon Bell's MyLifeBits at Microsoft Research (2001–2007) actually built this, capturing ~200,000 items totaling ~160GB. Bell's key finding: *"Bio-memories are just URLs into e-memory records"* — biological memory serves as pointers to the detailed digital record.

But Sellen and Whittaker's "Beyond Total Capture" (Communications of the ACM, 2010) delivered the essential critique: **even deliberately saved digital memorabilia is seldom accessed**, creating "data graveyards." Lecture recordings don't significantly improve grades. Meeting-capture systems showed little uptake. The effort to maintain and search captured data can exceed the cost of relying on organic memory. The design implication is stark: **capture must work in synergy with users' own memory, not replace it**. The most valuable signal is intentional user actions (copying, highlighting, switching to notes) rather than passive viewing.

### The macOS accessibility API surface is rich but uneven

The AX API provides `kAXSelectedTextAttribute` (currently selected text), `kAXValueAttribute` (full content), `kAXURLAttribute` (current URL in browsers), and `kAXDocumentAttribute` (file path). Event-driven observation via `AXObserverAddNotification` supports `kAXSelectedTextChangedNotification`, `kAXFocusedUIElementChangedNotification`, and `kAXValueChangedNotification` — all critical for knowledge capture.

**Native AppKit/SwiftUI apps** (TextEdit, Preview, Finder, Notes, Xcode, Safari, Mail) provide rich AX trees with full attribute support and reliable notifications. **Chrome/Chromium apps have AX disabled by default** for performance but can be activated programmatically via `AXUIElementSetAttributeValue(appRef, "AXManualAccessibility", kCFBooleanTrue)`. **Electron apps** (VS Code, Slack, Discord) require the same activation. Games, DRM-protected content, and custom-rendered UIs (some Adobe apps, Figma) have minimal or no AX trees. Realistic coverage: **~60–70% of knowledge worker apps provide adequate AX metadata** natively or with activation.

The recommended architecture uses a **hybrid event-driven/polling approach**: register `AXObserver` notifications on the focused app, detect app switches via `NSWorkspace.didActivateApplicationNotification`, and fall back to adaptive polling (500ms during active editing, 2–5s for static viewing) for apps where notifications don't fire reliably. A known Apple bug causes `kAXSelectedTextChangedNotification` to not fire reliably on root Application elements — the workaround is registering on individual text elements, though this is expensive. Maintain a per-bundle-ID capability cache to remember which apps support notifications.

For the remaining 30–40%, **Apple's Vision framework** (`VNRecognizeTextRequest`) performs on-device OCR in **~20–50ms on Apple Silicon** in `.fast` mode for a 1080p screen capture. Use ScreenCaptureKit's `SCContentFilter(desktopIndependentWindow:)` to capture only the focused window, trigger OCR only when the AX tree is sparse, and cache results until content changes (detected via frame diff or dirty rects). The `screencapturekit` Rust crate by svtlabs provides full Rust bindings including Metal GPU integration and async stream support.

### Privacy consent architecture: what Recall teaches and Granola gets right

Microsoft Recall's privacy backlash is the definitive case study for what not to do. The original design was **enabled by default**, stored data in an **unencrypted SQLite database** (security researcher Alexander Hagenah built "TotalRecall" to extract everything trivially), captured credit card numbers and passwords, and provided no app-level exclusions. Signal, Brave, and AdGuard all implemented blocking of Recall by default.

Rewind.ai demonstrated a better model: all-local encrypted storage, app-specific exclusions, private browser windows excluded by default, pause/resume capture, and granular deletion. But Rewind still faced "always watching" concerns and eventually pivoted to cloud-based processing with a wearable pendant, abandoning the local-only model.

**Granola's bounded capture model** offers the most trust-effective pattern: capture scoped to specific contexts (meetings only), user-initiated (must manually start), no audio storage (transcript only, audio discarded), and automated consent messaging to participants. The bounded approach works because its scope is **understandable and justifiable**.

For this system, the non-negotiable consent requirements are: **opt-in only** (never opt-out), always-visible menu bar indicator showing capture status, instant pause/resume via keyboard shortcut, per-app exclusion lists (banking and password managers excluded by default), local-only storage with FileVault encryption, transparent dashboard showing what's been captured, configurable data retention limits, and the ability to nuke all data instantly.

### The critical UX pitfall: context collapse

Capturing text without understanding *why* it was being read strips it of meaning. A highlighted passage has different significance depending on whether the user is researching a paper, casually browsing, or procrastinating. The mitigation is capturing **surrounding context** — which app, which document, what was before/after, time of day, duration of engagement, and especially whether the user took an intentional action (copy, highlight, switch to notes app). Intentional actions are orders of magnitude more valuable than passive viewing. The system should weight captures by intentionality signal strength.

---

## 3. Cognitive friction detection: what pause durations actually mean

### The Hayes-Flower model maps directly to OpLog observables

The foundational cognitive writing model (Hayes & Flower, 1980/1981) identifies three recursive processes — **planning**, **translating**, and **reviewing** — with a monitor that switches between them. Each process produces distinct signatures in edit telemetry: planning manifests as long pauses before new content generation (especially at paragraph boundaries), translating manifests as sustained keystroke bursts with forward-only text production, and reviewing manifests as cursor jumps to earlier text followed by deletion and replacement sequences.

Galbraith's knowledge-constituting model adds a crucial nuance: during genuine knowledge-constituting writing, ideas emerge through the act of text production itself. Writers in this mode show **sustained forward production with minimal revision** — and interrupting this process (including premature evaluation) actually *decreases* understanding. This means high friction during knowledge-constituting writing may signal productive cognitive work, not dysfunction. Any friction detection system must account for this.

### The specific behavioral signals from keystroke logging research

The literature converges on a **2-second threshold** separating transcription-level processes (motor execution, spelling) from higher-order cognitive processes (planning, reconceptualization). Pauses under 2 seconds reflect typing skill; pauses over 2 seconds reflect thinking. Both pause duration and frequency increase as text production moves from characters to sentences to paragraphs, reflecting increasingly demanding cognitive activities at higher discourse levels.

**P-bursts** (pause-delimited bursts, from Alves, Castro & Olive, 2008) are written segments terminated by pauses exceeding 2 seconds. P-burst length indicates the capacity of the translating process — longer bursts and shorter pauses correlate with higher fluency and improved text quality. **R-bursts** (revision-delimited bursts) are terminated by revision events. Higher R-burst rates positively correlate with text quality, indicating that revision refines output.

Deletion patterns carry distinct cognitive signals. Character-level backspaces typically indicate typo correction (low cognitive load). Word-level backspace sequences indicate word-choice reconsideration (moderate load). Select-and-replace indicates deliberate reformulation (active reviewing). Select-and-delete without replacement indicates content reconceptualization (high load). Cut operations indicate structural reorganization — the highest-level planning activity observable in telemetry.

### Computing a friction score from the OpLog

The composite friction score should integrate six signals, each z-score normalized against the user's personal baseline:

**Pause-to-burst ratio** (weight 0.25): total pause time (>2s pauses) divided by total execution time within a rolling 60-second window. **Deep revision rate** (0.20): cursor-jump-plus-edit events per characters produced, excluding inline backspace corrections. **Deletion density** (0.15): characters deleted divided by characters typed. **Cursor jump frequency** (0.15): non-adjacent cursor repositioning events per minute, with backward jumps weighted more heavily. **Burst length decline** (0.15): trend in P-burst lengths over the window — declining lengths signal increasing cognitive load. **Speed variability** (0.10): coefficient of variation in inter-keystroke interval within bursts.

**Baseline calibration is essential.** The system needs ~5 hours of writing data before activating friction scoring, and baselines should be maintained separately for different writing modes (email vs. long-form) if possible. Express friction as z-score deviations from personal baselines, not absolute values. Slow typists' pause patterns mean something fundamentally different from fast typists' pauses — the ratio of pause-to-execution differs between skill groups.

For **flow state detection**, the behavioral signatures are: sustained long P-bursts, consistent typing speed (low IKI coefficient of variation), minimal revision, low cursor jump frequency, and forward-only text production sustained for 10+ minutes. The honest assessment from the literature: flow can be *approximated* from behavioral signals when multiple indicators converge over sustained periods, but cannot be definitively confirmed without subjective report. Label these periods "high-fluency states" rather than claiming flow detection.

### No existing tool does anything like this

**Draftback** for Google Docs provides replay visualization but no quantitative scoring, no real-time analysis, no baseline calibration. **Grammarly** tracks word count and accuracy but has zero process analysis — no pause timing, no burst analysis, no typing dynamics. **Hemingway Editor** and **iA Writer** analyze static text, not how it was produced. Academic tools (**Inputlog**, **Scriptlog**, **Translog-II**) provide comprehensive keystroke logging analysis but require explicit session setup, run only on Windows, and analyze offline.

The OpLog's unique advantage: **continuous, ambient, longitudinal data across all documents over months**, enabling cross-document pattern analysis ("you write more fluidly in notes than formal documents"), topic-level friction analysis ("your friction increases when writing about X"), and individual calibration that improves over time.

### The cardinal UX rule: never interrupt flow to report flow

Csikszentmihalyi identified loss of self-consciousness as a core flow component. Any notification that says "you're in the zone!" immediately destroys that state. **Never show friction scores in real-time during composition.** Instead: collect data passively (the OpLog does this inherently), present friction analysis post-session as a reflective tool, and if any real-time signal is shown, make it ambient and non-judgmental — a subtle color gradient in the gutter, not a number. Interventions (break suggestions, reflection prompts) should be queued and delivered only when the writer naturally disengages, detected by a sustained pause of >30 seconds.

The system should operate like a flight recorder: always recording, rarely speaking. Present insights with non-evaluative language — not "poor flow" but "your writing rhythm shifted here." Frame high friction as potentially productive: some of the best writing involves struggle.

---

## 4. Temporal knowledge graph: tracking how understanding actually evolves

### Diachronic embeddings reveal personal conceptual drift

Hamilton, Leskovec, and Jurafsky's 2016 work established two statistical laws of semantic change: frequent words change slowly (law of conformity), and polysemous words change faster (law of innovation). Their methodology — train embeddings on time-sliced corpora, align via Orthogonal Procrustes, measure drift — translates directly to personal knowledge tracking by replacing "corpus per decade" with "user's notes per month."

Model2Vec has a specific advantage here: because its token embeddings are **static and deterministic** (vocabulary lookup + mean pooling, no contextual computation), any changes in aggregated concept embeddings across time periods are genuinely due to changes in co-occurring language, not model stochasticity. This eliminates the Procrustes alignment step entirely — all embeddings live in a fixed space. To track concept C's evolution: extract sentences containing C in each time window, embed them, average, and compare across periods. A declining cosine similarity between period-aggregated embeddings signals conceptual shift.

### Graph diffing reveals structural understanding changes

For a personal knowledge graph with hundreds to low thousands of nodes, practical graph differencing uses **edge-set differencing** (simple set operations on E(t+1) \ E(t)), **betweenness centrality tracking** (rising betweenness means a concept is becoming a bridge between knowledge areas), and **PageRank changes** (rising PageRank means a concept is becoming more referenced). When a concept moves from peripheral to central, the user is increasingly connecting that idea to many other ideas — a sign of deepening integration.

For community detection across time slices, the **Smoothed Louvain (SmoL)** algorithm uses the previous snapshot's community structure as initialization for the current snapshot, ensuring smooth evolution and reducing noise. **DF Louvain** (Dynamic Frontier) processes only vertices affected by recent changes, achieving up to **179× speedup** over static re-runs — practical for live-updating knowledge graphs. The **Leiden algorithm** (Traag et al., 2019) guarantees well-connected communities, avoiding Louvain's known issue of disconnected community detection.

### Cognitive science predicts specific patterns of conceptual change

Paul Thagard's ECHO model treats beliefs as a constraint-satisfaction network where coherence relations determine acceptance. The operational insight: when new notes contradict earlier ones, the system should create inhibitory links and run constraint satisfaction to identify which beliefs the user has implicitly abandoned. Michelene Chi's ontological category shift framework adds a powerful detector: track the **predicates and attributes** a user associates with a concept over time. If "machine learning" co-occurs with statistical terms (regression, p-value, hypothesis) in early notes but neural network terms (layers, backpropagation, attention) in later notes, that's a detectable ontological shift — the concept has moved categories in the user's understanding.

Posner et al.'s four conditions for conceptual change (dissatisfaction, intelligibility, plausibility, fruitfulness) can be partially operationalized: questioning language about a concept signals dissatisfaction, correct use of technical vocabulary signals intelligibility, new edges appearing from the concept signal plausibility, and the concept appearing in new cluster contexts signals fruitfulness.

### Implementation: temporal tables in SQLite with Rust graph processing

The storage pattern uses **valid-time columns**: each concept edge has `valid_from` and `valid_to` (NULL = current) timestamps, with a composite index on `(valid_from, valid_to)` for efficient range scans. Point-in-time queries reconstruct the graph at any date via `WHERE valid_from <= :target_date AND (valid_to IS NULL OR valid_to > :target_date)`. Concept embeddings are stored in a snapshot table keyed by `(concept_id, snapshot_date)` with packed float32 blobs.

Concept extraction uses Apple's **NaturalLanguage framework**: `NLTagger` with `.lexicalClass` for part-of-speech tagging (extract nouns and noun phrases), `.lemma` for normalization, and `.nameType` for named entity recognition. Edges are created from sentence-level co-occurrence weighted by frequency, with temporal decay so recent co-occurrences count more. Graph algorithms run in Rust using **petgraph's `StableGraph`** (indices stay valid across removals), with results sent to Swift via FFI.

### The "so what?" problem is the primary UX risk

Showing that a concept's embedding shifted 15% tells the user nothing. The mitigation: **translate metrics into natural language narratives**. Instead of "cosine similarity dropped from 0.85 to 0.72," say "Your understanding of machine learning has shifted — earlier you wrote about it alongside statistics and regression; now you associate it more with neural networks and transformers." Set minimum document count thresholds (don't compute drift from fewer than 5 documents mentioning the concept), apply smoothing to drift time series, and report only changes exceeding 2σ from the concept's historical variance. Every drift alert should include specific, actionable prompts: "Here are your key notes from before and after the shift. Was this intentional?"

---

## 5. Night Brain: autonomous processing that earns trust through transparency

### Spaced repetition applies to knowledge graphs, not just flashcards

The Ebbinghaus forgetting curve — roughly 50% forgotten within 1 hour, 70% within 24 hours, 90% within a month without reinforcement — applies to personal knowledge too. Andy Matuschak's work on the "mnemonic medium" demonstrates that spaced repetition can develop *conceptual understanding*, not just rote recall. His key insight: *"Memory system practice sessions are too disconnected from activities you actually care about"* — which is exactly the problem Night Brain solves by integrating spaced resurfacing into the natural knowledge workflow rather than requiring a separate flashcard practice.

The nightly digest should contain: key concepts encountered yesterday, newly discovered semantic connections, **spaced repetition candidates** (notes approaching their forgetting threshold weighted by relevance to current work), orphan knowledge alerts, and a single **serendipity slot** — a note that is NOT in any active cluster but has moderate semantic similarity and high importance. This implements the "anomalies and exceptions" approach from Toms's (2000) framework for inducing serendipity. Foster and Ford (2003) found serendipity widely experienced among interdisciplinary researchers, and both conditions (open browsing) and strategies (deliberate broad scanning) foster it.

### The orphan detection algorithm combines three signals

An orphan knowledge node has **high semantic relevance to current work**, **low recent access**, and **significant graph connectivity**. The detection formula: `orphan_score = importance(n) × recency_decay(n) × relevance(n)`, where importance combines PageRank (recursive importance) with betweenness centrality (bridging role), recency decay uses `1 - e^(-λ × days_since_access)`, and relevance is the maximum cosine similarity between the note's embedding and any active topic centroid. Inspired by bibliometric "Sleeping Beauty" detection (Van Raan, 2004), the system identifies notes with high embedding similarity to currently active topics but long periods of zero access — the "prince" is the new topic that makes a dormant note suddenly relevant.

### macOS background processing: launchd agent + XPC service + thermal monitoring

**NSBackgroundActivityScheduler** provides energy-aware scheduling via the Duet Activity Scheduler, but it requires the app to be running. For a nightly job that should run even after app quit, use a **launchd agent** with `StartCalendarInterval` targeting 2 AM, which launches an XPC service for heavy processing. The XPC service provides crash isolation (if processing fails, the main app is unaffected) and its own sandbox.

Preconditions before processing: AC power (check via `IOPSGetProvidingPowerSourceType()`), idle >15 minutes (via `IORegistryEntryCreateCFProperty` for HIDIdleTime), and thermal state ≤ `.fair` (via `ProcessInfo.processInfo.thermalState`). Hold an `IOPMAssertion` with `kIOPMAssertPreventUserIdleSystemSleep` during processing, but release immediately when done. Monitor thermal state continuously — at `.serious`, reduce batch sizes by 50%; at `.critical`, checkpoint and exit.

For incremental HNSW re-indexing, the **delta indexing strategy** maintains a small in-memory "hot" index of recent changes during the day and a large memory-mapped "cold" index on disk. Nightly merge: load cold index, add all hot vectors, process deletions (tombstone cleanup — reassign deleted nodes' neighbor edges), save merged index, swap atomically. USearch's multi-index search queries both indices simultaneously during the day. Full compaction runs monthly or when the tombstone ratio exceeds 10–20%.

The processing pipeline must be **checkpoint-resilient**: re-index → checkpoint → digest generation → checkpoint → orphan detection → checkpoint. Register for sleep notifications via `IORegisterForSystemPower()` and save state in the 30-second window before forced sleep. GRDB transactions ensure the database is never left inconsistent.

### Apple Photos is the design model; Spotlight is the engineering model

Apple Photos demonstrates the ideal trust pattern for autonomous background processing: face clustering runs during nighttime charging, uses a conservative first-pass (high precision, many small clusters) followed by gradual incremental merging, and presents results as **suggestions for user confirmation** rather than automatic reorganizations. Night Brain should follow the same pattern: all outputs additive (never modify existing notes), presented in a dedicated "Night Brain Report" section, with confidence scores on every suggested connection.

Spotlight's architecture demonstrates the engineering pattern: FSEvents-based change detection (near-real-time), `mdworker` processes for parallel parsing, progressive throttling (more aggressive when plugged in, minimal on battery), and `LowPriorityIO` for disk operations that don't compete with user work.

### The overnight surprise problem

The primary trust risk is the user opening the app to find connections they don't understand. The mitigation: **the Night Brain Report** — a transparent summary showing when processing ran, how many notes were re-indexed, what connections were discovered (with similarity scores), and any errors. Start with conservative thresholds (only surface high-confidence connections). Let users dismiss bad suggestions, training the system. Quality over quantity: **3 high-quality connections beat 20 mediocre ones**. If a type of suggestion is consistently dismissed, reduce its weight automatically.

---

## 6. Spatial graph canvas: where epistemic actions meet Metal compute shaders

### Physical manipulation of concepts is genuine cognitive work

Kirsh and Maglio's landmark 1994 Tetris study distinguished **pragmatic actions** (actions toward a physical goal) from **epistemic actions** (actions performed to uncover information hard to compute mentally). Players physically rotated pieces not to place them but to *see* them in different orientations, offloading internal computation to the world. On a thinking canvas, dragging a concept node near another is not data entry — it's an act of thinking. The user rearranges ideas spatially to explore relationships and discover structure.

Barbara Tversky's research demonstrates that **spatial cognition is foundational to all abstract thought**. Nobel Prize-winning grid cell research shows the brain uses the same neural machinery to navigate conceptual spaces as physical spaces. Tversky found that gesturing while communicating shapes the thinker's *own* thoughts — subjects forced to sit on their hands became incoherent. Scaife and Rogers's external cognition framework explains three mechanisms: computational offloading (see relationships instead of holding them in memory), re-representation (graph layout reveals clusters invisible in text), and graphical constraining (spatial structure limits the inference search space).

The implication: a spatial graph canvas isn't a visualization feature — it's **cognitive infrastructure** for thinking that text-based interfaces cannot provide.

### What the existing tools teach about success and failure

**TheBrain** handles large graphs (millions of nodes) through its "Active Thought" focus model — one node is always center, and the graph reorganizes dynamically around it. Navigation feels fluid, but spatial persistence is sacrificed, so users can't build persistent mental maps. **Scapple** takes the opposite approach: pure manual placement with full spatial persistence, but no automatic layout means no discovery of implicit structure and poor scaling beyond ~100 items. **Obsidian's Graph View** is the cautionary tale: non-deterministic, non-persistent layouts that produce a different arrangement each visit, described by users as "pretty but useless" and primarily used as a screenshot generator rather than a thinking tool. Obsidian Canvas is better for spatial thinking but operates in a completely separate mode disconnected from the graph.

**Kumu.io** provides the best existing hybrid model: force-directed layout runs continuously as the default, but users can **pin individual nodes** in place (exempt from forces), and pinned nodes become fixed points that the rest of the layout organizes around. This is the pattern to build on.

### ForceAtlas2 on Metal compute shaders scales to 50K+ nodes at 120fps

**ForceAtlas2** (Jacomy et al., PLOS ONE, 2014) is the optimal algorithm for this use case: O(n log n) with Barnes-Hut optimization, degree-dependent repulsive force (hubs repel more, producing cleaner layouts), adaptive speed control, and designed as a continuous algorithm (runs while users watch and interact). On brute-force O(n²), Apple Silicon GPUs handle ~5,000 nodes at 120fps. With Barnes-Hut, **10,000–50,000 nodes at 120fps on M1/M2**, and 100,000+ on M3 Pro/Max.

**GraphPU** (Latent Cat, 2025) is the closest Rust-based precedent: a GPU-accelerated graph visualization tool using compute shaders with 18 GPGPU kernels including bounding box computation, octree construction (the hardest to parallelize — ~1,000 lines of shader code), Barnes-Hut traversal (one thread per node), and spring force computation with custom merge-addition for high-degree nodes achieving **>60× speedup**. GraphWaGu (Dyken et al., Eurographics 2022) demonstrates 100,000 nodes with 2,000,000 edges at interactive rates using a pointerless quadtree representation designed for GPU compatibility.

For Metal specifically: maintain three `MTLBuffer` arrays for positions (float2), velocities, and forces, all staying in GPU memory between compute and render passes. Apple Silicon's **unified memory eliminates CPU-GPU transfer overhead** entirely. Sequence operations via `MTLCommandBuffer`: compute pass (force calculation) → compute pass (integration) → render pass (drawing). During drag interaction, fix the dragged node's position and apply a strong spring force to the cursor — other nodes continue responding to forces, creating a natural "focus + context" reorganization. On release, gradually blend back into simulation via exponential decay of the pinning force over ~500ms.

### Gesture design must earn discoverability

Five gesture-to-semantic mappings, each grounded in physical metaphor: **drag-to-relate** (proximity implies relationship — the most natural gesture), **pinch-to-synthesize** (squeezing two things into one, via `NSMagnificationGestureRecognizer`), **lasso-to-summarize** (circling a group, via freeform `NSPanGestureRecognizer` path), **spread-to-expand** (fanning out sub-concepts, positive magnification), and **flick-to-dismiss** (brushing aside, via velocity-thresholded pan gesture).

Norman's signifier concept is critical: users must discover that gestures exist. The solution is **progressive disclosure** — show gesture hints when the user pauses near actionable targets (pulsing connection zone when holding a node near another, subtle "expand" animation on hover). Provide right-click context menus as a parallel path to every gesture. Support aggressive undo (Cmd+Z for every operation) to reduce experimentation fear.

### The layout stability problem is make-or-break

Force-directed layouts that produce different arrangements each visit destroy spatial memory — the entire cognitive benefit of spatial arrangement depends on persistence. The required stability techniques: **deterministic initialization** (seed RNG with a hash of graph structure), **layout caching** (save converged positions and use as initial positions next session), **slow convergence with high damping** (ForceAtlas2's adaptive temperature does this), and **incremental layout** for new nodes (place near connected neighbors, apply forces only to affected neighborhood). New connections should trigger **smooth animated transitions**, never jump-cuts.

The deeper tension is the **map-territory problem**: force-directed layouts position nodes based on graph topology, but users may expect spatial position to encode semantic similarity, temporal recency, usage frequency, or their own manual arrangement. No single mapping works universally. The solution is a hybrid with explicit transparency: nodes the user has manually positioned become semi-pinned (decaying pin strength), with a subtle visual distinction (anchor icon) from auto-positioned nodes. The system should communicate what spatial relationships mean: "These nodes are close because they share 5 connections" vs. "You placed these here."

### The hairball threshold is ~200 visible nodes

Graphs become unreadable above **~200 visible nodes with >3× edge-to-node ratio**. Solutions: semantic zoom (cluster boundaries at low zoom, individual nodes at high zoom), edge bundling (reduces visual clutter by 50–80%), progressive disclosure (expand clusters on demand), and a minimap for orientation. Peixoto's (2023) critique is important: force-directed layouts can create *illusory* clusters that don't reflect real structure. Algorithmic community detection should drive visualization, not the reverse. Maximum **3–4 simultaneous visual encoding channels** (color for category, size for importance, position for relationships) — more overwhelms pattern recognition.

---

## Conclusion: the system as prosthetic expert memory

These six capabilities form a coherent cognitive architecture when viewed together. **Contextual Shadows** simulates the recognition-primed retrieval of an expert's associative memory. **Ambient Capture** extends this memory to everything the user encounters across applications, with consent architecture that learns from Recall's failures. **Friction Detection** closes the metacognitive loop by revealing the user's own thinking process without disrupting it. **The Temporal Knowledge Graph** makes conceptual evolution visible — something no human memory does well — enabling genuine belief revision awareness. **Night Brain** implements spaced repetition and orphan detection at the system level rather than requiring user discipline. **The Spatial Canvas** provides a thinking medium where physical manipulation of abstract concepts constitutes genuine cognitive work.

The recurring UX theme across all six: **the system must be calm**. Every capability has a failure mode where it becomes annoying instead of magical — the Clippy problem, the creepy factor, the anxiety-inducing quantified self, the "so what?" of drift metrics, the overnight surprise, the pretty-but-useless hairball. The antidote in every case is the same: let the user control the transition from periphery to focus, set high confidence thresholds, default to silence over noise, and never interrupt to inform. The goal is not a system that talks constantly but one that, when glanced at, always has something relevant to say.