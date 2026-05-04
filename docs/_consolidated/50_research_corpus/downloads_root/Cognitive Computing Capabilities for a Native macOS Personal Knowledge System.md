# Cognitive Computing Capabilities for a Native macOS Personal Knowledge System

## Executive Summary

This report maps the interdisciplinary landscape — cognitive science, HCI, systems architecture, and UX — for six capabilities that transform a local-first macOS knowledge system (Swift + Rust + Metal + on-device MLX inference, already equipped with HNSW vector search via usearch, Model2Vec at ~1ms/paragraph, an append-only OpLog, AXUIElement FFI, ScreenCaptureKit, and GRDB/FTS5) into a genuinely cognitive computing environment. Each capability is evaluated on its scientific grounding, competitive evidence, implementation specifics for the described stack, and the concrete UX pitfalls that separate "magical" from "annoying."

***

## Capability 1: Contextual Shadows — Ambient Semantic Retrieval Panel

### Cognitive Science Justification

The theoretical anchor for Contextual Shadows is Gary Klein's Recognition-Primed Decision (RPD) model from Naturalistic Decision Making research. Experts don't reason analytically from first principles; they pattern-match unconsciously and a solution "pops" into awareness before conscious deliberation begins. Klein's data from firefighters, ICU nurses, and military commanders shows that roughly 80% of decisions by domain experts are recognition events, not exhaustive searches. An ambient retrieval panel operationalizes this involuntary recall: the system performs the pattern search so the writer doesn't have to interrupt their working memory to do it.[^1]

The critical design constraint comes from Mark Weiser and John Seely Brown's calm technology framework (1995), which holds that the best technologies move fluidly between the center and periphery of attention without demanding it. Weiser's key insight is that peripheral information should inform without overburdening — which is precisely what a side panel that fades rather than pops must do. The MIT Tangible Media Group's work on "ambient displays" (Ishii, Wisneski, et al.) confirms that peripheral information channels can carry meaningful semantic signal without triggering attentional capture, provided the display uses luminance/opacity rather than motion or color change as its primary encoding dimension.[^2][^3]

Memory research adds a temporal dimension. Recency and contextual similarity are both retrieval cues, but they interact: the **contextual reinstatement effect** predicts that cues present during encoding will be strongest re-triggers at retrieval. For a personal knowledge system, the most useful semantic neighbors are those written in similar cognitive contexts (similar vocabulary, similar project phase), not necessarily the most recent. A temporal decay function that weights recency logarithmically — rather than linearly — will better approximate human memory's actual forgetting curve while still privileging recent work for active projects.[^4][^5]

### Competitive Analysis

| Product | Retrieval Mechanism | What It Got Right | Critical Failure |
|---------|-------------------|-------------------|------------------|
| Mem.ai | Vector similarity + LLM-reranked suggestions | Fast retrieval, good recall breadth | Suggestions are intrusive; too many, too often; users describe "notification anxiety" |
| Reflect | Chat-based: user explicitly queries against notes | Respects user intent; low noise | Requires active query — no ambient surface; destroys the recognition priming benefit |
| Notion AI | In-line prompt triggered by `/AI` | Clean opt-in UX | Not ambient at all; only fires when explicitly invoked |
| Rewind.ai | Full-text search across screen recordings | Comprehensive coverage | Screen-scrape granularity = signal-to-noise problem; no semantic ranking |

The consistent failure mode is **attention capture**: surfacing too many results, updating too frequently, or using visual changes aggressive enough to interrupt flow. The ceiling for ambient relevance panels is ~3–5 results, displayed at reduced opacity (~35%), updated only on significant semantic shift (cosine distance > 0.15 from last embedded state), not on every keystroke.[^6][^7]

### Implementation Patterns for the Stack

The pipeline is: `OpLog edit event` → 200ms Tokio debounce timer (Rust) → `model2vec-rs` encode current paragraph (~1ms, 8000 samples/sec throughput) → `usearch` HNSW top-K=7 cosine retrieval → Swift `@MainActor` panel update via Swift-Rust FFI.[^8][^9]

**Streaming incremental HNSW updates** are safe using usearch's `add()` API, which inserts single vectors without full index rebuild. The key architectural constraint is that `add()` must happen on a dedicated Rust async background thread — never on the editor's main thread — to avoid the ~1–5ms insertion latency bleeding into keystroke response time. The `codemem-vector` crate (v0.6.x) demonstrates exactly this pattern: persistent, incremental, SIMD-accelerated HNSW at 768 dimensions with M=16, efConstruction=200.[^10][^11][^12][^13]

For temporal decay scoring, apply a multiplicative weight to HNSW scores:

\[
\text{score}(d) = \text{cosine\_sim}(q, d) \cdot e^{-\lambda \cdot \Delta t}
\]

where \(\lambda\) is a half-life constant (experiment with 7–30 day half-life) and \(\Delta t\) is days since last edit. This keeps semantically close but recently active notes prominently ranked while gracefully fading stale content. Expose \(\lambda\) as a user-adjustable "temporal reach" slider.

**HNSW accuracy degrades under high deletion loads.** Recent research on the "unreachable points phenomenon" shows that frequent deletions (e.g., when notes are deleted or substantially rewritten) can strand graph nodes that are no longer reachable during search, silently degrading recall. The mitigation is periodic soft-rebuild triggered during Night Brain processing (Capability 5), not during active editing.[^14]

### UX Pitfalls

- **The observer effect:** A visible panel that updates while writing diverts attention to monitoring the panel rather than the text. Solution: auto-collapse after 8 seconds of non-interaction; re-expand only on significant semantic shift, not on every debounce.
- **Over-retrieval:** Showing 7+ results creates a scanning burden that converts the panel from ambient to attention-demanding. Hard cap at 5 results; show only title + 2-line excerpt.
- **Opacity cliff:** Instant opacity transitions feel like notifications. Use a 300ms ease-in-out fade for appearance and a 500ms fade for disappearance.
- **Panel width competition:** The panel should compress rather than push the editor. On sub-1400px displays, default to a hover-reveal that doesn't consume horizontal space.

***

## Capability 2: Ambient Cross-App Knowledge Capture

### Cognitive Science Justification

Vannevar Bush's 1945 Memex vision imagined a "device in which an individual stores all his books, records, and communications, and which is mechanized so that it may be consulted with exceeding speed and flexibility." Gordon Bell's MyLifeBits project (Microsoft Research, 2000s) attempted a total digital capture implementation, accumulating ~350GB of personal data over a decade. The critical lessons from the CACM retrospective on lifelogging are: (1) **selectivity beats total capture** — unfocused "capture everything" strategies produce archives that are impractical to search; (2) **cue design beats experience capture** — the goal is not to replay experience but to surface retrieval cues at the right moment; (3) **target memory failure points specifically** — capture should be directed at situations where human prospective and associative memory are demonstrably weak (cross-context connections, information from transient sources, exact wording of key phrases).[^15][^16]

