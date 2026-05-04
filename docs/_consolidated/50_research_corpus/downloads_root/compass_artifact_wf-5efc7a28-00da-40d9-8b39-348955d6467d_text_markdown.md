# Six cognitive layers for a local-first knowledge engine

Building cognitive computing capabilities into a native macOS knowledge system demands more than engineering skill — it requires grounding every feature in how human cognition actually works. **The strongest design pattern across all six capabilities is the same: externalize an internal cognitive process the user already performs, then make the machine version faster and more reliable without demanding attention.** This report maps the complete interdisciplinary landscape — cognitive science, competitive analysis, technical implementation patterns, and UX failure modes — for each of the six proposed capabilities running on Swift + Rust + Metal + on-device MLX inference with zero cloud dependencies.

The system's existing stack (HNSW via usearch, Metal-accelerated graph rendering, append-only OpLog, Model2Vec at ~1ms/paragraph, AXUIElement + ScreenCaptureKit, GRDB/FTS5) is unusually well-positioned. Most competitors rely on cloud inference; the on-device constraint is simultaneously the hardest engineering challenge and the strongest product differentiator.

---

## Capability 1: Contextual Shadows externalizes the expert's pattern-matching memory

### Why it works: recognition-primed decision making

Gary Klein's Recognition-Primed Decision (RPD) model, developed through U.S. Army research in the 1990s, found that **in 87% of 134 observed decision points, expert fireground commanders used pattern-matching rather than rational comparison of options**. Experts don't deliberate — they recognize a situation as matching a prototype stored in long-term memory, which instantaneously surfaces expectancies, relevant cues, plausible goals, and typical actions. The four by-products of recognition arrive in what Klein describes as "a blink of an eye."

Contextual Shadows replicates this process for knowledge workers. The fundamental problem is that digital knowledge is disconnected from the brain's natural pattern-matching: you wrote about a topic six months ago, but your brain cannot index 10,000 notes the way it indexes lived experience. John Mace's research on semantic-to-autobiographical memory priming (2019, *Memory & Cognition*) shows that semantic cues automatically activate related personal memories, even below conscious awareness. The side panel acts as a cue presentation system, transforming search from a **recall task** (generate a query from memory) into a **recognition task** (see past notes and recognize their relevance) — a shift that decades of memory research confirms is cognitively far easier.

### Ranking: semantic similarity dominates temporal proximity

Howard and Kahana's Temporal Context Model (TCM, 2002) and its CMR extension (Polyn, Norman & Kahana, 2009) establish that memory retrieval is driven by multiple context signals — temporal, semantic, and source — with semantic associations often overriding temporal proximity. The recommended ranking formula weights **semantic similarity at 0.7–0.8**, temporal decay at 0.1–0.15 (exponential with a 14–30 day half-life), and access recency at 0.05–0.1. A note from yesterday should rank slightly higher than an equally relevant six-month-old note, but the boost should be modest.

### The ambient display must follow calm technology principles

