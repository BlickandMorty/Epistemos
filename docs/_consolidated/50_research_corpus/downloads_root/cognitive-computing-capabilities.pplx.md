# Cognitive Computing Capabilities for a Local-First Knowledge System

> **System context:** Native macOS personal knowledge system built with Swift + Rust + Metal + on-device MLX inference. Existing infrastructure: HNSW vector search via usearch in Rust, Metal-accelerated graph renderer with Rust physics, append-only OpLog, NSTextView-based editor with BTK, AXUIElement access via Rust FFI, ScreenCaptureKit, Model2Vec embeddings (~1ms/paragraph), NaturalLanguage framework, GRDB/FTS5 search index. Everything runs locally on Apple Silicon.

---

## Executive Summary

This document specifies six cognitive computing capabilities for a local-first personal knowledge system on macOS. Each capability is grounded in cognitive science research, evaluated against existing products, designed for the specific Swift + Rust + Metal stack, and assessed for UX failure modes that would undermine user trust.

Three cross-cutting themes emerge from the research across all six capabilities:

**1. Ambient over explicit.** The strongest cognitive science evidence — from Klein's Recognition-Primed Decision model through Berntsen's involuntary autobiographical memory research to Weiser's calm technology principles — converges on a single design thesis: knowledge tools should surface information at the periphery of attention without demanding explicit query. Contextual Shadows (Capability 1), Cross-App Capture (Capability 2), and Cognitive Friction Detection (Capability 3) all operationalize this by acting silently and adapting the environment rather than interrupting the user.

**2. The retrieval problem dominates the capture problem.** Gordon Bell's MyLifeBits project and the broader lifelogging literature ([Sellen & Whittaker, "Beyond Total Capture"](https://www.microsoft.com/en-us/research/wp-content/uploads/2020/04/Beyond-total-capture.pdf)) established that total capture without effective retrieval creates "data graveyards." Night Brain (Capability 5) and Temporal Knowledge Graph (Capability 4) directly address retrieval quality by computing semantic relevance, orphan detection, and belief evolution — turning a passive archive into an active cognitive partner.

**3. The physics engine is a cognitive tool, not a layout optimizer.** Kirsh & Maglio's epistemic action research and Tversky's spatial cognition work establish that spatial manipulation of knowledge is not a convenience feature — it is a fundamental cognitive mechanism. The Spatial Graph (Capability 6) treats the Metal-accelerated physics simulation as an epistemic environment where gesture-driven spatial operations create semantic meaning.

The six capabilities share substantial infrastructure: HNSW search (Capabilities 1, 4, 5), the OpLog (Capabilities 3, 4), AXUIElement access (Capability 2), Metal compute shaders (Capabilities 4, 6), GRDB temporal storage (Capabilities 4, 5), and the Leiden community detection algorithm (Capabilities 4, 5, 6). A dependency-ordered implementation sequence is provided in the Cross-Cutting Architecture section.

---

## Capability 1: Contextual Shadows — Ambient Semantic Retrieval

### Cognitive Science Justification

The Contextual Shadows panel — a persistent sidebar that surfaces semantically related notes as the user writes — is grounded in four converging research traditions.