This reframes the design goal: Ambient Cross-App Capture should not aim to record everything but to intercept **semantic artifacts** (highlighted text, copied phrases, file names + metadata) and attach them to a context vector from the current knowledge session. The context vector ensures the captured item is retrievable not just by content but by when and what the user was working on.

### macOS AX API Surface

The accessibility API provides three primary capture channels:

1. **`kAXSelectedTextAttribute`**: Returns the currently selected/highlighted text from any AXUIElement that represents an editable or focusable text element. This attribute is required for all accessibility objects representing editable text. Works reliably in Safari, Chrome, TextEdit, Word, and most native AppKit apps.[^17]

2. **`kAXFocusedUIElementAttribute`**: Returns the UI element that currently has keyboard focus. By watching this on the running application's AXUIElement tree, the system can infer when the user's attention shifts between applications and documents.

3. **`AXObserverAddNotification`**: Registers an event-driven observer for specific AX notifications (e.g., `kAXFocusedUIElementChangedNotification`, `kAXSelectedTextChangedNotification`) on a target application's process. This is fundamentally superior to polling: an AXObserver fires only on actual state changes, consuming near-zero CPU in idle, whereas 500ms polling creates ~2% continuous CPU load even during periods of no user activity.[^18][^19]

The coverage gap (~18% of apps, per audit, with sparse or absent AX trees — Electron apps, some game engines, custom-rendered UIs) requires an OCR fallback path. The Screen2AX project (MacPaw, 2025) demonstrates a YOLOv11-based vision model that generates accessibility metadata from screenshots with 65.4% accuracy and 0.204s processing time per frame, a 2.2× improvement over native AX representations. For the described stack, this means: attempt AX attribute read → on failure, trigger ScreenCaptureKit frame capture → pass through Apple's VNRecognizeTextRequest (which achieves state-of-the-art on-device OCR on Apple Silicon) → attach to context.[^20]

### Privacy and Consent Architecture

The Microsoft Recall backlash (2024) provides the single most important negative case study. Recall was enabled **by default** without explicit opt-in consent, captured screenshots continuously into a local database, and was shown to be trivially searchable via plaintext after security researchers (Kevin Beaumont et al.) demonstrated the capture database was not encrypted. Microsoft was forced to reverse course and make Recall opt-in only. The core lesson: **any passive capture system must be opt-in, not opt-out,** and the capture scope must be granularly controllable per-application.[^21]

Granola's approach is instructive as a positive model: meeting-scoped capture (audio only, for meetings), with explicit automated consent messaging sent in-meeting chat at the start of each session. Granola's UX differentiator is framing the "no creepy bots" advantage while still requiring users to proactively obtain third-party consent. The lesson for a single-user PKS is different: the consent issue is self-consent (the user decides what apps to monitor), but the **granularity** of per-app opt-in is essential. A UI showing a list of monitored apps (similar to macOS Privacy & Security → Accessibility) with per-app toggles satisfies both the technical requirement and the user's mental model of control.[^22][^23][^24]

### Implementation Patterns

```swift
// Swift side: register AXObserver for focused element changes
func startAXMonitoring(pid: pid_t) {
    var observer: AXObserver?
    AXObserverCreate(pid, axCallback, &observer)
    let element = AXUIElementCreateApplication(pid)
    AXObserverAddNotification(observer!, element, 
        kAXFocusedUIElementChangedNotification as CFString, nil)
    AXObserverAddNotification(observer!, element, 
        kAXSelectedTextChangedNotification as CFString, nil)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), 
        AXObserverGetRunLoopSource(observer!), .defaultMode)
}
```