Mark Weiser's 1995 calm technology framework demands that technology "inform without demanding focus." The side panel must operate on Ishii and Ullmer's center-to-periphery continuum — visible at the edge of attention, available for conscious inspection when relevant, never interrupting the writing flow. Concrete design rules: **3–5 results maximum** (consistent with Cowan's working memory limit of 4±1 items), cross-fade transitions over 300–500ms, no attention-grabbing animations, and a stability threshold where the panel only updates when the new result set differs from the current one by more than 30%.

### Technical pipeline: 200ms debounce → Model2Vec → concurrent HNSW search

USearch is explicitly concurrent by design: `add_in_thread()` and `search_in_thread()` accept thread identifiers, with memory pre-allocated per core during initialization. The recommended threading architecture uses NSTextStorageDelegate to capture text changes on the main thread, a Combine-based 200ms debounce, then a background serial queue that extracts the current paragraph, encodes via Model2Vec (~1ms), queries HNSW (~<1ms for 100K vectors), applies temporal weighting, and dispatches results back to the main thread. Paragraph-level re-embedding with content-hash caching avoids redundant computation when the cursor moves without editing.

### Competitive landscape: Obsidian's Smart Connections is closest, but nobody updates per-keystroke

**Mem.ai** surfaces related notes via a "Heads Up" panel with zero configuration, but requires cloud processing — no offline capability, and ~30% of users report trust erosion from irrelevant suggestions. **Reflect** computes client-side embeddings for "Similar Notes" and achieves ~70% accuracy, but updates per-note, not per-paragraph. **Obsidian's Smart Connections plugin** (Brian Petro, 2023) is the closest analog — a real-time sidebar showing semantically related notes with block-level matching and local-first embeddings. Its weaknesses: not optimized for keystroke-level updates, pure semantic similarity without temporal weighting, and Electron-based performance bottlenecks. **Notion AI** has the data but requires explicit invocation — no ambient surfacing during writing. The gap is clear: nobody delivers real-time, keystroke-responsive, temporally-weighted semantic surfacing in a native app.

### Critical pitfall: the Clippy problem and trust calibration

Microsoft's Clippit failed because it was interruptive, poorly context-sensitive, and competed for attention. Lee and See's automation trust research (2004, *Human Factors*) shows that **trust calibration requires consistent reliability** — users must experience high precision before they'll habitually check ambient information. Launch with high precision / lower recall: better to miss good matches than show bad ones. A confidence threshold below which the panel shows nothing is essential. Track implicit feedback (which surfaced results users click on) and consider a warm-up period — don't show the panel until the vault exceeds ~50 notes.

---

## Capability 2: Cross-app capture works best through the accessibility tree, not screen recording

### The AX API surface is rich but unevenly implemented

The macOS accessibility API provides three critical attributes: `kAXFocusedUIElementAttribute` returns the currently focused element system-wide, `kAXSelectedTextAttribute` reads selected text from any editable element, and `kAXValueAttribute` reads full document content from text views. AXObserver notifications (`kAXSelectedTextChangedNotification`, `kAXValueChangedNotification`, `kAXFocusedWindowChangedNotification`) enable event-driven observation in native Cocoa apps. The `accessibility-sys` Rust crate provides complete FFI bindings, and `macos-accessibility-client` wraps trust-checking.

The catch: **Chrome and Electron apps disable their AX trees by default** for performance. Chrome requires setting `AXEnhancedUserInterface` on the main window to activate it; Electron apps need `AXManualAccessibility` set programmatically. Known Electron bugs include off-by-one errors in text range calculations (issue #36337). Safari exposes web content through the AX tree more reliably. For the ~15–20% of apps with sparse AX trees, Apple's Vision framework (`VNRecognizeTextRequest`) provides on-device OCR at ~130–210ms per frame on M-series chips, with `regionOfInterest` cropping to process only changed screen regions.

### The optimal architecture is hybrid: event-driven primary, polling fallback

AXObserver event-driven notification is efficient for apps that support it — zero CPU overhead between events. Register for `kAXFocusedWindowChangedNotification` and `kAXFocusedUIElementChangedNotification` on each running application; on focus change, read selected text, window title, and app bundle ID. For apps where AXObserver fails (some processes return `kAXErrorCannotComplete` perpetually, as documented by the yabai window manager project, causing up to 8% CPU consumption), fall back to 1-second polling of the focused element only.

For clipboard monitoring, `NSPasteboard` has no change notification on macOS. Poll `changeCount` every 200ms — it's an integer comparison with negligible CPU cost. Critically, respect `org.nspasteboard.ConcealedType` and `org.nspasteboard.TransientType` markers to avoid capturing passwords from 1Password and similar managers.

### Microsoft Recall's privacy backlash provides the definitive consent architecture lesson

Microsoft Recall (May 2024) screenshotted every few seconds, stored data in an **unencrypted SQLite database**, and was planned as enabled by default. Security researcher Kevin Beaumont discovered it trivially exposed credit cards, passwords, and private messages. Signal implemented "screen security" DRM to block Recall. Forrester's Jeff Pollard stated he couldn't "imagine any security or privacy controls making me comfortable with having it activated." The lesson: **never enable by default, encrypt at rest, filter sensitive content before indexing, and solve the third-party consent problem** (your capture affects other people's privacy in messages and video calls).

Rewind.ai's local-first approach was better received — all data processed and stored locally, with app-level exclusion lists and automatic private-browsing-window exclusion via ScreenCaptureKit filtering. But even Rewind pivoted away from desktop capture toward meeting transcription before being acquired by Meta in December 2025, suggesting ambient screen capture triggers deep user distrust at scale.

**Granola's model is instructive**: capture scoped to meetings only, manually initiated, device audio only (no bot joining calls), transcripts retained but audio deleted, consent messaging to participants. The recommended consent architecture for this system: explicit opt-in with clear scope explanation, granular per-app controls (default-exclude password managers and banking apps), a persistent menu-bar indicator with one-click pause, content-aware regex filtering for credit card numbers and SSNs before indexing, and time-based auto-expiration of captured data.

### The Memex lineage: capture is cheap, retrieval is the hard problem

Vannevar Bush's 1945 Memex envisioned "associative trails" linking documents — not hierarchical filing but association-based retrieval mirroring how the mind works. Gordon Bell's MyLifeBits project (Microsoft Research, 2001–2007) captured all of Bell's digital life into a SQL Server database. The key finding: **annotation is the bottleneck** — raw capture without intelligent filtering creates noise, not knowledge. Bell stopped his experiment when the iPhone shipped, noting that "AI was the missing piece." SenseCam research (Sellen et al., 2007, CHI) found that passively captured images were better memory cues than actively captured ones — counterintuitive but consistent with the recognition-over-recall principle. However, lifelogging research consistently finds that "information retrieval from large digital life archives is often poor" (Whittaker et al., 2012). The system must invest as heavily in retrieval and surfacing as in capture.

---

## Capability 3: Edit telemetry reveals cognitive states through pause-burst rhythms

### The Hayes-Flower model maps writing to three detectable cognitive processes

The Hayes-Flower cognitive process model (1981) identifies planning, translating, and reviewing as recursive processes orchestrated by a monitor. Hayes' 2012 revision explicitly incorporated working memory and transcription as distinct components. Critically for telemetry-based detection, **each process produces distinct behavioral signatures in keystroke data**: planning manifests as long pauses between paragraphs, translating as sustained typing bursts with within-sentence pauses, and reviewing as cursor repositioning and deletion patterns.

### Pause analysis requires personal baselines, not universal thresholds

The most robust signal is **pause duration relative to text location**. Research consistently shows pauses before higher-level textual units are longer (Wengelin, 2006; Medimorec & Risko, 2017): between paragraphs (global planning), between sentences (content generation), between words (lexical retrieval), within words (motor execution). The conventional threshold of **2 seconds** distinguishes "cognitive pauses" from "motor/transcription pauses" (Alves, Castro & Olive, 2008), while pauses exceeding 5 seconds typically indicate extended planning or conceptual restructuring.

However, Galbraith et al. (2022) and Roeser et al. (2021) argue convincingly that fixed thresholds are problematic. Bayesian mixture modeling reveals three components in between-word transition distributions: automated lexical processes, supra-lexical planning, and reflective thought. CMU's stress detection research (Lau, 2018) found that keystroke-based stress markers were **highly individualized** — discriminable within subjects but not across subjects. The system must establish personal baselines using a calibration period (first 5–10 minutes, or a dedicated copy task following Van Waes et al.'s 2019 multilingual protocol), then express all friction signals as z-scores relative to the individual baseline. Baselines should drift via exponential moving average to account for skill improvement.

### P-burst analysis is the highest-signal metric for cognitive load

P-bursts (production bursts, delimited by pauses ≥2 seconds) are the fundamental unit of fluent production. Chenoweth and Hayes (2001) showed that **burst length positively correlates with writing quality** — longer bursts indicate greater ability to manage complex language while writing, because motor execution is more automated, freeing cognitive resources. The composite friction score should weight: pause frequency and duration relative to personal baseline (strongest signal), burst length (shorter bursts = more friction), revision depth (surface vs. semantic), delete-retype ratio, and cursor displacement entropy.

For windowing, use a multi-scale adaptive approach: a micro window (5–30 seconds) for immediate friction events, a meso window (2–5 minutes) for burst-pause rhythm assessment, and a macro window (session-level) for phase transition detection. Rust implementation should use circular buffers with Welford's online algorithm for streaming mean/variance (O(1) memory, numerically stable), and the `augurs` or `scirs2-series` crates for change-point detection.

### Flow detection is feasible from behavioral signals alone

Csikszentmihalyi's flow theory, operationalized through neural correlates (Ulrich et al., 2014, *NeuroImage* — decreased medial prefrontal cortex activity during flow indicating reduced self-referential processing), maps to detectable typing signatures: **sustained high typing speed with low variability, long P-bursts with brief regular pauses, minimal revision, forward-only cursor movement, and low application switching**. IEEE research (2019) on non-invasive flow detection from computer interaction traces confirms this is viable. The critical distinction: productive flow (long bursts + minimal revision + forward progress) vs. unfocused "zone-out" (long bursts but low content density) vs. hyperfocus trap (oscillating between text and revision of the same passage).

### The gap in the market is genuine

**Draftback** shows Google Docs revision history in playback but offers no cognitive interpretation. **Hemingway Editor** analyzes text complexity but only the product, never the process. **Grammarly's Authorship** tracks writing provenance for AI detection, not cognitive support. Academic tools like **Inputlog** (University of Antwerp) collect millisecond-precision keystroke data with pause, revision, and burst analysis modules, but are research instruments, not user-facing products. **No existing tool combines real-time process analysis, cognitive state inference, personalized baselines, and actionable gentle interventions in a production editor.** This capability would be genuinely novel.

### The Hawthorne effect is the critical UX risk

Making cognitive state monitoring visible changes writing behavior — potentially inducing the exact self-consciousness that destroys flow. The system should surface friction data **retrospectively** (end-of-session summary) or through abstract ambient cues (gentle color gradients in margins) rather than numeric scores. Frame positively: show "flow time" rather than "friction time." Present patterns as "your writing rhythm" rather than "your cognitive difficulty score." Any intervention during writing must redirect attention to the content ("What's the one thing you're trying to say?") rather than the meta-level ("You've deleted this 4 times"). False positives — misinterpreting a coffee break as cognitive difficulty — require application focus detection: if the editor loses focus, mark the pause as "away" rather than "thinking."

---

## Capability 4: Tracking conceptual drift through embedding neighborhoods and graph topology

### Adapting diachronic embedding methods to personal knowledge

Hamilton, Leskovec, and Jurafsky's ACL 2016 work on diachronic word embeddings tracked cultural semantic change by training per-period embedding models, aligning them via Orthogonal Procrustes transformation, and measuring cosine distance between aligned vectors. Their two statistical laws — frequent words change slowly (conformity) and polysemous words change faster (innovation) — operate at corpus scale over decades.

For a personal knowledge system with Model2Vec's static embeddings, the paradigm shifts fundamentally. Since Model2Vec is deterministic (same text always produces the same vector), **drift must be measured as changes in what the user writes about a concept, not changes in the embedding model**. The practical approach: compute rolling aggregate embeddings for concepts — for concept C in time window [t₁, t₂], the centroid is the mean of all note embeddings mentioning C created in that window. Compare centroids across windows using cosine similarity. Track k-nearest-neighbor note sets per concept over time; changed neighbors indicate changed conceptual associations. A two-tier test distinguishes vocabulary change from genuine belief change: if the centroid drifts but graph neighborhood stays stable, it's likely vocabulary change; if both shift, it's conceptual change.

### Graph topology changes reveal four types of conceptual evolution

The Leiden algorithm (Traag, Waltman & van Eck, 2019, *Scientific Reports*) corrects Louvain's tendency to produce disconnected communities and is strongly preferred for community detection. Running Leiden at each time snapshot and tracking concept-community membership reveals four key signals:

- **Concept migration** (concept moves from Cluster A to Cluster B) — reconceptualization, directly mapping to Chi's ontological category shift
- **Cluster merger** (two communities combining) — the user recognizing a deeper connection between previously separate domains
- **Cluster fission** (one community splitting) — the user recognizing important distinctions
- **Bridge formation** (new edges connecting previously separate clusters) — interdisciplinary insight

Changes in centrality metrics are equally revealing. **A concept gaining betweenness centrality is becoming a bridge between knowledge domains** — the "aha, these connect!" moment. Growing PageRank indicates increasing importance through citation by other high-value concepts. These are computationally detectable proxies for Thagard's explanatory coherence shifts and Posner et al.'s conditions for conceptual accommodation.

### Storage: anchor-plus-delta in SQLite beats full snapshots by 5.7x

The AeonG system (VLDB 2024) demonstrated that anchor-plus-delta temporal graph storage achieves **5.73x lower storage and 2.57x lower query latency** compared to alternatives. The recommended SQLite schema stores periodic full-graph anchors (weekly) with community partitions, centrality scores, and modularity, plus inter-anchor deltas recording edge additions, removals, community membership changes, and centrality shifts. An event-sourcing log of all graph mutations enables reconstruction of any historical state. For graph analysis in Rust, `petgraph` provides the core data structures (StableGraph for stable indices under deletion) but lacks built-in community detection — implement Leiden directly or use the `graphalgs` crate for supplementary metrics. Incremental computation is essential: maintain a dirty set of concepts affected by recent changes, recompute centrality only for the 2-hop neighborhood, and trigger full Leiden only when accumulated changes exceed 5% of edges.

### Temporal graph visualization: animation with timeline scrubber

Beck, Burch, Diehl, and Weiskopf's taxonomy (2017) identifies two major approaches: animation-based (graph evolves in real-time, requiring mental map preservation for stability) and timeline-based (multiple time points shown simultaneously via small multiples or superimposed views). The recommended design combines an interactive animated graph with staged transitions (leveraging Metal/GPU acceleration) as the primary view, small multiples for before/after comparisons, and a timeline scrubber that morphs the graph smoothly between states. Keyframe markers at automatically detected change points guide the user to moments of significant evolution. Color encoding signals temporal information: warm gradients for new connections, cool for old ones, saturation proportional to drift magnitude.

### The false-positive risk: vocabulary change masquerading as belief change

The most dangerous UX pitfall is flagging vocabulary change as conceptual change. Require corroborating signals — don't flag a concept as "changed" based on embedding drift alone; demand at least two of: embedding centroid drift, community membership change, centrality change, or explicit contradiction detected in text. Present detected changes for user validation: "Did your understanding of X actually change, or are you just using different terminology?" Adaptive temporal windowing — activity-based windows containing N notes regardless of calendar time, plus change-point detection via CUSUM or PELT — avoids the trap of fixed windows that are too granular (daily noise) or too coarse (yearly blur).

---

## Capability 5: Night Brain exploits overnight idle time through macOS background APIs

### macOS provides the scheduling infrastructure, but architecture matters

`NSBackgroundActivityScheduler` wraps the XPC Activity API and Duet Activity Scheduler (DAS), which maintains a scored list of 70+ background activities, rescoring based on energy, thermal state, and CPU use. The critical limitation: it assumes the app is running. For overnight processing after the user quits the app, the architecture requires a **Login Item helper** (LSUIElement=1, invisible in Dock) that persists after the main app exits, checks `IOPSCopyPowerSourcesInfo()` for AC power and `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .any)` for idle time >15 minutes, then launches an XPC service for heavy computation.

Power assertions via `IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep, ...)` prevent idle sleep while allowing display sleep — the correct mode for Night Brain. `ProcessInfo.processInfo.thermalState` monitoring should throttle work at `.serious` or above, though Apple Silicon's thermal reporting is coarser than expected (`.fair` covers both moderate and heavy throttling). The XPC service provides process isolation — if embedding generation crashes, the main app survives — and memory isolation so HNSW work doesn't bloat the main process.

### Spaced repetition principles reshape what the digest surfaces

Ebbinghaus' forgetting curve (1885, replicated by Murre & Dros in 2015 with "remarkably similar" results) shows retention dropping to ~33% after one day and ~21% after one month for meaningless material. For connected, meaningful knowledge, the curve is shallower — the key insight for Night Brain. Andy Matuschak's core principle is that **"spaced repetition memory systems make memory a choice"** — once adopted, remembering becomes a low-stakes decision. His observation that "notes should surprise you" directly supports serendipitous discovery in the digest. Michael Nielsen's "Augmenting Long-term Memory" (2018) adds that SRS works best when collecting knowledge toward a specific project, not piling up general knowledge.

The Leitner box metaphor adapts naturally: newly created/edited notes start at high surfacing frequency, notes the user engages with when surfaced get promoted to longer intervals, dismissed notes get demoted or retired. But the digest should optimize for **recognition and serendipity, not flashcard-style recall** — showing note titles with context snippets tests recognition, which is appropriate for a morning knowledge briefing.

### Delta indexing keeps nightly processing under 60 seconds for 50K paragraphs

Model2Vec's throughput (~25,000+ sentences/second on CPU single-thread) combined with usearch's incremental `add()` API means delta indexing — computing embeddings only for new/modified paragraphs tracked via content hashes in GRDB — takes under 1 second for typical daily changes (500 paragraphs modified in a 50K vault). Full rebuilds of 50K paragraphs take approximately 20 seconds. The recommended strategy: daily delta indexing with incremental add/remove, weekly recall quality measurement by sampling random queries and comparing HNSW results versus brute-force, and full rebuild only when recall drops below 95%. Build the new index in the XPC service, then atomically swap the file. The main app uses `Index.restore("path", view: true)` for memory-mapped serving during search.

HNSW does tolerate incremental additions well, but accumulated deletions degrade recall through the "unreachable points phenomenon" (arXiv:2407.07871v2) — after many delete-insert cycles, graph connectivity weakens. This makes periodic full rebuilds during idle time genuinely valuable rather than merely precautionary.

### Orphan detection combines graph centrality with embedding proximity

The strongest signal for "forgotten but valuable" knowledge: notes whose embeddings are highly similar to the centroid of recently active notes but haven't been accessed in the last 30 days. Compute this by running k-NN search in the HNSW index against the recent-work centroid, then filtering out recently accessed notes. Supplement with graph centrality: **high betweenness centrality combined with low access frequency** indicates critical connective tissue being neglected. Reserve 20–30% of digest slots for serendipitous connections — notes with moderate (not high) similarity from different topic clusters, following Matuschak's principle that notes should surprise.

Apple Photos' on-device ML processing provides the reference architecture: `photoanalysisd` separates fast per-item processing (embed on import) from slow global analysis (clustering overnight). Night Brain should follow the same split: real-time embedding of new/changed notes during normal use, overnight batch operations for full graph analysis, orphan detection, and digest generation.

### The morning digest must be ruthlessly short

Hard cap of **5–7 items** (Miller's magic number), front-loaded by value. Rank by: relevance to recent work (0.4), urgency via calendar proximity (0.3), serendipity score (0.2), and time since last surfaced (0.1). Show the user's own words, never AI-generated paraphrases — the digest should be a curated view of existing content, not generated content. Track which connections have been surfaced and when; apply exponential backoff for dismissed connections (don't re-show for 2^n days). A diversity constraint ensures no two items in the same digest come from the same topic cluster.

---

## Capability 6: Spatial graphs work because manipulation is cognition, not just display

### Epistemic actions are genuine cognitive work

Kirsh and Maglio's foundational 1994 study of Tetris players demonstrated that physical manipulation of the world reduces mental computation. Players rotated pieces more than necessary because seeing pieces in different orientations externalized the mental rotation task. These **epistemic actions** — actions taken to change the computational burden rather than move toward a goal — are distinct from pragmatic actions. For spatial graph interaction, this means dragging, grouping, and spatially arranging nodes are not "busywork" but genuine cognitive work that reduces the mental load of understanding relationships.

Barbara Tversky's *Mind in Motion* (2019) strengthens this: spatial thinking is the foundation of all thought, including abstract reasoning. Nobel Prize-winning grid cell research confirms the brain tracks conceptual proximity using the same neural mechanisms as spatial proximity. Lakoff's conceptual metaphor theory establishes that abstract thought is fundamentally grounded in spatial experience — "understanding is seeing," "ideas are locations," "thinking is object manipulation." These aren't mere metaphors; they are the cognitive substrate that makes spatial knowledge organization work.

### The competitive landscape reveals what works and what doesn't

**Heptabase** is the current leader in visual PKM, with cards on infinite whiteboards, non-duplicative card references across whiteboards, and nested hierarchical spaces. Users report it "feels like thinking on a physical wall." **TheBrain** offers a unique Plex visualization that recenters on the active thought with animated transitions and three relationship types (parent, child, jump). Its constraint — manual link creation — makes connections feel "more purposeful and meaningful." **Obsidian's Graph View** is universally criticized for the hairball problem at scale — users report it's "visually interesting but reveals little insight" above ~1,000 notes. **Scapple** (Literature & Latte) excels at free-form spatial note creation with no forced hierarchy, but lacks any semantic intelligence. **Kinopio** gets the spatial memory argument right: "the journey of placing ideas and figuring out what should be grouped together is vitally important to building up your own spatial memory."

The gap: no tool combines force-directed algorithmic layout with user pinning, semantic zooming, GPU-accelerated physics at 120fps, and graph operations driven by spatial gestures.

### GPU-accelerated Barnes-Hut makes 10K+ nodes feasible at 120fps

The Barnes-Hut tree optimization reduces O(n²) n-body force calculation to **O(n log n)** by recursively subdividing space into a quadtree and treating distant cell groups as single bodies (θ ≈ 1.0 for ~5% pixel-level error). GraphPU (Rust + wgpu) demonstrated that GPU-parallel Barnes-Hut with 18 compute kernels and spring-force merge acceleration achieves 60fps — without optimization, the same scene ran at 0.1fps. ForceAtlas2 (from Gephi) combines Barnes-Hut with degree-dependent repulsive force and adaptive step length; GPU implementations achieve **40–123x speedup** over CPU (Brinkmann et al., ICPP 2017).

On Apple Silicon with unified memory architecture, the implementation uses shared `MTLBuffer` with `storageModeShared` for zero-copy data sharing between Rust physics and Metal rendering. The render loop: CADisplayLink fires at display refresh rate → Swift calls Rust physics step via C-ABI FFI → Rust updates positions in shared buffer → Metal render pipeline draws nodes and edges → Swift overlays labels and gesture feedback. For ProMotion displays, use `preferredFrameRateRange` to request 120Hz during interaction and drop to lower rates when the graph has converged (energy below threshold). Structure data as **Structure of Arrays** (separate aligned arrays for x[], y[], vx[], vy[], mass[], color[]) rather than Array of Structures for coalesced GPU memory access.

### The map ≠ territory problem requires hybrid layout with clear mode signaling

The deepest design challenge: spatial proximity in force-directed layout reflects topological distance (link hops), not necessarily semantic similarity. Users may misinterpret accidental proximity as meaningful relationship. The solution is a **hybrid layout**: UMAP projection of Model2Vec embeddings for initial semantic positioning (preserving both local and global structure), ForceAtlas2 for relationship-aware refinement, and user pinning for manual overrides (pinned nodes get infinite mass in the physics simulation, and the rest of the graph relaxes around them).

Critical caveat from recent research (arxiv:2506.08725): practitioners frequently misuse t-SNE/UMAP by assuming inter-cluster distances are meaningful — distances within clusters are reliable, but distances between clusters may be projection artifacts. For the knowledge graph, use UMAP for initial clustering but rely on explicit edges and force-directed physics for cross-cluster layout. Semantic zooming provides different information at different scales: galaxy view (far) shows colored cluster nebulae with only cluster labels, constellation view (medium) shows individual nodes with key labels, and card view (close) shows full note previews with all connections.

### Gesture design must avoid system conflicts while enabling semantic operations

macOS reserves three-finger swipe (Spaces), four-finger gestures (Mission Control), and two-finger pinch-to-zoom as system gestures. Custom semantic gestures must use **modifier keys**: Option+pinch for semantic grouping vs. plain pinch for zoom, Cmd+drag for "create relationship" vs. plain drag for repositioning. Every gesture must have a menu and keyboard equivalent for discoverability. Shneiderman's direct manipulation principles demand continuous representation, physical actions, and rapid reversible operations — but DM is slow for power users, requiring command palette support for expert workflows. The undo problem for semantic operations (merge, split, create relationship) is harder than for spatial moves; consider an operation-level undo stack with visual preview before commit.

### The hairball is not a bug to fix but an inherent limitation to design around

Force-directed graphs degrade into unreadable tangles at scale because they can only reveal assortative mixing patterns. The hairball problem requires multiple solutions working together: **filtering** (threshold edges below minimum weight), **semantic zooming** (cluster aggregation at far zoom), **focus mode** (dim everything except the selected node's 1–2 hop neighborhood, following TheBrain's Plex approach), and **named views** (saved spatial arrangements the user can switch between). Without these, the graph view becomes what Obsidian users universally report: pretty but useless.

---

## Conclusion: what connects these six capabilities

Three architectural principles unite all six capabilities. First, **the append-only OpLog is the unifying substrate** — it feeds Contextual Shadows (text change triggers semantic search), Cognitive Friction Detection (behavioral analysis of edit patterns), Temporal Knowledge Graph (time-stamped content evolution), and Night Brain (incremental change detection via content hashes). Building it right — with millisecond timestamps, operation types, positions, and content — enables all four downstream capabilities.

Second, **the ranking problem is universal and always requires the same solution**: semantic similarity as the dominant signal, temporal context as a secondary boost, and personal calibration to avoid false positives. This applies to the Contextual Shadows panel, orphan knowledge detection, digest ranking, and even friction score computation.

Third, **the trust equation determines adoption more than technical sophistication**. Contextual Shadows fails if results are irrelevant 30% of the time (Reflect's problem). Cross-app capture fails if users feel surveilled (Recall's problem). Friction detection fails if it induces the self-consciousness it tries to measure (the Hawthorne effect). Temporal Knowledge Graph fails if it flags vocabulary change as belief change. Night Brain fails if the digest becomes notification noise. Spatial graphs fail if layout is pretty but meaningless. In every case, **high precision and graceful silence beat high recall and false positives**. The system should feel like an extension of the user's own cognition — noticing what they would notice if they had perfect memory and infinite attention — rather than an agent with its own agenda.