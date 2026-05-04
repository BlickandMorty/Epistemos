# Contextual Shadows — Ambient Semantic Retrieval Panel
## Research Compendium for a Native macOS Personal Knowledge System

> **System context:** Swift + Rust + Metal + on-device MLX inference. HNSW vector search via usearch in Rust, Model2Vec embeddings (~1ms/paragraph), NSTextView-based editor. Pipeline: 200ms debounce → Model2Vec encoding → HNSW top-K retrieval.

---

## Section 1: Cognitive Science Justification

### 1.1 Gary Klein's Recognition-Primed Decision (RPD) Model and Naturalistic Decision Making

Gary Klein's Recognition-Primed Decision (RPD) model, developed through fieldwork with firefighters and military commanders in the late 1980s and formalized in the 1989 Naturalistic Decision Making conference, describes how experts make decisions in complex, time-pressured environments. Rather than performing exhaustive option comparisons, experts **pattern-match the current situation against a rich library of prior experience** stored in long-term memory. When a situation is recognized as familiar, the expert retrieves a plausible course of action along with associated expectancies — predictions about how the situation will develop.

The core mechanism is two-stage: (1) **situational recognition** — matching the current context to a prototype or exemplar from memory — and (2) **mental simulation** — running forward the anticipated action to test plausibility before executing. Klein emphasizes that this process is not analytical; it operates largely below conscious deliberation. The expert *knows* what to do because the situation *reminds* them of other situations.

Wright and Klein's 2016 review of Naturalistic Decision Making and its evolution into **Macrocognition** — the study of cognitive performance in real-world conditions — identifies the core macrocognitive functions as: sensemaking, mental simulation, leveraging expertise, and maintaining shared awareness ([Wright & Klein, 2016, *Frontiers in Psychology*](https://pmc.ncbi.nlm.nih.gov/articles/PMC4731510/)). The Contextual Shadows panel is, computationally, an externalization of the RPD situational recognition mechanism: it surfaces the "prior experience" that an expert mind would match against, but which a less experienced user (or the same expert in a new domain) cannot retrieve unaided.

**Implications for system design:** The panel should present **complete past notes as units of recognition**, not extracted fragments. The RPD model predicts that seeing a whole prior episode (the note) triggers a richer associative cascade than seeing a sentence fragment, because recognition fires on structural pattern similarity rather than keyword overlap. The embedding space of Model2Vec — trained on sentence structure, not bag-of-words — aligns better with this than BM25.

Patterson et al.'s 2009 system dynamics model of the RPD framework demonstrates that the model has three distinct variations covering simple match, diagnosed situation, and comparative evaluation ([Patterson et al., 2009, *NDM Conference*](https://www.scienceopen.com/document_file/efb29f77-ce60-437e-b845-5f0e11b57e66/ScienceOpen/113_Patterson.pdf)). The simplest form — simple match — dominates expert recall and is precisely what the panel should facilitate: a single high-confidence recognition at low attentional cost.

---

### 1.2 Involuntary Autobiographical Memory and Creative Insight

Dorthe Berntsen (Aarhus University) has produced the foundational taxonomy of involuntary autobiographical memories (IAMs) — memories that come to mind spontaneously, without deliberate retrieval intention, triggered by cues in the immediate environment. Her 2009 monograph *Involuntary Autobiographical Memory* (Cambridge University Press) and subsequent empirical work establish several facts relevant to knowledge system design:

1. **IAMs are not rare.** A telephone survey of 1,500 Danes found approximately 60% of IAMs reported were positive, and a mechanical counter study showed IAMs occur *three times more frequently* than voluntary memories in everyday life ([Berntsen & Rubin, 2009, *Memory & Cognition*](https://pmc.ncbi.nlm.nih.gov/articles/PMC3044938/)). The cognitive architecture already produces ambient retrieval constantly; the Contextual Shadows panel externalizes and directs this natural process.

2. **IAMs are cue-driven.** They are elicited by external cues — activities, sensory stimuli, locations, or thoughts — that match encoded aspects of the original experience. Crucially, the cue need not literally match the content; *structural* or *thematic* similarity suffices. This mirrors how embedding-based nearest-neighbor search works: similarity in latent semantic space, not string overlap.

3. **IAM chains propagate via spreading activation.** Mace (2014) documented involuntary memory chaining — where one IAM triggers another through associative links — and proposed this operates via a process "akin to spreading activation" over autobiographical memory organization ([Mace, 2014, *Frontiers in Psychiatry*](https://pmc.ncbi.nlm.nih.gov/articles/PMC4267106/)). The panel's top-K results are the initial links in such a chain; users who follow them are engaging in precisely the kind of creative free-association that insight research associates with remote conceptual access.

4. **IAMs and creative insight.** Berntsen's model positions IAMs as a mechanism for "spontaneous integration" — they bring forward contextually relevant prior episodes that bear on current cognition without conscious search. Research on the [incubation effect](https://pmc.ncbi.nlm.nih.gov/articles/PMC3044938/) in creativity suggests that ambient exposure to loosely related prior material during work on a problem increases the probability of insight. The Contextual Shadows panel operationalizes this: by surfacing semantically proximate past notes while the user writes, it creates the conditions for IAM-like recognition events.

**Design implication:** Panel results should be **presented with enough context to trigger recognition** — a title, a first sentence, and a timestamp — not just metadata. The retrieval is only useful if it fires the same semantic-associative recognition that IAMs leverage.

---

### 1.3 Spreading Activation Theory (Collins & Loftus)

Collins and Loftus's 1975 paper "A Spreading Activation Theory of Semantic Processing" (*Psychological Review*, 82(6), 407–428) introduced the computational framework most directly analogous to what the Contextual Shadows pipeline does. In their model, concepts are represented as **nodes in a semantic network**, and activation spreads outward along associative links when a concept is processed — with activation decaying with semantic distance. Processing the word "fire engine" activates not just "truck" and "red" (close neighbors) but also "ambulance" and "sunset" (more distal, through multiple hops).

Subsequent work on **semantic priming** — where processing a word speeds recognition of semantically related words — provides empirical validation of spreading activation. Masked priming studies show this operates automatically at SOAs as short as 200ms ([Silkes & Rogers, 2012](https://pmc.ncbi.nlm.nih.gov/articles/PMC4598179/)), consistent with the pipeline's target latency.

The spreading activation framework maps directly onto dense vector search:
- **Nodes** = embedded notes in vector space
- **Semantic distance** = cosine distance between embeddings  
- **Activation spreading** = the neighborhood structure of the HNSW graph
- **Priming** = the user's current writing context activating nearby notes

Critically, Bell et al. (2016) extended Collins & Loftus to **emotional memory networks**, showing spreading activation operates over episodic memory (not just semantic) and that somatic markers modulate which pathways are traversed ([Bell et al., 2016, *Brain Informatics*](https://pmc.ncbi.nlm.nih.gov/articles/PMC5413589/)). This supports including recently-accessed notes with emotional salience markers in the ranking function — not just semantic similarity scores.

**Design implication:** The HNSW search is not just finding "similar" notes; it is simulating the automatic spreading activation process that the brain performs when encountering a concept. The quality of the embedding model directly governs the fidelity of this simulation. Model2Vec's distilled static embeddings, while faster than transformer inference, should be validated on the specific domain vocabulary of personal notes (which differ from typical pretraining corpora in register, abbreviation density, and personal proper nouns).

---

### 1.4 The Generation Effect and Recognition vs. Recall

The **generation effect** — first rigorously documented by Slamecka and Graf (1978) and extensively replicated — establishes that memory for information is better when the learner generates it (e.g., solves for a word from a clue) than when they passively read it. The mechanisms are debated but converge on two factors: enhanced item-specific processing (the generative effort creates more distinctive encoding) and enhanced relational processing (generation forces the learner to connect the item to prior knowledge).

Shimamura, Elman, and Rosner (2013) demonstrated via fMRI that generation activates **broad neural circuits** during encoding — frontal-posterior cortical dynamics associated with elaborative processing — compared to passive reading ([Shimamura et al., 2013, *Cortex*](https://pmc.ncbi.nlm.nih.gov/articles/PMC3556209/)). This provides a neurological account for why recognition (being shown a related note) can trigger deeper processing than mere recall would.

McCurdy et al. (2020) showed that generation under **lower constraints** (open-ended tasks, not fill-in-the-blank) produces stronger generation effects via enhanced relational processing, and this extends to *source memory* (contextual details) as well as item memory ([McCurdy et al., 2020, *Memory*](https://www.tandfonline.com/doi/full/10.1080/09658211.2020.1749283)). This is the relevant condition for knowledge work: a writer generating prose has low constraint on what emerges, meaning seeing a related note is more likely to produce a deep relational encoding and a lasting insight connection.

**The recognition vs. recall distinction matters here.** The panel is a **recognition aid**, not a recall aid. The cognitive literature consistently shows that recognition outperforms recall for complex semantic material — the related note appearing in the panel reduces the cognitive demand from "generate a connection" to "evaluate and accept/reject a presented connection." This substantially lowers the barrier to cross-note linking and conceptual integration. DEVONthink's "See Also" feature exploits this; the difference in the current system is real-time, context-sensitive triggering rather than document-level triggering.

---

## Section 2: Ambient Information Systems & Calm Technology Design

### 2.1 Mark Weiser's Calm Technology Principles

Mark Weiser and John Seely Brown's 1996 paper "The Coming Age of Calm Technology" (Xerox PARC) remains the definitive theoretical framework for peripheral information display. Their central claim: **"Calm technology engages both the center and the periphery of our attention, and in fact moves back and forth between the two."**

Weiser and Brown defined the **periphery** as "what we are attuned to without attending to explicitly." They argued that peripheral awareness is processed by a large portion of brain architecture devoted to sensory/peripheral processing — this substrate is informationally rich but attentionally cheap. A technology is *encalming* if it:

1. **Lives primarily in the periphery** — it informs without demanding focus
2. **Moves easily center ↔ periphery** — the user can pull it into attention at will
3. **Enhances peripheral reach** — it extends what can be known without looking directly

Their exemplar artifact was the "dangling string" — a physical network traffic indicator where motion in peripheral vision conveyed bandwidth without requiring screen attention. The Contextual Shadows panel is a software analog: it lives at the screen edge, updating silently, never demanding response, but capturable with a glance.

The [Designing Calm Technology paper (MIT CSAIL mirror)](https://people.csail.mit.edu/rudolph/Teaching/weiser.pdf) explicitly warns against the failure mode where the periphery becomes overloaded: "This is encalming when the enhanced peripheral reach increases our knowledge and so our ability to act **without increasing information overload**." The key qualifier is *without increasing information overload* — a panel that updates too frequently, shows too many results, or uses high-contrast visual elements crosses from peripheral to intrusive.

**Amber Case's 2015 codification** of calm technology principles ([Principles of Calm Technology](https://www.caseorganic.com/post/principles-of-calm-technology)) is operationally useful:
- Technology can communicate, but **doesn't need to speak**
- Communicate information **without taking the user out of their environment or task**
- A person's primary task should not be computing, **but being human**
- Give people what they need to solve their problem, **and nothing more**

For the Contextual Shadows panel: no sound, no animations that animate *into* the editing area, no bold or high-saturation colors in result cards, and a default collapsed state that the user must **choose** to expand.

---

### 2.2 Hiroshi Ishii & MIT Tangible Media Group: Ambient Displays

Hiroshi Ishii and Brygg Ullmer's 1997 CHI paper "Tangible Bits: Towards Seamless Interfaces between People, Bits and Atoms" introduced **tangible user interfaces** — physical objects that embody digital information. Their follow-on work on **ambient displays** (notably the ambientROOM installation at MIT Media Lab, 1998) demonstrated that information encoded as room-level environmental changes — light, sound, airflow, water ripples — could be absorbed via background perception without interrupting foreground tasks.

The ambientROOM exploited the brain's pre-attentive processing: pattern changes in peripheral vision and changes in ambient sound register subcognitively and shift into focus when salient enough, but do not hijack attention when below threshold. The critical insight for software design: **ambient information should exploit pre-attentive visual features** (color, motion, spatial position) rather than attentive features (text, iconography, precise shapes) when operating in peripheral mode.

Scott Wisneski (MIT, 1998) extended this to **peripheral information systems** in screen-based interfaces, studying what visual properties allowed information to be absorbed peripherally. Their findings: smooth, **slow-moving** visual changes in **low-saturation** colors in the **spatial periphery of the screen** (edges, corners) were processed without attention capture. High-contrast, high-frequency updates — even in the periphery — captured attention involuntarily.

**Practical implication for the panel:**
- Panel placement: right edge of screen, below the fold of the current editing position
- Result card appearance: low-contrast text on a slightly differentiated background — no bright colors, no borders with strong contrast
- Update behavior: fade-transition between result sets over ~400ms, not instant swap (which triggers peripheral attention capture)
- Result count: 3–5 maximum visible without scroll (see Section 6.2)

---

### 2.3 Matthews et al. and McCrickard & Chewar: Peripheral Displays and Attention

McCrickard and Chewar (2003, Virginia Tech) developed the **Interruption, Reaction, Comprehension (IRC) framework** for evaluating notification systems, which maps the design space of peripheral vs. focal displays ([McCrickard et al., 2003, *International Journal of Human-Computer Studies*](https://linkinghub.elsevier.com/retrieve/pii/S1071581903000223)). The three axes:

- **Interruption (I):** Does the system interrupt the primary task?
- **Reaction (R):** Does the system require an immediate reaction?
- **Comprehension (C):** Does the system require deep understanding to interpret?

A well-designed ambient panel should score **low on I, low on R, and low on C** — it presents information peripherally, doesn't require response, and is interpretable at a glance. McCrickard and Chewar's empirical work showed that notification systems with high I scores (interrupting) but low utility create learned helplessness: users begin ignoring all system outputs, including high-utility ones.

Chewar and McCrickard (2004) further refined this with the concept of **user goals trade-offs**: users have competing goals around (a) not being interrupted, (b) staying aware of relevant information, and (c) being alerted to important changes ([Chewar et al., 2004, *CHI Workshop*](https://dl.acm.org/doi/10.1145/1013115.1013155)). The panel must be designed so that the dominant user goal is (b) — awareness — with (a) protecting it from being perceived as (c).

**Alert fatigue and change blindness trade-off:** Matthews et al.'s research on peripheral display attention capture found that systems can fail in two opposite directions:
- **Change blindness:** Updates are so subtle they are never noticed (under-informing)
- **Alert fatigue:** Updates are so salient they become habitual background noise that eventually ceases to register (over-informing)

The design solution is **adaptive salience calibration**: initial result changes should be visually distinct (so users form the habit of glancing), then reduce salience after the user has established the peripheral attention pattern. A fade-in over 400ms is sufficient for initial noticeability; after 2–3 weeks of use, the fade might be shortened or eliminated.

---

## Section 3: Technical Patterns for Streaming HNSW Updates

### 3.1 HNSW Concurrency Architecture

The Hierarchical Navigable Small World (HNSW) algorithm, introduced by Malkov & Yashunin (2018), builds a multi-layer proximity graph over embedding vectors. Its core advantage — logarithmic search complexity — comes from the hierarchical layer structure: sparse layers for long-range navigation, dense lower layers for precision.

**usearch's concurrency model:** The USearch library ([GitHub](https://github.com/unum-cloud/usearch)) states explicitly that "the USearch index structure is concurrent by design" and notes "Compatible with OpenMP and custom executors for fine-grained parallelism." The Rust binding (via crates.io) notes: "The add is thread-safe for concurrent index construction." However, the Rust bindings lack native `Send+Sync` derivation ([GitHub Issue #482](https://github.com/unum-cloud/usearch/issues/482)), which requires a manual wrapper using `Arc<Mutex<Index>>` for thread-safe sharing across Swift-bridged Rust threads.

**Known concurrency hazard:** [GitHub Issue #697](https://github.com/unum-cloud/usearch/issues/697) documents an integer underflow bug in `Index::size()` during concurrent add/remove operations, producing values like `18446744073709551614`. Production code should gate on explicit node counts tracked separately, not rely on `Index::size()` for correctness checks under concurrent mutation.

**Alternative: hnswlib-rs.** The `hnswlib-rs` crate ([lib.rs](https://lib.rs/crates/hnswlib-rs)) provides an `InMemoryVectorStore` that "supports lock-free reads and parallel updates (per-node spinlocks)." This architecture is preferable for the Contextual Shadows use case because:
1. Lock-free reads mean search latency is unaffected by ongoing insertions
2. Per-node spinlocks make write contention localized, not global
3. The API separates the graph structure (HNSW) from the vector store, enabling double-buffering patterns

---

### 3.2 Async Pipeline Architecture

For the 200ms debounce → encode → search pipeline, the recommended Rust async architecture is:

```
NSTextView (Swift)
    ↓ NSTextStorage delegate: textDidChange
    ↓ debounce: 200ms (via combine Publisher or async/await Task.sleep)
    ↓ [crossing FFI boundary via Swift-Rust FFI or uniffi]
Rust async worker (tokio runtime, single-threaded dedicated executor)
    ↓ Model2Vec encode: ~1ms
    ↓ HNSW search: top-K, ~2-5ms for 50k notes
    ↓ Temporal re-ranking: ~0.5ms
    ↓ [crossing back via async channel]
Swift MainActor: update NSView panel
```

**Key design choices:**

1. **Dedicated tokio executor for ML/search:** Isolate the encode+search work on a separate `tokio::runtime::Builder::new_current_thread()` runtime thread, not the shared async pool. This prevents search latency variance from competing with other async work.

2. **Cancel-on-new-input semantics:** Each keypress that resets the debounce timer should cancel the in-flight encode+search Task if it exists. In Rust with tokio, use `tokio::task::JoinHandle::abort()`. In Swift Combine, use `Cancellable.cancel()` on the previous task before creating a new one. Without cancellation, bursts of typing create a queue of encode operations that execute *after* the user has stopped typing, producing stale results.

3. **Double-buffering the index for writes:** New notes should be added to a **staging index** (small, fast to build) and periodically merged into the primary index during idle periods. The search runs against `primary_index UNION staging_index`, returning results from both. This pattern avoids blocking search during index construction. Concretely:

```rust
struct SearchEngine {
    primary: Arc<RwLock<HnswIndex>>,   // read frequently, write rarely
    staging: Arc<Mutex<Vec<(u64, Vec<f32>)>>>,  // pending inserts
}

impl SearchEngine {
    async fn search(&self, query: &[f32], k: usize) -> Vec<SearchResult> {
        let primary_results = self.primary.read().search(query, k);
        let staging = self.staging.lock().staged_search(query, k);
        merge_and_rerank(primary_results, staging, k)
    }
    
    // Called from a background task on low-activity timer
    async fn flush_staging(&self) {
        let staged = self.staging.lock().drain();
        self.primary.write().batch_insert(staged);
    }
}
```

4. **Stale reads are acceptable.** For the Contextual Shadows use case, a note written 30 seconds ago not appearing in search results is entirely acceptable — the user is writing *new* content, not trying to find something they just wrote. The staging buffer can accumulate for up to 30 seconds before being flushed without any perceptible quality degradation. This significantly reduces write contention.

---

### 3.3 Streaming HNSW Update Research

The 2025 literature on dynamic HNSW updates converges on several findings relevant to this system:

**IP-DiskANN (Xu et al., 2025)** presents the first algorithm for true in-place updates without batch consolidation, achieving stable recall over lengthy update patterns ([Xu et al., 2025, arXiv 2502.13826](https://arxiv.org/abs/2502.13826)). Their key insight: the "unreachable points phenomenon" — where deleted nodes create graph disconnections that degrade search accuracy — is the primary failure mode. For a personal knowledge system where notes are rarely deleted, this is a minor concern. Insertions-only workloads are substantially easier to manage.

**CleANN (Zhang et al., 2025)** specifically addresses concurrent updates and searches, achieving 7–1200x throughput improvement over static baseline at equivalent recall levels ([Zhang et al., 2025, arXiv 2507.19802](https://arxiv.org/abs/2507.19802)). Their approach: workload-aware linking and semi-lazy memory cleaning. The key lesson for usearch users: **do not attempt fine-grained lock-free HNSW mutation without a tested implementation** — the correctness requirements are subtle. Prefer the staging buffer pattern.

**Enhancing HNSW for Real-Time Updates (Xiao et al., 2024)** documents the "unreachable points phenomenon" in detail and proposes the MN-RU algorithm ([Xiao et al., 2024, arXiv 2407.07871](https://arxiv.org/abs/2407.07871)). For a personal note corpus of 10k–500k notes with ~1 insertion/minute, standard HNSW insert (which adds the new node and links it to existing neighbors) is entirely sufficient. The literature's concerns apply at much higher update rates.

**Latency budget analysis for the 300ms target:**

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

The pipeline has substantial headroom. Even with Model2Vec encode time doubling under thermal throttling (~2ms), the total remains under 210ms from debounce end to display update.

---

## Section 4: Temporal Relevance and Ranking

### 4.1 Memory Research on Temporal Context in Retrieval

**Tulving's Encoding Specificity Principle (1983):** Endel Tulving's foundational principle holds that retrieval is most effective when the cues present at retrieval match the context present at encoding. This has a direct implication for the panel: a note written while the user was thinking about "startup strategy" is more likely to be recalled and used when they are again thinking about "startup strategy" — not just because of semantic similarity, but because the *temporal context* of the original thought is partially restored by the similarity of the current cognitive context.

**Howard & Kahana's Temporal Contiguity Effect:** Kahana (1996) documented that in free recall, participants disproportionately recall items that were studied temporally close to the most recently recalled item — a phenomenon now called the **temporal contiguity effect (TCE)**. Healey, Kahana, and Long (2018) established that the TCE is robust across recognition, paired associates, and autobiographical recall, and across timescales from minutes to years ([Healey et al., 2018, *Psychonomic Bulletin & Review*](https://pmc.ncbi.nlm.nih.gov/articles/PMC6529295/)). Crucially, the TCE is **time-scale invariant** — notes written a week apart behave similarly to notes written a day apart relative to notes written a month apart.

Folkerts, Rutishauser, and Howard (2018) provided direct neural evidence via single-unit recording: when a human participant recalls an episodic memory with high confidence, the population vector in medial temporal lobe reinstates the *temporal context* of the original encoding — "a neural jump back in time" ([Folkerts et al., 2018, *Journal of Neuroscience*](https://www.jneurosci.org/lookup/doi/10.1523/JNEUROSCI.2312-17.2018)). This means temporal proximity is encoded as a feature of memories, not just a retrieval artifact. Notes written around the same time *are genuinely more related* in the user's memory architecture than a purely semantic distance measure would suggest.

**Ebbinghaus forgetting curve:** Murre and Dros's 2015 replication of Ebbinghaus's 1885 experiments confirmed the forgetting curve — retention declines rapidly in the first 24 hours, then more slowly, with a possible "jump upwards" at the 24-hour mark ([Murre & Dros, 2015, *PLoS ONE*](https://pmc.ncbi.nlm.nih.gov/articles/PMC4492928/)). For retrieval panel design, this means **very recent notes (last 24 hours) may deserve a recency boost** precisely because the user has not yet consolidated them into long-term memory — they are "fragile" knowledge that benefits from reinforcement. Conversely, notes older than a month have survived consolidation and their retrieval value depends primarily on semantic relevance, not recency.

---

### 4.2 Should Recent Notes Rank Higher?

The answer from the cognitive literature is **context-dependent**:

1. **Same-session notes should rank higher.** Notes written in the current writing session (last ~2 hours) are in working memory's temporal context. The TCE predicts strong associative links. A 2x boost for same-session notes is cognitively justified.

2. **Recent-week notes are likely to be from the same project.** Knowledge workers tend to work in project-bounded time blocks. Notes from the last 7 days are more likely to be contextually related than notes from 6 months ago, even controlling for semantic similarity.

3. **Very old notes with high semantic similarity should not be penalized heavily.** The "deep relevance" of an old note that perfectly matches the current semantic context outweighs recency. A note from 3 years ago about the exact concept being written about now is more useful than a note from yesterday on a tangentially related topic.

4. **Recency bias without context creates a filter bubble.** Heavy recency weighting causes older, high-quality reference notes to disappear from results, reinforcing the last-week's context rather than the full knowledge base. See Section 6.3.

---

### 4.3 Practical Ranking Formulas

The recommended approach is a **multiplicative composite score** that prevents either dimension from completely dominating:

**Formula:**
```
score(note) = semantic_similarity(query, note) × temporal_boost(note)
```

Where:

```
temporal_boost(note) = α + (1 - α) × decay_factor(age_days)

decay_factor(age_days) = {
  1.0                          if age_days < 1     (same session)
  exp(-λ₁ × age_days)         if 1 ≤ age_days < 30
  exp(-λ₂ × log(age_days))    if age_days ≥ 30    (logarithmic decay)
}
```

With parameters:
- `α = 0.7` (semantic similarity is the dominant signal; temporal only modulates)
- `λ₁ = 0.02` (exponential decay with half-life ~35 days for recent notes)
- `λ₂ = 0.15` (logarithmic decay for old notes — deep history decays much more slowly)

This formula gives:
- Same-session notes: 1.0 × semantic score (no decay)
- 1-week-old notes: ~0.86 × semantic score  
- 1-month-old notes: ~0.55 × semantic score
- 6-month-old notes: ~0.81 × semantic score (logarithmic regime — old notes still viable)
- 1-year-old notes: ~0.75 × semantic score

The **logarithmic decay for old notes** prevents the "archive disappears" failure mode. A note from 5 years ago that is semantically highly relevant will still rank above a recent note that is less relevant.

---

### 4.4 How Search Engines Handle Time-Weighted Relevance

**Elasticsearch** implements three decay function families in its `function_score` query: Gaussian (`gauss`), exponential (`exp`), and linear (`linear`) ([Elasticsearch decay functions](https://www.elastic.co/blog/found-function-scoring)):

```json
{
  "function_score": {
    "query": { "match": { "content": "..." } },
    "functions": [
      {
        "gauss": {
          "created_at": {
            "origin": "now",
            "scale": "7d",
            "offset": "1d",
            "decay": 0.5
          }
        }
      }
    ],
    "boost_mode": "multiply"
  }
}
```

The `gauss` function is recommended for most relevance applications because it decays smoothly with a natural shoulder near the origin, avoids the "cliff" of linear decay, and doesn't decay as aggressively as exponential for distant time points. For the note retrieval use case, `boost_mode: "multiply"` is correct — it ensures semantic relevance still dominates, with temporal position only scaling the result.

**Re³ (Relevance & Recency Retrieval):** A 2025 paper introduces a learnable gating mechanism for balancing semantic and temporal signals ([arXiv 2509.01306](https://arxiv.org/html/2509.01306v1)). Their benchmark Re²Bench demonstrates that a fixed-weight combination (either pure semantic or pure recency) underperforms a query-adaptive balance. For a personal knowledge system, the query-adaptive approach is achievable: if the user types a date or time reference ("last month when I was working on..."), apply stronger temporal gating; if the query is purely conceptual, rely on semantic similarity.

**Biologically-inspired hybrid formula (community synthesis):**

A practitioner synthesis on the RAG subreddit ([Reddit r/Rag, 2025](https://www.reddit.com/r/Rag/comments/1oy1omu/biologicallyinspired_memory_retrieval_r_bio_sqc/)) proposes:

```
R_bio = S(q,c) + α·E(c) + A(c) + w_r·R(c) - w_d·D(c)
```

Where `S` = semantic similarity, `E` = emotional weight/salience, `A` = associative strength, `R` = recency, `D` = decay/drift. For a personal note system, `E` can be approximated by note length (a long note represents significant investment) and `A` by incoming backlink count.

---

## Section 5: Competitive Analysis

### 5.1 Mem.ai

**What Mem does:** Mem surfaces contextually related notes in a right-panel sidebar called "MemX" that updates as you interact with notes. Its Smart Write feature uses the full knowledge base as context for LLM-generated content. Related notes are shown as a sidebar panel — "MemX displays similar mems in the sidebar, and these mems are often contextually related to the one that you're currently working on" ([Mem.ai, 2024](https://get.mem.ai)). The system uses cloud-side embedding and semantic retrieval.

**What it gets right:**
- Passive, non-interruptive sidebar placement (users report it surfaces surprising connections)
- Semantic matching rather than keyword/tag matching means related notes appear without explicit taxonomy
- Integration with Smart Write means related notes can be directly pulled into composition

**What it gets wrong:**
- **Cloud dependency and privacy.** All notes are indexed on Mem's servers. For a personal knowledge system with sensitive professional or personal content, this is a dealbreaker. The Contextual Shadows architecture with on-device Model2Vec + usearch is qualitatively differentiated.
- **Latency.** Cloud round-trip for semantic search means the panel updates with a perceptible delay (~500ms–2s depending on network). The 200ms debounce + ~5ms on-device search represents a >100x latency advantage.
- **Context window limitations.** Smart Write's "related notes" surfacing degrades as the knowledge base grows because of LLM context window constraints. HNSW search scales logarithmically.
- **Result quality.** User reports suggest Mem surfaces topically adjacent notes but misses deep conceptual connections across different surface forms. Model2Vec's semantic compression may handle this better for highly personal writing.

---

### 5.2 Rewind.ai / Limitless

**What Rewind does:** Rewind (now rebranded as Limitless) captures continuous screen recordings and audio transcripts, stores them locally, and enables retroactive search. Its retrieval approach is **temporal-primary**: the user searches "what did I see/hear on Tuesday" rather than "what is semantically related to what I'm writing." The system uses OCR over screen captures and speech recognition over audio to build a searchable text index, with LLM overlaid for question-answering.

**What it gets right:**
- Local-first privacy model (data never leaves device)
- Temporal navigation — the "time machine" metaphor for recalling specific past moments is genuinely useful for meeting notes and reference material
- Low friction capture (always-on, no manual note-taking required)

**What it gets wrong:**
- **No semantic retrieval.** Rewind cannot surface notes that are *conceptually* related to current writing; it can only find notes by keyword or by explicit time navigation. This is the inverse of what Contextual Shadows does.
- **Privacy ambiguity.** Despite claiming local-first, user reports describe confusion about what is stored and what is uploaded ([Reddit r/RewindAI, 2025](https://www.reddit.com/r/RewindAI/comments/1lfzpyv/honest_review_after_daily_use_the_gap_between/)).
- **Search is pull, not push.** Rewind requires the user to actively query; it does not proactively surface related past content while writing. This is the core capability gap the Contextual Shadows panel fills.
- **No structured knowledge representation.** A screen capture is not a note — it lacks semantic structure. The notes-based approach enables much higher precision retrieval.

---

### 5.3 Notion AI

**What Notion AI does:** Notion AI finds related content within a workspace via explicit invocation — the user must ask Notion to search or suggest. The retrieval uses OpenAI embeddings over workspace content, invoked through the `/AI` command or the "Ask AI" button.

**What it gets right:**
- Deep integration with structured database properties enables hybrid search (semantic + metadata filtering)
- High relevance for document-centric knowledge bases with explicit structure

**What it gets wrong:**
- **Requires explicit invocation.** There is no ambient, passive surfacing; the user must interrupt their writing to ask for related content. This defeats the cognitive science rationale entirely — the value of ambient surfacing is that it presents connections *before* the user knows to look for them.
- **Slow.** Cloud API round-trips to OpenAI add 1–5 seconds per query. Not viable for real-time surfacing.
- **Workspace-locked.** Notion cannot surface notes from outside its own database, and export workflows are complex. A native macOS app that reads from a local file store has no such constraint.

---

### 5.4 Reflect.app

**What Reflect does:** Reflect is a backlink-first note-taking app with a strong daily note orientation. Its note surfacing is primarily **explicit-backlink-based**: the right-panel sidebar shows incoming backlinks to the current note, and the daily note view shows backlinks to named entities (people, projects, concepts) that appear in the current note.

**What it gets right:**
- Daily note backlink view is genuinely useful for time-based context retrieval ("what was I doing with this person last week?")
- Calendar integration surfaces meeting context naturally
- Fast (native app, local-first)
- The backlink philosophy mirrors spreading activation theory's associative network model

**What it gets wrong:**
- **Backlinks require explicit syntax.** Related content only appears if the user has previously written `[[Project X]]` links. Notes with the same semantic content but different surface forms are invisible.
- **No semantic similarity.** If the user writes about "neural networks" in one note and "deep learning" in another without explicit linking, Reflect cannot connect them.
- **No ambient semantic push.** The backlinks panel updates only when the note changes (which notes link to the current note), not based on semantic similarity to what the user is *currently typing*.

---

### 5.5 Obsidian Backlinks Panel

Obsidian's backlinks panel shows **linked mentions** (notes that explicitly `[[link]]` to the current note) and **unlinked mentions** (notes that contain the current note's title as plain text). The unlinked mentions feature is Obsidian's closest analog to semantic surfacing, but it operates via exact string matching on note titles only — not semantic similarity.

**Design lessons:**
- Obsidian's UI placing the backlinks panel in a **collapsible right sidebar** is the standard UX pattern that users have already internalized. The Contextual Shadows panel should follow this placement convention rather than inventing a new location.
- The split between linked and unlinked references maps to an explicit/implicit knowledge relationship that users find useful for deliberate knowledge organization — but neither is responsive to the current *writing context*.
- Unlinked mentions fail for semantic connections because they require exact title matches. A 512-dimensional embedding space is categorically more powerful.

---

### 5.6 Roam Research Linked/Unlinked References

Roam's reference panels (linked references at the bottom of each page) are the ancestral design pattern for backlink-based PKM. The system surfaces all blocks that reference the current page, giving a chronologically ordered view of every time the concept was mentioned. This is fundamentally a **tag/entity-based retrieval**, not semantic retrieval.

**Design lessons from Roam:**
- The bottom-of-page placement creates a natural "read when done writing" flow — but for ambient surfacing while writing, a side panel is preferable
- Roam's unlinked references (plain-text mentions of the page title) are more serendipitous than linked references and approximate the "What have I written about this before?" question that ambient retrieval should answer
- The block-level granularity in Roam (surfacing individual blocks rather than whole notes) may be appropriate for very long notes, but whole-note surfacing (with truncation) is lower cognitive overhead

---

### 5.7 DEVONthink's "See Also" Feature

DEVONthink's "See Also & Classify" feature is the most relevant competitive benchmark for semantically similar document retrieval in a macOS-native PKM. DEVONthink uses an **internal AI** (not LLM-based, not vector embedding-based in the traditional sense) that the developers describe as "statistical language analysis" — essentially a TF-IDF-like latent semantic analysis that builds a similarity model over the full corpus.

**What it gets right:**
- Results are surfaced in a side inspector panel, always visible alongside the current document — the correct ambient placement
- Document-level similarity (whole-note comparison) rather than sentence-level retrieval
- The feature is fast because the similarity model is maintained incrementally

**What it gets wrong:**
- **See Also is triggered by the whole document, not the current cursor context.** It shows what is similar to the note currently open — not what is similar to the paragraph being written. This is a critical limitation: the Contextual Shadows system is context-sensitive at the *sentence/paragraph* level.
- **No vector embeddings.** DEVONthink's developers confirmed in 2025 that "See Also and Classify are driven by DEVONthink's internal AI. There is no RAG or embedding going on in it" ([DEVONtechnologies Community, 2025](https://discourse.devontechnologies.com/t/dt4-inner-workings-of-indexing-see-also-similar-documents-thought-about-using-vectorization/82596)). The statistical approach lacks the cross-modal, cross-register semantic capability of transformer-derived embeddings.
- **Requires re-indexing.** Large-scale changes require full corpus re-indexing. The HNSW incremental insert pattern is O(log n) per insertion.

**Competitive positioning summary:** The Contextual Shadows panel targets the intersection of Mem's ambient semantic surfacing (but private/on-device), DEVONthink's See Also (but cursor-context-sensitive), and Obsidian's backlinks UX pattern (but based on embedding similarity rather than explicit links). No existing system occupies this intersection.

---

## Section 6: Critical UX Pitfalls

### 6.1 The Clippy Problem: Unsolicited Suggestions and Mixed-Initiative Failure

Eric Horvitz (Microsoft Research) has produced the canonical academic analysis of why unsolicited AI suggestions fail. His 1999 paper "Principles of Mixed-Initiative User Interfaces" (CHI 1999) established the framework: **mixed-initiative systems** — where both the human and the system can initiate actions — require careful management of who controls the interaction agenda.

Clippy failed not because the suggestions were wrong, but because:
1. **Interruption timing was uncorrelated with user readiness.** Clippy appeared at random or trigger-based moments that often didn't align with attentional slack.
2. **The cost of dismissal was always high.** Users had to take an action to make Clippy go away, which interrupted their primary task.
3. **Suggestions were at a meta-level** ("it looks like you're writing a letter") rather than the object level the user cared about.
4. **No learning from rejection.** The system reoffered suggestions after dismissal, failing to learn user preferences.

Gluck's 2006 UBC thesis on interruption design ([Gluck, 2006](https://www.cs.ubc.ca/labs/imager/th/2006/GluckMScThesis/GluckMScThesis.pdf)) — specifically studying how to avoid Clippy-style annoyance in mixed-initiative recommender systems — found that **matching attentional draw of notification to utility** was the critical design principle: "It is essential that such systems present interruptions diplomatically so that users neither ignore suggestions nor are driven by annoyance to stop using the system, as was the case of the anthropomorphic office assistant we all love to hate: Microsoft's ill-fated Clippy."

**Mitigation for Contextual Shadows:**

1. **No panel-initiated focus steal.** The panel never gains keyboard focus, never generates sounds, never produces a notification badge. The user's eye must travel to the panel voluntarily.
2. **No persistence after note access.** If the user clicks a result (indicating they consumed it), it should not reappear in subsequent queries for the same context unless the semantic distance changes significantly.
3. **Dismissal at the level of the result, not the panel.** A per-result "not helpful" signal that temporarily downweights that note for the current context, without requiring any panel configuration interaction.
4. **No anthropomorphism.** The panel should not "explain itself" or use conversational language. Result cards show: title, date, and first ~80 characters. No "I think this might be relevant..." framing.

---

### 6.2 Information Overload: How Many Results to Show

The classic reference is Miller (1956), whose "magical number seven, plus or minus two" (*Psychological Review*, 63(2)) established limits on short-term memory capacity. However, Miller's result applies to **serial, active recall** under a working memory load — not passive visual scanning of a peripheral panel.

More relevant is research on **glanceable displays** and peripheral information panels. The design consensus for ambient peripheral panels supports **3–5 results maximum**:

- 3 results requires ~150ms to scan (within foveal and near-peripheral vision with a single eye movement)
- 5 results requires ~300ms and one additional eye movement
- 7+ results crosses into a "list to read" rather than a "panel to glance"

The distinction matters because the panel is competing with the primary editing task for attention. If scanning the panel requires the user to context-switch from writing-mode to reading-mode (different neural processing regimes), the cognitive cost exceeds the benefit for all but the most highly relevant results.

**Practical recommendation:** Show **3 results by default**, expandable to 7 with a visible "More" control. The top result (highest composite score) should always be visible; the 2nd and 3rd at 80% and 60% opacity respectively, creating a visual gradient that naturally draws the eye to the most relevant result first.

McCrickard and Chewar's IRC framework directly supports this: for a panel targeting "low Comprehension, low Interruption, low Reaction" — the ideal quadrant for ambient awareness — the information density must remain parseable in a single ~300ms glance.

---

### 6.3 The Filter Bubble Effect in Personal Knowledge Systems

Eli Pariser's 2011 "filter bubble" concept, applied to recommendation systems, describes how personalization feedback loops narrow the content users see to an ever-smaller region of the information space that matches their prior interests. For a semantic retrieval panel, the analogous failure mode is:

**Semantic echo chamber:** The panel consistently surfaces notes that agree with and reinforce the user's current line of thinking, while suppressing contradictory, adjacent-domain, or older notes that might expand it.

Jiang et al. (2023) and Gao et al. (2023) have studied filter bubble effects in recommender systems extensively. Their findings apply to PKM:
1. **Feedback-loop amplification:** If the user frequently clicks a certain type of note (positive signal), the ranking function will upweight similar notes, progressively narrowing results
2. **Recency-semantic correlation:** Recent notes tend to be *about the current project*, so heavy temporal weighting amplifies the filter bubble
3. **Domain siloing:** Semantic similarity within a narrow domain is much higher than across domains, so top-K results from the same project dominate results from adjacent projects that might offer transferable insights

**Mitigation strategies:**

1. **Serendipity injection:** Every 5th result should be drawn from a **longer-tail semantic neighborhood** — cosine similarity in the 0.5–0.7 range (moderately similar, not closely similar). Label it visually as a "tangentially related" note (subtle distinction, not distracting).

2. **Temporal diversity constraint:** No more than 2 of 3 visible results should be from the same calendar month. This forces older notes into rotation.

3. **Source diversity:** If more than 2 results come from the same parent notebook/folder, demote the 3rd and substitute from another area of the knowledge base.

4. **User control of diversity vs. precision.** A subtle "Explore" vs. "Focus" toggle in the panel header lets users signal their intent: Focus mode = maximize cosine similarity; Explore mode = enforce the diversity constraints above.

---

### 6.4 Visual Design Pitfalls

**Panel width creep:** Sidebar panels in macOS apps are notorious for consuming too much screen real estate. The Contextual Shadows panel should have:
- Default width: 240px (sufficient for a truncated title + date + 2 lines of preview)
- Maximum width: 320px (user-resizable)
- Collapsible with a keyboard shortcut (e.g., ⌘⇧K) that the user learns within the first session

**Update frequency and peripheral attention capture:** Peripheral motion in the visual field is processed by the superior colliculus — a phylogenetically ancient brain region responsible for orienting responses — before reaching cortical processing. This means **any visible animation in the panel will capture attention** reflexively, even when the user is deeply focused on writing. The specific risks:

- **Instant result swaps** (old results disappearing, new results appearing without transition): Creates an involuntary attention shift on every debounce event (every 200ms of typing)
- **Scroll animation in the panel** (results shifting up/down): Triggers motion detection
- **High-contrast result highlighting** (bold borders, bright backgrounds on new results): Pre-attentively salient

**Correct approach:**
- Crossfade transitions at 400ms (too slow for pre-attentive motion detection to fire)
- No repositioning animation — new results appear in the same ranked slots (slot 1 always has the top result, even if the content changes)
- Low-contrast result cards: dark text on off-white background, no borders, 1px separator lines only

**Lack of dismissal/control:** Users who cannot control a panel will disable it entirely. Required controls:
- Per-result dismiss ("hide this note from results for this session")
- Panel collapse with one click or one keyboard shortcut
- A "pause panel" mode when the user needs to focus for an extended period
- Panel state persistence: if the user collapses the panel, it stays collapsed until they re-open it

**No loading spinners visible to user:** The 200ms debounce + ~10ms encode/search happens entirely in the background. The panel should never show a spinner or "Loading..." state — results should simply update on each debounce completion, with the crossfade transition masking the transition. If a query takes longer than 500ms (system under load), show the previous results rather than a loading indicator.

---

## Summary: Design Principles Synthesized from Research

| Principle | Source | Implementation |
|---|---|---|
| Ambient surfacing mimics expert RPD pattern-matching | Klein (1989, 2016) | Panel surfaces whole notes for recognition, not fragments |
| IAM frequency justifies always-on surfacing | Berntsen & Rubin (2009) | Panel is persistent, not invoked |
| Spreading activation → vector neighborhood search | Collins & Loftus (1975) | Model2Vec embeddings + HNSW k-NN |
| Recognition > recall for knowledge integration | Generation effect research | Show note titles + previews, not just metadata |
| Periphery ↔ center movement is encalming | Weiser & Brown (1996) | Panel lives in right edge, pulls into focus on click |
| Attention capture by motion is pre-attentive | Ishii/Wisneski ambientROOM work | 400ms crossfade, no scroll animation |
| Match attentional draw to utility | Gluck (2006), McCrickard & Chewar (2003) | Low contrast, no sound, never steals focus |
| 3–5 results for glanceable peripheral display | McCrickard & Chewar IRC framework | Default 3 results, expand to 7 |
| Temporal contiguity predicts relevance | Kahana (1996), Healey et al. (2018) | Temporal boost with decay formula |
| Forgetting curve → boost very recent notes | Ebbinghaus (1885), Murre & Dros (2015) | Same-session: 1.0x; 1 month: ~0.55x |
| Filter bubble → diversity constraint | Jiang et al. (2023), Gao et al. (2023) | Serendipity injection, temporal diversity |
| Clippy failure → no anthropomorphism, low cost dismissal | Horvitz (1999), Gluck (2006) | No explanatory text, per-result dismiss |
| Unsolicited suggestions → learned helplessness | McCrickard & Chewar (2003) | Result quality must be high or panel is disabled by users |
| No LLM dependency → on-device, private | Competitive analysis | Model2Vec + HNSW + usearch, no API calls |

---

## References

### Cognitive Science
- Collins, A.M. & Loftus, E.F. (1975). A spreading-activation theory of semantic processing. *Psychological Review*, 82(6), 407–428.
- Klein, G. (1999). *Sources of Power: How People Make Decisions*. MIT Press.
- Wright, C. & Klein, G. (2016). Macrocognition: From theory to toolbox. *Frontiers in Psychology*, 7, 54. https://pmc.ncbi.nlm.nih.gov/articles/PMC4731510/
- Berntsen, D. & Rubin, D.C. (2009). The frequency of voluntary and involuntary autobiographical memories. *Memory & Cognition*, 37(5), 679–688. https://pmc.ncbi.nlm.nih.gov/articles/PMC3044938/
- Mace, J.H. (2014). Involuntary autobiographical memory chains. *Frontiers in Psychiatry*, 5, 183. https://pmc.ncbi.nlm.nih.gov/articles/PMC4267106/
- Shimamura, A., Elman, J., & Rosner, Z. (2013). The generation effect: Activating broad neural circuits during memory encoding. *Cortex*, 49(7), 1901–1909. https://pmc.ncbi.nlm.nih.gov/articles/PMC3556209/
- McCurdy, M.P. et al. (2020). Fewer generation constraints increase the generation effect. *Memory*, 28(6). https://www.tandfonline.com/doi/full/10.1080/09658211.2020.1749283
- Bell, C. et al. (2016). Spreading activation in emotional memory networks. *Brain Informatics*, 3, 1–14. https://pmc.ncbi.nlm.nih.gov/articles/PMC5413589/

### Memory and Temporal Relevance
- Kahana, M.J. (1996). Associative retrieval processes in free recall. *Memory & Cognition*, 24, 103–109.
- Healey, M.K., Kahana, M.J., & Long, N.M. (2018). Contiguity in episodic memory. *Psychonomic Bulletin & Review*, 26, 699–720. https://pmc.ncbi.nlm.nih.gov/articles/PMC6529295/
- Folkerts, S., Rutishauser, U., & Howard, M.W. (2018). Human episodic memory retrieval is accompanied by a neural contiguity effect. *Journal of Neuroscience*, 38(17). https://www.jneurosci.org/lookup/doi/10.1523/JNEUROSCI.2312-17.2018
- Murre, J. & Dros, J. (2015). Replication and analysis of Ebbinghaus' forgetting curve. *PLoS ONE*, 10(7). https://pmc.ncbi.nlm.nih.gov/articles/PMC4492928/
- Tulving, E. (1983). *Elements of Episodic Memory*. Oxford: Clarendon Press.

### Ambient Information Systems
- Weiser, M. & Brown, J.S. (1996). The coming age of calm technology. Xerox PARC. https://people.csail.mit.edu/rudolph/Teaching/weiser.pdf
- McCrickard, D.S., Catrambone, R., Chewar, C.M., & Stasko, J. (2003). Establishing tradeoffs that leverage attention for utility. *International Journal of Human-Computer Studies*, 58(5). https://linkinghub.elsevier.com/retrieve/pii/S1071581903000223
- Chewar, C.M., McCrickard, D.S., & Sutcliffe, A. (2004). Unpacking critical parameters for interface design. *CHI Workshop*. https://dl.acm.org/doi/10.1145/1013115.1013155

### Technical (HNSW)
- Xu, H. et al. (2025). In-place updates of a graph index for streaming ANN search. arXiv:2502.13826. https://arxiv.org/abs/2502.13826
- Xiao, W. et al. (2024). Enhancing HNSW index for real-time updates. arXiv:2407.07871. https://arxiv.org/abs/2407.07871
- Zhang, Z. et al. (2025). CleANN: Efficient full dynamism in graph-based ANN search. arXiv:2507.19802. https://arxiv.org/abs/2507.19802
- USearch GitHub. Thread safety notes. https://github.com/unum-cloud/usearch

### UX Pitfalls
- Horvitz, E. (1999). Principles of mixed-initiative user interfaces. *CHI 1999*.
- Gluck, J.S. (2006). An investigation of the effects of matching attentional draw with utility in computer-based interruption. UBC MSc Thesis. https://www.cs.ubc.ca/labs/imager/th/2006/GluckMScThesis/GluckMScThesis.pdf
- Jiang, R. et al. (2019). Degenerate feedback loops in recommender systems. arXiv:1902.10730. https://arxiv.org/abs/1902.10730
- Gao, C. et al. (2023). CIRS: Bursting filter bubbles by counterfactual interactive recommender system. arXiv:2204.01266. https://arxiv.org/abs/2204.01266

### Competitive Products
- Mem.ai product description: https://get.mem.ai
- DEVONtechnologies community forums on See Also: https://discourse.devontechnologies.com/t/dt4-inner-workings-of-indexing-see-also-similar-documents-thought-about-using-vectorization/82596
- Elasticsearch decay functions: https://www.elastic.co/blog/found-function-scoring
- Re³ (Relevance & Recency Retrieval): arXiv:2509.01306. https://arxiv.org/html/2509.01306v1