On the Rust side, receive the captured text via FFI, run `model2vec-rs` to embed it (~1ms), attach a `captured_from` context vector (the active note's current embedding), and insert into GRDB with FTS5 tokenization. This dual-index approach enables both semantic retrieval (HNSW) and exact-phrase search (FTS5).

For apps with sparse AX trees, ScreenCaptureKit's `SCStreamConfiguration` can be set to capture only specific windows at reduced frequency (1 fps when user is idle, 0 fps when app is in background) to minimize performance impact. Pass frames through VNRecognizeTextRequest on a concurrent DispatchQueue, not the main thread.

### UX Pitfalls

- **Capture anxiety:** Users lose trust if they can't clearly answer "what is being captured right now?" A persistent menubar icon with a live log of the last 3 captured items, dismissable with one click, solves this.
- **Noisy capture sources:** Browser URL bars, autocomplete dropdowns, and tooltips all trigger `kAXSelectedTextChangedNotification`. Implement a minimum-length filter (>10 characters) and a source-type filter (skip `kAXRole == AXTextField` for single-line inputs).
- **App exclusion gaps:** Password managers, banking apps, and medical apps should be excluded from AX monitoring by default, with a pre-seeded blocklist (1Password, Keychain, banking app bundle IDs).
- **Data localization:** All captured data must remain in the local SQLite database, never transmitted. Surface this prominently in the UI: "All captured knowledge stays on your Mac."

***

## Capability 3: Cognitive Friction Detection via Edit Telemetry

### Cognitive Science Justification

The Hayes-Flower cognitive writing model (1981) establishes that writing comprises three recursively nested processes: **Planning** (constructing a mental representation), **Translating** (converting plans to text), and **Reviewing** (evaluating and revising). A 2025 study using 135,178 observations from 4,618 keystroke-logging sessions confirmed all three phases with unsupervised ML clustering: Planning occupied 43.5% of writing time (characterized by 94.7% pause time within each interval), Translating 46.3% (dominated by word production), and Revising 10.2%. This provides an empirically validated mapping from keystroke telemetry patterns to cognitive phase.[^25][^26][^27][^28]

Research on **P-burst analysis** (from Alves, Limpo, and colleagues) decomposes writing into production bursts delimited by pauses exceeding a threshold (typically 2 seconds for L2 writers, adjustable by user baseline). Key findings: P-bursts for conceptually demanding content (final claims, primary arguments) are longer in duration but lower in production fluency — fewer characters per second — compared to P-bursts for supporting detail. This means a real-time friction score can be derived from the ratio of characters produced to inter-keystroke interval within a burst: short bursts with high revision-to-production ratios signal cognitive difficulty, while long bursts with low revision rates signal flow.[^29]

Csikszentmihalyi's flow theory, operationalized through keystroke dynamics research, provides the other anchor. Flow is operationally defined as "action-awareness merger with loss of self-consciousness," and it correlates behaviorally with low inter-keystroke interval variance, long uninterrupted burst duration, and near-zero revision rate. The classification of task-unrelated thoughts (mind-wandering) vs. task-engaged writing is detectable from keystroke patterns with above-chance accuracy using behavioral signals alone.[^30][^31]

### Behavioral Signals and the Friction Score

From the described append-only OpLog (capturing insertions, deletions, cursor movements, pauses), the following signals are most diagnostically valid:

| Signal | Cognitive Interpretation | Implementation |
|--------|------------------------|----------------|
| Pause > 2s before deletion | Pre-revision evaluation; high cognitive load | OpLog: gap between `cursor_move` and `delete` event |
| Revision-to-production ratio (RPR) | High RPR = strong reviewing phase, potential friction | Count `delete` bytes / `insert` bytes per paragraph |
| Mean inter-keystroke interval (IKI) | High IKI = slower production, higher load | Timestamp deltas between `insert` events |
| Burst duration | Long smooth bursts = flow; short choppy bursts = friction | Segment OpLog by 2s silence threshold |
| Cursor backtracking distance | Long backward jumps = structural revision, high load | Cursor position deltas in OpLog |
| Paragraph-boundary pause | > 5s suggests planning phase transition | Detect newline insertion preceded by long pause |

A composite **Friction Score** \(F_t\) per writing session can be computed as:

\[
F_t = \alpha \cdot \text{RPR}_t + \beta \cdot \overline{\text{IKI}}_t + \gamma \cdot (1 - \text{BurstSmooth}_t)
\]

where \(\alpha, \beta, \gamma\) are learnable weights calibrated against the user's personal baseline (first 20 sessions), and `BurstSmooth` is the autocorrelation of keystroke intervals within a burst (high autocorrelation = smooth, predictable = flow). This avoids the observer effect problem (where knowing friction is being measured changes behavior) by never displaying the raw score to the user during writing.

### Competitive Landscape

| Tool | What It Measures | What It Misses |
|------|-----------------|----------------|
| Draftback (Google Docs) | Playback reconstruction of edit history, timeline of changes | Purely retrospective; no real-time signal; no cognitive interpretation |
| Writefull | Word count, session duration, writing pace | No pause analysis, no revision-to-production ratio |
| Grammarly | Productivity score (words/hour), clarity score | Surface-level; gamified; no cognitive-phase awareness |
| iA Writer | Focus mode (hides UI), no analytics | Addresses flow but doesn't detect or respond to friction |

None of the existing tools compute real-time friction from edit telemetry, nor do they distinguish between productive revision (writer is improving) and stuck revision (writer is looping without progress). The stuck-revision signal is specifically: RPR > 0.8 for more than 60 consecutive seconds on the same paragraph, combined with cursor movements that stay within a 50-character window (indicating the writer is circling without advancing).

### Implementation Patterns

The OpLog already captures every mutation. The friction computation pipeline runs as a Rust background actor (no FFI overhead), consuming OpLog events and maintaining a rolling 60-second sliding window:

```rust
struct FrictionState {
    window: VecDeque<OpEvent>,      // rolling 60s buffer
    last_embed_pos: usize,           // cursor pos at last embedding
    rpr: f32,                        // revision-to-production ratio
    mean_iki: Duration,              // mean inter-keystroke interval
    burst_smooth: f32,               // burst autocorrelation
}

impl FrictionState {
    fn update(&mut self, event: &OpEvent) -> FrictionScore {
        self.window.push_back(event.clone());
        self.evict_stale();
        let rpr = self.compute_rpr();
        let iki = self.compute_mean_iki();
        let bs = self.compute_burst_smoothness();
        FrictionScore { value: 0.4*rpr + 0.3*iki.as_secs_f32()/3.0 + 0.3*(1.0-bs) }
    }
}
```

The Swift UI layer subscribes to friction score updates via the Rust FFI channel. When friction exceeds the user's 85th percentile baseline for 90+ seconds, the system can surface a non-intrusive ambient cue (e.g., a subtle pulsing of the contextual shadows panel, suggesting the user look at related past writing for unsticking inspiration) — rather than a text notification, which would break flow.

**Metacognitive interventions that work:** Research on self-regulated writing strategies shows that the most effective interventions are brief, specific, and embedded in the workflow — not separate tools. Prompts that ask "What's the one thing you're trying to say here?" outperform generic "take a break" nudges. The implementation implication: friction-triggered prompts should be contextually aware (use the FTS5 index to find the most common phrase in the paragraph being struggled with, then surface related past notes) rather than generic.

### UX Pitfalls

- **Direct score display during writing destroys flow.** Never show the friction score as a visible HUD during an active writing session. Only surface it in post-session analytics.
- **False positive baseline mismatch:** Academic writing, code documentation, and creative fiction have radically different baseline friction profiles. The score must be calibrated per user over at least 20 sessions before producing actionable signal; label it "calibrating" until then.
- **Patronizing interventions:** Any friction-triggered UI element must be dismissable with a single keystroke and should never interrupt the cursor position or active text.
- **Observer effect:** If users know their typing is being analyzed, they change their typing. Frame the feature as "writing rhythm insights" rather than "cognitive load monitoring" in all UI copy.

***

## Capability 4: Temporal Knowledge Graph — Conceptual Drift and Belief Evolution

### Cognitive Science Justification

Thagard's explanatory coherence theory models belief revision as constraint satisfaction over a network of interconnected beliefs: accepting or rejecting a hypothesis depends on maximizing the coherence of the entire network, not just local pairwise consistency. For a personal knowledge system, this maps naturally to a graph where edges represent evidential, explanatory, and contradictory relationships between notes. When a user's writing about a topic shifts — they introduce new vocabulary, contradict old claims, or reframe a concept — the coherence structure of the local neighborhood changes in ways that are detectable from embedding drift.[^32][^33][^34]

Chi's ontological category shift framework provides a finer-grained taxonomy of conceptual change: (1) **belief revision** — updating an attribute within an existing category (easiest); (2) **mental model transformation** — accumulating multiple belief revisions until a mental model restructures (medium difficulty); (3) **categorical shift** — reassigning a concept to a fundamentally different ontological category (hardest, but most significant). For a personal PKS, categorical shifts are the signal of genuine intellectual breakthrough — detectable when a concept's embedding vector moves out of its original semantic neighborhood entirely, not just gradually drifting within it.[^35][^36][^37][^38]

Hamilton et al.'s foundational work on diachronic word embeddings establishes two quantitative laws of semantic change that apply directly to personal concept drift: (1) the **law of conformity** — concepts used frequently in the vault change meaning more slowly (they're "anchored" by many usages); (2) the **law of innovation** — polysemous concepts (used in many different contexts) change faster. In a personal PKS, this predicts that a user's most heavily linked "evergreen" concepts (the nodes with highest degree in the knowledge graph) will exhibit the most stable embeddings over time, while exploratory, recently-introduced concepts will show high drift. Both patterns are computationally measurable.[^39][^40][^41][^42]

