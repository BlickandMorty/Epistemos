# Capability 4: Temporal Knowledge Graph — Conceptual Drift and Belief Evolution

> **Target system:** Native macOS knowledge system (Swift + Rust + Metal + HNSW + GRDB/SQLite + FTS5)  
> **Feature:** A time-aware knowledge graph that tracks how a user's understanding of concepts evolves over months, detecting conceptual drift and belief revision.  
> **Audience:** Expert engineers building production PKM software.

---

## Section 1: Tracking Semantic Drift in Personal Knowledge

### 1.1 Hamilton, Leskovec & Jurafsky — Diachronic Word Embeddings

The foundational methodology for computationally tracking meaning change comes from Hamilton, Leskovec, and Jurafsky's two 2016 papers. The first, ["Diachronic Word Embeddings Reveal Statistical Laws of Semantic Change"](https://www.aclweb.org/anthology/P16-1141.pdf), established a rigorous evaluation framework by testing three embedding methods (PPMI, SVD, SGNS/word2vec) against known historical shifts across six corpora spanning four languages and two centuries. The second, ["Cultural Shift or Linguistic Drift?"](https://www.aclweb.org/anthology/D16-1229.pdf), operationalized two distinct measurement strategies.

**Two core measures:**

| Measure | Definition | Sensitive to |
|---|---|---|
| **Global (cosine distance)** | `d_G(w_i^t, w_i^{t+1}) = cos-dist(v_i^t, v_i^{t+1})` after Procrustes alignment | Regular linguistic drift (subjectification, grammaticalization) — captures verb/adjective shifts |
| **Local neighborhood** | Cosine distance between second-order vectors: `s_i^t(j) = cos-sim(w_i^t, w_j^t)` for the k=25 nearest neighbors union across two periods | Cultural shifts — captures noun/concept shifts driven by external change |

The distinction is crucial for a personal knowledge system: linguistic drift (e.g., you start using "machine learning" more casually as a verbal shorthand) should be distinguished from conceptual drift (e.g., your nearest semantic neighbors for "fairness" have migrated from "justice/equality" to "calibration/statistical-parity" as your thinking becomes more technical).

**Two statistical laws:**

1. **Law of Conformity**: Rate of semantic change scales with an inverse power-law of word frequency — `Δ(w_i) ∝ f(w_i)^βf`, with βf ∈ [-1.26, -0.27]. High-frequency personal anchor concepts ("learning", "work", "health") change slowly; rare technical terms shift fast.

2. **Law of Innovation**: Independent of frequency, polysemous words change faster. Words with multiple active contexts in your notes will drift more than single-domain terms.

**Embedding alignment via Orthogonal Procrustes:** Because word2vec (SGNS) and SVD embeddings have arbitrary rotation, comparing two time-sliced models requires alignment. The solution:

```
R^t = argmin_{Q^TQ=I} ||W^t · Q − W^{t+1}||_F
```

Solved via SVD of W^t · W^{t+1,T} (Schönemann 1966). This produces a rotation matrix R^t that aligns embedding space at time t into the space at t+1, making cosine distances meaningful across time. For a personal knowledge system this means you can train separate embedding models on monthly note snapshots and align them retrospectively.

**Method tradeoffs for small personal corpora:**

| Method | Strengths | Weaknesses |
|---|---|---|
| SVD (on PPMI matrix) | More sensitive; performs well on small datasets; good for detecting subtle shifts | Artifact-prone on small/noisy corpora |
| SGNS (word2vec) | Robust to corpus artifacts; best for discovery and visualization | Requires more data for reliable shift detection |
| Contextual (BERT-based) | Token-level, no alignment needed; handles polysemy per instance | Computationally heavy; overkill for personal notes |

For a personal knowledge system with 10K–100K tokens per time window, **SVD on PPMI** or the **second-order embedding approach** (no alignment required) are the most practical choices.

### 1.2 Kutuzov et al. Survey — Methods and Minimum Viable Data