**Gary Klein's Recognition-Primed Decision (RPD) model**, developed through fieldwork with firefighters and military commanders and formalized at the 1989 Naturalistic Decision Making conference, describes how experts make decisions by pattern-matching the current situation against prior experience stored in long-term memory. The expert *knows* what to do because the situation *reminds* them of other situations. Wright and Klein's 2016 review identifies the core macrocognitive functions as sensemaking, mental simulation, leveraging expertise, and maintaining shared awareness ([Wright & Klein, 2016, *Frontiers in Psychology*](https://pmc.ncbi.nlm.nih.gov/articles/PMC4731510/)). The Contextual Shadows panel externalizes the RPD situational recognition mechanism: it surfaces the "prior experience" that an expert mind would match against. Patterson et al.'s 2009 system dynamics model demonstrates that the simplest RPD variation — simple match — dominates expert recall and is precisely what the panel should facilitate ([Patterson et al., 2009](https://www.scienceopen.com/document_file/efb29f77-ce60-437e-b845-5f0e11b57e66/ScienceOpen/113_Patterson.pdf)). The panel should present **complete past notes as units of recognition**, not extracted fragments, because recognition fires on structural pattern similarity rather than keyword overlap.

**Dorthe Berntsen's involuntary autobiographical memory (IAM) research** establishes that spontaneous, cue-driven memories occur *three times more frequently* than voluntary memories in everyday life ([Berntsen & Rubin, 2009, *Memory & Cognition*](https://pmc.ncbi.nlm.nih.gov/articles/PMC3044938/)). IAMs are elicited by external cues that match encoded aspects of the original experience — structural or thematic similarity suffices, not literal content match. Mace (2014) documented involuntary memory chaining operating via "spreading activation" over autobiographical memory organization ([Mace, 2014, *Frontiers in Psychiatry*](https://pmc.ncbi.nlm.nih.gov/articles/PMC4267106/)). The panel's top-K results are the initial links in such a chain, creating conditions for the creative free-association that insight research associates with remote conceptual access.

**Collins and Loftus's spreading activation theory** (1975) provides the computational framework most directly analogous to the pipeline. Concepts are nodes in a semantic network; activation spreads outward along associative links, decaying with semantic distance. Masked priming studies show this operates automatically at SOAs as short as 200ms ([Silkes & Rogers, 2012](https://pmc.ncbi.nlm.nih.gov/articles/PMC4598179/)), consistent with the pipeline's target latency. Bell et al. (2016) extended this to emotional memory networks, showing spreading activation operates over episodic memory and that somatic markers modulate which pathways are traversed ([Bell et al., 2016, *Brain Informatics*](https://pmc.ncbi.nlm.nih.gov/articles/PMC5413589/)). The HNSW search simulates automatic spreading activation: nodes = embedded notes, semantic distance = cosine distance, activation spreading = the neighborhood structure of the HNSW graph.

**The generation effect and recognition vs. recall distinction.** Shimamura, Elman, and Rosner (2013) demonstrated via fMRI that generation activates broad neural circuits during encoding ([Shimamura et al., 2013, *Cortex*](https://pmc.ncbi.nlm.nih.gov/articles/PMC3556209/)). McCurdy et al. (2020) showed that generation under lower constraints produces stronger effects via enhanced relational processing ([McCurdy et al., 2020, *Memory*](https://www.tandfonline.com/doi/full/10.1080/09658211.2020.1749283)). The panel is a **recognition aid** — it reduces cognitive demand from "generate a connection" to "evaluate and accept/reject a presented connection," substantially lowering the barrier to cross-note linking.

**Temporal relevance research** further refines ranking. Healey, Kahana, and Long (2018) established that the temporal contiguity effect is robust across recognition, paired associates, and autobiographical recall, and across timescales from minutes to years ([Healey et al., 2018, *Psychonomic Bulletin & Review*](https://pmc.ncbi.nlm.nih.gov/articles/PMC6529295/)). Folkerts, Rutishauser, and Howard (2018) provided direct neural evidence: recalling an episodic memory reinstates the *temporal context* of the original encoding — "a neural jump back in time" ([Folkerts et al., 2018, *Journal of Neuroscience*](https://www.jneurosci.org/lookup/doi/10.1523/JNEUROSCI.2312-17.2018)). Murre and Dros's 2015 replication of Ebbinghaus confirmed that retention declines rapidly in the first 24 hours, suggesting very recent notes deserve a recency boost ([Murre & Dros, 2015, *PLoS ONE*](https://pmc.ncbi.nlm.nih.gov/articles/PMC4492928/)).

**Ambient information systems.** Mark Weiser and John Seely Brown's 1996 "The Coming Age of Calm Technology" ([MIT CSAIL mirror](https://people.csail.mit.edu/rudolph/Teaching/weiser.pdf)) defines the periphery as "what we are attuned to without attending to explicitly." A technology is encalming if it (1) lives primarily in the periphery, (2) moves easily between center and periphery, and (3) enhances peripheral reach without increasing information overload. Amber Case's 2015 codification operationalizes this: technology can communicate but doesn't need to speak; communicate information without taking the user out of their task ([Principles of Calm Technology](https://www.caseorganic.com/post/principles-of-calm-technology)).

Hiroshi Ishii and Brygg Ullmer's ambient display research at MIT (1997–1998) demonstrated that information encoded as room-level environmental changes is absorbed via background perception without interrupting foreground tasks. Scott Wisneski (MIT, 1998) found that smooth, slow-moving visual changes in low-saturation colors in the spatial periphery of the screen were processed without attention capture, while high-contrast, high-frequency updates captured attention involuntarily. For the panel: low-contrast text on slightly differentiated background; fade-transition between result sets over ~400ms; 3–5 results maximum visible without scroll.

McCrickard and Chewar (2003) developed the **Interruption, Reaction, Comprehension (IRC) framework** for evaluating notification systems ([McCrickard et al., 2003, *IJHCS*](https://linkinghub.elsevier.com/retrieve/pii/S1071581903000223)). A well-designed ambient panel scores low on all three axes: does not interrupt, does not require immediate reaction, and is interpretable at a glance. Their empirical work showed that notification systems with high interruption but low utility create **learned helplessness** — users begin ignoring all outputs. Chewar and McCrickard (2004) further refined this with user goal tradeoffs around non-interruption, awareness, and alerting ([Chewar et al., 2004, *CHI Workshop*](https://dl.acm.org/doi/10.1145/1013115.1013155)).

### Competitive Landscape

| Product | Approach | Strengths | Weaknesses |
|---------|----------|-----------|------------|
| **Mem.ai** | Cloud-side embedding + semantic sidebar ("MemX") | Passive, non-interruptive; semantic matching without taxonomy; Smart Write integration | Cloud dependency (privacy dealbreaker); 500ms–2s latency; context window degradation at scale ([Mem.ai](https://get.mem.ai)) |
| **Rewind.ai / Limitless** | Continuous screen capture + temporal search | Local-first privacy; temporal navigation; low-friction capture | No semantic retrieval; pull-not-push (requires explicit query); no structured knowledge representation ([Reddit r/RewindAI](https://www.reddit.com/r/RewindAI/comments/1lfzpyv/honest_review_after_daily_use_the_gap_between/)) |
| **Notion AI** | OpenAI embeddings over workspace, explicit invocation | Deep integration with structured database properties | Requires explicit invocation (no ambient surfacing); 1–5s cloud latency; workspace-locked |
| **Reflect.app** | Backlink-first + daily note orientation | Fast native app; calendar integration; backlink philosophy mirrors spreading activation | Requires explicit `[[link]]` syntax; no semantic similarity; no ambient semantic push |
| **Obsidian** | Linked/unlinked mentions via exact title match | Collapsible right sidebar is the standard UX pattern; users have internalized this placement | No semantic connections; unlinked mentions fail for cross-register similarity |
| **DEVONthink** | Statistical language analysis ("See Also") | Side inspector panel; document-level similarity; fast incremental model | Triggered by whole document, not cursor context; no vector embeddings; requires re-indexing ([DEVONtechnologies Community, 2025](https://discourse.devontechnologies.com/t/dt4-inner-workings-of-indexing-see-also-similar-documents-thought-about-using-vectorization/82596)) |

**Roam Research** pioneered the linked/unlinked references panel at the bottom of each page — chronologically ordered blocks referencing the current page. This is fundamentally tag/entity-based retrieval, not semantic retrieval. Roam's unlinked references (plain-text mentions of the page title) approximate the "What have I written about this before?" question but operate via exact string matching only.

**Competitive positioning:** The Contextual Shadows panel targets the intersection of Mem's ambient semantic surfacing (but private/on-device), DEVONthink's See Also (but cursor-context-sensitive), and Obsidian's backlinks UX pattern (but embedding-based). No existing system occupies this intersection.

### Technical Implementation Patterns

**Async pipeline architecture (200ms debounce → encode → search):**

```
NSTextView (Swift)
    ↓ NSTextStorage delegate: textDidChange
    ↓ debounce: 200ms (via Combine or async/await Task.sleep)
    ↓ [crossing FFI boundary via Swift-Rust FFI or uniffi]
Rust async worker (tokio runtime, single-threaded dedicated executor)
    ↓ Model2Vec encode: ~1ms
    ↓ HNSW search: top-K, ~2-5ms for 50k notes
    ↓ Temporal re-ranking: ~0.5ms
    ↓ [crossing back via async channel]
Swift MainActor: update NSView panel
```

**Key design choices:**

1. **Dedicated tokio executor for ML/search.** Isolate encode+search on a separate `tokio::runtime::Builder::new_current_thread()` runtime thread to prevent search latency variance from competing with other async work.

2. **Cancel-on-new-input semantics.** Each keypress that resets the debounce timer should cancel the in-flight encode+search Task via `tokio::task::JoinHandle::abort()`. Without cancellation, bursts of typing create a queue of stale encode operations.

3. **Double-buffering the index for writes.** New notes should be added to a staging index and periodically merged into the primary:

```rust
struct SearchEngine {
    primary: Arc<RwLock<HnswIndex>>,   // read frequently, write rarely
    staging: Arc<Mutex<Vec<(u64, Vec<f32>)>>>,  // pending inserts
}
```

4. **Stale reads are acceptable.** A note written 30 seconds ago not appearing in results is fine — the staging buffer can accumulate for up to 30 seconds without perceptible quality degradation.

**HNSW concurrency:** USearch's Rust bindings lack native `Send+Sync` derivation ([GitHub Issue #482](https://github.com/unum-cloud/usearch/issues/482)), requiring `Arc<Mutex<Index>>`. A known integer underflow bug in `Index::size()` during concurrent add/remove operations ([GitHub Issue #697](https://github.com/unum-cloud/usearch/issues/697)) means production code should gate on explicit node counts.

**Streaming HNSW update research.** IP-DiskANN (Xu et al., 2025) presents the first algorithm for true in-place updates without batch consolidation ([arXiv 2502.13826](https://arxiv.org/abs/2502.13826)). Their key insight: the "unreachable points phenomenon" — where deleted nodes create graph disconnections — is the primary failure mode, but insertions-only workloads (the dominant case for personal notes) are substantially easier. CleANN (Zhang et al., 2025) achieves 7–1200x throughput improvement over static baseline at equivalent recall ([arXiv 2507.19802](https://arxiv.org/abs/2507.19802)). Xiao et al. (2024) documents the unreachable points phenomenon and proposes the MN-RU algorithm ([arXiv 2407.07871](https://arxiv.org/abs/2407.07871)). For a personal note corpus of 10K–500K notes with ~1 insertion/minute, standard HNSW insert is entirely sufficient — the literature's concerns apply at much higher update rates.

**Alternative HNSW library:** The `hnswlib-rs` crate ([lib.rs](https://lib.rs/crates/hnswlib-rs)) provides lock-free reads and parallel updates (per-node spinlocks), which is preferable for real-time search during ongoing insertions.

**Temporal ranking formula:**

```
score(note) = semantic_similarity(query, note) × temporal_boost(note)

temporal_boost(note) = α + (1 - α) × decay_factor(age_days)

decay_factor(age_days) = {
  1.0                          if age_days < 1     (same session)
  exp(-λ₁ × age_days)         if 1 ≤ age_days < 30
  exp(-λ₂ × log(age_days))    if age_days ≥ 30    (logarithmic decay)
}
```

With α=0.7, λ₁=0.02, λ₂=0.15. This gives same-session notes 1.0× (no decay), 1-week-old notes ~0.86×, 1-month-old notes ~0.55×, 6-month-old notes ~0.81× (logarithmic regime preserves deep history), and 1-year-old notes ~0.75×. The logarithmic decay for old notes prevents the "archive disappears" failure mode.

**Elasticsearch** implements three decay function families in its `function_score` query: Gaussian, exponential, and linear ([Elasticsearch decay functions](https://www.elastic.co/blog/found-function-scoring)). The Gaussian function is recommended for most relevance applications because it decays smoothly with a natural shoulder near the origin and doesn't decay as aggressively as exponential for distant points. For the note retrieval use case, `boost_mode: "multiply"` ensures semantic relevance dominates.

A 2025 paper on Re³ (Relevance & Recency Retrieval) introduces a learnable gating mechanism for query-adaptive balance — if the user types a date reference, apply stronger temporal gating; if the query is purely conceptual, rely on semantic similarity ([arXiv 2509.01306](https://arxiv.org/html/2509.01306v1)). A practitioner synthesis on the RAG community ([Reddit r/Rag, 2025](https://www.reddit.com/r/Rag/comments/1oy1omu/biologicallyinspired_memory_retrieval_r_bio_sqc/)) proposes a biologically-inspired formula: `R_bio = S(q,c) + α·E(c) + A(c) + w_r·R(c) - w_d·D(c)` where S = semantic similarity, E = emotional weight/salience, A = associative strength, R = recency, D = decay/drift. For personal notes, E can be approximated by note length and A by incoming backlink count.

**Latency budget analysis:**

| Step | Budget | Actual (estimated) |
|---|---|---|
| NSTextView change detection | <1ms | ~0.1ms |
| Debounce wait | 200ms | 200ms |
| FFI crossing (Swift→Rust) | <1ms | ~0.5ms |
| Model2Vec encode (1 paragraph) | ~1ms | ~1ms |
| HNSW search (50k notes, top-10) | 2–10ms | ~4ms |
| Temporal re-rank (10 results) | <0.5ms | ~0.2ms |
| FFI crossing (Rust→Swift) | <1ms | ~0.5ms |
| MainActor UI update | <5ms | ~2ms |
| **Total** | **~300ms** | **~208ms** |

### Critical UX Pitfalls

**The Clippy Problem.** Eric Horvitz's 1999 "Principles of Mixed-Initiative User Interfaces" established why unsolicited AI suggestions fail: interruption timing uncorrelated with user readiness, high dismissal cost, meta-level rather than object-level suggestions, and no learning from rejection. Gluck's 2006 thesis found that matching attentional draw to utility is the critical design principle ([Gluck, 2006](https://www.cs.ubc.ca/labs/imager/th/2006/GluckMScThesis/GluckMScThesis.pdf)). **Mitigations:** No panel-initiated focus steal; no persistence after note access; per-result "not helpful" dismiss; no anthropomorphism or explanatory text.

**Information overload.** McCrickard and Chewar's IRC framework supports 3–5 results maximum for ambient peripheral panels. Show 3 results by default, expandable to 7. Top result at full opacity; 2nd and 3rd at 80% and 60% opacity respectively, creating a visual gradient ([McCrickard et al., 2003](https://linkinghub.elsevier.com/retrieve/pii/S1071581903000223)).

**Filter bubble.** Eli Pariser's 2011 "filter bubble" concept, applied to recommendation systems, describes how personalization feedback loops narrow the content users see. For a semantic retrieval panel, the analogous failure mode is a semantic echo chamber where the panel consistently surfaces notes reinforcing current thinking while suppressing contradictory or adjacent-domain notes. Jiang et al. (2023) and Gao et al. (2023) studied filter bubble effects in recommender systems — feedback-loop amplification, recency-semantic correlation, and domain siloing all apply ([arXiv 1902.10730](https://arxiv.org/abs/1902.10730); [arXiv 2204.01266](https://arxiv.org/abs/2204.01266)). **Mitigations:** (1) Serendipity injection: every 5th result drawn from cosine similarity 0.5–0.7 range (moderately similar, not closely similar), labeled as "tangentially related." (2) Temporal diversity constraint: no more than 2 of 3 visible results from same calendar month. (3) Source diversity: if 2+ results come from the same notebook/folder, demote the 3rd. (4) User-controllable "Explore" vs. "Focus" toggle: Focus = maximize cosine similarity; Explore = enforce diversity constraints.

**Visual design.** Peripheral motion is processed by the superior colliculus — a phylogenetically ancient brain region responsible for orienting responses — before reaching cortical processing. Any visible animation in the panel captures attention reflexively, even during deep focus. Specific risks: instant result swaps trigger involuntary attention shifts on every debounce event; scroll animation triggers motion detection; high-contrast highlighting is pre-attentively salient. **Correct approach:** Crossfade transitions at 400ms (too slow for pre-attentive motion detection); no repositioning animation — new results appear in the same ranked slots; low-contrast result cards (dark text on off-white, no borders, 1px separator lines only); no loading spinners (show previous results if query takes >500ms). Panel width: 240px default, 320px maximum, collapsible with ⌘⇧K.

**Required controls for user agency:** Per-result dismiss ("hide this note from results for this session"); panel collapse with one click or one keyboard shortcut; "pause panel" mode for extended focus periods; panel state persistence (if collapsed, stays collapsed until re-opened).

**Design principles synthesized from research:**

| Principle | Source | Implementation |
|---|---|---|
| Ambient surfacing mimics expert RPD pattern-matching | Klein (1989, 2016) | Panel surfaces whole notes for recognition, not fragments |
| IAM frequency justifies always-on surfacing | Berntsen & Rubin (2009) | Panel is persistent, not invoked |
| Spreading activation → vector neighborhood search | Collins & Loftus (1975) | Model2Vec embeddings + HNSW k-NN |
| Recognition > recall for knowledge integration | Generation effect research | Show note titles + previews, not just metadata |
| Periphery ↔ center movement is encalming | [Weiser & Brown (1996)](https://people.csail.mit.edu/rudolph/Teaching/weiser.pdf) | Panel lives in right edge, pulls into focus on click |
| Attention capture by motion is pre-attentive | Ishii/Wisneski ambientROOM work | 400ms crossfade, no scroll animation |
| Match attentional draw to utility | Gluck (2006), McCrickard & Chewar (2003) | Low contrast, no sound, never steals focus |
| Temporal contiguity predicts relevance | Kahana (1996), Healey et al. (2018) | Temporal boost with decay formula |
| Filter bubble → diversity constraint | Jiang et al. (2023), Gao et al. (2023) | Serendipity injection, temporal diversity |
| Clippy failure → no anthropomorphism | Horvitz (1999), Gluck (2006) | No explanatory text, per-result dismiss |

---

## Capability 2: Ambient Cross-App Knowledge Capture

### Cognitive Science Justification

Ambient cross-app capture is rooted in the lifelogging research tradition originating with Vannevar Bush's 1945 Memex proposal. In "As We May Think" ([The Atlantic, 1945](https://www.theatlantic.com/magazine/archive/1945/07/as-we-may-think/303881/)), Bush articulated that the Memex would serve as "an enlarged intimate supplement to memory," emphasizing associative indexing over hierarchical filing and frictionless capture. Gordon Bell's MyLifeBits project (1998–2007) at Microsoft Research attempted total capture of every life artifact, building SQL Server-based search with hyperlinks, annotations, and clustering ([Microsoft Research](https://www.microsoft.com/en-us/research/project/mylifebits/)).

However, Sellen and Whittaker's critique "Beyond Total Capture" ([Microsoft Research](https://www.microsoft.com/en-us/research/wp-content/uploads/2020/04/Beyond-total-capture.pdf)) found MyLifeBits produced surprisingly little evidence of practical utility: digital archives are "rarely accessed, even when deliberately saved," and total capture was used by "only a small number of people with direct investment in the technology." Their four lessons — selectivity over total capture, cues over high-fidelity facsimiles, clarity about which memory to support, synergy rather than substitution — are the design constraints for this capability.

Steve Mann's 30-year sousveillance research ([ACM](https://dl.acm.org/doi/10.1145/1027527.1027673); [MIT Press](https://direct.mit.edu/pvar/article/14/6/625/18597/Sousveillance-and-Cyborglogs-A-30-Year-Empirical)) provides the ethical framing: personal capture (sousveillance) is qualitatively different from institutional surveillance because data flows toward the individual. The critical ethical line is whether capture reveals information about others without their consent — meeting transcripts and shared documents cross this boundary.

Peter Pirolli and Stuart Card's Information Foraging Theory models humans as rational foragers maximizing "information scent" (value per time cost). The Marginal Value Theorem applies: a user leaves a topic "patch" when the local gain rate falls below the global average ([Pirolli, *Information Foraging Theory*](https://www.peterpirolli.com/ewExternalFiles/31354_C01_UNCORRECTED_PROOF.pdf)). Ambient capture can detect when a topic patch was abandoned prematurely — a note cluster heavily accessed 6 months ago then abandoned represents a depleted patch, but if current work triggers semantic similarity, the patch may have been abandoned prematurely.

A 2024 survey ["Lifelogging As An Extreme Form of Personal Information Management"](https://arxiv.org/html/2401.05767v1) confirms the data graveyard and overload problems: "The vast volume and immense complexity of lifelog archives presents a challenge for users to navigate and analyse these archives." The annual Lifelog Search Challenge (LSC) benchmarking workshop exists specifically because retrieval from large lifelogs is an unsolved research problem. A typical ambient capture system generates approximately 14GB/month of H.264 video (Rewind's estimate) or ~1.5TB per year ([Sellen & Whittaker critique at Stanford HCI](https://hci.stanford.edu/courses/cs247/2011/readings/sellen.pdf)).

### Competitive Landscape

| System | Architecture | Privacy Model | Capture Scope | Retrieval |
|--------|-------------|---------------|---------------|-----------|
| **Rewind.ai / Limitless** | Screenshot every 2s + OCR + H.264 compression | Local-only (but unencrypted at rest) | Total screen + optional audio | Temporal + keyword search; no semantic |
| **Microsoft Recall** (redesigned) | Screenshot every 3–5s + OCR | Encrypted; Windows Hello biometric required | Full screen; opt-in after backlash | Semantic timeline search |
| **Granola** | Scoped to meetings only (Zoom/Meet) | Consent messaging; audio + transcript | Meeting context only | Meeting-scoped |
| **screenpipe** | Event-driven ScreenCaptureKit + Vision OCR | Local + encrypted; open source | Screen + AX events | Structured search |

Microsoft Recall's original failure provides the definitive lesson. Announced May 2024 as a Copilot+ PC feature, it silently took screenshots every 3–5 seconds with an OCR'd text database. Problems: (1) opt-out by default — the psychological framing of "already watching you" created immediate backlash; (2) unencrypted local database — security researcher Kevin Beaumont demonstrated any malware with user-level access could exfiltrate the entire database in seconds; (3) no authentication to view captured data; (4) sensitive content (bank logins, health information) captured indiscriminately ([WIRED, June 2024](https://www.wired.com/story/microsoft-recall-off-default-security-concerns/)). The redesign moved to opt-in, encrypted storage requiring Windows Hello biometric, and improved sensitive content filtering ([VentureBeat](https://venturebeat.com/ai/microsofts-recall-feature-will-now-be-opt-in-and-double-encrypted-after-privacy-outcry); [The Hacker News](https://thehackernews.com/2024/06/microsoft-revamps-controversial-ai.html)).

[Granola](https://docs.granola.ai/help-center/consent-security-privacy/getting-consent) takes a fundamentally different approach: it scopes capture exclusively to meeting contexts (Zoom/Google Meet). This scope reduction has significant privacy-anxiety-reduction effects — users understand what's being captured (meeting audio + transcript), third-party consent is manageable, and the meeting start/end acts as a natural permission bracket. Granola uses AX APIs to open the chat panel, paste consent text, and send.

Kevin Chen's Rewind.ai teardown ([kevinchen.co](https://kevinchen.co/blog/rewind-ai-app-teardown/)) confirmed the full data pipeline: AX APIs for frontmost window metadata → screenshots every 2 seconds via ScreenCaptureKit → on-device OCR via Apple Vision → H.264 compression at 0.5fps → FTS4 SQLite index with Porter stemming. All data stored unencrypted in `~/Library/Application Support/com.memoryvault.MemoryVault/` — readable by any process with Full Disk Access. The recommendation: encrypt the SQLite database and video chunks using a key stored in the macOS Keychain, requiring biometric authentication.

[screenpipe](https://rewind.sh) is the leading open-source alternative, built in Rust with an event-driven capture model: "captures your screen using an intelligent event-driven system that triggers on actual user activity instead of continuous polling." Per-app exclusion list including incognito detection; all OCR and storage in Rust.

### Technical Implementation Patterns

**Core AXUIElement pipeline.** The canonical pattern for reading selected text from a third-party app is a two-step attribute copy using `AXUIElementCreateApplication(pid)` → `kAXFocusedUIElementAttribute` → `kAXSelectedTextAttribute` ([Apple Developer](https://developer.apple.com/documentation/applicationservices/kaxselectedtextattribute)). AX APIs must be called on the main thread — background thread calls produce undefined behavior ([Stack Overflow](https://stackoverflow.com/questions/64435187/can-the-functions-in-axuielement-h-be-safely-called-from-threads-other-than-the)). The recommended FFI architecture: Swift handles all AX interactions on the main thread; Rust processes downstream embedding, storage, and search indexing.

**AX coverage reality.** The [Screen2AX paper (MacPaw, July 2025)](https://arxiv.org/html/2507.16704v1) analyzed 99 popular and 452 randomly selected macOS apps: only **36.4%** of popular apps provide full AX metadata; **17.7%** have essentially absent AX trees. Electron-based apps (VS Code, Slack, Discord) disable AX by default but can be unlocked via `AXUIElementSetAttributeValue(axApp, "AXManualAccessibility", true)` ([Electron docs](https://electronjs.org/docs/latest/tutorial/accessibility)).

**AX notification constants for knowledge capture:**

| Notification | When Fired | Capture Strategy |
|---|---|---|
| `kAXFocusedUIElementChangedNotification` | User tabs between fields or clicks into new element | Re-read `kAXSelectedTextAttribute` on new focused element |
| `kAXSelectedTextChangedNotification` | User changes text selection (highlight) | Read `kAXSelectedTextAttribute` immediately |
| `kAXValueChangedNotification` | Content of text element changes (typing) | Debounce ≥ 2000ms idle before capture |
| `kAXFocusedWindowChangedNotification` | Active window changes | Update which app/window is being monitored |
| `kAXApplicationActivatedNotification` | App comes to foreground | Re-establish observer set for the new app |

**Sandboxing constraints.** The app cannot be sandboxed for full Accessibility cross-app text reading. Sandboxed apps can request the `com.apple.security.temporary-exception.accessibility` entitlement, but this frequently fails in practice ([Stack Overflow](https://stackoverflow.com/questions/36375434/appsandboxing-accessibility-axuielement)). Ambient capture apps (Rewind.ai, Granola, etc.) distribute outside the Mac App Store for this reason.

**OCR fallback via Apple Vision framework.** `VNRecognizeTextRequest` runs fully on-device via the Neural Engine (~100–300ms per frame in `.accurate` mode on M-series chips; ~20–50ms in `.fast` mode). Language support includes en-US, fr-FR, it-IT, de-DE, es-ES, pt-BR, zh-Hans, zh-Hant (Revision 2), and adds ja-JP, ko-KR, ru-RU from macOS Ventura Revision 3 ([Apple Developer](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)). Note that `VNRecognizeTextRequest` is **not thread-safe** — create a new request per image ([Reddit](https://www.reddit.com/r/swift/comments/1bkkt9n/need_help_parallelizing_ocr_using_visions/)). For OCR, use `SCContentFilter(desktopIndependentWindow:)` from ScreenCaptureKit for surgical single-window capture — other windows' content cannot bleed in, and private browser windows are excluded by default ([WWDC22](https://developer.apple.com/videos/play/wwdc2022/10155/)).

**OCR vs AX privacy comparison:**

| Dimension | AX-Based Capture | OCR-Based Capture |
|---|---|---|
| Scope | Reads only structured UI data (role, value, selection) | Reads all visually rendered text |
| Sensitivity | Lower: only what AX model exposes | Higher: captures everything visible including passwords |
| Selectivity | Can target `kAXSelectedTextAttribute` only | Must capture full window; post-filter in software |
| Recommendation | Prefer AX for interactive text | Use OCR only as fallback with sensitive-content filtering |

**Hybrid AXObserver architecture:**
```
Level 1: NSWorkspace observers (zero AX cost)
├── NSWorkspaceDidActivateApplicationNotification → set up AX observers for PID
└── NSWorkspaceScreensDidSleepNotification → suspend all monitoring

Level 2: AXObserver for focus/window changes (low cost)
├── kAXFocusedUIElementChangedNotification → read selected text
└── kAXApplicationActivatedNotification → rebuild observer set

Level 3: AXObserver for content changes (medium cost, rate-limited)
├── kAXSelectedTextChangedNotification → debounce ≥ 300ms
└── kAXValueChangedNotification → debounce ≥ 2000ms idle

Fallback: Targeted polling at 1000ms only for apps without notifications
```

**CPU overhead comparison.** The Muzzle app analysis found that polling for window state every ~30 seconds via AX consumed ~5% CPU with 2+ second detection latency, compared to AXObserver approach at under 0.3% CPU idle ([lifetips.alibaba.com](https://lifetips.alibaba.com/tech-efficiency/muzzle-automatically-disables-macos-notifications-when-y)). Polling at 500ms on a complex app (browser with many tabs) could consume 3–8% CPU continuously. Observer-based design targeting <1 wake event per second keeps battery impact below user-noticeable drain.

**User idle detection.** Use `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: kCGAnyInputEventType)` covering keyboard, mouse, and tablet input. Treat ≥60s idle as "suspend monitoring" ([Apple Developer](https://developer.apple.com/documentation/coregraphics/cgeventsource/secondssincelasteventtype(_:eventtype:))).

**Rust FFI.** The `accessibility-sys` crate (0.2.0, March 2025) provides complete C-level FFI bindings; the higher-level `accessibility` crate has sparse safe wrappers ([crates.io](https://crates.io/crates/accessibility-sys)). The `objc2` ecosystem does not yet support ApplicationServices directly ([Reddit/r/rust](https://www.reddit.com/r/rust/comments/1do68tl/what_knowledge_and_rust_libraries_do_i_need_to/)).

**Privacy architecture.** TCC permissions require Accessibility (`kTCCServiceAccessibility`) and Screen Recording (`kTCCServiceScreenCapture`) ([The Eclectic Light Company](https://eclecticlight.co/2025/11/08/explainer-permissions-privacy-and-tcc/)). The app **cannot be sandboxed** for full cross-app AX access ([Stack Overflow](https://stackoverflow.com/questions/36375434/appsandboxing-accessibility-axuielement)). Permission sequencing: Accessibility first (lower risk), Screen Recording only after user sees first capture value. Deep-link to the right Settings pane: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` ([jano.dev](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)).

### Critical UX Pitfalls

**The creepy factor.** A 2025 study on smart home surveillance ([Taylor & Francis](https://www.tandfonline.com/doi/full/10.1080/0144929X.2025.2598603)) identified five creepiness factors: persistent privacy fears, creepy personalization, hidden data practices, surveillance awareness, and bias/manipulation concerns. Temporal proximity is the key amplifier — surfacing captured data immediately after capture triggers "it knows what I said" discomfort. **Mitigation:** Introduce a deliberate 5–15 minute lag between capture and first surfacing.

**The data graveyard.** The specific failure modes: no retrieval surface (user must know what they're looking for), staleness without curation, context loss (snippet without the source article), and no signal/noise differentiation (banking text vs. article text weighted equally). **Countermeasures:** Context weighting (selected/highlighted text > briefly-viewed text); immediate processing into structured knowledge; temporal decay weighting in retrieval; "Save this" / "Discard this" curation.

**Permission fatigue.** Five permission dialogs in sequence creates decision paralysis and trust erosion. Recommended sequencing:

| Phase | Permission | Rationale |
|---|---|---|
| First launch | Accessibility only | Minimal footprint; enables clipboard and selected-text capture |
| After user sees first capture | Screen Recording | User has evidence of value; explain what it enables |
| Explicitly optional | Microphone | Only for meeting transcription; skip if not building that feature |
| Never request | Full Disk Access | Not needed; requesting it is a major trust red flag |

Use just-in-time permission requests at the moment the user tries the feature requiring it. The macOS restart problem for Screen Recording (permission doesn't take effect in the running process) requires detecting the just-granted state and prompting for restart.

**Minimal viable consent architecture:** (1) Default state: capture DISABLED, opt-in only. (2) Minimum capture: AX-only selected text. (3) Full capture: AX + ScreenCaptureKit OCR, opt-in after user sees value. (4) Encryption: all stored knowledge encrypted at rest, decrypt on Touch ID. (5) Exclusion defaults: password managers, private browsing, banking apps. (6) Visual indicator: always-visible capture status. (7) One-click pause in ≤2 clicks.

**False confidence.** The most dangerous UX failure: the user believes the system captured important information, but it silently failed (scanned PDF, custom-rendered app, Figma canvas). **Mitigation:** Capture confidence signals — brief "Captured from Preview" indicator on success; "No capture available" state for AX-sparse apps; per-app capture status view.

**Performance impact on target apps.** Chrome's accessibility tree with `AXManualAccessibility = true` incurs real overhead — enable only while Chrome is frontmost ([Chromium bug tracker](https://issues.chromium.org/40865608)). Java Swing's CAccessibility bridge can freeze on large trees ([GitHub/corretto](https://github.com/corretto/corretto-17/issues/132)). Use `AXUIElementSetMessagingTimeout(element, 0.5)` to cap AX query wait time.

---

## Capability 3: Cognitive Friction Detection via Edit Telemetry

### Cognitive Science Justification

The foundational cognitive model of writing is Flower and Hayes's 1980 paper "A Cognitive Process Theory of Writing" ([JSTOR](https://www.jstor.org/stable/356600)), which broke from linear stage-based accounts by treating writing as recursive, interleaved cognitive processes — Planning, Translating, and Reviewing — governed by a Monitor. Hayes's 2012 revision added resource-level constraints: working memory, long-term memory retrieval, and the text-produced-so-far as continuous feedback stimulus ([Hayes, 2012, *Written Communication*](https://journals.sagepub.com/doi/abs/10.1177/0741088312451260)).

**Pause analysis research.** Leijten and Van Waes (University of Antwerp) developed the Inputlog keystroke logging system over two decades, establishing the empirical foundations for computing cognitive process indicators from keystroke data ([Leijten & Van Waes, 2013, *Written Communication*](https://journals.sagepub.com/doi/10.1177/0741088313491692); [Leijten & Van Waes, 2020](https://www.inputlog.net/wp-content/uploads/2020_CJSLW-Designing_KSL-studies.pdf)). Schilperoord's (1996) *It's About Time* ([Semantic Scholar](https://www.semanticscholar.org/paper/It's-about-time:-Temporal-aspects-of-cognitive-in-Schilperoord/b4042e468636ae90a6e4278fbb14be76984c4b30)) established that pause location is as informative as pause duration — a 5-second pause at a paragraph boundary is planning; the same pause mid-word is a disruption.

Wengelin (2006) and the Frontiers in Psychology threshold paper ([PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC3971171/)) established that individual differences in typing speed require individual calibration — what counts as a "pause" must be defined relative to each user's own interkey interval distribution. Pause duration maps to cognitive process:

| Duration | Cognitive Process | Location |
|---|---|---|
| <250ms | Motor execution; within-keystroke dynamics | Any position |
| 250ms–1s | Word-level lexical retrieval; orthographic encoding | Word-initial dominant |
| 1–2s | Syntactic planning for next phrase or clause | Between-word, pre-clause |
| 2–5s | Sentence-level planning; evaluating coherence | Sentence-boundary dominant |
| 5–30s | Discourse-level planning; global re-reading | Paragraph-boundary or post-sentence |
| >30s | Extended planning, distraction, or stuck state | Variable |

The most practically important distinction for the OpLog is between **within-word pauses** (>200ms within a word, associated with spelling difficulty and word retrieval failure) and **between-word pauses** at sentence or paragraph boundaries (discourse-level planning). An elevated rate of within-word pauses relative to personal baseline reliably signals increased linguistic-level cognitive load.

**Burst analysis.** Chenoweth and Hayes (2001/2003) formalized the "burst" — an uninterrupted stretch of typing bounded by pauses above a threshold (2 seconds for adult writers). The segmentation algorithm: for each character insertion event, compute the gap since previous insertion; if gap > threshold T, mark a burst boundary; label resulting segments as burst periods. Burst length variability is as informative as mean burst length: high variability suggests alternation between fluent production and effortful struggling; low variability at high burst length suggests sustained flow.

Alves, Castro, and Olive (2008) used the triple-task paradigm to show that revising is the most cognitively demanding subprocess, and that writing processes overlap during both execution and pause periods ([Alves et al., 2008, *International Journal of Psychology*](https://pubmed.ncbi.nlm.nih.gov/22022840/)). Key finding: writers with low typing skill showed higher cognitive demand during execution (typing consumes more resources, leaving less for higher-order processes). Kim (2022) confirmed that burst-level measures (mean burst length, burst variability) mediate the relationship between language/cognitive skills and writing quality ([Kim, 2022, *Written Communication*](https://pmc.ncbi.nlm.nih.gov/articles/PMC9355459/)).

**The pause-burst-pause pattern** is the computational primitive of writing process analysis:

| Pattern Characteristic | Low Friction / Flow | High Friction |
|---|---|---|
| Pause duration before burst | Brief (0.5–2s) | Extended (5s+) |
| Burst length | Long (20+ words) | Short (1–5 words) |
| Burst typing rate | Consistent, near personal max | Variable, slowed |
| Deletions within burst | Rare | Frequent |
| Post-burst pause duration | Brief | Extended (evaluation episode) |
| Cursor regression during pause | Absent or minimal | Frequent, distant |

**Flow state detection.** Csikszentmihalyi's flow theory describes a state of complete absorption characterized by concentration, clarity, effortlessness, and challenge-skill balance ([Nature, 2024](https://www.nature.com/articles/s44271-024-00115-3)). Ulrich, Keller, and Grön (2016) used fMRI to show flow involves increased frontal theta and moderate frontal alpha — distinguishing flow from overload (excessive alpha) and boredom (low theta) ([Ulrich et al., 2016, *SCAN*](https://pmc.ncbi.nlm.nih.gov/articles/PMC4769635/)). The behavioral analog: long consistent burst lengths, low deletion density, forward-only cursor movement, and low pause frequency.

**Interruption cost.** Gloria Mark's CHI 2008 research showed interrupted work is completed faster but at significantly higher stress, frustration, and mental workload ([Mark et al., 2008](https://www.ics.uci.edu/~gmark/chi08-mark.pdf)). This means the moment of highest friction is the *worst* moment to offer help — the correct intervention moment is the natural pause after difficulty resolves.

### Competitive Landscape

| Tool | What It Analyzes | Real-Time? | Process vs. Product |
|------|-----------------|-----------|-------------------|
| **Draftback** | Google Docs revision history playback | Post-hoc only | Product visualization (what changed, not when/how) |
| **Writefull** | Grammar, register, vocabulary in academic writing | No (submitted text) | Product only |
| **Grammarly Insights** | Weekly word count, error rate, vocabulary diversity | Weekly aggregate | Product metrics |
| **iA Writer Focus Mode** | Sentence/paragraph dimming, typewriter scroll | Real-time environment | No analysis — shapes environment only |
| **ProWrite** | Keystroke + eye-tracking + intervention prompts | Real-time + interventions | Process analysis (30 metrics) but restricted to assigned essay tasks ([Frontiers in Communication, 2022](https://www.frontiersin.org/journals/communication/articles/10.3389/fcomm.2022.933878/pdf)) |

The universal gap: existing tools analyze the **output, not the process** ([Taylor & Francis, 2020](https://www.tandfonline.com/doi/full/10.1080/09588221.2020.1839503)). A polished paragraph could have been written in 2 minutes of flow or 45 minutes of struggle — the product looks the same.

### Technical Implementation Patterns

**Friction score computation** over a sliding window W:

```
F(W) = w₁ · z(pause_rate) + w₂ · z(mean_pause_duration) - w₃ · z(burst_length)
     + w₄ · z(burst_length_CV) + w₅ · z(deletion_density) + w₆ · z(regression_frequency)
     + w₇ · z(regression_distance)
```

Where `z(x)` is the z-score relative to the user's personal rolling baseline. Burst length contributes negatively (longer = less friction). A **dual-window system**: short event window (N=50 events ≈ 1–2 min) for high-frequency signals; long time window (T=10 min) for trend signals.

**Baseline calibration.** During the first 3–5 sessions, compute descriptive statistics for each component variable (mean, variance, percentile distribution). Maintain rolling EWMA (exponentially weighted moving average) with ~7-day half-life capturing recent behavioral patterns. Z-score computation: z = (observed − baseline_mean) / baseline_SD. Friction events: F > µ_F + 1.5·σ_F. Per-user pause threshold calibration: if mean IKI = 120ms with SD=40ms, cognitive pause threshold ≈ 400ms (mean + 7SD, per Wengelin's method) ([Wengelin, 2006](https://www.lunduniversity.lu.se/lup/publication/4f38448c-1fcd-41d2-9950-1de0bb919483)). The Inputlog literature recommends a per-user copy-task baseline, but for the macOS system, the first several sessions of normal use serve as approximate baseline collection.

**Key research-validated parameter choices:**

| Parameter | Value | Basis |
|---|---|---|
| Burst boundary threshold (adult) | 2.0 seconds | Chenoweth & Hayes (2003); Limpo & Alves (2017) |
| Within-word cognitive pause threshold | 200–400ms (user-calibrated) | Wengelin (2006); Inputlog methodology |
| Friction detection window (primary) | 10 minutes | Smooth individual events; capture sustained patterns |
| Friction detection window (secondary) | 50-event buffer | Capture recent high-frequency signals |
| Baseline calibration period | First 3–5 sessions | Sufficient for stable mean/SD estimates |
| Friction score threshold for ambient action | +1.5 σ from session baseline | Conservative to avoid over-triggering |
| Flow detection threshold | -1.5 σ friction + +1.5 σ flow index | Requires convergence of both signals |

**Algorithmic pipeline:**
```
OpLog Stream → [1] Per-User Calibration Model → [2] Real-Time Event Stream Processor
→ [3] Sliding Window Aggregator (dual window) → [4] Friction Score Computation
→ [5] State Classification (FLOW / NEUTRAL / FRICTION / STUCK)
→ [6] Background Actions (silent) → [7] Session-End Logging
```

**State-triggered background actions:**
- **FLOW:** Suppress all ambient panel updates; hold notifications
- **FRICTION:** Pre-load related notes in ambient panel; deprioritize notifications
- **STUCK (>10 min):** Pre-render break suggestion for post-sentence delivery

**Flow detection disambiguation.** The EDM 2024 plagiarism detection study ([EDM 2024](https://educationaldatamining.org/edm2024/proceedings/2024.EDM-short-papers.47/index.html)) showed transcribers produce longer burst lengths and lower deletion density than authentic composers — mimicking flow. Distinguishing signals: sentence-initial pause structure (authentic composition shows significantly longer pauses at sentence-initial positions), intra-word pause rate (transcribers have anomalously low rates because they read words from source), and revision pattern (genuine flow has *some* revision activity, especially distant regressions for conceptual revision). A complete session of invariant, extremely long bursts with zero revisions is suspicious — more likely dictation replay, copy-paste, or AI-generated content insertion than human flow writing.

**Revision behavior taxonomy.** The OpLog enables fine-grained revision analysis: (1) **Local vs. distant revisions** — local revisions within current word/phrase indicate surface monitoring; distant regressions to earlier paragraphs indicate discourse-level evaluation. (2) **Insertion-to-deletion ratio** (Inputlog's "produced ratio") — values of 0.6–0.8 are typical for fluent adult composers; sustained values below 0.5 signal heavy revision. (3) **Immediate vs. delayed correction** — the time-lag between production and deletion is computable from OpLog timestamps; a shift toward more distant, delayed revisions signals a mode switch from translating to evaluating.

**Metacognitive interventions.** Zimmerman and Risemberg's 1997 triadic self-regulation model ([Zimmerman & Risemberg, 1997](https://www.semanticscholar.org/paper/Becoming-a-Self-Regulated-Writer:-A-Social-Zimmerman-Risemberg/9401183a22d13f2f88311bc95e8568f5489517d5)) identifies environmental, behavioral, and covert regulation of writing. The system's best intervention opportunity is the post-session self-reflection phase. Buckingham Shum and colleagues' reflective writing analytics ([LAK 2017](https://simon.buckinghamshum.net/wp-content/uploads/2018/02/LAK17_ReflectiveWritingAnalytics.pdf)) demonstrated that post-session analytics feedback is actionable: 85.7% of students found the feedback helpful. Feedback must be **actionable** ("You spent 12 minutes on your third paragraph") rather than merely descriptive (reporting metrics). Graham and Harris's SRSD model produced effect sizes of 1.47 for writing quality ([IES review](https://ies.ed.gov/ncee/wwc/Docs/InterventionReports/wwc_srsd_111417.pdf)), validating that explicit metacognitive support produces substantial improvements.

**Spaced retrieval integration.** When the OpLog detects a pause >5 seconds at a sentence boundary (a natural planning pause), the system can present related notes in the ambient panel. This timing aligns with the pause's cognitive function — the writer is in planning/evaluation mode, not mid-execution — and implements spaced retrieval practice at the moment the writer is most likely to find it useful ([University of Rochester review](https://www.rochester.edu/college/learningcenter/assets/pdf-doc/studying/spaced-retrieval-practice-final.pdf)).

### Critical UX Pitfalls

**The Hawthorne effect.** Displaying a friction score in real time would transform an anxiety-reducing tool into an anxiety-inducing one. Writers "gamified" to avoid triggering intervention prompts in the ProWrite study. **Hard rule:** No friction gauge, flow indicator, or score widget in the UI. Only the ambient panel adapts — silently. The system acts as a silent observer that adapts the environment ([NN/g](https://www.nngroup.com/articles/hawthorne-effect-observer-bias-user-research/); [Simply Psychology](https://www.simplypsychology.org/hawthorne-effect.html)).

**"Quantified Self" burnout.** Behavioral tracking for well-being can create anxiety, shift accountability problematically, and reduce agency ([CSCW, PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC9879386/)). Frame post-session analytics as "session character" ("this was an exploratory session"), not deficit ("you had high friction today"). Never show comparative metrics unless explicitly requested.

**Privacy of thought.** Edit telemetry records deleted text, abandoned phrases, and reconsidered ideas — the writer's thinking process. **Mitigations:** All OpLog data processed entirely on-device; deleted text stored encrypted with separate key or not stored at all; single-keystroke pause for OpLog collection; configurable retention period (default: 30 days); no semantic analysis of deleted content — only temporal patterns.

**Over-interpretation.** Pauses have many causes beyond cognitive difficulty: physical interruption, deep contemplation before fluent expression, intentional re-reading, environmental distraction. The friction score must be computed over a minimum 5-minute window. A single 30-second pause means nothing; a pattern over 10 minutes is meaningful. Adjust baseline for document-type differences (complex technical writing legitimately produces more pauses).

**Intervention timing paradox.** The correct response to detected cognitive difficulty is to do nothing visible. Silently pre-load context in the ambient panel. Wait — most cognitive difficulty is self-resolving. The correct intervention moment is the natural pause *after* difficulty resolves ([Cognitive Load Theory, Sweller 1988](https://www.tandfonline.com/doi/full/10.1080/10447318.2026.2628994)).

---

## Capability 4: Temporal Knowledge Graph — Conceptual Drift and Belief Evolution

### Cognitive Science Justification

**Diachronic word embeddings.** Hamilton, Leskovec, and Jurafsky's two 2016 papers established the computational methodology for tracking meaning change. ["Diachronic Word Embeddings Reveal Statistical Laws of Semantic Change"](https://www.aclweb.org/anthology/P16-1141.pdf) tested three embedding methods (PPMI, SVD, SGNS/word2vec) across six corpora spanning four languages and two centuries. ["Cultural Shift or Linguistic Drift?"](https://www.aclweb.org/anthology/D16-1229.pdf) operationalized two distinct measures:

| Measure | Definition | Sensitive to |
|---|---|---|
| **Global (cosine distance)** | `d_G(w_i^t, w_i^{t+1}) = cos-dist(v_i^t, v_i^{t+1})` after Procrustes alignment | Regular linguistic drift (subjectification, grammaticalization) |
| **Local neighborhood** | Cosine distance between second-order vectors for k=25 nearest neighbors union across periods | Cultural/conceptual shifts driven by external change |

Two statistical laws: the Law of Conformity (rate of change scales with inverse power-law of frequency — `Δ(w_i) ∝ f(w_i)^βf`, with βf ∈ [-1.26, -0.27]; high-frequency anchor concepts change slowly) and Law of Innovation (polysemous words change faster). For personal knowledge: linguistic drift ("machine learning" becomes casual shorthand) should be distinguished from conceptual drift (your nearest neighbors for "fairness" migrate from philosophy to statistical calibration).

**Embedding alignment via Orthogonal Procrustes:** Because SGNS and SVD embeddings have arbitrary rotation, comparing two time-sliced models requires alignment: `R^t = argmin_{Q^TQ=I} ||W^t · Q − W^{t+1}||_F`, solved via SVD of `W^t · W^{t+1,T}`. For a personal knowledge system, second-order embeddings (compute similarity vectors to a fixed core vocabulary) are an alignment-free alternative — architecturally simpler: no alignment optimization step, just a dot-product operation against a stable reference vocabulary.

**Method tradeoffs for small personal corpora:**

| Method | Strengths | Weaknesses |
|---|---|---|
| SVD (on PPMI matrix) | More sensitive; performs well on small datasets | Artifact-prone on small/noisy corpora |
| SGNS (word2vec) | Robust to corpus artifacts; best for discovery | Requires more data for reliable shift detection |
| Contextual (BERT-based) | Token-level, no alignment needed | Computationally heavy; overkill for personal notes |

For 10K–100K tokens per time window, SVD on PPMI or second-order embeddings are the most practical choices.

**Belief revision theory.** Paul Thagard's (1989) Explanatory Coherence Theory (ECHO) models belief acceptance as parallel constraint satisfaction across a network of propositions ([Thagard, 1989](https://gwern.net/doc/philosophy/epistemology/1989-thagard.pdf)). ECHO's seven principles include symmetry, explanation, analogy, data priority, and contradiction. The mechanism: propositions become neurons with coherence as excitatory links and incoherence as inhibitory links; the network settles via parallel constraint satisfaction; final activation (positive/negative) = accepted/rejected belief. When new evidence accumulates, the network can undergo a *phase transition* — not gradual probability update but a flip in the constraint satisfaction landscape. The computational mapping to a PKM: propositions → concept nodes + note assertions; coherence links → citations, thematic co-occurrence; incoherence links → contradiction-detection (NLI-based); acceptability → network-state flip detected across time snapshots.

Michelene Chi's ontological category shift framework ([Chi, Slotta & de Leeuw, 1994](https://education.asu.edu/sites/g/files/litvpz656/files/lcl/chislottaleeuw_2.pdf)) describes the hardest conceptual changes: reassigning a concept from one *ontological category* to another. The three primary trees — MATTER (things with volume, mass), PROCESSES (events occurring over time), MENTAL STATES (beliefs, intentions) — carry incompatible attribute sets. When students misunderstand heat as substance rather than process (energy transfer), they carry false inferences. Detection signatures in notes: predicate change ("store knowledge" → "practice knowledge"), neighbor cluster migration, and language pattern shift ("X is a Y" → "X involves/requires/produces Y"). Posner, Strike, Hewson, and Gertzog (1982) identified four necessary conditions for accommodation:

| Condition | Definition | PKM Detection Signal |
|---|---|---|
| **Dissatisfaction** | Existing conception is inadequate | Multiple contradictory assertions about same concept |
| **Intelligibility** | New conception must be comprehensible | Citation burst to explanatory sources after contradictions |
| **Plausibility** | New conception consistent with other beliefs | New concept cluster forms coherent neighborhood |
| **Fruitfulness** | New conception productive for solving problems | Rising betweenness centrality |

([Posner et al., 1982](https://faculty.weber.edu/eamsel/Classes/Practicum/TA%20Practicum/papers/Posner%20et%20al.%20(1982).PDF)). These give a sequenced lifecycle: dissatisfaction (contradiction spike) → intelligibility search (citation burst) → plausibility (community restructuring) → fruitfulness (betweenness centrality increase).

Susan Carey's distinction between **weak restructuring** (new relations among existing concepts) and **strong restructuring** (core concepts transformed, ontological commitments change) ([Carey, 1986](http://edci670.pbworks.com/w/file/fetch/59138742/Carey_1986.pdf)) maps directly to graph metrics: weak restructuring = increasing local edge density; strong restructuring = community migration + contradiction detection + centroid shift above threshold.

### Competitive Landscape

No existing personal knowledge tool tracks conceptual drift computationally. Obsidian, Roam, and Logseq maintain static graph structures. DEVONthink's "See Also" uses TF-IDF-like LSA that does not model temporal evolution ([DEVONtechnologies Community](https://discourse.devontechnologies.com/t/dt4-inner-workings-of-indexing-see-also-similar-documents-thought-about-using-vectorization/82596)). The closest academic work is the diachronic word embedding literature applied at corpus scale (Hamilton et al., [Kutuzov et al. (2018)](https://arxiv.org/abs/1806.03537)), which has not been adapted to personal note corpora. [Kutuzov, Øvrelid, Szymanski & Velldal (2022)](https://arxiv.org/abs/2209.00154) review contextualized language models for semantic change detection, but their computational demands are excessive for on-device personal use.

### Technical Implementation Patterns

**Personal concept embedding pipeline:**
1. For each concept node C, collect all note paragraphs referencing C within time window [t, t+Δ]
2. Compute per-paragraph embedding using a frozen sentence encoder
3. Compute centroid embedding e_C^t = mean of paragraph embeddings
4. Track drift as `drift_score(C, t→t+1) = 1 - cosine_sim(e_C^t, e_C^{t+1})`
5. Track local measure: k=10 nearest concept-neighbors by similarity; compute Jaccard distance across periods

This sidesteps the minimum-frequency problem: even a concept mentioned 5 times per window generates a stable centroid. [Kutuzov et al. (2018)](https://arxiv.org/abs/1806.03537) recommend second-order embeddings as an alignment-free alternative to Procrustes — architecturally simpler for an embedded system.

**Bitemporal edge table schema (event-sourced):**

```sql
CREATE TABLE edges (
    id TEXT PRIMARY KEY,
    source_id TEXT NOT NULL REFERENCES nodes(id),
    target_id TEXT NOT NULL REFERENCES nodes(id),
    relation TEXT NOT NULL,      -- 'supports', 'contradicts', 'elaborates', 'cites'
    valid_from INTEGER NOT NULL, -- When relationship became true (user's world)
    valid_until INTEGER,         -- NULL = currently valid
    recorded_at INTEGER NOT NULL, -- When system learned this fact
    confidence REAL DEFAULT 1.0,
    weight REAL DEFAULT 1.0
) STRICT;
```

Enables "as-of" queries: `WHERE valid_from <= ?1 AND (valid_until IS NULL OR valid_until > ?1)`. Additional tables for concept embeddings per epoch and drift events log support the full temporal analysis pipeline.

**Temporal query patterns:**

```sql
-- "Show me the graph as of 2024-06-01"
SELECT source_id, target_id, relation, weight
FROM edges
WHERE valid_from <= 1717200000000
  AND (valid_until IS NULL OR valid_until > 1717200000000);

-- "Which concepts drifted most in the last 90 days?"
SELECT de.node_id, n.label, MAX(de.drift_score) as max_drift,
       de.drift_type, de.old_community, de.new_community
FROM drift_events de
JOIN nodes n ON de.node_id = n.id
WHERE de.detected_at > (strftime('%s', 'now') * 1000 - 7776000000)
GROUP BY de.node_id
ORDER BY max_drift DESC LIMIT 20;
```

**Event-sourcing architecture.** The append-only OpLog is the source of truth; the edges/nodes tables are materialized projections. To see the graph at any historical state, replay `op_log` entries up to that point. For drift analysis, consuming new entries since last run is O(new_entries) regardless of total graph size.

**SQLite JSON1 extension** for flexible node metadata: `json_extract(metadata, '$.domain')` enables schema-flexible properties without additional tables. Index on extracted JSON values (SQLite 3.38+): `CREATE INDEX idx_node_domain ON nodes(json_extract(metadata, '$.domain'))`.

**Graph algorithms via petgraph.** `petgraph` ([docs.rs](https://docs.rs/petgraph/)) provides `DiGraph`, PageRank, betweenness centrality, and DFS/BFS. Its `StableGraph` variant preserves node indices under deletion/insertion — critical for delta computation. Community detection via Leiden algorithm; [Sahu (2024)](https://arxiv.org/abs/2410.15451) introduced dynamic Leiden variants achieving ~1.37× speedup over full static recomputation.

**Restructuring severity ladder:**
```
Level 0 — Stable:        drift_score < 0.05, community unchanged
Level 1 — Growing:       drift_score 0.05–0.15, new edges added
Level 2 — Evolving:      drift_score 0.15–0.30, partial neighbor turnover
Level 3 — Shifting:      drift_score 0.30–0.50, community migration detected
Level 4 — Restructuring: drift_score > 0.50, contradictions + community migration
Level 5 — Belief Revision: Explicit contradiction with archived belief + resolution
```

Levels 3–5 correspond to Carey's strong restructuring and Chi's ontological category shifts.

**Implementation in Rust:**

```rust
enum RestructuringClass {
    Assimilation,        // Edge density increase, neighbors stable
    WeakRestructuring,   // New edges, community unchanged, some neighbor turnover
    StrongRestructuring, // Community migration, centroid shift > threshold,
                         // predicate-type change (MATTER→PROCESS)
}
```

**Piaget's assimilation vs. accommodation** maps to graph signals: assimilation = increasing edge density around existing concept (monotonically increasing local edge weight); accommodation = spike in contradiction-detection score followed by cluster reorganization. Posner et al.'s four conditions for accommodation give a sequenced lifecycle: dissatisfaction (contradiction spike) → intelligibility search (citation burst) → plausibility (community restructuring) → fruitfulness (betweenness centrality increase) ([Posner et al., 1982](https://faculty.weber.edu/eamsel/Classes/Practicum/TA%20Practicum/papers/Posner%20et%20al.%20(1982).PDF)).

**Computational cost and scheduling:**

| Operation | Cost | Frequency |
|---|---|---|
| Embedding centroid update | O(k) dot products | Per new note (very cheap) |
| Full graph community detection (Leiden) | O(|E| log |V|) | Should NOT run per note |
| PageRank computation | O(|E| × iterations) | Should NOT run per note |
| Drift score computation | O(d) per concept-pair | Per epoch boundary (cheap) |
| UMAP projection for visualization | O(n²) naive | Per user request (expensive) |

Recommended: real-time centroid updates on every note save; daily community detection during device idle; weekly drift scoring; on-demand UMAP projection with caching (recompute only when >N% of nodes have moved significantly).

**Temporal graph visualization.** [Beck, Burch, Diehl & Weiskopf (2017)](https://onlinelibrary.wiley.com/doi/10.1111/cgf.12791) provides the canonical taxonomy. Recommended approach: current graph view with temporal encoding (node color temperature: blue=stable, red=high drift; pulsing border for community migration; edge opacity by recency). "Temporal maps" show concept trajectory through embedding space using UMAP, analogous to [Stoltz & Taylor's "Cultural Cartography"](https://arxiv.org/abs/2007.04508).

### Critical UX Pitfalls

**The "So What?" problem.** Raw drift metrics are meaningless without interpretation. Drift detection should surface *questions*, not answers: "It looks like your thinking on X may have shifted — want to review how?" — not "Your semantic drift score is 0.34." Always provide actionable suggestions: "Here are 3 older notes that now appear to contradict your recent writing."

**False positives.** The core confound: if a user writes detailed notes some periods and brief notes others, embedding centroid shifts are driven by *coverage variation*, not conceptual change. One deep-dive essay on "consciousness" in March inflates that concept's centroid toward the essay's vocabulary; in April, a brief mention pulls it back. This looks like drift but is noise.

**Mitigations:**

| Mitigation | Implementation |
|---|---|
| Minimum token threshold | Only compute drift when ≥500 tokens reference the concept in each window |
| Confidence intervals | Bootstrap the embedding centroid; if 95% CI of cosine distance includes 0, report "stable" |
| Frequency-normalized drift | Compute `drift_score / sqrt(token_count_prev × token_count_curr)` to penalize low-coverage windows |
| Corroborating signals | Require both embedding drift AND structural change (edge additions/community migration) |
| Smoothing | Use exponential moving average of centroid rather than hard window boundaries |

The [statistically significant detection approach](https://aclanthology.org/2021.eval4nlp-1.11.pdf) (Medlar et al. 2021) applies permutation-based tests to detect genuine shifts vs. noise in small corpora.

**Adaptive windowing.** Rather than fixed calendar windows, accumulate notes until a minimum coverage threshold is met:

```rust
fn should_compute_drift(concept: &ConceptNode,
                        new_tokens: usize,
                        days_since_last: u64) -> bool {
    // Minimum signal: 500 tokens OR 30 days, whichever comes last
    (new_tokens >= 500) && (days_since_last >= 30)
    || days_since_last >= 90  // Force quarterly check regardless
}
```

This naturally produces more frequent drift assessments for heavily-used concepts and slower assessments for rarely-mentioned ones — matching the user's actual engagement pattern.

**Temporal resolution tradeoffs:**

| Window Size | Problem |
|---|---|
| Daily | High noise: single unusual note pollutes centroid |
| Weekly | Better but still volatile for sparse note-takers |
| Monthly | Reasonable for active users (~30+ notes/month) |
| Quarterly | Stable signal; aligns with seasonal life periods |
| Yearly | Too coarse for tracking learning within a domain |

**Overwhelming visualization.** The [Cambridge Intelligence analysis](https://cambridge-intelligence.com/graph-visualization-ux-how-to-avoid-wrecking-your-graph-visualization/) identifies three canonical failures: hairballs (dense edge overplotting), snowstorms (too many isolated nodes), and starbursts (one hub with hundreds of spokes hiding non-hub structure). **Counter-strategy:** (1) Level-of-detail rendering — show community-level summary graph by default; expand to within-community detail on interaction. (2) Temporal diff as primary view — when surfacing a drift event, show only the changed subgraph (concept + 2-hop neighborhood), not the entire graph. (3) Curated insight cards — "3 concepts evolved this month" card deck, each backed by a targeted mini-graph. (4) Focus+Context layout — the concept being read/edited rendered large at center; surrounding context fades with distance.

**Privacy and vulnerability.** A system surfacing "Your understanding of [topic] shifted significantly after [date]" is revealing something intimate. If the topic is grief, addiction, political belief, or relationship breakdown, showing a "drift timeline" can feel intrusive or distressing. **Design principles:** (1) User-initiated retrospection only — never push temporal drift notifications without explicit opt-in. (2) Topic sensitivity filtering — allow users to mark certain concept clusters as private/no-analysis. (3) Framing as growth — "Your thinking on X has evolved significantly" not "You changed your mind about X." (4) Deniability by design — operates on embedding centroids and graph structure, does not quote back exact prior words. (5) All data local — the privacy risk is limited to interaction design, but the *feeling* of being tracked by your own tool is a real UX problem.

---

## Capability 5: Night Brain — Autonomous Background Processing

### Cognitive Science Justification

**Ebbinghaus forgetting curve.** The 2015 Murre & Dros replication confirmed the curve's validity: after 1 day without review, ~30% retention; after 1 week, ~10–15% ([Murre & Dros, PLoS ONE 2015](https://pmc.ncbi.nlm.nih.gov/articles/PMC4492928/)). A single well-timed review at the 70% retention point reshapes the curve, extending the next forgetting half-life exponentially. Notes written >7 days ago without access are likely below the 15% retention threshold.

**SM-2 algorithm (SuperMemo).** SM-2 (Wozniak, 1987) is the foundational spaced repetition algorithm used in early Anki versions. Interval calculation: I(1)=1 day, I(2)=6 days, I(n)=I(n-1)×EF. Easiness Factor update: EF' = EF + (0.1 − (5−q)×(0.08+(5−q)×0.02)), with EF≥1.3 minimum ([Stack Overflow](https://stackoverflow.com/questions/49047159/spaced-repetition-algorithm-from-supermemo-sm-2)). SM-2's limitation for note surfacing: EF is a static per-item scalar that doesn't model the multi-dimensional nature of a note's relevance, recency, or semantic relationship to active work.

**FSRS algorithm (Free Spaced Repetition Scheduler).** FSRS (Ye et al., 2022, default in Anki 23+) is substantially more accurate than SM-2 because it models memory as continuous rather than discrete. Three state variables: Retrievability R(t) = (1 + F × t/S)^C (where F=19/81, C=−0.5), Stability S (days for R to decay from 100% to 90%), and Difficulty D (scalar 1–10). Stability update on successful review: S_new = S × SInc, where SInc = 1 + e^(w₈)×(11−D)×S^(−w₉)×(e^(w₁₀(1−R))−1)×w₁₅[grade]×w₁₆[grade]. Interval computation: I = (S/F)×(DR^(1/C)−1). When desired retention (DR)=90%, I=S exactly. 17–20 weight parameters optimized via gradient descent on binary cross-entropy; personalizable to individual user review logs.

FSRS' S (stability) value is directly actionable: a note with S=2 needs review in ~2 days; S=60 needs review in ~60 days. The Night Brain can maintain an FSRS state table per note in GRDB and compute "due for review tonight" notes as those where R(t) < configurable threshold (e.g., 0.75) ([FSRS4Anki GitHub](https://github.com/open-spaced-repetition/fsrs4anki); [Expertium technical explanation](https://expertium.github.io/Algorithm.html); [Fernando Borretti implementation](https://borretti.me/article/implementing-fsrs-in-100-lines)).

**Leitner system integration.** The Leitner system (1970s) maps naturally to note access tiers: Box 1 (daily — new/missed), Box 2 (every 3 days), Box 3 (weekly), Box 4 (bi-weekly), Box 5 (monthly) ([University of York](https://subjectguides.york.ac.uk/study-revision/leitner-system)). Use Leitner-style tiering as fast O(1) lookup for "which notes are due tonight" — compute FSRS only for Box 1–2 notes; use approximate bucket membership for Box 3–5.

**Andy Matuschak and Michael Nielsen's "transformative tools for thought"** established that memory systems should surface material in *context* — cards linked to a source essay have higher retention than isolated items. The Night Brain's digest should show why each note is relevant, not just the note itself ([Matuschak & Nielsen, 2019](https://numinous.productions/ttft/); [Matuschak on prompts](https://andymatuschak.org/prompts/)).

**Zettelkasten daily review** philosophy: the slip-box should "present you with ideas you have already forgotten, allowing your brain to focus on thinking instead of remembering" ([Zettelkasten.de](https://zettelkasten.de/posts/daily-review-tasks/)). Boris Smus's semantic similarity work demonstrated continuous embedding-based surfacing from the current paragraph ([Smus](https://smus.com/semantic-similarity-note-taking/)). Night Brain extends this to temporal context: use the centroid of embeddings from the last 7 days of active notes.

### Competitive Landscape

| System | Background Processing | Scheduling | Isolation |
|--------|----------------------|------------|-----------|
| **Apple Photos** | Person clustering overnight during charging; ANE-first embedding; incremental HAC | Overnight + charging | Private on-device ML pipeline ([Apple ML Research](https://machinelearning.apple.com/research/recognizing-people-photos)) |
| **Spotlight** | FSEvents → mds → mdworker XPC; QoS `.background`; DAS scheduling | Event-driven + maintenance | XPC isolation (mdworker crash doesn't crash Spotlight) ([Eclectic Light Company](https://eclecticlight.co/2022/12/08/spotlight-problems-mds_stores-and-mdworker-in-trouble/)) |
| **DEVONthink** | Incremental LSA/LSI as documents added | Event-driven (no explicit nightly) | Background jobs can hang indefinitely ([DEVONtechnologies Community](https://discourse.devontechnologies.com/t/background-jobs-hanging-for-ever/85497)) |
| **Obsidian MCP** | Nightly full re-index + `--watch` for continuous | Timer-based | JavaScript on main thread (blocks UI) ([Skywork.ai](https://skywork.ai/skypage/en/unlocking-second-brain-obsidian-index/1977912100451192832)) |

Apple Photos' design decisions directly applicable to Night Brain: ANE first, GPU second, CPU third for embedding generation (ANE is dramatically more energy-efficient for inference); overnight + charging as the canonical scheduling trigger; incremental HAC (not full rebuild each night); privacy as architecture constraint (all on-device). Apple explicitly addresses the core challenge: "users don't want the battery to drain or the performance of the system to slow to a crawl... background computer vision processing shouldn't significantly impact the rest of the system's features" ([Apple ML Research](https://machinelearning.apple.com/research/face-detection)).

Spotlight's architecture is the canonical macOS incremental background indexing reference: FSEvents subsystem records every file modification to a persistent kernel-level journal; `mds` dispatches `mdworker` XPC processes for changed files; DAS scheduling at QoS `.background`. Night Brain equivalents: FSEvents → GRDB `notes` table modified_at trigger; mdworker → NightBrainWorker XPC; .Spotlight-V100 → usearch index + GRDB vector table. Critical lesson: XPC isolation ensures the embedding generator crash doesn't crash the main app.

DEVONthink's "See Also" uses LSA/LSI (not vector embeddings or RAG). The developer explicitly noted that "without a vector database [DT4's approach] is considerably more accurate for querying a specific PDF" and adding vector store indexing has "disadvantages: increased disk space usage and slower indexing (a lot slower)" ([DEVONtechnologies Community](https://discourse.devontechnologies.com/t/dt4-inner-workings-of-indexing-see-also-similar-documents-thought-about-using-vectorization/82596)). Night Brain's advantage: modern transformer-based embeddings are multilingual, contextual, and substantially more semantically expressive than LSI for clustering and orphan detection.

macOS Core Data CloudKit Sync (`NSPersistentCloudKitContainer`) uses event-driven rather than timer-driven background processing — sync fires in response to data events, not on a fixed schedule ([Apple TN3163](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer)). Night Brain should similarly be event-responsive: if the user adds 50 notes just before bed, incorporate them even if the pipeline has already started.

### Technical Implementation Patterns

**Scheduling.** `NSBackgroundActivityScheduler` with `interval: 86400`, `tolerance: 3600`, `qualityOfService: .background`. Check `shouldDefer` frequently — if `true`, checkpoint and call `.deferred`. For headless operation, use a LaunchAgent via `SMAppService` (macOS 13+) ([Apple Energy Efficiency Guide](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/SchedulingBackgroundActivity.html)).

**Precondition gate:**
```swift
func canStartNightBrain() -> Bool {
    return isOnACPower() &&
           userIdleSeconds() > 300 &&   // 5 min idle
           thermalPressureLevel() <= 1   // nominal or moderate
}
```

Thermal monitoring via `thermald` notifyd (`com.apple.system.thermalpressurelevel`) provides 5-level granularity (ProcessInfo.thermalState conflates "moderate" and "heavy" under `.fair`) ([Stanislas Blog](https://stanislas.blog/2025/12/macos-thermal-throttling-app/)).

**XPC isolation.** Run NightBrainWorker.xpc as a separate process with its own memory space: HNSW re-indexing, embedding generation, orphan detection, and digest assembly all isolated from the main app. Design for crash-safe resumption via GRDB-backed checkpoints. Key principles: XPC services must be minimally stateful (OS can kill at any time); communication via `NSXPCConnection` with declared protocol; use `NSProgress` for pipeline progress reporting. Apple uses XPC pervasively: Spotlight's `mdworker` processes are XPC services; Photos' ML analysis workers are XPC-isolated ([Apple Developer — XPC Services](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html)).

**App Nap prevention.** Use `ProcessInfo.processInfo.beginActivity(options: [.background, .idleSystemSleepDisabled, .automaticTerminationDisabled], reason:)` during active pipeline execution. The token must be kept strongly referenced — if deallocated, the activity ends immediately ([Stack Overflow — Disable App Nap](https://stackoverflow.com/questions/27653939/disable-app-nap-in-swift)). For critical write operations (HNSW snapshot serialization, GRDB commits), use `IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep)` to prevent idle sleep — the assertion string is shown in Energy Saver's "Why is my Mac not sleeping?" UI ([Apple Technical QA1340](https://developer.apple.com/library/archive/qa/qa1340/_index.html)).

**Time Machine-style snapshot architecture.** Before each nightly run, GRDB records a vault snapshot (all note IDs, hashes, modification timestamps). On completion, the delta (added/modified/deleted notes) is logged. This provides both a correctness audit trail and data for "what changed last night" in the user-facing digest, analogous to Time Machine's APFS snapshot + FSEvents delta pattern ([Eclectic Light Company](https://eclecticlight.co/2021/03/11/time-machine-to-apfs-understanding-backups/)).

**HNSW re-indexing.** usearch benchmarks on ARM Graviton 3: f32×256 at 75,640 add QPS, 131,654 search QPS, 99.3% recall@1. On 100M vectors, usearch achieves 105,000 insertions/second vs FAISS's 5,500 (19x faster) ([usearch GitHub](https://github.com/unum-cloud/usearch)). Apple Silicon estimates:

| Vault Size | Vectors | Full Rebuild Time | Incremental Adds/Night |
|---|---|---|---|
| 10K notes | ~10K | ~8 seconds | ~100 adds in <1s |
| 100K notes | ~100K | ~80 seconds | ~1,000 adds in <2s |
| 500K notes | ~500K | ~7 minutes | ~5,000 adds in <10s |

For personal vaults (5K–50K notes), full nightly rebuild is simpler than incremental management. Delta indexing (main index + delta buffer + tombstone set in GRDB) becomes important at 200K+ notes. HNSW deletion is fundamentally a tombstone operation; most implementations use soft deletion and defer cleanup to compaction ([Milvus](https://milvus.io/ai-quick-reference/how-do-you-handle-incremental-updates-in-a-vector-database)). Studies show recall@10 begins degrading after 20% soft-deleted nodes (1–3% drop); nightly compaction keeps the deletion fraction near zero.

**Copy-on-Write index swap.** Build new index into temp file, atomic rename via `rename(2)` (POSIX atomic on APFS), hot-swap in-memory pointer — ARC handles deallocation after in-flight queries complete. Weaviate's production HNSW uses a commit log + periodic snapshot pattern: "Every time a node starts, the HNSW commit log is read and used to rebuild the index in memory" ([Weaviate HNSW Snapshots](https://docs.weaviate.io/weaviate/configuration/hnsw-snapshots)).

Three HNSW merge algorithms proposed by [arXiv 2505.16064](https://arxiv.org/html/2505.16064v1): Naive Graph Merge, Intra Graph Traversal Merge (IGTM), and Cross Graph Traversal Merge — IGTM outperforms. Elasticsearch showed 30% merge time improvement using SEARCH-LAYER ([Elasticsearch Labs](https://www.elastic.co/search-labs/blog/hnsw-graphs-speed-up-merging)).

**Orphan knowledge detection.** An orphan note is not simply one with no links — it is one that is semantically relevant to the user's current work but effectively forgotten. A note about a topic the user finished with is *legitimately* dormant; an orphan has latent value the user would want to know about if prompted. The detection problem is a false-positive problem.

**Component signals:**

*Signal 1: Semantic similarity to active context.* Compute centroid embedding of the user's active context (notes modified/accessed in last N=7 days). `sim_active(note) = cosine(embed(note), centroid(active_7_days))`. Notes with sim_active > 0.65 but not in the active set are prime candidates.

*Signal 2: Temporal recency decay.* `recency_score(note) = exp(−λ × (now − τ_last) / days)`. A reasonable λ=0.1 gives half-life of ~7 days. Weight by `log(1+c)` where c is access count to deprioritize notes genuinely stopped.

*Signal 3: Graph betweenness centrality.* High-betweenness notes are "bridge concepts" connecting otherwise separate clusters. A note with high betweenness that is semantically relevant but not recently accessed is the highest-value orphan — it potentially bridges the user's current project to forgotten prior work. For large vaults, use approximate BC via Brandes' algorithm with sampling ([Memgraph — Betweenness Centrality](https://memgraph.com/blog/betweenness-centrality-and-other-centrality-measures-network-analysis)).

*Signal 4: Unlinked semantic neighbors.* Apply HNSW nearest neighbor search: for each note in the active cluster, find k=20 nearest neighbors, subtract already-linked notes. Remaining candidates are unlinked semantic neighbors — the knowledge graph has not yet recognized the relationship.

*Signal 5: Information foraging patch depletion.* A note cluster heavily accessed 6 months ago then abandoned represents a depleted patch. If current work triggers semantic similarity, the patch may have been abandoned prematurely. The orphan detection algorithm flags notes in depleted patches that have re-emerged as relevant.

**The "hidden gem" problem:** A note written in context X (ML optimization paper, 2022) is now relevant to context Y (implementing a gradient descent optimizer, 2024), but the user never connected them because they were in different mental contexts. This is solvable only by semantic similarity search across time — the HNSW index is precisely the tool.

**Scoring formula:**
```
orphan_score(note) = w₁ × sim_active(note)          // relevance to current work
                   + w₂ × (1 − recency_score(note))   // forgotten-ness
                   + w₃ × betweenness_centrality(note) // bridge value
                   + w₄ × unlinked_neighbor_score(note)// semantic proximity
```
Starting weights: w₁=0.40, w₂=0.25, w₃=0.20, w₄=0.15. Learnable from explicit user feedback (act on surfaced note = reinforce weights; dismiss repeatedly = decay contributing signal). Hard filters: exclude notes modified today, accessed within 3 days, or with zero content. Surface top 5–10 orphan candidates in the morning digest — more than 10 creates cognitive overload.

**Note selection for daily review** is governed by three principles: (1) **forgetting risk** (FSRS-derived: notes where R(t) < threshold), (2) **semantic relevance to current active projects** (notes with high cosine similarity to recent-7-day note embeddings), and (3) **bridge value** (notes with high betweenness centrality but not recently accessed).

### Critical UX Pitfalls

**The "morning surprise" problem.** A note from 3 years ago surfaces with no explanation. **Mitigation:** Always show *why* each note was surfaced: "High semantic similarity to [Project X notes from this week]." Show the bridge between the surfaced note and current work.

**Battery drain and thermal discomfort.** A laptop fan spinning at 4,500 RPM at 2 AM is a UX problem. **Mitigations:** Hard cap at thermal pressure level 1; deliberate `Task.sleep` pauses between work batches; sequential phases (GRDB reads → Metal embedding → HNSW insertions) to prevent thermal accumulation; `.background` QoS throughout ([Apple ML Research](https://machinelearning.apple.com/research/face-detection)).

**Processing overruns.** Hard timeout: pipeline must complete in ≤4 hours. GRDB tracks pipeline state for checkpoint-and-resume. Partial digest: "Tonight's processing is 67% complete. Here are results so far."

**Stale digests.** Expiry model: digest expires 36 hours after generation. Each morning's digest replaces the previous — never accumulate. If a surfaced note was truly important, its orphan score will remain high and it will appear in future digests — the system does not need to nag. Staleness indicator: "This digest is from 2 days ago. Generate a fresh one?" gives the user explicit control.

**Night Brain pipeline architecture summary:**

| Pipeline Phase | Technology | Key Risk | Mitigation |
|---|---|---|---|
| Trigger detection | `NSBackgroundActivityScheduler` + LaunchAgent | Missed fire if app not running | LaunchAgent as safety net |
| Power/idle gate | `IOPowerSources` + `CGEventSource` | False positive (user returned) | Recheck every 60s during run |
| Sleep prevention | `IOPMAssertionCreateWithName` | Forgotten release on crash | XPC isolates crashes; assertion auto-releases on exit |
| Thermal management | `thermald` notifyd + levelcheck | Thermal overrun | Hard backoff at level 2; pause at level 3 |
| App Nap prevention | `ProcessInfo.beginActivity` | Token deallocation | Store strongly on long-lived object |
| Process isolation | XPC service | Crash propagation | XPC crash does not affect main app |
| Embedding generation | Metal compute shaders | GPU thermal pressure | Sequential phases, not concurrent |
| HNSW re-indexing | usearch (Swift/Rust) | Rebuild overrun | Checkpoint every N insertions |
| Deletion handling | Soft tombstone in GRDB | Recall degradation | Nightly compaction (full rebuild) |
| Index swap | Atomic rename + CoW | Read-during-write races | ARC reference counting |
| Orphan detection | HNSW ANN + graph centrality | False positives | Multi-signal scoring + confidence threshold |
| Digest assembly | GRDB + struct serialization | Stale content | 36h expiry; replace not accumulate |
| User trust | Transparent log + read-only | "Cleaned my desk" failure | Hard rule: never writes to vault |

**The "assistant cleaned my desk" problem.** Autonomous reorganization that confuses the user's mental model is the most trust-destroying failure mode ([Frontiers in Psychology](https://pmc.ncbi.nlm.nih.gov/articles/PMC5799275/)). **Hard rule:** Night Brain is **read-only** on the vault. It never moves, renames, deletes, or modifies notes. The digest is a recommendation surface; any action requires user confirmation. Transparency: action log of every overnight action; score explanations; immutability statement in UI ([Standard Beagle](https://standardbeagle.com/improving-user-trust-through-ux-design/)).

---

## Capability 6: Spatial Graph Interaction — Physics-Driven Thinking Canvas

### Cognitive Science Justification

**Epistemic actions.** Kirsh and Maglio's landmark 1994 study ["On Distinguishing Epistemic from Pragmatic Action"](https://adrenaline.ucsd.edu/kirsh/Articles/CogsciJournal/DistinguishingEpi_prag.pdf) found that in Tetris, players rotate pieces far more often than necessary for placement — excess rotations are *epistemic actions* performed to change the agent's computational state, not to advance a plan. Physical rotation costs ~100ms; mental rotation costs 800–1,200ms. The five epistemic functions: visual disambiguation, reduced mental rotation workload, memory retrieval through multi-perspective priming, simplified type identification, and perceptual contour matching. **Design implication:** Every gesture on the thinking canvas should support exploratory, non-committed manipulation before requiring semantic assignment.

**Spatial cognition as cognitive foundation.** Barbara Tversky's research demonstrates that spatial thinking is not a metaphor for abstract thought but its foundation. In ["Visualizing Thought"](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1756-8765.2010.01113.x) and ["The Cognitive Design of Tools of Thought"](https://hci.ucsd.edu/220/TverskyCogtiveDesign.pdf), she shows that spatial arrangements reduce working memory load, enable discovery of new relations, and support analogical reasoning. She introduces **spractions** (spatial-abstraction-actions): when a user places two knowledge nodes spatially adjacent, they enact a spraction that creates and communicates an abstraction. The brain's hippocampal systems that encode physical spatial maps encode abstract conceptual spaces.

**Distributed cognition.** Edwin Hutchins's theory ([Hutchins, *Distributed Cognition*](https://arl.human.cornell.edu/linked%20docs/Hutchins_Distributed_Cognition.pdf)) proposes that the cognitive unit is "a collection of individuals and artifacts and their relations." The graph is a cognitive artifact holding representational states the brain cannot hold simultaneously; the physics engine actively reorganizes representational states.

**Representational guidance.** [Zhang & Norman (1994)](https://pages.ucsd.edu/~scoulson/203/zhang.pdf) established the **representational effect**: different representations of the same abstract structure produce "dramatically different cognitive behaviors." External representations enable perception without symbolic formulation, anchor cognitive behavior, and transform tasks fundamentally. The physics engine is not neutral — its output biases cognition by determining which nodes are proximate and thus compared.

**Gestalt principles.** Proximity, similarity, common fate, connectedness, and closure are pre-attentive perceptual processes ([Interaction Design Foundation](https://ixdf.org/literature/topics/gestalt-principles)). Users will infer semantics from layout proximity even when none exists. The layout engine imposes a perceptual interpretation that users cannot easily override consciously.

**Embodied cognition.** Ishii and Ullmer's tangible user interface research ([CHI 1997](https://dl.acm.org/doi/10.1145/1240866.1241085)) and a [2014 Frontiers in Psychology review](https://pmc.ncbi.nlm.nih.gov/articles/PMC4137171/) confirm that abstract concepts are grounded in sensorimotor metaphors: "power is up," "similarity is proximity," synthesis = bringing together → pinch.

### Competitive Landscape

| Tool | Spatial Persistence | Semantic Position | Scaling | Rich Content |
|------|-------------------|-------------------|---------|-------------|
| **Obsidian Graph View** | None (positions change every load) | Topology only (no semantic anchoring) | Unusable at ~2K+ nodes | No (graph view) |
| **Scapple** | Full persistence | User-defined (freeform) | Limited (no LOD) | Basic text cards |
| **TheBrain** | Active thought centering (shifts context) | Hierarchy-based (parent/child/jump) | 500K+ claimed | Link-organized |
| **Heptabase** | Canvas persistence | User spatial + card connections | Limited (no clustering) | Rich card content |
| **Kumu** | Pinning supported but unreliable across sessions | Force-directed + manual override | Good (web-scale) | System mapping focus |
| **Cosma** | Read-only visualization | Citation-based | Moderate | Full content cards ([Cosma](https://cosma.arthurperret.fr)) |

Obsidian's graph view failure is instructive: positions are non-deterministic across sessions, destroying spatial memory. Users report it is "non-functional because there is no consistency in the actual graph" ([Obsidian forum](https://forum.obsidian.md/t/whats-the-point-of-the-graph-view-how-are-you-using-it/71316)). The Heptabase-Obsidian gap — spatial manipulation without semantic linking vs. semantic linking without spatial persistence — is the opportunity this system aims to fill.

### Technical Implementation Patterns

**ForceAtlas2 algorithm.** [Jacomy et al. (2014, *PLoS ONE*)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4051631/) is the most practically relevant force-directed algorithm for knowledge graphs (100–100K nodes). Force model: repulsion `f_r(n_i,n_j) = k_r·(deg(i)+1)·(deg(j)+1)/d(i,j)²`, attraction `f_a = d(i,j)/k_r` (linear, or log for LinLog mode), gravity `f_g = g·(deg(i)+1)/d(i,0)`. Degree-dependent repulsion is the key innovation — hub nodes repel more strongly, preventing leaf-node forests from clustering around hubs. Adaptive cooling: per-node swinging measure `s(n,t) = ||F(n,t) - F(n,t-1)||`; per-node speed scales inversely with oscillation. Default tolerance by graph size: <5K nodes: 0.1; 5K–50K: 1.0; >50K: 10.0.

**Benchmark against alternatives** (68 networks, 5–23,133 nodes):

| Algorithm | Avg QO Convergence | Notes |
|---|---|---|
| ForceAtlas2 | 638ms | Best balance quality/speed |
| Yifan Hu | 333ms | Fastest convergence |
| FA2 LinLog | 1,184ms | Best cluster separation |
| Fruchterman-Reingold | 20,201ms | Best quality, unusable at scale |

Barnes-Hut approximation reduces O(n²) to O(n log n). The critical parameter θ controls accuracy/speed: θ=1.0 gives significant speedup with ~5% pixel error avg ([Heer interactive analysis](https://jheer.github.io/barnes-hut/)). For multilevel approaches at 10K+ nodes, FM³ (Fast Multipole Multilevel Method) achieves O(|V| log |V| + |E|) with recursive coarsening, base layout, and refinement phases — producing "nice drawings of graphs with 100,000 nodes in less than 5 minutes" ([FM³ paper](https://d-nb.info/1251482813/34)).

**Metal compute shader architecture.** Apple Silicon's unified memory (`MTLStorageMode.shared`) enables zero-copy semantics between CPU and GPU — the same physical memory is accessible from both ([Apple Developer](https://developer.apple.com/documentation/metal/mtlstoragemode/shared)). Buffer layout: `NodeData { position: float2, velocity: float2, force: float2, mass: float, pinned: float, node_id: uint }`. Three-pass compute pipeline: (1) repulsion via Barnes-Hut quadtree traversal, (2) attraction per edge, (3) integration with ForceAtlas2 adaptive speed. Attraction kernel race condition handled via `atomic_float` (Metal 3), sorted edge processing, or hybrid GPU-repulsion + CPU-attraction ([LambdaClass blog](https://blog.lambdaclass.com/using-metal-and-rust-to-make-fft-even-faster/)).

**Metal compute shader buffer layout:**

```metal
struct NodeData {
    float2 position;    // current position
    float2 velocity;    // current velocity
    float2 force;       // accumulated force for this step
    float  mass;        // degree+1 (for FA2 repulsion)
    float  pinned;      // 0.0 = free, 1.0 = pinned (ignores forces)
    uint   node_id;
    uint   pad;         // alignment
};
```

Three-pass compute pipeline: (1) repulsion via Barnes-Hut quadtree traversal (one thread per node), (2) attraction per edge (one thread per edge, using `atomic_float` for Metal 3 to handle race conditions on shared node force accumulators), (3) integration with ForceAtlas2 adaptive speed. Option 3 for the atomic race: GPU handles expensive O(n log n) repulsion, CPU handles O(e) attraction in parallel using Rust's Rayon — pragmatic for graphs up to ~50K edges, with Apple Silicon's unified memory enabling zero-copy position buffer reads.

**120fps via decoupled physics and rendering.** The canonical pattern: fixed timestep (60Hz physics) with interpolated rendering (up to 120Hz on ProMotion displays). Triple-buffered position buffer: physics writes to one buffer while render reads another; atomic pointer swap. Apple's ProMotion displays vary between 24Hz and 120Hz adaptively — if physics and rendering are coupled, the physics timestep varies with display refresh, causing non-deterministic behavior. Decoupling ensures physics always runs at fixed rate while rendering runs at whatever rate the display supports ([Glenn Fiedler, "Fix Your Timestep"](https://stackoverflow.com/questions/43302268/why-use-integration-for-a-fixed-timestep-game-loop-gaffer-on-games)).

**Rust-Metal integration.** `objc2-metal` (replacing deprecated `metal-rs`) provides Rust bindings for Metal device, command queue, and compute pipeline state. Pre-compile `.metal` shaders to `.metallib` during build. Architectural split: Swift handles Metal rendering; Rust manages graph data structures and physics coordination; shared state in `MTLBuffer` with `StorageModeShared`.

**Gesture design for semantic operations.** Ben Shneiderman's direct manipulation framework ([Shneiderman, 1997](https://www.cs.umd.edu/~ben/papers/Shneiderman1997Direct.pdf)) specifies three requirements: continuous representation of objects of interest, physical actions instead of complex syntax, and rapid incremental reversible operations. For semantic operations (pinch-to-synthesize, lasso-to-summarize), the reversibility requirement is hardest to meet because these operations are semantically destructive. **Strategy:** Treat semantic gesture operations as *proposals*, not immediate commitments — pinching shows a preview synthesis with accept/adjust/reject options.

**Pinch-to-synthesize.** [Ohta & Tanaka (2016)](https://www.semanticscholar.org/paper/Using-Pinching-Gesture-to-Relate-Applications-on-Ohta-Tanaka/9fd0147fa7d2a39c9bd79f807427ba8ce819f64f) demonstrated that pinch is "intuitive" for combining "multiple partial solutions into one." Visual feedback requirements: (1) during approach — show connecting arc between targeted nodes; (2) during pinch execution — merging animation with text content overlapping; (3) post-gesture, pre-commit — synthesis preview with Accept/Edit/Reject; (4) on reject — animate nodes back to original positions.

**Lasso-to-summarize.** The lasso selection paradigm from vector graphics tools (Illustrator, Figma, [Adobe lasso docs](https://helpx.adobe.com/photoshop/using/selecting-lasso-tools.html)). After lasso completion: show a minimal HUD floating near selection center with radiating buttons (Summarize, Group, Tag, Delete) — menus break spatial flow. Summary node should expand on tap to reveal underlying nodes; original nodes preserved (not deleted).

**Drag-to-relate.** Direct manipulation edge creation: after ~200ms hold on node body, show edge creation indicator (translucent arrow). Arrow snaps to nearby nodes within ~60pt with haptic feedback (NSHapticFeedbackManager). Drop on target = create edge with inline type picker; drop on empty canvas = create new connected node.

**Gesture disambiguation.** macOS trackpad reserves two-finger pinch for zoom. Semantic pinch-to-synthesize: if pinch center is within bounding box of two nodes and both within 200pt, interpret as node-targeting; otherwise canvas zoom. Implement via `NSGestureRecognizer` subclass with `gestureRecognizerShouldBegin` checking node proximity. Edge creation: single-finger long-press (500ms) on node body; two-finger interactions reserved for navigation. Three-finger swipe up (Mission Control) is non-interceptable; use three-finger *tap* for in-app operations.

**Continuous vs. discrete interaction.** Research on [fluid interaction for creative work](https://dl.acm.org/doi/10.1145/3544548.3581433) distinguishes continuous interaction (analog, gradual, undoable at any point) from discrete interaction (committed, semantic, creates new state). Semantic gesture operations are discrete — the system must clearly signal the transition via a "release to commit" moment with distinct visual feedback. Additionally, Don Norman's [critique of gestural interfaces](https://jnd.org/gestural-interfaces-a-step-backwards-in-usability/) identifies the discoverability problem: "Swipes and gestures cannot readily be incorporated in menus." The gesture hints layer (toggleable overlay showing available gestures in context) is the canonical solution. Progressive disclosure: teach basic gestures first; introduce semantic gestures after users demonstrate facility with navigation.

**Spatial persistence.** Hard pins with serialized positions in graph data. Soft constraints (bias forces toward user-set position):

```metal
// In integrate kernel:
float2 user_anchor = nodes[i].user_anchor;  // 0,0 if not set
float anchor_strength = nodes[i].anchor_strength;  // 0.0–1.0
float2 bias_force = (user_anchor - nodes[i].position) * anchor_strength;
nodes[i].force += bias_force;
```

`anchor_strength = 0.0` = fully physics-driven; `1.0` = equivalent to hard pin; `0.3–0.5` creates a node that gravitates toward its user-set position but can be displaced by strong topological forces. [User-Guided Force-Directed Layout](https://arxiv.org/html/2506.15860) (2025) uses freehand sketching to generate positional constraints that guide force-directed layout — directly applicable as a "sketch mode" where the user draws a rough arrangement refined by physics.

**Settle mode vs. Explore mode** resolves the stability-responsiveness tradeoff. Settle mode (default): high damping (0.98+), only processes incremental changes, mental map largely preserved. Explore mode (opt-in toggle): lower damping (0.85), force strengths increased, users can "shake" a region by dragging a node to reveal hidden cluster structure. Warning indicator prevents accidental reorganization. Incremental layout for new nodes: if connected, place within bounding box of direct neighbors; if unconnected, place at periphery or user's last cursor position.

**LOD strategies.** Node LOD tiers:

| Zoom Level | Node Count Visible | Rendering | Label |
|---|---|---|---|
| Overview (<0.2x) | All nodes | Points (1–3px) | None |
| Mid (0.2–0.8x) | All nodes | Points (3–8px) + cluster hulls | Cluster labels only |
| Focus (0.8–2x) | All nodes | Small circles | Top-degree nodes only |
| Detail (>2x) | Viewport nodes only | Full node (circle + icon) | All visible nodes |

Cluster LOD via density-based aggregation: render each community as a single representative node at overview zoom, sized by node count, colored by dominant type. [MINGLE edge bundling](http://yifanhu.net/PUB/edge_bundling.pdf) (Gansner et al., AT&T Labs) achieves O(k|E| log |E|) complexity, bundling 100,000 edges in ~20 seconds, reducing visual clutter by 60–80%. For real-time rendering, pre-compute bundles during idle time and cache as spline paths in a Metal vertex buffer.

**Semantic zooming** (distinct from geometric zoom) changes the *type and meaning* of information displayed, not just its size. Key algorithmic guarantees: persistence (nodes introduced at a zoom level persist at all more-detailed levels), no label overlap, geometric stability, and scale-to-layer monotonicity. Empirical results on Google Scholar's Topics graph (5,947 nodes, 26,695 edges): semantic zoom over 8 levels achieves lower layout stress and superior compactness relative to non-semantic zooming ([emergentmind.com](https://www.emergentmind.com/topics/semantic-zoom)). Implementation: precompute layouts at 5–8 zoom level intervals during idle time; cross-fade between levels using spring-damped interpolation (not linear) for smooth deceleration.

**Spatial memory research.** Robertson et al.'s [Data Mountain](https://dl.acm.org/doi/pdf/10.1145/288392.288596) (Microsoft, 1998) directly established that humans form spatial memory for document positions in 3D virtual environments — retrieval times and error rates were lower with spatial memory compared to title-based search. [Czerwinski et al.](https://www.sciencedirect.com/science/article/abs/pii/S1071581904000096) confirmed improved user memory. **Every time the force-directed layout rearranges nodes, it destroys the spatial memory users have built** — this is not minor annoyance but erasure of cognitive investment.

Misue et al.'s mental map preservation principles (referenced in [Mennens et al., "A Stable Graph Layout Algorithm"](https://robinmennens.github.io/Portfolio/files/Mennens%20et%20al.%20-%202019%20-%20A%20stable%20graph%20layout%20algorithm%20for%20processes.pdf)) define four properties: relative direction preservation, proximity preservation, regional containment, and orthogonality preservation. "Stability and quality are two conflicting requirements: graph layout stability helps preserve the mental map of the user, but also restricts the graph layout algorithm in optimizing layout quality." Resolution: use animation to bridge layout changes — even when positions must change, animated transitions allow users to track nodes through displacement.

### Critical UX Pitfalls

**The hairball problem.** The catastrophic failure of large knowledge graphs. Root cause: visualizing raw graph instead of purpose-specific views ([Cambridge Intelligence](https://cambridge-intelligence.com/how-to-fix-hairballs/)). **Ranked mitigations:** (1) Semantic clustering with cluster-level nodes; (2) MINGLE edge bundling; (3) degree-dependent sizing + importance culling; (4) edge culling by weight; (5) LOD-based edge rendering.

**Layout instability.** The #1 practical complaint. **Root causes and mitigations:** Non-deterministic initial positions → seed RNG with graph hash. Force simulation runs to different equilibria → hierarchical multilevel layout. User positions overwritten → hard pin system with serialized positions. Session persistence failure → serialize all node positions on every change. **Spatial memory research:** Robertson et al.'s [Data Mountain](https://dl.acm.org/doi/pdf/10.1145/288392.288596) (Microsoft, 1998) established that humans form spatial memory for document positions; [Czerwinski et al.](https://www.sciencedirect.com/science/article/abs/pii/S1071581904000096) confirmed improved user memory with spatial visualization. Every layout rearrangement destroys cognitive investment.

**Performance cliff.** <1K nodes: naive O(n²); 1K–10K: Barnes-Hut + GPU; 10K–100K: GPU mandatory + LOD + multilevel; >100K: incremental only, never global force simulation. The [mlx-vis benchmark](https://arxiv.org/html/2603.04035v3) demonstrates 70K points at ~5ms per SGD step on M3 Ultra.

**Gesture conflicts with macOS.** Two-finger pinch (zoom vs. synthesize) resolved by context detection via `gestureRecognizerShouldBegin`. Three-finger swipe up (Mission Control) is non-interceptable — avoid three-finger swipe gestures entirely.

**Accidental reorganization.** Every physics state change must be on the undo stack. Explicit mode boundaries: layout-affecting gestures only work in labeled edit modes. Commit-then-settle: after drag in physics mode, pause physics 2 seconds, show "Settle" button ([undo analysis](https://dev.to/isaachagoel/you-dont-know-undoredo-4hol)).

**Spatial bias.** Users interpret physics-derived positions as semantic. **Mitigations:** Show position provenance (solid border = user-positioned, dashed = physics-positioned); semantic similarity coloring on edges independent of spatial distance; "Why are these near each other?" hover affordance. Shneiderman's direct manipulation requirements — continuous representation, physical actions over syntax, rapid incremental reversible operations ([Shneiderman, 1997](https://www.cs.umd.edu/~ben/papers/Shneiderman1997Direct.pdf)) — and Norman's critique of gestural interfaces ([Norman, 2010](https://jnd.org/gestural-interfaces-a-step-backwards-in-usability/)) both require gesture hints and keyboard alternatives.

**Accessibility.** [WCAG 2.5 Pointer Gestures](https://www.w3.org/WAI/WCAG21/Understanding/input-modalities.html) requires that all multipoint or path-based gestures can be operated with a single pointer. [WCAG 2.5.7 Dragging Movements](https://andrewhick.com/accessibility/humans/) (WCAG 2.2 AA) requires all drag-and-drop can be achieved with point-and-click.

**Required keyboard alternatives for every gesture:**

| Gesture | Keyboard Alternative |
|---|---|
| Pinch-to-synthesize | Select two nodes (Shift+click), then Cmd+M (Merge) |
| Lasso-to-summarize | Select nodes (Shift+click multiple), then Cmd+Shift+S |
| Drag-to-relate | Select source node, Cmd+E, Tab to target, Enter to create |
| Node drag (position) | Select node, arrow keys with hold modifier |
| Canvas pan | Keyboard scroll or dedicated arrow key mode |

**Reduced-motion accessibility:** `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` must suppress physics animation when enabled. Provide a "snap to stable layout" mode showing a static force-equilibrium without animation. Single-finger alternatives for every two-finger gesture accessible via the gesture hint overlay.

---

## Cross-Cutting Architecture

### Shared Infrastructure Components

| Component | Used By | Implementation |
|-----------|---------|---------------|
| **HNSW vector index (usearch)** | Cap 1 (search), Cap 4 (concept embedding), Cap 5 (orphan detection, re-indexing) | Single index file managed by Rust; staging buffer pattern for concurrent writes; nightly compaction by Night Brain |
| **Model2Vec embeddings** | Cap 1 (query encoding), Cap 4 (concept centroids), Cap 5 (re-embedding) | ~1ms/paragraph; frozen encoder shared across all capabilities |
| **Append-only OpLog** | Cap 3 (edit telemetry), Cap 4 (graph events), Cap 5 (change detection) | GRDB table with per-event timestamps; source of truth for temporal reconstruction |
| **AXUIElement / Rust FFI** | Cap 2 (cross-app capture), Cap 1 (active context detection) | `accessibility-sys` crate; main-thread-only constraint; Swift AX → Rust processing pipeline |
| **Metal compute shaders** | Cap 4 (GPU graph rendering), Cap 5 (embedding generation), Cap 6 (physics simulation) | `MTLStorageMode.shared` for zero-copy; sequential phase scheduling to prevent thermal accumulation |
| **GRDB/SQLite** | Cap 4 (bitemporal schema), Cap 5 (FSRS state, pipeline checkpoints), Cap 6 (spatial position persistence) | STRICT tables; JSON1 for flexible metadata; covering indexes for temporal range queries |
| **Leiden community detection** | Cap 4 (community migration), Cap 5 (cluster-based orphan detection), Cap 6 (cluster-level LOD rendering) | Dynamic Frontier variant (Sahu 2024) for incremental updates; run nightly by Night Brain |
| **petgraph** | Cap 4 (centrality computation, graph diffing), Cap 5 (betweenness centrality for orphan scoring) | Rust FFI to Swift; `StableGraph` for stable node indices across snapshots |

### Dependency Ordering for Implementation

```
Phase 1 — Foundation (no inter-capability dependencies):
  ├── Cap 1: Contextual Shadows (requires HNSW + Model2Vec — already built)
  └── Cap 3: Cognitive Friction Detection (requires OpLog — already built)

Phase 2 — Capture Layer (depends on AX infrastructure):
  └── Cap 2: Ambient Cross-App Capture (requires AXUIElement FFI, ScreenCaptureKit)
      Produces: captured knowledge that feeds into HNSW index

Phase 3 — Analysis Layer (depends on Phases 1-2 producing data):
  ├── Cap 4: Temporal Knowledge Graph (requires GRDB bitemporal schema, Leiden, petgraph)
  │           Consumes: note content + timestamps from Caps 1-3
  └── Cap 5: Night Brain (requires NSBackgroundActivityScheduler, XPC, usearch rebuild)
              Consumes: full vault for re-indexing, graph state for orphan detection

Phase 4 — Interaction Layer (depends on graph infrastructure):
  └── Cap 6: Spatial Graph (requires Metal physics, Rust-Metal FFI, Leiden clusters)
              Consumes: graph topology from Cap 4, community structure from Leiden
```

### Interaction Patterns Between Capabilities

**Cap 3 → Cap 1:** When cognitive friction is detected, the Contextual Shadows panel increases its density of related notes. When flow is detected, the panel suppresses updates. The friction score modulates the panel's update frequency and result diversity.

**Cap 2 → Cap 1 + Cap 5:** Cross-app captured text is embedded and added to the HNSW staging buffer, appearing in Contextual Shadows results within 30 seconds. Night Brain re-indexes captured content and detects orphan connections between captured knowledge and existing notes.

**Cap 4 → Cap 6:** The temporal knowledge graph's community structure drives the spatial graph's cluster-level LOD rendering. Community migration events appear as animated node movements in the spatial canvas. Drift scores color-encode nodes.

**Cap 5 → Cap 4 + Cap 6:** Night Brain runs Leiden community detection nightly, producing community assignments consumed by both the temporal graph (for migration tracking) and the spatial graph (for cluster rendering). It also computes embedding centroids used by Cap 4 for drift detection and pre-computes UMAP projections cached by Cap 6.

**Cap 3 → Cap 5:** Session-level friction and flow data from the OpLog are logged by Cap 3 and consumed by Night Brain's morning digest: "Yesterday's session was high-effort — here are the concepts you were reaching for."

### Thermal and Energy Budget

Apple Silicon's unified memory architecture means CPU, GPU, and ANE share the same thermal envelope. Running a Metal embedding compute shader at full throughput while HNSW insertion is hot on CPU cores can quickly push the package to heavy thermal pressure, triggering throttling that reduces overall throughput below what sequential scheduling would achieve. The key architectural constraint: capabilities that run during active use (Caps 1, 2, 3, 6) must never compete with each other for GPU or ANE resources. Capabilities that run in the background (Caps 4, 5) must respect thermal limits.

**During active use:** Cap 1 (Model2Vec encode: ~1ms, negligible), Cap 2 (AXObserver + occasional OCR: ANE, low impact), Cap 3 (OpLog processing: CPU, negligible), Cap 6 (Metal physics + rendering: GPU, dominant). The GPU budget during active use is dominated by Cap 6; Caps 1-3 operate in the thermal margin.

**During overnight processing (Night Brain):** Phase work sequentially: GRDB reads → Metal embedding generation → HNSW insertions → Leiden community detection → orphan scoring → digest assembly. Never pipeline GPU + CPU heavy work simultaneously. Hard backoff at thermal pressure level 2; pause at level 3. QoS `.background` throughout to activate efficiency cores.

### Design Principles Synthesized Across All Capabilities

**Architecture Principles:**
1. **Ambient over explicit.** The system surfaces information at the periphery of attention without demanding explicit query. Capabilities 1, 2, and 3 all operate silently.
2. **On-device, private by default.** All computation (embedding, search, friction detection, drift analysis, orphan scoring) runs locally on Apple Silicon. No data leaves the device.
3. **Event-sourced append-only.** The OpLog is the source of truth for Capabilities 3, 4, and 5. Any historical state can be reconstructed. Deletions are soft (tombstones), not destructive.
4. **Sequential phase scheduling.** Capabilities sharing the thermal envelope (Metal GPU + CPU + ANE) never pipeline heavy work simultaneously. Night Brain sequences GRDB reads → Metal embedding → HNSW insertion → Leiden community detection.

**Interaction Principles:**
5. **Every semantic operation is a proposal, not a commitment.** Pinch-to-synthesize shows preview; lasso-to-summarize shows preview; friction-triggered ambient panel updates are revocable.
6. **The moment of highest difficulty is the worst moment to interrupt.** Capability 3's friction detection triggers silent environmental adaptation, never overt notification.
7. **Undo covers spatial state.** Every node position change, semantic operation, and layout shift is on the undo stack.
8. **Night Brain is read-only.** It never moves, renames, deletes, or modifies notes. The digest is a recommendation surface.

**Semantic Principles:**
9. **Distinguish physics proximity from semantic proximity.** Visual encoding differentiates user-positioned from physics-positioned nodes.
10. **Drift detection surfaces questions, not answers.** "Your thinking on X may have shifted" not "drift score 0.34."
11. **Show why, not just what.** Every surfaced note, orphan candidate, and digest item includes its reasoning chain.
12. **Forgetting is not failure.** The system respects that some knowledge is legitimately dormant; orphan detection applies confidence thresholds to avoid surfacing noise.

This architecture ensures that the six capabilities operate as a coherent system: ambient retrieval during writing, silent capture from other apps, invisible friction detection modulating the ambient surface, temporal analysis revealing conceptual evolution, overnight processing maintaining index quality and surfacing orphaned knowledge, and a spatial canvas that makes the full knowledge graph physically manipulable.