### Implementation Patterns

The key data structure is a **time-sliced embedding archive**: for each note node in the graph, store a vector of `(timestamp, embedding_vector)` pairs. Serialize these into SQLite using BLOB columns for the vectors, indexed by `(note_id, epoch_bucket)` where `epoch_bucket` is a week or month granularity integer.

```sql
CREATE TABLE concept_snapshots (
    note_id     TEXT NOT NULL,
    epoch       INTEGER NOT NULL,  -- week number since epoch
    embedding   BLOB NOT NULL,      -- f32 array, 256-dim Model2Vec
    centrality  REAL,               -- PageRank at time of snapshot
    cluster_id  INTEGER,            -- Louvain community at snapshot
    PRIMARY KEY (note_id, epoch)
);
```

**Semantic drift detection** between epoch T1 and T2 is cosine distance between aligned embedding vectors:

\[
\text{drift}(n, T_1, T_2) = 1 - \frac{\mathbf{e}_{n,T_1} \cdot \mathbf{e}_{n,T_2}}{\|\mathbf{e}_{n,T_1}\| \cdot \|\mathbf{e}_{n,T_2}\|}
\]

Hamilton et al. recommend computing drift against a sliding reference point (e.g., a 90-day centered average embedding) rather than against the earliest snapshot, to avoid long-range alignment errors accumulating. For personal-scale corpora (~1K–50K notes), exact cosine distance is fast enough without approximate methods; there is no need for HNSW in this temporal comparison path.[^43][^39]

**Graph diffing** for topological change detection proceeds as: (1) snapshot the Louvain community assignments and PageRank scores for all nodes at epoch T; (2) compare against T-1 snapshot; (3) flag nodes that changed community membership (conceptual cluster migration) or exhibited >20% PageRank change (shift in structural importance). The `codemem-vector` crate's integration of usearch HNSW with petgraph's 25 graph algorithms (including PageRank) provides an off-the-shelf Rust-native implementation.[^12][^13]

**Categorical shift detection** (the rarest but most significant event) requires detecting when a node's nearest semantic neighbors in the embedding space have changed substantially — not just that the node's embedding drifted, but that its entire semantic neighborhood is different. Compute the Jaccard similarity between the node's top-20 HNSW neighbors at T1 vs T2; if Jaccard < 0.3, flag as potential categorical shift.

For visualization, Beck et al.'s taxonomy of dynamic graph visualization recommends **time-to-space mapping** (side-by-side snapshots) over animation for analytical tasks, since animation creates change blindness for subtle topological shifts. The Metal graph renderer can render two temporally adjacent snapshots in a split view with highlight overlays showing changed edges and drifted nodes — using color temperature (cool = stable, warm = drifted) to encode change magnitude without requiring the user to watch an animation.[^44][^45]

### UX Pitfalls

- **Drift without interpretation is anxiety-inducing.** A user seeing that their notes about "machine learning" have drifted 0.42 cosine distance over 6 months doesn't know if that's good (intellectual growth) or bad (inconsistency). The display must pair drift with a narrative: "Your understanding of ML has evolved significantly — you've moved from supervised learning focus to architectural concerns."
- **Snapshot frequency vs. storage:** Weekly snapshots of 768-dim embeddings for 10,000 notes = ~800MB/year. At 256-dim (Model2Vec default), this is ~260MB/year — acceptable. Use Model2Vec's quantized i8 weights for the archived snapshot vectors (not search-time inference).
- **Temporal granularity mismatch:** Conceptual drift operates on month–year timescales, not day timescales. Displaying drift at daily granularity creates noise with no signal; weekly to monthly granularity is appropriate.

***

## Capability 5: Night Brain — Autonomous Background Processing

### Cognitive Science Justification

Ebbinghaus's forgetting curve remains one of the most replicated findings in cognitive psychology: without review, approximately 67% of learned material is forgotten within 24 hours, with the steepest decline in the first two hours post-encoding. The key insight for personal knowledge management is that **the forgetting curve can be dramatically flattened by the timing of review, not just its frequency**: reviewing material at increasing intervals (spaced repetition) produces 10–30% better retention than massed review. A nightly processing pipeline that flags notes for review based on time-since-access can implement a soft Leitner-system equivalent without requiring the user to actively manage flashcard decks.[^5][^4]

Andy Matuschak's work on evergreen notes extends this to a PKS-specific observation: because dense associative note-taking requires constant rereading and revision of past writing, it naturally approximates spaced repetition — the review interval follows the user's present interests rather than a fixed schedule. The Night Brain pipeline formalizes this: instead of waiting for the user's interests to organically surface old notes, the system computes which past notes are semantically proximate to current active work but have not been accessed recently, and queues them for the next session's Contextual Shadows panel.[^46]

### macOS Background Processing APIs

**NSBackgroundActivityScheduler** (macOS 10.10+) is the correct primitive for Night Brain. It submits work to the system's activity scheduler, which determines the optimal time based on battery charge level, thermal state, and system idle status. Setting `qualityOfService = .background` and `interval = 3600 * 6` (6 hours) instructs the scheduler to run the task approximately nightly when the system is plugged in and idle.[^47][^48]

```swift
let nightBrain = NSBackgroundActivityScheduler(identifier: "com.pkm.nightbrain")
nightBrain.interval = 6 * 3600
nightBrain.repeats = true
nightBrain.qualityOfService = .background
nightBrain.schedule { completion in
    guard ProcessInfo.processInfo.thermalState == .nominal else {
        completion(.deferred) // reschedule if thermally constrained
        return
    }
    Task { await NightBrainPipeline.run(); completion(.finished) }
}
```

**Thermal state monitoring** is critical: Apple Silicon's thermal state can escalate from `.nominal` to `.serious` under sustained background load, triggering App Nap and potentially throttling the CPU. The pipeline should checkpoint after each major phase (re-indexing, digest generation, graph snapshot) and gracefully defer if thermal state deteriorates. Use `ProcessInfo.processInfo.isLowPowerModeEnabled` as an additional gate — when Low Power Mode is active, skip the computationally expensive HNSW rebuild and only perform lightweight FTS5 re-indexing.

Apple's Photos ML processing model (recognized people clustering, scene analysis) provides the production reference implementation. Photos runs its agglomerative clustering algorithm periodically overnight during device charging; face embedding generation completes in < 4ms on the Apple Neural Engine (ANE), and incremental cluster updates process 1,000 new photos in ~2.1 seconds vs. 47 seconds for full-library re-indexing. This confirms that the incremental-only processing strategy is not just theoretically correct but measurably critical for overnight background workload sizing.[^49][^50]

### Incremental HNSW Re-indexing

The usearch `add()` API enables incremental vector insertion without full rebuild. For Night Brain, the delta indexing strategy is:[^11][^10]