[Kutuzov, Øvrelid, Szymanski & Velldal (2018)](https://arxiv.org/abs/1806.03537) provide the canonical survey of diachronic embedding approaches. Key methodological findings relevant to personal knowledge tracking:

**Data volume thresholds:**  
Real-world diachronic work uses a minimum "core vocabulary" defined as words occurring **≥100 times in all periods**. For personal notes, this means you need roughly 100+ mentions of a concept across each time window to get stable embeddings. Achieving this from raw note text requires either:
- Semantic aggregation: combine all notes referencing a concept-cluster (not just the exact term)
- Windowed accumulation: use rolling 3-month windows rather than strict calendar months
- Paragraph embedding rather than word embedding: embed the centroid of all paragraphs where a concept appears, bypassing the minimum-frequency problem entirely

The Twitter-scale case (monthly subcorpora) confirms that **sub-decade granularity is viable** when using SGNS with incremental updates. Personal notes updated weekly could realistically support monthly or quarterly concept-embedding snapshots.

**Second-order embeddings as an alignment-free alternative:**  
Rather than aligning two separately trained models with Procrustes, compute a word's *similarity vector* to a fixed core vocabulary in each period. These second-order vectors are inherently comparable across time without any transformation. This is architecturally simpler for an embedded macOS system: no alignment optimization step, just a dot-product operation against a stable reference vocabulary.

**Incremental update strategy:**  
Train an initial SGNS model on the earliest notes, then use incremental negative-sampling updates for each new time window. This avoids full retraining and is compatible with an append-only note architecture. The [Kaji and Kobayashi (2017) negative sampling extension](https://arxiv.org/abs/1702.08712) maintains semantic consistency across incremental updates.

### 1.3 Adapting Cultural Drift Detection to Personal Knowledge

The cultural/corpus-level framework maps to the personal domain with these substitutions:

| Corpus-level concept | Personal knowledge equivalent |
|---|---|
| Word meaning in a corpus | How you use and contextualize a concept in notes |
| Corpus time slice | Notes from a given time window (month/quarter) |
| Nearest semantic neighbors | Concepts that co-appear or co-cite in same note cluster |
| Cultural shift in society | Conceptual reorganization in your understanding |
| Linguistic drift | Changes in vocabulary/jargon without semantic reorganization |

**Personal concept embedding pipeline:**

1. For each concept node `C` in the knowledge graph, collect all note paragraphs that contain or reference `C` within a time window `[t, t+Δ]`
2. Compute a per-paragraph embedding using a frozen sentence encoder (e.g., `nomic-embed-text` or Apple's on-device embedding model)
3. Compute the **centroid embedding** `e_C^t` = mean of all paragraph embeddings in that window
4. Track drift as `drift_score(C, t→t+1) = 1 - cosine_sim(e_C^t, e_C^{t+1})`
5. For the local measure: track the k=10 nearest concept-neighbors by embedding similarity and compute the Jaccard distance of the neighbor sets across periods

This approach sidesteps the minimum-frequency problem entirely: even a concept mentioned 5 times per window generates a stable centroid if the paragraphs are embedding-rich. Sentence transformers extract meaning from context, not co-occurrence statistics.

**Detecting the two types of drift in personal notes:**

- **Local neighborhood shift** (concept migrates to different semantic cluster): indicates *conceptual reorganization* — you've re-filed "consciousness" from philosophy-cluster to neuroscience-cluster
- **Global centroid shift** (meaning of your usage changes but neighbors stay same): indicates *deepening within a domain* — your treatment of "optimization" has become more mathematical without changing which other concepts you associate it with

---

## Section 2: Graph Diffing Algorithms

### 2.1 Topological Change Detection Between Snapshots

A temporal knowledge graph generates a sequence of snapshots `G^0, G^1, ..., G^T`. Detecting *meaningful* changes between snapshots requires distinguishing noise from signal at multiple topological levels.

**Change categories by scale:**

| Level | What changes | Signal |
|---|---|---|
| Node-level | New concept added, concept deleted | Expanding/contracting knowledge domain |
| Edge-level | New link added, link deleted, link weight changes | New association discovered, association weakened |
| Centrality-level | Betweenness/PageRank/degree of existing nodes shifts | Concept becoming more/less central to thinking |
| Community-level | Cluster membership of node changes | Conceptual reorganization — concept migrates between topic areas |
| Global-level | Graph diameter, density, connected components change | Overall knowledge structure shift |

### 2.2 Node Centrality Changes as Epistemic Signal

Changes in node centrality metrics carry specific semantic meaning in a personal knowledge graph:

**Betweenness centrality** (fraction of shortest paths passing through node): A concept's rising betweenness indicates it is becoming a *bridge concept* — linking previously disconnected domains. When "information theory" starts bridging your "biology" cluster to your "machine learning" cluster, betweenness spikes. This is the computational signature of interdisciplinary synthesis.

**PageRank**: Measures recursive importance — a concept is important if important concepts link to it. Rising PageRank means increasingly authoritative concepts in your notes point to this concept. This tracks growing *epistemic weight* rather than mere connectivity.

**Degree centrality**: Raw connection count. A concept moving from degree 3 to degree 30 over 6 months signals domain deepening — you're actively building out the neighborhood of that concept.

**Implementation in `petgraph`:**

```rust
use petgraph::graph::DiGraph;
use petgraph::algo::page_rank;

// Compute PageRank drift between two snapshots
fn centrality_drift(g_prev: &DiGraph<NodeId, f32>, 
                    g_curr: &DiGraph<NodeId, f32>,
                    damping: f32) -> Vec<(NodeId, f32)> {
    let pr_prev = page_rank(g_prev, damping, 100);
    let pr_curr = page_rank(g_curr, damping, 100);
    // Compute delta per node, align by stable node IDs
    pr_prev.iter().zip(pr_curr.iter())
           .map(|((id, p0), (_, p1))| (*id, p1 - p0))
           .collect()
}
```

`petgraph` ([docs.rs](https://docs.rs/petgraph/)) provides `DiGraph`, `UnGraph`, PageRank, betweenness centrality, Dijkstra, minimum spanning tree, and DFS/BFS out of the box. Its `StableGraph` variant preserves node indices under deletion/insertion — critical for delta computation where node IDs must remain stable across snapshots.

### 2.3 Community Membership Migration

When a concept migrates from one cluster to another, this is the computational fingerprint of *conceptual reorganization* — the most significant signal in the graph for downstream belief-revision detection.

**Louvain vs. Leiden:**  
[Traag, Waltman & van Eck (2019)](https://arxiv.org/abs/1810.08473) demonstrated that the Louvain algorithm — despite its popularity — produces internally disconnected communities in up to 25% of cases and fully disconnected ones in up to 16% of cases. The Leiden algorithm corrects this with an explicit *refinement phase* between the local-moving and aggregation phases. For knowledge graphs where community identity is semantically meaningful, Leiden is strongly preferred.

**Dynamic Leiden for incremental updates:**  
[Sahu (2024)](https://arxiv.org/abs/2410.15451) introduced three dynamic Leiden variants:
- **Naive-dynamic (ND)**: Re-run from previous membership as starting point; simplest, ~1.14× speedup over static
- **Delta-screening (DS)**: Identify affected region by modularity scoring before running; ~1.11× speedup
- **Dynamic Frontier (DF)**: Propagate affected vertex frontier from batch update edges; ~1.09–1.37× speedup depending on graph type

For a personal knowledge graph with small incremental changes (notes added daily), the ND approach is architecturally simplest and adequate: only a small fraction of communities change per note addition.

**Community migration tracking:**

```rust
// Track cluster membership changes between snapshots
struct CommunityMigration {
    node_id: NodeId,
    prev_community: CommunityId,
    curr_community: CommunityId,
    prev_community_label: String,  // e.g., "Philosophy"
    curr_community_label: String,  // e.g., "Cognitive Science"
}

fn detect_migrations(
    prev_membership: &HashMap<NodeId, CommunityId>,
    curr_membership: &HashMap<NodeId, CommunityId>
) -> Vec<CommunityMigration> {
    prev_membership.iter()
        .filter_map(|(node, prev_c)| {
            let curr_c = curr_membership.get(node)?;
            if prev_c != curr_c {
                Some(CommunityMigration { node_id: *node, 
                     prev_community: *prev_c, 
                     curr_community: *curr_c, .. })
            } else { None }
        })
        .collect()
}
```

### 2.4 Graph Edit Distance — Complexity and Practical Alternatives

**Exact Graph Edit Distance (GED)** is NP-hard. It measures the minimum number of edit operations (insert/delete node, insert/delete edge, relabel) needed to transform `G^t` into `G^{t+1}`. For knowledge graphs with hundreds of nodes, exact GED is computationally infeasible.

**Practical alternatives for a PKM system:**

| Approach | Complexity | Use case |
|---|---|---|
| Edge-based delta (set difference) | O(|E|) | Fast daily diff, event sourcing |
| Structural similarity via embeddings ([Dall'Amico et al., 2024](https://arxiv.org/abs/2401.12843)) | O(n log n) | Comparing overall graph evolution across months |
| Approximate GED via tree matching | O(|V| · k²) where k = tree height | Detecting structural similarity of subgraphs |
| Community-level Jaccard distance | O(n) | High-level structural divergence metric |

For the append-only OpLog architecture described in the implementation plan, **event sourcing is the correct approach**: track edge insertions and deletions directly rather than comparing full snapshots. The snapshot-diff problem then reduces to replaying events between two timestamps.

### 2.5 Efficient Delta Computation

Rather than computing full graph snapshots for each time period:

```
delta(t → t+1) = {
    nodes_added:   N^{t+1} \ N^t
    nodes_removed: N^t \ N^{t+1}  
    edges_added:   E^{t+1} \ E^t
    edges_removed: E^t \ E^{t+1}
    weight_changes: {(u,v): w_t(u,v) ≠ w_{t+1}(u,v)}
}
```

**Incremental centrality updates** avoid recomputing PageRank from scratch on every note addition. For small batches of edge additions/deletions affecting a local neighborhood, approximate PageRank can be updated in O(affected_vertices × avg_degree) rather than full O(|E|) convergence. The [Know-Evolve framework (Trivedi et al., 2017)](https://arxiv.org/abs/1705.05742) showed that point-process temporal models can learn entity representations that update continuously — a design philosophy applicable here: maintain a *live graph state* plus an *event log* from which any historical state can be reconstructed.

---

## Section 3: Cognitive Science of Belief Revision

### 3.1 Thagard's Explanatory Coherence Theory (ECHO)

[Paul Thagard (1989)](https://gwern.net/doc/philosophy/epistemology/1989-thagard.pdf) proposed that belief acceptance is fundamentally a problem of **parallel constraint satisfaction** across a network of propositions. The ECHO (Explanatory Coherence by Harmonic Optimization) model translates this into a connectionist neural network:

**Seven principles of explanatory coherence:**
1. **Symmetry**: Coherence is bidirectional
2. **Explanation**: If P explains Q, P and Q cohere; the more propositions in an explanation, the lower the pairwise coherence weight
3. **Analogy**: Analogous explanations produce coherence between analogous hypotheses
4. **Data Priority**: Observation propositions have baseline acceptability
5. **Contradiction**: Contradictory propositions incohere
6. **Acceptability**: Overall acceptability depends on global coherence
7. **Acceptability**: The system prefers maximal global coherence

**ECHO mechanism:**
- Propositions → units (neurons)
- Coherence → excitatory links (positive weights)
- Incoherence → inhibitory links (negative weights)
- Network settles via parallel constraint satisfaction
- Final activation (positive/negative) = accepted/rejected belief

**Key dynamic property for belief revision detection:** When new evidence arrives, the network *resettles*. If H2 gains sufficient explanatory support from new data E3, E4, E5, the network can flip — H1 deactivates, H2 activates. This is not gradual probability update but a *phase transition* in the constraint satisfaction landscape. In a personal knowledge system, this corresponds to detecting when contradictory note content has accumulated enough to trigger reconsidering a previously accepted belief.

**Computational mapping to a PKM:**

```
Propositions     → concept nodes + note assertions
Coherence links  → explicit citations, thematic co-occurrence 
Incoherence links→ contradiction-detection (NLI-based)
Data priority    → recency-weighted, source-authority-weighted notes
Acceptability    → user's current belief strength (implicit or explicit)
Belief revision  → network-state flip detected across time snapshots
```

### 3.2 Michelene Chi's Ontological Category Shift Framework

[Chi, Slotta & de Leeuw (1994)](https://education.asu.edu/sites/g/files/litvpz656/files/lcl/chislottaleeuw_2.pdf) proposed that the hardest conceptual changes involve reassigning a concept from one *ontological category* to another. The three primary ontological trees are:

- **MATTER** (things, substances): has volume, mass, is containable, storable
- **PROCESSES** (events, procedures, constraint-based interactions): occurs over time, results in outcomes
- **MENTAL STATES**: beliefs, intentions, emotions

**The central insight for knowledge systems:** Concepts categorized as MATTER carry attributes that make them intuitively "substance-like" (can be stored, transferred, has quantity). When students misunderstand heat as a *substance* rather than a *process* (energy transfer), they carry false inferences: that heat can be "stored in" objects, that it "flows" like a fluid. Correcting this requires not just replacing a false belief but *switching ontological trees* — and this is cognitively expensive.

**Detection signatures in notes:** An ontological category shift in personal knowledge manifests as:
- **Predicate change**: Phrases like "store knowledge" → "practice knowledge" (matter → process)
- **Neighbor cluster migration**: Concept moves from THING-cluster to PROCESS-cluster in embedding space
- **Language pattern shift**: Subject-complement constructions ("X is a Y") → process constructions ("X involves/requires/produces Y")

For a temporal knowledge graph, these shifts are detectable by tracking which *linguistic predicates* a user applies to a concept over time. A note-writing NLP pipeline that extracts (subject, predicate, object) triples from user notes can track predicate-type distributions per concept per time period.

### 3.3 Piaget's Accommodation vs. Assimilation

Piaget's classical framework distinguishes:
- **Assimilation**: New information is absorbed into existing schemas without changing the schema. Example: learning that a platypus is a mammal by extending "mammal" to include egg-laying.
- **Accommodation**: Existing schemas must be restructured to absorb genuinely novel information. Example: learning that heat is not a substance at all requires dismantling the "caloric theory" schema entirely.

**Detection heuristic for a PKM:** Notes that assimilate new information will show *increasing edge density* around an existing concept (more connections to known neighbors). Notes that require accommodation will show *community migration* and *contradictions* with prior notes before eventually stabilizing in a new configuration. The temporal signature: assimilation = monotonically increasing local edge weight; accommodation = spike in contradiction-detection score followed by cluster reorganization.

### 3.4 Posner, Strike, Hewson & Gertzog (1982) — Conditions for Conceptual Change

[Posner et al. (1982)](https://faculty.weber.edu/eamsel/Classes/Practicum/TA%20Practicum/papers/Posner%20et%20al.%20(1982).PDF) identified four necessary conditions for *accommodation* (major conceptual change) to occur:

| Condition | Definition | PKM detection signal |
|---|---|---|
| **Dissatisfaction** | Learner must believe existing conception is inadequate | Multiple contradictory assertions about same concept over short period |
| **Intelligibility** | New conception must be comprehensible | User references/citations to explanatory sources after noting contradictions |
| **Plausibility** | New conception must be consistent with other beliefs | New concept cluster forms coherent neighborhood with existing beliefs |
| **Fruitfulness** | New conception must appear productive for solving problems | New concept starts bridging previously disconnected topics (rising betweenness) |

These four conditions give a sequenced *lifecycle model* for detecting belief revision events in a temporal knowledge graph: dissatisfaction (contradiction spike) → intelligibility search (citation burst) → plausibility (community restructuring) → fruitfulness (betweenness centrality increase).

### 3.5 Susan Carey's Weak vs. Strong Restructuring

[Carey (1985/1986)](http://edci670.pbworks.com/w/file/fetch/59138742/Carey_1986.pdf) distinguished:

- **Weak restructuring**: New relations among existing concepts; new schemas forming over existing nodes. The concepts themselves remain intact but their interconnections change. Example: learning that Newton's second law connects force, mass, and acceleration — all three concepts already existed, but the specific quantitative relationship is new.

- **Strong restructuring (genuine conceptual change)**: The core concepts themselves are transformed — differentiated, coalesced, or replaced. Ontological commitments change. Example: the pre-Galilean concept of "impetus" (force as property of moving objects) is not just updated by Newtonian mechanics; it is replaced by an incommensurable conceptual system.

**Implementation consequence:** The graph diff system should maintain two distinct drift-severity scores:

```rust
enum RestructuringClass {
    Assimilation,      // Edge density increase, neighbors stable
    WeakRestructuring, // New edges added, community membership unchanged
                       // Some neighbor turnover, centroid shift < threshold
    StrongRestructuring, // Community migration, centroid shift > threshold
                          // Predicate-type change detected (MATTER→PROCESS)
                          // Contradiction with prior core beliefs
}
```

Strong restructuring events are the rarest and most important to surface to the user — they represent genuine learning milestones, not incremental note-taking.

---

## Section 4: Temporal Graph Visualization

### 4.1 Beck, Burch, Diehl & Weiskopf Taxonomy

[Beck, Burch, Diehl & Weiskopf (2017)](https://onlinelibrary.wiley.com/doi/10.1111/cgf.12791) published the canonical taxonomy of dynamic graph visualization techniques. Their framework organizes approaches along two primary axes: **time representation** (animation vs. timeline) and **graph representation** (node-link vs. matrix).

**Primary approaches:**

| Approach | Representation | Strengths | Weaknesses |
|---|---|---|---|
| **Animation** | Sequential frames, user navigates time | Preserves mental map; intuitive for small changes; engaging | Hard to track multiple simultaneous changes; no comparison |
| **Small multiples** | Side-by-side graph snapshots at discrete time points | Easy comparison; all time points visible simultaneously | Screen space scales linearly; loses continuity |
| **Timeline-based / hybrid** | Space-time cube or matrix with time as third axis | Shows all evolution in one view; supports temporal queries | Visually complex; cognitive load high |
| **Temporal node attributes** | Single graph with encoding (color, size) mapping temporal properties | Space-efficient; natural for current-state focus | Encoding conflicts; limited temporal depth |

**Key finding:** Animation is preferred for tracking *individual elements* over time; small multiples are preferred for *structural comparison* at two specific time points. For detecting *drift* (gradual change), timeline-based approaches or animating centroid-trajectory paths outperform both.

### 4.2 Recommended Approach: Diff-Based Highlighting

For a personal knowledge system, the most UX-effective approach combines:

1. **Current graph view** as the primary artifact (node-link diagram, force-directed layout)
2. **Temporal encoding** for change magnitude:
   - Node **color temperature**: blue = stable, orange→red = high drift score
   - Node **border animation**: pulsing border on nodes with recent community migration
   - Edge **opacity**: recently added edges rendered bright; old stable edges faded
3. **Diff overlay mode**: User selects two time points; graph shows only what changed — added edges in green, removed in red, migrated nodes highlighted

**Avoiding the hairball problem:** The most dangerous failure mode in knowledge graph visualization is the ["hairball"](https://cambridge-intelligence.com/graph-visualization-ux-how-to-avoid-wrecking-your-graph-visualization/) — a fully connected mess where structure is invisible. Mitigations:
- Default to showing the **top-N most central nodes** (e.g., top 50 by PageRank)
- Use **progressive disclosure**: tap a node to expand its neighborhood
- Community detection drives **cluster layout**: Leiden communities rendered as spatial clusters with inter-cluster edges collapsed to summary links
- **Temporal filtering**: show only nodes with drift score > threshold since last view

### 4.3 "Temporal Maps" — Concept Paths Through Time

A high-value visualization for individual concepts: show a concept's **trajectory through embedding space** as a 2D path, using UMAP or t-SNE to project the embedding centroid at each time point into a 2D plane. The path visualization shows:
- Direction of drift (which other concepts is this one moving toward?)
- Rate of drift (path segment length proportional to cosine distance)
- Reversals (did the concept return to an earlier meaning after temporary excursion?)

This is analogous to Stoltz & Taylor's ["Cultural Cartography with Word Embeddings"](https://arxiv.org/abs/2007.04508) approach, adapted to personal concept trajectories.

### 4.4 Metal-Accelerated Graph Rendering

For a native macOS implementation, Metal provides the GPU pipeline for rendering large node-link diagrams efficiently:

**Force-directed layout on GPU:**
```metal
// Metal compute shader for Barnes-Hut force accumulation
kernel void computeRepulsiveForces(
    device float4* positions [[buffer(0)]],
    device float2* forces [[buffer(1)]],
    constant uint& nodeCount [[buffer(2)]],
    uint id [[thread_position_in_grid]])
{
    float2 myPos = positions[id].xy;
    float2 force = float2(0, 0);
    for (uint j = 0; j < nodeCount; j++) {
        if (j == id) continue;
        float2 delta = myPos - positions[j].xy;
        float dist = max(length(delta), 0.01);
        force += normalize(delta) * (1.0 / (dist * dist));
    }
    forces[id] = force;
}
```

For the temporal encoding layer:
- Pack node drift scores into `float4` position buffers (x, y, drift_magnitude, change_timestamp)
- Use fragment shaders to interpolate node color based on drift magnitude
- Use indirect command buffers for batching draw calls when only a subset of nodes have changed state (avoids full scene redraw on incremental graph updates)

Apple's [tile-based deferred rendering](https://developer.apple.com/documentation/metal/tailor-your-apps-for-apple-gpus-and-tile-based-deferred-rendering) architecture on Apple Silicon means that for graphs up to ~10K nodes, real-time force-directed layout is achievable at 60fps with proper Metal buffer management.

### 4.5 Showing "What Changed" Without Overwhelming

The core UX design challenge is presenting meaningful change without triggering anxiety. Recommended pattern:

**Progressive temporal disclosure:**
1. **Default view**: Current graph, nodes colored by *recency* of last significant change. User sees at a glance which areas of knowledge have been active.
2. **Drift summary**: Weekly/monthly digest notification: "3 concepts shifted significantly this month: [X], [Y], [Z]"
3. **Concept deep-dive**: Tap a concept to see its temporal trajectory: embedding path, community history, contradiction timeline
4. **Comparison mode**: User selects "then" and "now" dates; graph shows only the diff with semantic annotations ("this concept migrated from Philosophy to Cognitive Science")

---

## Section 5: SQLite/Rust Implementation Patterns

### 5.1 Schema Design for Temporal Knowledge Graphs in SQLite

The fundamental choice is **snapshot-based** (store full graph state at each timestamp) vs. **event-sourced** (store change events, reconstruct any state on demand). For a personal knowledge system with daily additions and monthly analysis cycles, **event sourcing is strongly preferred** for these reasons:
- Disk-efficient: a single note addition adds ~3 rows to the event log, not a full graph copy
- Consistent with the existing append-only OpLog architecture
- Enables both *valid time* (when fact became true) and *transaction time* (when system recorded it) queries
- Supports "as-of" queries: reconstruct graph state at any point

**Bitemporal edge table design:**

```sql
-- Core entity/node registry (stable identifiers across time)
CREATE TABLE nodes (
    id          TEXT PRIMARY KEY,        -- UUID v7 (time-sortable)
    label       TEXT NOT NULL,
    node_type   TEXT NOT NULL,           -- 'concept', 'note', 'source', 'person'
    created_at  INTEGER NOT NULL,        -- Unix milliseconds
    metadata    TEXT,                    -- JSON1 flexible attributes
    embedding   BLOB                     -- Serialized f32[] vector
) STRICT;

-- Bitemporal edge log (append-only)
CREATE TABLE edges (
    id           TEXT PRIMARY KEY,
    source_id    TEXT NOT NULL REFERENCES nodes(id),
    target_id    TEXT NOT NULL REFERENCES nodes(id),
    relation     TEXT NOT NULL,          -- 'supports', 'contradicts', 'elaborates', 'cites', 'migrated_from'
    
    -- Bitemporal columns
    valid_from   INTEGER NOT NULL,       -- When the relationship became true (user's world)
    valid_until  INTEGER,                -- NULL = currently valid; set when edge deleted
    recorded_at  INTEGER NOT NULL,       -- When system learned this fact (transaction time)
    
    confidence   REAL DEFAULT 1.0,
    weight       REAL DEFAULT 1.0,
    source_note  TEXT REFERENCES notes(id),
    metadata     TEXT                    -- JSON1: {"inferred": true, "strength": 0.85}
) STRICT;

-- Node attribute history (for tracking property changes)
CREATE TABLE node_attributes (
    id           TEXT PRIMARY KEY,
    node_id      TEXT NOT NULL REFERENCES nodes(id),
    attribute    TEXT NOT NULL,          -- 'community_id', 'pagerank', 'centroid_epoch', 'drift_score'
    value        TEXT NOT NULL,          -- JSON-encoded value
    valid_from   INTEGER NOT NULL,
    valid_until  INTEGER,
    recorded_at  INTEGER NOT NULL
) STRICT;

-- Embedding snapshots (per concept, per time window)  
CREATE TABLE concept_embeddings (
    id           TEXT PRIMARY KEY,
    node_id      TEXT NOT NULL REFERENCES nodes(id),
    epoch        INTEGER NOT NULL,       -- Time window identifier (e.g., YYYYMM)
    embedding    BLOB NOT NULL,          -- Serialized f32[768] or f32[384]
    token_count  INTEGER NOT NULL,       -- How many tokens contributed to centroid
    computed_at  INTEGER NOT NULL,
    UNIQUE(node_id, epoch)
) STRICT;

-- Drift events log
CREATE TABLE drift_events (
    id             TEXT PRIMARY KEY,
    node_id        TEXT NOT NULL REFERENCES nodes(id),
    epoch_from     INTEGER NOT NULL,
    epoch_to       INTEGER NOT NULL,
    drift_score    REAL NOT NULL,        -- cosine distance between centroids
    drift_type     TEXT NOT NULL,        -- 'centroid_shift', 'community_migration', 'contradiction'
    old_community  TEXT,
    new_community  TEXT,
    detected_at    INTEGER NOT NULL,
    metadata       TEXT                  -- JSON: neighbor set changes, etc.
) STRICT;
```

**Index strategy for temporal range queries:**

```sql
-- Critical: covering index for "show me the graph as of date X"
CREATE INDEX idx_edges_valid_time 
    ON edges(valid_from, valid_until) 
    WHERE valid_until IS NOT NULL;

CREATE INDEX idx_edges_source_time
    ON edges(source_id, valid_from, valid_until);

-- For fast "changes between A and B" queries
CREATE INDEX idx_edges_recorded
    ON edges(recorded_at);
    
CREATE INDEX idx_node_attrs_history
    ON node_attributes(node_id, attribute, valid_from);

-- Covering index for community queries
CREATE INDEX idx_drift_events_node_epoch
    ON drift_events(node_id, epoch_from, epoch_to, drift_score);
```

### 5.2 Temporal Query Patterns

```sql
-- "Show me the graph as of 2024-06-01"
SELECT source_id, target_id, relation, weight
FROM edges
WHERE valid_from <= 1717200000000  -- 2024-06-01 in ms
  AND (valid_until IS NULL OR valid_until > 1717200000000);

-- "Show all changes between 2024-01-01 and 2024-06-01"
SELECT e.*, n1.label as source_label, n2.label as target_label
FROM edges e
JOIN nodes n1 ON e.source_id = n1.id
JOIN nodes n2 ON e.target_id = n2.id  
WHERE e.recorded_at BETWEEN 1704067200000 AND 1717200000000
ORDER BY e.recorded_at;

-- "Which concepts drifted most in the last 90 days?"
SELECT de.node_id, n.label, MAX(de.drift_score) as max_drift, 
       de.drift_type, de.old_community, de.new_community
FROM drift_events de
JOIN nodes n ON de.node_id = n.id
WHERE de.detected_at > (strftime('%s', 'now') * 1000 - 7776000000)  -- 90 days
GROUP BY de.node_id
ORDER BY max_drift DESC
LIMIT 20;

-- Reconstruct community membership at any historical point using CTE
WITH community_at_time AS (
    SELECT node_id, value as community_id
    FROM node_attributes
    WHERE attribute = 'community_id'
      AND valid_from <= ?1
      AND (valid_until IS NULL OR valid_until > ?1)
)
SELECT n.label, cat.community_id 
FROM community_at_time cat
JOIN nodes n ON cat.node_id = n.id;
```

### 5.3 SQLite JSON1 Extension for Flexible Node Metadata

SQLite's built-in JSON1 extension (enabled by default in modern SQLite) allows schema-flexible node properties without additional tables:

```sql
-- Store arbitrary concept attributes as JSON
UPDATE nodes 
SET metadata = json_set(metadata, '$.domain', 'philosophy', '$.confidence', 0.9)
WHERE id = ?;

-- Query by JSON attribute
SELECT id, label, json_extract(metadata, '$.domain') as domain
FROM nodes
WHERE json_extract(metadata, '$.confidence') > 0.8;

-- Index on JSON extracted values (SQLite 3.38+)
CREATE INDEX idx_node_domain 
ON nodes(json_extract(metadata, '$.domain'));
```

### 5.4 Rust/petgraph Integration via FFI

The typical architecture for a macOS PKM using GRDB (Swift SQLite wrapper) + Rust graph algorithms:

```
Swift (UI + GRDB)  ←→  Rust FFI (graph algorithms)
         ↑                        ↓
      SQLite          petgraph DiGraph (in-memory)
```

**Rust FFI surface for Swift:**

```rust
// lib.rs — exposed to Swift via uniffi or raw C FFI
#[no_mangle]
pub extern "C" fn compute_pagerank(
    edges_ptr: *const EdgeData,
    edge_count: usize,
    damping: f32,
    out_ranks: *mut f32,
    node_count: usize
) -> i32 {
    let edges = unsafe { slice::from_raw_parts(edges_ptr, edge_count) };
    let mut graph = DiGraph::<u64, f32>::new();
    
    // Build petgraph from edge array
    let mut node_map: HashMap<u64, NodeIndex> = HashMap::new();
    for edge in edges {
        let s = *node_map.entry(edge.source).or_insert_with(|| graph.add_node(edge.source));
        let t = *node_map.entry(edge.target).or_insert_with(|| graph.add_node(edge.target));
        graph.add_edge(s, t, edge.weight);
    }
    
    let ranks = page_rank(&graph, damping, 100);
    // Write results to output buffer
    // ... (copy ranks to out_ranks by stable node ordering)
    0
}
```

For the Leiden community detection algorithm, the `leiden` crate or a custom implementation using `petgraph`'s graph traversal primitives is appropriate. Community detection runs are expensive (O(|E| log |V|)) and should run **asynchronously** on a background Rust thread, not on the main Swift event loop.

### 5.5 Event-Sourcing Architecture with OpLog

```sql
-- Append-only operations log (the source of truth)
CREATE TABLE op_log (
    seq          INTEGER PRIMARY KEY AUTOINCREMENT,
    op_type      TEXT NOT NULL,          -- 'ADD_NODE', 'ADD_EDGE', 'DELETE_EDGE', 
                                          -- 'UPDATE_EMBEDDING', 'DETECT_DRIFT'
    payload      TEXT NOT NULL,          -- JSON: full operation data
    timestamp    INTEGER NOT NULL,
    source       TEXT NOT NULL,          -- 'user_note', 'inference_engine', 'drift_detector'
    session_id   TEXT
) STRICT;

-- Materialized views rebuilt from op_log
-- The edges/nodes tables above are materialized projections, 
-- not the authoritative source
```

This allows complete audit trail and time-travel: to see the graph at any historical state, replay `op_log` entries up to that point. For the drift analysis background job, consuming new `op_log` entries since last run is an O(new_entries) operation regardless of total graph size.

---

## Section 6: Critical UX Pitfalls

### 6.1 The "So What?" Problem

**Risk**: You successfully detect that the user's concept of "attention" has drifted 0.34 cosine units from the Philosophy cluster toward the Neuroscience cluster over 8 months. You show them this. They think "...and?"

**Root cause**: Raw drift metrics are meaningless without *interpretation*. The metric needs to be grounded in:
1. **A question the user actually has**: "Did I change my mind about X?" or "What have I been thinking about differently lately?"
2. **An actionable suggestion**: "Your treatment of 'consciousness' has shifted significantly — here are 3 older notes that now appear to contradict your recent writing. Review?"
3. **A learning milestone framing**: "You've built 40 new connections around 'information theory' in the last 3 months. Here's what that neighborhood looks like now vs. 6 months ago."

The right UX pattern: **drift detection surfaces *questions*, not answers**. "It looks like your thinking on X may have shifted — want to review how?" — not "Your semantic drift score is 0.34."

### 6.2 False Positives — Inconsistent Note-Taking vs. Belief Change

**The core confound**: If a user writes detailed notes in some periods and brief notes in others, the embedding centroid shifts are driven by *coverage variation*, not conceptual change. Writing one deep-dive essay on "consciousness" in March inflates that concept's centroid toward the specific essay's vocabulary; in April, a brief mention in an unrelated note pulls it back. This looks like drift but is just noise.

**Mitigations:**

| Mitigation | Implementation |
|---|---|
| **Minimum token threshold** | Only compute drift scores when ≥500 tokens of content reference the concept in each window |
| **Confidence intervals** | Bootstrap the embedding centroid: if 95% CI of cosine distance includes 0, report "stable" |
| **Frequency-normalized drift** | Compute `drift_score / sqrt(token_count_prev * token_count_curr)` to penalize low-coverage windows |
| **Corroborating signals** | Require both embedding drift AND structural change (edge additions/community migration) before surfacing a drift event |
| **Smoothing** | Use exponential moving average of the centroid rather than hard window boundaries |

The ["statistically significant detection"](https://aclanthology.org/2021.eval4nlp-1.11.pdf) approach (Medlar et al. 2021) applies permutation-based tests to detect genuine shifts vs. noise in small corpora — directly applicable to personal note corpora.

### 6.3 Temporal Resolution — Finding the Right Window

**The tradeoff:**

| Window size | Problem |
|---|---|
| Daily | High noise: single unusual note pollutes centroid; community detection on sparse graphs is unstable |
| Weekly | Better but still volatile for sparse note-takers |
| Monthly | Reasonable for active users (~30+ notes/month); matches natural review cadence |
| Quarterly | Stable signal; aligns with seasonal life periods; appropriate for sparse note-takers |
| Yearly | Too coarse for tracking learning within a domain; misses important drift periods |

**Recommended approach: adaptive windowing.** Rather than fixed calendar windows, accumulate notes until a minimum coverage threshold is met per concept:

```rust
// Don't compute drift until sufficient signal
fn should_compute_drift(concept: &ConceptNode, 
                        new_tokens: usize,
                        days_since_last: u64) -> bool {
    // Minimum signal: 500 tokens OR 30 days, whichever comes last
    (new_tokens >= 500) && (days_since_last >= 30)
    || days_since_last >= 90  // Force quarterly check regardless
}
```

This naturally produces more frequent drift assessments for heavily-used concepts and slower assessments for rarely-mentioned ones — matching the user's actual engagement pattern.

### 6.4 The Overwhelming Visualization Problem

Knowledge graphs are notoriously difficult to make readable. The [Cambridge Intelligence analysis](https://cambridge-intelligence.com/graph-visualization-ux-how-to-avoid-wrecking-your-graph-visualization/) identifies three canonical failure modes:

1. **Hairballs**: Dense edge overplotting — all concepts linked to everything, unreadable
2. **Snowstorms**: Too many isolated nodes with no structure
3. **Starbursts**: One hub concept with hundreds of spokes — hides interesting non-hub structure

**Counter-strategy for temporal knowledge graphs:**
- **Level-of-detail (LOD) rendering**: Show community-level summary graph by default; expand to within-community detail on user interaction
- **Temporal diff as the primary view, not the full graph**: When surfacing a drift event, show *only the changed subgraph* (concept + 2-hop neighborhood), not the entire knowledge graph
- **Curated insights rather than raw visualization**: "3 things changed this month" card deck, each backed by a targeted mini-graph showing just the relevant drift
- **Focus+Context layout**: The concept the user is currently reading/editing rendered large at center; surrounding context fades with distance

### 6.5 Privacy and Vulnerability

**The exposure risk**: A system that surfaces "Your understanding of [topic] shifted significantly after [date]" is revealing something intimate. If the topic is grief, addiction, political belief, or relationship breakdown, showing a "drift timeline" can feel intrusive or distressing.

**Design principles:**
1. **User-initiated retrospection only**: Never push temporal drift notifications without explicit opt-in. The default should be silent background computation, with drift insights available on demand.
2. **Topic sensitivity filtering**: Allow users to mark certain concept clusters as private/no-analysis. The system should not surface drift events for these clusters.
3. **Framing as growth, not exposure**: "Your thinking on X has evolved significantly" vs. "You changed your mind about X." The former is celebratory; the latter can feel like an accusation.
4. **Deniability by design**: The drift detection operates on embedding centroids and graph structure — it does not quote back the user's exact prior words. This preserves plausible distance: the system can say "your perspective on X appears to have shifted" without surfacing the specific prior note that made the old belief explicit.
5. **All data local**: For a native macOS app with local-only data, the privacy risk is limited to the interaction design — but the *feeling* of being tracked by your own tool is a real UX problem that must be managed.

### 6.6 Computational Cost — Batch vs. Real-Time

**What's expensive:**
| Operation | Cost | Frequency |
|---|---|---|
| Embedding centroid update | O(k) dot products | Per new note (very cheap) |
| Full graph community detection (Leiden) | O(|E| log |V|) | Should NOT run per note |
| PageRank computation | O(|E| × iterations) | Should NOT run per note |
| Drift score computation | O(d) per concept-pair | Per epoch boundary (cheap) |
| UMAP projection for visualization | O(n²) naive | Per user request (expensive) |
| Procrustes alignment | O(d² × |V|) | Per epoch boundary |

**Recommended scheduling:**

```swift
// Background processing schedule
struct TemporalAnalysisScheduler {
    // Real-time (on every note save):
    // - Update raw embedding centroid incrementally
    // - Append to op_log
    // - Update local edge set
    
    // Low-priority background (every 24 hours, device idle):
    // - Recompute full Leiden community detection
    // - Update centrality metrics via petgraph FFI
    // - Check for drift events since last analysis run
    
    // Weekly (Sunday night, device charging):
    // - Compute epoch-boundary drift scores
    // - Run UMAP projection for visualization cache
    // - Generate insight candidates for user review
}
```

**Incremental community detection** using the Dynamic Frontier Leiden variant (Sahu 2024) achieves ~1.37× speedup over full static recomputation for small batch updates. For a personal knowledge graph with 10–50 note additions per day, the affected community set per day is tiny — ND or DF Leiden will update community assignments in milliseconds.

**Caching the expensive computations:**
- Cache the last UMAP projection; only recompute when more than N% of nodes have moved significantly in embedding space
- Cache PageRank scores with a staleness threshold: if edge count has changed by less than 5%, use cached values
- Pre-compute temporal graph state for common query points (e.g., 30/60/90/180/365 days ago) so the "what changed?" view is instantaneous

---

## Appendix: Design Recommendations Summary

### Key Decision Points

| Decision | Recommendation | Rationale |
|---|---|---|
| Embedding method | SVD on PPMI for detection; SGNS for discovery/visualization | Hamilton et al.: SVD more sensitive for small corpora |
| Alignment | Second-order embeddings (no alignment needed) | Simplest architecture for embedded system |
| Window size | Adaptive (500 tokens OR 30 days minimum) | Avoids sparse-window false positives |
| Drift metric | Cosine distance of centroid vectors + community membership delta | Combines global and local signal |
| Graph diffing | Event-sourced op_log + incremental Leiden (ND variant) | Append-only, efficient, reconstructable |
| Schema type | Bitemporal edges (valid_time + transaction_time) | Enables "as of" queries and audit trail |
| Visualization | Current graph + diff overlay + temporal trajectory paths | Progressive disclosure, avoids hairballs |
| Analysis scheduling | Real-time centroid updates; daily community detection; weekly drift scoring | Balances responsiveness vs. battery/compute |
| UX framing | Insight cards ("3 concepts evolved this month") not raw metrics | "So what?" prevention |
| False positive mitigation | Require corroborating embedding + structural signal | Prevents noise from inconsistent note-taking |

### Conceptual Change Severity Ladder (for UI presentation)

```
Level 0 — Stable:           drift_score < 0.05, community unchanged
Level 1 — Growing:          drift_score 0.05–0.15, new edges added
Level 2 — Evolving:         drift_score 0.15–0.30, partial neighbor turnover  
Level 3 — Shifting:         drift_score 0.30–0.50, community migration detected
Level 4 — Restructuring:    drift_score > 0.50, contradictions + community migration
Level 5 — Belief Revision:  Explicit contradiction with archived belief + resolution
```

Levels 3–5 correspond to Carey's strong restructuring and Chi's ontological category shifts — the rare, high-value events worth surfacing prominently to the user.

---

## References

- Hamilton, W.L., Leskovec, J., & Jurafsky, D. (2016a). Diachronic word embeddings reveal statistical laws of semantic change. *ACL 2016*. https://www.aclweb.org/anthology/P16-1141.pdf
- Hamilton, W.L., Leskovec, J., & Jurafsky, D. (2016b). Cultural shift or linguistic drift? *EMNLP 2016*. https://www.aclweb.org/anthology/D16-1229.pdf
- Kutuzov, A., Øvrelid, L., Szymanski, T., & Velldal, E. (2018). Diachronic word embeddings and semantic shifts: A survey. *COLING 2018*. https://arxiv.org/abs/1806.03537
- Kutuzov, A., Velldal, E., & Øvrelid, L. (2022). Contextualized language models for semantic change detection: Lessons learned. *NEJLT*. https://arxiv.org/abs/2209.00154
- Traag, V., Waltman, L., & van Eck, N.J. (2019). From Louvain to Leiden: guaranteeing well-connected communities. *Scientific Reports*. https://arxiv.org/abs/1810.08473
- Sahu, S. (2024). Heuristic-based Dynamic Leiden Algorithm for Efficient Tracking of Communities on Evolving Graphs. https://arxiv.org/abs/2410.15451
- Thagard, P. (1989). Explanatory coherence. *Behavioral and Brain Sciences*, 12(3). https://gwern.net/doc/philosophy/epistemology/1989-thagard.pdf
- Thagard, P., & Findlay, S. (2011). Changing minds about climate change: Belief revision, coherence, and emotion. *Belief Revision meets Philosophy of Science*. https://link.springer.com/10.1007/978-90-481-9609-8_14
- Chi, M.T.H., Slotta, J., & de Leeuw, N. (1994). From things to processes: A theory of conceptual change for learning science concepts. *Learning and Instruction 4*(1). https://education.asu.edu/sites/g/files/litvpz656/files/lcl/chislottaleeuw_2.pdf
- Posner, G., Strike, K., Hewson, P., & Gertzog, W. (1982). Accommodation of a scientific conception: Toward a theory of conceptual change. *Science Education 66*(2). https://faculty.weber.edu/eamsel/Classes/Practicum/TA%20Practicum/papers/Posner%20et%20al.%20(1982).PDF
- Carey, S. (1986). Cognitive science and science education. *American Psychologist*. http://edci670.pbworks.com/w/file/fetch/59138742/Carey_1986.pdf
- Beck, F., Burch, M., Diehl, S., & Weiskopf, D. (2017). A taxonomy and survey of dynamic graph visualization. *Computer Graphics Forum 36*(1). https://onlinelibrary.wiley.com/doi/10.1111/cgf.12791
- Dall'Amico, L., Barrat, A., & Cattuto, C. (2024). An embedding-based distance for temporal graphs. *Nature Communications*. https://arxiv.org/abs/2401.12843
- Trivedi, R., Dai, H., Wang, Y., & Song, L. (2017). Know-Evolve: Deep temporal reasoning for dynamic knowledge graphs. *ICML 2017*. https://arxiv.org/abs/1705.05742
- petgraph Rust crate. https://docs.rs/petgraph/
- Medlar, A., Głowacka, D., & Liu, Y. (2021). Statistically significant detection of semantic shifts using contextual word embeddings. https://aclanthology.org/2021.eval4nlp-1.11.pdf
- Stoltz, D.S., & Taylor, M.A. (2021). Cultural cartography with word embeddings. *Poetics*. https://arxiv.org/abs/2007.04508