1. At session end, maintain a **dirty set** of note IDs that were modified since the last Night Brain run (tracked in GRDB).
2. Night Brain processes only the dirty set: re-embed each dirty note via model2vec-rs, call `usearch::Index::add()` for new notes and `usearch::Index::remove()` + re-add for modified notes.
3. After 10% or more of the index has been modified (soft threshold), trigger a full HNSW rebuild during the next Night Brain window to reclaim index quality.

The "unreachable points" problem from deletions — nodes that become graph-isolated under the HNSW structure — is managed by the 10% threshold rebuild, which runs during idle charging time when performance budget is unconstrained.[^14]

**SPFresh** (2024) proposes LIRE (Lightweight Incremental Rebalancing) for billion-scale in-place vector updates that split partitions and reassign boundary vectors. At personal-PKS scale (~50K notes), usearch's simpler `add()`/`remove()` API is sufficient; SPFresh-style rebalancing becomes relevant only above ~500K vectors.[^51]

### Orphan Knowledge Detection

An "orphan" in this system is a note with high potential relevance to current work but low recent access — a concept that has fallen out of the user's working set despite remaining semantically connected. The detection algorithm combines three signals:

\[
\text{orphan\_score}(n) = \text{sem\_sim}(n, \text{current\_context}) \cdot (1 - \text{recency\_score}(n)) \cdot (1 - \text{centrality\_norm}(n))
\]

where `sem_sim` is cosine similarity between the note's embedding and the centroid of notes accessed in the last 7 days, `recency_score` is normalized days since last access (0 = not accessed in > 30 days), and `centrality_norm` is the node's normalized PageRank within the knowledge graph (high-centrality nodes are already well-connected, less likely to be forgotten). Notes above the 85th percentile orphan score are queued for the next day's Contextual Shadows panel with a visual "rediscovered" badge.

### UX Pitfalls

- **Silent failure invisibility:** If Night Brain fails (thermal deferral, crash), the user should see an indicator in the next session: "Last vault optimization: 3 days ago." Silent failures degrade index quality without explanation.
- **Cognitive digest length:** Generated digests of overnight processing ("3 concepts drifted significantly, 7 orphan notes identified, index rebuilt 12% delta") should be scannable in < 30 seconds. Do not generate LLM prose summaries that require reading.
- **Processing during non-charging state:** Night Brain running on battery causes battery anxiety and may wake the user (fan noise). The `isLowPowerModeEnabled` gate and a hard check for `ProcessInfo.processInfo.powerState == .full` are non-negotiable.

***

## Capability 6: Spatial Graph Interaction — Physics-Driven Thinking Canvas

### Cognitive Science Justification

Barbara Tversky's research on spatial cognition establishes its primacy as the foundation of abstract thought — the same cortical circuits that encode physical navigation also encode abstract conceptual relationships, with the hippocampus and neighboring areas supporting both spatial and non-spatial knowledge organization. Her book *Mind in Motion* argues that movement, not language, forms the substrate of human cognition — which grounds the intuition that physically rearranging notes on a canvas is not a metaphor for thinking but a form of thinking itself.[^52][^53][^54]

Kirsh and Maglio's theory of **epistemic actions** provides the operational mechanism: physical manipulations of external representations that are not aimed at achieving a goal state but at making computation easier — restructuring the problem environment to reduce internal cognitive load. When a user drags a note cluster closer to another on a graph canvas, they are not just moving data; they are restructuring their inferential landscape, making connections visible that were previously mental. The key insight for implementation is that the physics simulation must be **responsive enough that drag feels like direct manipulation** — latency > 50ms between drag gesture and node movement breaks the epistemic action loop and converts it back into manipulation of an inert UI element.[^1]

Cognitive maps research confirms that both map-like (continuous, Euclidean) and graph-like (topological, relational) representations exist in the mind simultaneously, with the format depending on environmental structure. For a PKS graph canvas, this means users naturally form both types of representations — they expect spatial proximity to reflect semantic proximity, but they also build topological intuitions about connectivity paths. Both must be satisfiable in the layout.[^55][^56]

### Competitive Landscape

| Tool | Spatial Paradigm | Strength | Critical Weakness |
|------|-----------------|----------|-------------------|
| Obsidian Canvas | Free-form drag-drop markdown cards | Low friction entry; familiar for Obsidian users | No semantic layout awareness; graph proximity ≠ semantic proximity |
| Scapple | Unconstrained spatial notes, optional connections | Maximum freedom; good for early brainstorm | No automatic layout; becomes unmaintainable at scale |
| TheBrain | Hierarchical "parent–child–sibling" graph | Strong for taxonomic knowledge | Too rigid for associative, exploratory thinking |
| Heptabase | Card-based whiteboard ($1.7M seed) | Good UX for card placement | No physics simulation; no semantic layout grounding |
| Cosma | Static force-directed site generation | Good visual output | No interactivity; read-only |

The consistent gap across all competitors: none of them ground spatial layout in semantic embedding similarity. A node's position in Obsidian Canvas is purely user-defined; there is no force that makes semantically similar notes tend toward proximity. The described Metal graph renderer with Rust physics is uniquely positioned to close this gap.

### Metal/GPU Physics at 120fps

The force-directed graph layout problem is an N-body simulation: each node exerts repulsive forces on all others, while edges exert attractive forces. Naïve O(N²) computation fails at 10K+ nodes. **Barnes-Hut** reduces this to O(N log N) by using a hierarchical octree: when the ratio of cell size to particle distance falls below θ (typically θ = 1.0), the entire cell is approximated as a single mass at its center of gravity. At θ = 1.0, approximation error is ~5% of a single pixel distance vs. brute force, entirely imperceptible to the user.[^57][^58][^59]

A 2025 stochastic extension of Barnes-Hut demonstrates up to 9.4× performance improvement over standard deterministic Barnes-Hut for GPU computation by using BH traversal as a control variate for an unbiased stochastic estimator. On Apple Silicon's unified memory architecture, the octree data structure can reside in shared Metal `MTLBuffer` memory accessible by both CPU and GPU without copy overhead — the M-series chips' advantage for this workload is precisely that there is no PCIe transfer bottleneck between CPU-built octree and GPU force computation.[^57]

For 10K+ nodes at 120fps on M-series hardware, the practical implementation is:

1. **CPU (Rust):** Build octree on each frame from current node positions, O(N log N).
2. **GPU (Metal compute shader):** Each thread computes the force on one node by traversing the octree, using the θ approximation criterion. Use Metal's `threadgroupMemory` for Barnes-Hut cell cache sharing within a threadgroup.
3. **Velocity Verlet integration** (second-order, stable): \(\mathbf{x}_{t+1} = \mathbf{x}_t + \mathbf{v}_t \Delta t + \frac{1}{2}\mathbf{a}_t \Delta t^2\) — more stable than first-order Euler at large timesteps, important for responsive drag interaction.
4. **Semantic force augmentation:** In addition to the standard repulsive/attractive pair, add a weak semantic attractive force between nodes with cosine similarity > 0.7 (computed nightly by Night Brain, not per-frame). This "semantic gravity" gradually pulls related clusters together without requiring the user to manually arrange them.

### Gesture-Semantic Operations

HCI research on direct manipulation of abstract concepts confirms that gestures achieve their cognitive benefit only when the gesture-action coupling is **transparent and reversible**:

- **Pinch-to-synthesize (two nodes → new summary note):** Trigger a local MLX inference call to generate a one-sentence synthesis of the two pinched notes. Create a new HNSW node at the midpoint embedding. This is epistemically powerful: the gesture externalizes the synthesis act rather than making it purely mental.
- **Lasso-to-summarize (cluster → digest):** Select a topological cluster by gesture, generate a cluster summary via on-device MLX, display as an overlay card. The lasso gesture's shape implicitly defines the "boundary of interest," which is more natural than selecting nodes individually.
- **Drag-to-relate (edge creation by drag):** Dragging one node onto another creates a bidirectional edge. The semantic distance (cosine similarity) is displayed as an edge label, giving the user immediate feedback on whether the connection they've created is semantically grounded.

### The Map ≠ Territory Problem

The most fundamental UX challenge for the spatial canvas is that **spatial proximity creates a false reality**: users begin to believe notes that are visually close are semantically related, even when the proximity is the result of manual arrangement rather than semantic force. Mitigations:

1. **Layout mode selector:** Provide three explicit layout modes — "Semantic" (force layout driven by embedding similarity), "Temporal" (proximity = recency, most recent notes toward center), "Manual" (user-controlled, no auto-forces). Display the active mode prominently; never mix modes silently.
2. **Semantic distance tooltip:** When hovering over an edge or hovering near a node pair, display the cosine similarity score between them. If two manually placed nodes have cosine sim < 0.3, display a subtle "low semantic affinity" indicator.
3. **Layout drift prevention:** In Semantic mode, dampen the semantic forces enough that user-dragged nodes stay where they are placed for 10 seconds before being gently pulled back toward their semantic equilibrium position. This preserves epistemic action (the drag has cognitive value) while maintaining long-term layout coherence.

### UX Pitfalls

- **Hair-ball collapse at scale:** Force-directed layouts at 10K+ nodes produce unintelligible hair-balls without hierarchical zoom and level-of-detail clustering. Implement community detection (Louvain algorithm, available in petgraph) to show cluster-level layout at zoom-out and node-level layout at zoom-in, with a smooth Metal-rendered LOD transition.
- **Gesture ambiguity:** Pinch-to-zoom (standard trackpad gesture) must not conflict with pinch-to-synthesize. Distinguish by velocity: slow pinch = synthesize, fast pinch = zoom.
- **120fps thermal cost:** Continuous physics simulation at 120fps is thermally unsustainable during battery use. Gate 120fps to plugged-in or user-explicit "performance mode"; default to 60fps simulation, 120fps rendering (Metal ProMotion) on battery.
- **Undo graph:** Every gesture-based semantic operation (synthesis, relation creation) must be undoable with Cmd-Z. The graph's OpLog (analogous to the text OpLog) must be append-only and replayable.

***

## Cross-Capability Synthesis

### Stack Integration Architecture

All six capabilities share the same Rust backend actor model:

```
Swift UI ←→ Rust FFI boundary ←→ Async Rust Runtime (Tokio)
                                    ├── EmbeddingActor (model2vec-rs, CPU)
                                    ├── HNSWActor (usearch, incremental)
                                    ├── GraphActor (petgraph + codemem-vector)
                                    ├── FrictionActor (OpLog consumer)
                                    ├── CaptureActor (AXObserver events)
                                    └── NightBrainScheduler (NSBackgroundActivityScheduler)
```

The append-only OpLog is the single source of truth for Capabilities 3, 4, and 5. Every mutation (text edit, graph edge creation, AX capture event) appends to the OpLog with a monotonic timestamp; all downstream actors read from the OpLog rather than from each other, ensuring there are no circular dependencies and the system is fully replayable for debugging.

### Capability Interaction Map

| Capability | Feeds Into | Consumes From |
|-----------|-----------|--------------|
| Contextual Shadows (1) | — | HNSW index, Night Brain's orphan queue |
| Cross-App Capture (2) | HNSW index, FTS5 index | AXObserver events, ScreenCaptureKit |
| Friction Detection (3) | Night Brain analytics | OpLog |
| Temporal Graph (4) | Night Brain visualization | HNSW snapshots, OpLog |
| Night Brain (5) | Contextual Shadows queue, Temporal Graph snapshots | OpLog, HNSW dirty set |
| Spatial Graph (6) | Graph edge creation → OpLog | HNSW embeddings, Temporal Graph centrality |

### Privacy and Trust Architecture

Every capability that touches user data must satisfy the following non-negotiable invariants for a local-first, no-cloud system:

1. **No network egress:** All models (Model2Vec, MLX inference) run on-device. The Sandbox entitlements should explicitly deny outbound network connections for the core PKS process.
2. **Capability-scoped permissions:** AXUIElement access, ScreenCaptureKit access, and microphone access (if capturing meeting audio) should each be requested separately, with per-capability revocation UI.
3. **Encrypted-at-rest vault:** The SQLite database should be encrypted using SQLCipher (available as a GRDB plugin) with a key derived from the user's macOS Keychain entry.
4. **Audit log:** A human-readable log of all ambient capture events (what was captured, from which app, at what time) should be accessible from the app's Privacy settings panel, with a one-click "delete all captures from this app" function.

The Microsoft Recall lesson, Granola's burying of consent information, and the CACM lifelogging retrospective's "selectivity, not total capture" principle all converge on the same architectural recommendation: **build consent and transparency as first-class data structures, not as UI afterthoughts.**[^24][^21][^15]

---

## References

1. [[PDF] Interaction, External Representation and Sense Making - David Kirsh](https://adrenaline.ucsd.edu/kirsh/Articles/Interaction/Kirsh-Interaction.pdf) - Why do people create extra representations to help them make sense of situations, diagrams, illustra...

2. [Designing for the periphery of our attention: a study on Ambient ...](http://www.feiramoderna.net/2010/07/07/designing-for-the-periphery-of-our-attention/) - This paper discusses a specific category of information systems known as Ambient Information Systems...

3. [[Video] Designing Calm Technology in IoT](https://www.verytechnology.com/insights/video-designing-calm-technology-in-iot) - Ambient Awareness (or Peripheral Attention). Ambient awareness makes use of our peripheral attention...

4. [Teaching Strategies for Students | The Ebbinghaus Forgetting Curve](https://www.structural-learning.com/post/ebbinghaus-forgetting-curve) - The forgetting curve reveals that without review, students lose up to 70% of new information within ...

5. [Replication and Analysis of Ebbinghaus' Forgetting Curve | PLOS One](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0120644) - We conclude that the Ebbinghaus forgetting curve has indeed been replicated and that it is not compl...

6. [AI Essentials: How to Use Rewind.ai to Record, Search, and ...](https://chalktalkai.substack.com/p/ai-essentials-how-to-use-rewindai) - Continuous screen and audio recording · Voice-to-text transcription · Instant search across all capt...

7. [Tired of Rewind.ai's 'record everything' approach? I'm building ...](https://www.reddit.com/r/macapps/comments/1mo9p03/tired_of_rewindais_record_everything_approach_im/) - Hey friends, The idea of a "second brain" like Rewind ai is powerful, but their "record everything" ...

8. [Minish's Post - LinkedIn](https://www.linkedin.com/posts/minish-lab_weve-just-released-model2vec-rs-our-official-activity-7330124806442340352-yQlN) - We've just released model2vec-rs – our official Rust port of Model2Vec! With model2vec-rs, you get: ...

9. [GitHub - MinishLab/model2vec-rs: Official Rust Implementation of ...](https://github.com/MinishLab/model2vec-rs) - Model2Vec is a technique for creating compact and fast static embedding models from sentence transfo...

10. [Unum · USearch 2.24.0 documentation - GitHub Pages](https://unum-cloud.github.io/USearch/) - USearch and FAISS both employ the same HNSW algorithm, but they differ significantly in their design...

11. [USearch | Billion-Scale Similarity Search - Unum Cloud](https://www.unum.cloud/usearch) - USearch implements the HNSW algorithm, identical to FAISS and Hnswlib. ... USearch provides native b...

12. [codemem_vector - Rust - Docs.rs](https://docs.rs/codemem-vector/latest/codemem_vector/) - codemem-vector: HNSW vector index for Codemem using usearch. Provides persistent, incremental, SIMD-...

13. [codemem-vector - crates.io: Rust Package Registry](https://crates.io/crates/codemem-vector/0.6.1) - Key Features. Graph-vector hybrid architecture -- HNSW vector search (768-dim) + petgraph knowledge ...

14. [Enhancing HNSW Index for Real-Time Updates: Addressing Unreachable
  Points and Performance Degradation](https://arxiv.org/pdf/2407.07871.pdf) - ...indices, such as HNSW
(Hierarchical Navigable Small World). However, the performance of HNSW and ...

15. [Beyond Total Capture: A Constructive Critique of Lifelogging](https://cacm.acm.org/research/beyond-total-capture/) - Vannevar Bush's 1945 “Memex” vision. UF2 Figure. MyLifeBits by Gordon Bell is a lifetime store of ev...

16. [[PDF] Beyond total capture - Microsoft](https://www.microsoft.com/en-us/research/wp-content/uploads/2020/04/Beyond-total-capture.pdf) - They can be traced back to Vannevar Bush's. 1945 “Memex” vision (a sort of desk) supporting the arch...

17. [kAXSelectedTextAttribute | Apple Developer Documentation](https://developer.apple.com/documentation/applicationservices/kaxselectedtextattribute?language=objc) - The currently selected text within this accessibility object. This attribute is required for all acc...

18. [AXObserverAddNotification - Documentation - Apple Developer](https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification?language=objc) - AXObserverAddNotification. Registers the specified observer to receive notifications from the specif...

19. [AXObserverAddNotification(_:_:_:_:) - Apple Developer](https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification?changes=_9) - AXObserverAddNotification(_:_:_:_:). Registers the specified observer to receive notifications from ...

20. [Vision-Based Approach for Automatic macOS Accessibility Generation](https://arxiv.org/html/2507.16704v1) - Using this benchmark, we demonstrate that Screen2AX delivers a 2.2× performance improvement over nat...

21. [Total Recall? What Infosec Teams Can Learn From Microsoft's Misstep](https://www.corporatecomplianceinsights.com/total-recall-infosec-teams-microsoft-misstep/) - Recall's functionality highlights the particular threat AI poses to our privacy rights. Microsoft's ...

22. [Allow accessibility apps to access your Mac - Apple Support](https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac) - Allow accessibility apps to access your Mac. When a third-party app tries to access and control your...

23. [Getting consent - Granola Docs & Help Center](https://docs.granola.ai/help-center/consent-security-privacy/getting-consent) - Depending on where your meeting participants are located, you may need to get consent from participa...

24. [How Granola enhances note-taking with context and user intent](https://intelligentinterfaces.substack.com/p/how-granola-enhances-note-taking) - Learning #4: Respecting user consent is essential to ethical and user-friendly design. Clear consent...

25. [Automated Detection of Writing Phases: An Unsupervised Learning Validation of the Hayes & Flower Cognitive Writing Model](https://ieeexplore.ieee.org/document/11250401/) - The 1980 Hayes and Flower model established that writing is comprised of three distinct cognitive pr...

26. [[PDF] International Journal of Instruction - ERIC](https://files.eric.ed.gov/fulltext/EJ1106333.pdf) - Hayes and Linda S. Flower: Three Major Processes of Writing. Hayes and Flower (1980) proposed that p...

27. [[PDF] A Review of Writing Model Research Based on Cognitive Processes](https://wacclearinghouse.org/docs/books/horning_revision/chapter3.pdf) - In 1980 Linda Flower and John Hayes proposed a shift from the traditional linear sequence models bei...

28. [Flower, Linda, and John R. Hayes. “A Cognitive Process Theory of ...](https://fsuprelims.weebly.com/composition/flower-linda-and-john-r-hayes-a-cognitive-process-theory-of-writing-ccc-324-dec-1981-365-387) - Flower and Hayes attempt to show a (formal) model of the composing process. Their theory is guided b...

29. [Making sense of L2 written argumentation with keystroke logging](https://www.jowr.org/index.php/jowr/article/view/920) - This study examines associations between writing behaviors manifested by keystroke analytics and the...

30. [Mihaly Csikszentmihalyi - The Flow State, Definition & How-to](https://stillmindflorida.com/mental-health/mihaly-csikszentmihalyi-the-flow-state-definition-how-to/) - The sense of effortless concentration and enjoyment is what psychologist Mihaly Csikszentmihalyi cal...

31. [Flow on the net–detecting Web users' positive affects and their flow ...](https://www.sciencedirect.com/science/article/abs/pii/S0747563204001189) - When Web users' minds flow in virtual space they tend to forget their mind states and their problems...

32. [Coherence](https://computationalcognitivescience.github.io/lovelace/part_ii/coherence) - In this chapter we study a computational-level model of coherence developed by cognitive scientists ...

33. [[PDF] Assessing Explanatory Coherence: A New Method for Integrating ...](https://morenumerate.sri.com/downloads/SchankRanney1992.pdf) - Ranney and Thagard (1988) characterize belief revision as the result of seeking ex- planatory cohere...

34. [Coherence as Constraint Satisfaction - Thagard - Wiley Online Library](https://onlinelibrary.wiley.com/doi/abs/10.1207/s15516709cog2201_1) - This paper provides a computational characterization of coherence that applies to a wide range of ph...

35. [Explorations in promoting conceptual change in electrical concepts via ontological category shift](http://www.tandfonline.com/doi/abs/10.1080/09500690119851) - Chi (1992, 1993) Chi et al. (1994) suggests that many of the difficulties encountered by students in...

36. [A theory of conceptual change for learning science concepts](https://www.sciencedirect.com/science/article/pii/0959475294900175) - The theory of conceptual change in this article explains why some kinds of conceptual change, or cat...

37. [Tackling Misconceptions Through Conceptual Change – Part I](https://3starlearningexperiences.wordpress.com/2019/06/04/tackling-misconceptions-through-conceptual-change-part-i/) - Chi defines conceptual change as the processes of removing misconceptions. According to her (2008), ...

38. [Belief Revision, Mental Model Transformation, and Categorical Shift](https://tipsforteachers.substack.com/p/research-bite-52-three-types-of-conceptual) - Categorical shift is required for robust misconceptions, which are highly resistant to change. This ...

39. [Diachronic Word Embeddings Reveal Statistical Laws of Semantic Change](http://aclweb.org/anthology/P16-1141) - Understanding how words change their meanings over time is key to models of language and cultural ev...

40. [[PDF] Diachronic Word Embeddings Reveal Statistical Laws of Semantic ...](https://cs.stanford.edu/people/jure/pubs/diachronic-acl16.pdf) - In this work, we develop a robust methodol- ogy for quantifying semantic change using embed- dings b...

41. [Diachronic Word Embeddings Reveal Statistical Laws of Semantic ...](https://arxiv.org/abs/1605.09096) - We develop a robust methodology for quantifying semantic change by evaluating word embeddings (PPMI,...

42. [Diachronic Word Embeddings Reveal Statistical Laws of Semantic ...](https://aclanthology.org/P16-1141/) - Diachronic word embeddings reveal statistical laws of semantic change. William L. Hamilton, Jure Les...

43. [Diachronic Word Embeddings Reveal Statistical Laws of Semantic ...](https://aryamccarthy.github.io/hamilton2016diachronic/) - The authors claim to have uncovered two laws of semantic change. The first is the “law of conformity...

44. [[PDF] Perception of Animated Node-Link Diagrams for Dynamic Graphs](http://www.umiacs.umd.edu/~elm/projects/dyngraph/dyngraph.pdf) - In this paper, we study the impact of different dynamic graph metrics on user perception of the anim...

45. [Dynamic graph exploration by interactively linked node ... - PMC - NIH](https://pmc.ncbi.nlm.nih.gov/articles/PMC8423958/) - A visually and algorithmically scalable approach that provides views and perspectives on graphs as i...

46. [Evergreen note maintenance approximates spaced repetition](https://notes.andymatuschak.org/Evergreen_note_maintenance_approximates_spaced_repetition) - This type of note-taking approximates spaced repetition. In particular, the spaced repetition follow...

47. [Blog - NSBackgroundActivityScheduler - Michael Tsai](https://mjtsai.com/blog/2015/09/08/nsbackgroundactivityscheduler/) - If your Mac app needs to run background tasks in an energy efficient way, use NSBackgroundActivitySc...

48. [Run periodic tasks in the background after app terminates in MacOS](https://stackoverflow.com/questions/52296229/run-periodic-tasks-in-the-background-after-app-terminates-in-macos) - I have used NSBackgroundActivityScheduler to schedule a periodic activity, which works fine, when th...

49. [How to Automatically Sort Pictures with Smart Albums in Apple](https://lifetips.alibaba.com/tech-efficiency/automatically-sort-pictures-with-smart-albums-in-apple) - On-Device Indexing: Unlike Spotlight (which indexes filenames and text), Photos builds a parallel in...

50. [Recognizing People in Photos Through Private On-Device Machine ...](https://machinelearning.apple.com/research/recognizing-people-photos) - Photos uses a number of machine learning algorithms, running privately on-device, to help curate and...

51. [SPFresh: Incremental In-Place Update for Billion-Scale Vector Search](https://arxiv.org/pdf/2410.14452.pdf) - ...rebuilding the entire index periodically. However, this approach has
high fluctuations of search ...

52. [[PDF] Embodied spatial cognition - space syntax network](https://www.spacesyntax.net/symposia-archive/SSS4/abstracts/07_Tversky_abstract.pdf) - Embodied spatial cognition. Barbara Tversky. Stanford University, USA. Abstract. What does it mean f...

53. [Barbara Tversky: Spatial Cognition - YouTube](https://www.youtube.com/watch?v=ezUwmEv3MAs) - her theory that spatial thinking is the foundation of abstract thought. While most people were focus...

54. [In her book 'Mind In Motion', Barbara Tversky explains that spatial ...](https://www.facebook.com/movementarchery/posts/morning-sketchesin-her-book-mind-in-motion-barbara-tversky-explains-that-spatial/2607298639386213/) - Morning Sketches: In her book 'Mind In Motion', Barbara Tversky explains that spatial thinking is th...

55. [Structuring Knowledge with Cognitive Maps and Cognitive Graphs](https://pmc.ncbi.nlm.nih.gov/articles/PMC7746605/) - ...locations connected by paths. Here we review evidence suggesting that both map-like and graph-lik...

56. [The format of the cognitive map depends on the structure of the environment.](https://pmc.ncbi.nlm.nih.gov/articles/PMC10872840/) - ...individual variability emerged, with some participants forming Euclidean representations and othe...

57. [Stochastic Barnes-Hut Approximation for Fast Summation on the GPU](https://arxiv.org/html/2506.02219v1) - Our method is well-suited for GPU computation, capable of outperforming a GPU-optimized implementati...

58. [Parallel N-Body Simulation with Barnes-Hut Approximation - GitHub](https://github.com/dileban/nbody-simulation) - This repository contains code that demonstrates the effectiveness of parallelization using MPI and t...

59. [Barnes-Hut N-body Simulation - ISS](https://iss.oden.utexas.edu/?p=projects%2Fgalois%2Fscientific%2Fgpu-bh) - This benchmark simulates the gravitational forces acting on a galactic cluster using the Barnes-Hut ...

