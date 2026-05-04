# Capability 6: Spatial Graph Interaction — Physics-Driven Thinking Canvas

**Audience:** Production engineers building a native macOS knowledge system with Metal-accelerated graph renderer and Rust physics engine.  
**Scope:** Transforming a force-directed graph into an interactive thinking canvas where spatial gestures create semantic operations.

---

## Section 1: Spatial Cognition and External Representations

### 1.1 Epistemic Actions — Kirsh & Maglio (1994)

The theoretical cornerstone for gesture-driven semantic operations is Kirsh and Maglio's landmark study ["On Distinguishing Epistemic from Pragmatic Action"](https://adrenaline.ucsd.edu/kirsh/Articles/CogsciJournal/DistinguishingEpi_prag.pdf), published in *Cognitive Science* 18:513–549 (1994). Their core finding: in Tetris, players rotate falling pieces physically far more often than is necessary to achieve placement goals. The excess rotations are **epistemic actions** — physical actions performed not to advance a plan, but to change the agent's *computational state*, making mental operations easier, faster, or more reliable.

**Quantified results:** For all zoid types, observed average rotations significantly exceeded the pragmatic expectation of 1.5 rotations per piece (the statistical expectation for random initial orientations). Critically, many epistemic rotations began within 100–400ms of a piece appearing — before the player could have computed a placement plan — indicating they serve perception and identification, not execution. Physical rotation of a piece costs approximately 100ms; performing the equivalent mental rotation costs 800–1,200ms for a 90° transformation (based on tachistoscopic reaction-time data from Kirsh & Maglio's pilot studies).

**The five epistemic functions of rotation in Tetris:**
1. Early discovery of hidden parts of the zoid (visual disambiguation)
2. Reduces mental rotation workload (100ms physical vs. 800-1200ms mental)
3. Facilitates memory retrieval through multi-perspective priming
4. Simplifies zoid type identification by pruning attentional decision trees
5. Eases zoid-contour matching by enabling perceptual rather than symbolic processing

**Design implication for spatial graph interaction:** Every gesture on the thinking canvas should be evaluated against this epistemic/pragmatic distinction. A user dragging two nodes together may not be trying to create an edge — they may be physically enacting a comparison to see whether two concepts "fit." The system should tolerate and support such exploratory, non-committed manipulation before requiring explicit semantic assignment.

### 1.2 Barbara Tversky: Spatial Thinking as Cognitive Foundation

Tversky's extensive research program argues that spatial thinking is not merely a metaphor for abstract thought — it is its foundation. In ["Visualizing Thought"](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1756-8765.2010.01113.x) (*Topics in Cognitive Science*, 2011) and ["The Cognitive Design of Tools of Thought"](https://hci.ucsd.edu/220/TverskyCogtiveDesign.pdf), she demonstrates that diagrams and spatial arrangements externalize conceptual structure in ways that:

- **Reduce working memory load** by offloading intermediate representational states
- **Enable discovery** of new relations not explicitly represented (emergent structure from arrangement)
- **Support analogical reasoning** through spatial metaphor — "up is more," "near is related," "left precedes right"

Tversky introduces the concept of **spractions** (spatial-abstraction-actions): the designed world is itself a diagram. When a user places two knowledge nodes spatially adjacent, they are enacting a spraction — a spatial act that creates and communicates an abstraction. The brain's same hippocampal and parahippocampal systems that encode physical spatial maps encode abstract conceptual spaces. This is why spatial arrangement of knowledge nodes is cognitively meaningful, not merely aesthetic.

**Key finding for layout design:** Tversky's research on sketches shows they are "representations of reality, not presentations" — they omit, distort, and schematize. A knowledge graph layout is the same: it represents the user's model of conceptual structure, which may differ from the formal graph topology. The layout *is* the model. Forcing users to accept physics-derived positions undermines their ability to express their own conceptual model.

### 1.3 Distributed Cognition — Hutchins

Edwin Hutchins's theory of [distributed cognition](https://arl.human.cornell.edu/linked%20docs/Hutchins_Distributed_Cognition.pdf), developed through ethnographic studies of ship navigation and cockpit crew coordination, proposes that the unit of cognitive analysis is not the individual brain but "a collection of individuals and artifacts and their relations to each other in a particular work practice."

For a knowledge graph:
- **The graph itself is a cognitive artifact** — it holds representational states that the brain cannot hold simultaneously
- **Spatial manipulation is propagation of representational states** across the brain-artifact system
- **The physics engine is part of the cognitive system**, not merely a rendering tool — it actively reorganizes representational states when the user adds connections

Hutchins distinguishes three distributions: across people, across internal/external artifacts, and across time. The third is critical: "products of earlier events transform the nature of later events." A knowledge graph that preserves spatial history (where you placed things, not just what you linked) is a distributed cognitive system that encodes temporal reasoning structure.

### 1.4 External Representations and Representational Guidance — Zhang & Norman (1994)

[Zhang & Norman (1994)](https://pages.ucsd.edu/~scoulson/203/zhang.pdf), "Representations in Distributed Cognitive Tasks," *Cognitive Science* 18:87–122, provide the formal theoretical framework. Their **representational effect** is foundational: different representations of the same abstract structure produce "dramatically different cognitive behaviors." This is not a minor usability concern — it determines what cognitive operations are even possible.

Zhang & Norman's framework identifies three critical properties of external representations:

1. **Perception without formulation**: Information in external representations can be read directly without symbolic mediation — a cluster of nodes is immediately perceived as a cluster; the user does not compute it.
2. **Anchoring cognitive behavior**: Physical structure constrains the range of possible actions — the layout constrains which operations feel natural to attempt.
3. **Task transformation**: Tasks with and without external representations are fundamentally different cognitive tasks, not harder/easier versions of the same task.

**Representational guidance** — the mechanism by which external structure guides what operations users attempt — means the spatial layout of the graph actively shapes the thinking it mediates. Nodes that are close together will be compared; nodes that are far apart will be less likely to be synthesized. The physics engine is not neutral. Its output biases cognition.

### 1.5 Tangible User Interfaces and Embodied Cognition — Ishii

Hiroshi Ishii and Brygg Ullmer's tangible user interface (TUI) research (["Tangible Bits"](https://dl.acm.org/doi/10.1145/1240866.1241085), CHI 1997) argues that physical manipulation of digital information should leverage the human sensorimotor system — not just the visual system. TUIs give "physical form to digital information."

For trackpad-based spatial interaction, the relevant insight is that **gesture design should exploit proprioceptive memory** — the memory of physical actions taken in space. When a user performs a pinch gesture, they encode both the semantic outcome (synthesis) and the motor pattern. Subsequent invocations become faster and more reliable because they recruit sensorimotor memory, not just declarative memory. As [Ishii et al. demonstrate](https://cs.wellesley.edu/~oshaer/TUI_NOW.pdf), "tangible interfaces offer the user manipulation and perception in three dimensions... in line with the natural capacities of the human being (touch, depth perception)."

**Embodied cognition and abstract concepts:** A [2014 Frontiers in Psychology review](https://pmc.ncbi.nlm.nih.gov/articles/PMC4137171/) by Dijkstra et al. confirms that abstract concepts are grounded in sensorimotor metaphors. "Power is up," "more is up," "similarity is proximity" — these are not arbitrary conventions but cross-cultural cognitive structures. Knowledge graph interaction can exploit these mappings: synthesis (bringing things together → pinch), expansion (elaborating → spread), prominence (important nodes → center/large), temporal sequence (earlier → left) align with natural sensorimotor metaphors.

### 1.6 Gestalt Principles in Knowledge Graph Layouts

The Gestalt principles of perception are not merely aesthetic guidelines — they are descriptions of how the visual system pre-attentively segments scenes before any deliberate interpretation. For knowledge graphs:

| Gestalt Law | Graph Relevance | Design Implication |
|-------------|-----------------|-------------------|
| **Proximity** | Nodes close together are perceived as related | Force-directed repulsion/attraction produces clustering; users will infer semantics from layout proximity even when none exists |
| **Similarity** | Nodes with similar visual treatment (color, size, shape) are grouped | Node visual encoding should signal type, not just decoration; similar-looking nodes will be cognitively grouped regardless of edges |
| **Common fate** | Nodes moving together are perceived as related | Animating a cluster during layout changes signals grouphood; selective damping can communicate semantic groupings |
| **Connectedness** | Explicitly connected nodes are perceived as strongly related | Edge rendering dominates proximity for connected nodes; edge weight should map to visual weight |
| **Closure** | Users complete partial boundaries | Hull rendering around clusters should be used deliberately, as users will perceive any near-enclosure as a group |

The [Interaction Design Foundation's treatment](https://ixdf.org/literature/topics/gestalt-principles) and [Observable visualization analysis](https://observablehq.com/@jwolondon/gestalt-principles-for-visual-design) confirm these are pre-attentive, not deliberate. This means the layout engine is **not neutral** — it imposes a perceptual interpretation that users cannot easily override consciously.

**Critical implication:** The physics engine will create spatial proximity relationships that users will read as semantic. This is the root cause of the "spatial bias" problem (Section 6.6). You must either (a) accept this and lean into it, making physics-proximity meaningfully reflect semantic proximity, or (b) clearly differentiate physics-derived arrangement from user-defined arrangement.

---

## Section 2: Force-Directed Graph Interaction in Research Tools

### 2.1 Obsidian Graph View and Canvas

Obsidian's graph view is the most widely deployed force-directed knowledge graph among personal knowledge management tools, making its failures instructive.

**What works:**
- Visual overview of connectivity enables **cluster discovery** — users can identify densely connected topic areas at a glance
- Local graph view (showing immediate neighbors) is more useful than global view because it scales cognitively
- Filters (by tag, folder, path) reduce visual complexity and allow focused exploration

**What fails:**

*Layout instability:* As users on the [Obsidian forum document extensively](https://forum.obsidian.md/t/whats-the-point-of-the-graph-view-how-are-you-using-it/71316), "the position of each note changes on every load." There is no spatial persistence. Users cannot build spatial memory of where their nodes live because the positions are non-deterministic across sessions. The graph becomes "non-functional because there is no consistency in the actual graph, which prevents analysis."

*Scaling cliff:* The [Reddit thread on a 39,000-file vault](https://www.reddit.com/r/ObsidianMD/comments/soyr4p/39000_file_graph_view_testing_the_limits_of/) demonstrates catastrophic failure at scale. Users report the need for "grouping near nodes when zooming out to reduce entities number presented on the screen" — a plea for LOD rendering that Obsidian does not implement. The graph degrades from useful at ~500 nodes to a hairball at ~2,000 nodes and unusable at ~10,000 nodes.

*Semantic vacuousness of position:* Because Obsidian uses force-directed layout without any semantic anchoring, node position reflects graph topology (connectivity patterns) not semantic content. Users report they "can't specify a directional flow for nodes" and "can't pin nodes on the default graph." Spatial position in Obsidian's graph conveys only connectivity structure, not user-defined meaning.

*The canvas vs. graph distinction:* Obsidian's newer Canvas feature addresses spatial organization but as a separate modality from the graph. Users must choose between topological analysis (graph view) and spatial composition (canvas). The integration of these two — graph topology + semantic spatial organization — is the problem this system aims to solve.

### 2.2 Cosma

[Cosma](https://cosma.arthurperret.fr) is a principled tool designed at Université Bordeaux Montaigne by Arthur Perret, explicitly for "network synthesis rather than analysis." Its [FOSDEM 2024 presentation](https://archive.fosdem.org/2024/schedule/event/fosdem-2024-3394-cosma-a-visualization-tool-for-network-synthesis/) clarifies the design philosophy:

- Graph visualization is used for **synthesis** (building a coherent view of a field) not analysis (measuring graph properties)
- It reads plain Markdown files with wiki-links, rendering as interactive node-link cards
- The tool creates "portable knowledge bases" that combine graph visualization with contextualized backlinks, citations, and metadata filters
- Exports are standalone HTML files with full interactive capability — the tool's philosophy is "as much functionality in exports as within the app"

**What Cosma gets right:** It treats the graph as a *reading interface*, not a layout optimization problem. Users navigate the intellectual structure of a knowledge domain, not an abstract graph. Node cards contain full content, edges carry citation context, and metadata filters allow focused views.

**What Cosma reveals about limits:** By being a read-only visualization tool (no editing within the graph), Cosma avoids the gesture-conflict problems of interactive graphs. But this also means it cannot serve as a *thinking* canvas — it presents knowledge, it does not enable its manipulation.

### 2.3 Scapple

[Scapple](https://www.literatureandlatte.com/scapple/overview) (Literature & Latte) is the reference implementation for freeform spatial note-taking. Its design philosophy is explicitly anti-hierarchical: "Scapple doesn't force you to make connections — every note is equal, so it's up to you which notes have connections and which don't."

**What works:**
- Pure freeform: notes can exist without any connections. This matches the epistemic action pattern — users place notes spatially to think about them, before deciding whether to connect them
- Direct manipulation: double-click to create, drag-and-drop to connect. The interaction cost for each operation is minimal
- Stack notes in columns of related ideas without requiring formal grouping
- Export to Scrivener closes the gap between brainstorming and writing

**Lessons for spatial graph interaction:**
- Users want to place ideas spatially before committing to semantic relationships. The system must support **provisional placement** — objects that exist in space without edges.
- The ability to NOT connect things is as important as the ability to connect them. Force-directed layout assumes every connected component should cohere. Scapple's model allows spatial organization to carry meaning even without edges.
- [App Store reviews](https://apps.apple.com/us/app/scapple/id568020055?mt=12&see-all=reviews&platform=mac) consistently praise: "works better than an outliner for problems that do not have a well-understood structure." This is the thinking canvas use case — the problem structure is what the user is trying to discover, not what they already know.

### 2.4 TheBrain

[TheBrain](https://www.thebrain.com) implements the most distinctive navigation model in the knowledge graph space: **active thought centering**. Every node ("Thought") is navigated to by clicking on it, whereupon it moves to the center of the pane, and all its relationships (parent thoughts, child thoughts, jump thoughts/cross-links) radiate outward. The spatial context shifts with every navigation step.

**What TheBrain teaches about focus+context:**
- The centered active thought has both prominence (central position) and context (all neighbors visible as radiating connections)
- Navigation doesn't feel like traversal — it feels like the knowledge space reorganizes around your current focus
- "Associative mapping: build your network of connections, mimicking the way your mind works" captures the intent, though the implementation is constrained to TheBrain's taxonomy (parent/child/jump hierarchy)

**TheBrain's limitation:** The centering model sacrifices peripheral awareness. Users build strong spatial memory for the local neighborhood of any thought, but lose the global map that would allow discovery of unexpected connections across distant parts of the graph. It scales well (500,000+ items claimed) but at the cost of the overview that makes graphs useful.

**Implication:** Consider a hybrid: a stable global layout for overview, but a "focus mode" that recenters around a selected node with context-aware LOD — showing the focal node in full detail with radiating neighbors, and progressively simplifying the rest of the graph.

### 2.5 Heptabase

[Heptabase](https://techindulger.com/marketing/heptabase-visual-brainstorming-clarity) implements the most sophisticated card-based spatial canvas currently available. Its approach:

- Cards (rich-content notes) are the primary manipulation unit, not graph nodes
- Canvases (spatial whiteboards) are the primary spatial organization context
- Graph relationships emerge from card-to-card connections, but the *primary interaction* is spatial placement of cards on whiteboards
- Multiple whiteboards allow different views of the same conceptual space

**What Heptabase reveals:** Users gravitate toward spatial organization as their primary cognitive tool. "Cards naturally cluster around related concepts. I spot gaps in my research when sections of the canvas look sparse." The spatial metaphor is powerful enough that users report the canvas *reveals* structure they did not consciously place there — an emergent property of spatial arrangement.

**The Heptabase-Obsidian gap:** Heptabase has excellent spatial manipulation but limited semantic linking between whiteboards. Obsidian has excellent linking but no spatial persistence. The opportunity for this system is to unify persistent spatial arrangement with the full graph topology.

### 2.6 Kumu.io

[Kumu](https://kumu.io) is the most sophisticated force-directed layout tool for systems mapping and stakeholder analysis. Its [force-directed layout documentation](https://docs.kumu.io/guides/layouts/force-directed) reveals considered design decisions:

**Three-force model:**
1. Gravity — pulls all elements toward center (prevents drift)
2. Particle charge — mutual repulsion (prevents overlap)
3. Connection force — pulls connected elements together (reveals topology)

**Manual override as first-class feature:** Kumu supports pinning individual elements to fixed positions, allowing hybrid layouts where some nodes follow physics and others are manually anchored. This is the key feature that makes Kumu useful for systems mapping — practitioners need to place elements in meaningful spatial positions (e.g., "upstream" vs. "downstream" in a causal system) that force-directed layout cannot infer.

**Kumu's critical limitation documented by UNDP Jordan:** "[Elements] immediately bounce back if you refresh, leave the page, or make and save changes to the settings. These changes are also not maintained if you share the hyperlink with someone for viewing." Spatial positions of pinned elements are not reliably persisted across sessions. This is the layout instability problem in practice — even manual overrides don't survive.

**What works across all tools — synthesis:**

| Pattern | Works | Fails |
|---------|-------|-------|
| Manual override of physics | Kumu, Scapple | Obsidian |
| Spatial persistence across sessions | Scapple | Kumu, Obsidian |
| Semantic meaning of position | Scapple (user-defined) | Obsidian (topology only) |
| Scaling past ~2K nodes | TheBrain, Kumu | Obsidian, Heptabase |
| Rich content in nodes | Heptabase | Obsidian graph view |
| Overview + focus simultaneously | Cosma | TheBrain |

---

## Section 3: Gesture Design for Semantic Operations

### 3.1 Direct Manipulation Principles — Shneiderman

Ben Shneiderman's direct manipulation framework, originally defined in 1982–1983 and extended in his [1997 analysis](https://www.cs.umd.edu/~ben/papers/Shneiderman1997Direct.pdf), specifies three requirements for a direct manipulation interface:

1. **Continuous representation of objects of interest**: The knowledge nodes must always be visible and manipulable, not hidden in menus or dialogs.
2. **Physical actions instead of complex syntax**: Spatial gestures replace typed commands. The action vocabulary should map onto physical intuitions.
3. **Rapid incremental reversible operations whose impact is immediately visible**: Every gesture must produce immediate, visible feedback, and must be undoable.

The [Nielsen Norman Group's synthesis](https://www.nngroup.com/articles/direct-manipulation/) confirms the psychological grounding: "Users experience less anxiety because the system is comprehensible and because actions can be reversed so easily." For semantic operations on a knowledge graph — pinch-to-synthesize, lasso-to-summarize — the reversibility requirement is the hardest to meet because the operations are semantically destructive (merging creates something new, summarization loses detail).

**Design strategy:** Treat semantic gesture operations as *proposals*, not immediate commitments. Pinching two nodes together should show a preview synthesis (a draft merged node) with options to accept, adjust, or reject — not immediately commit. This maintains the "reversible" property of direct manipulation even when the underlying semantic operation is lossy.

### 3.2 Norman's Critique: Natural User Interfaces Are Not Natural

Don Norman's [2010 essay](https://jnd.org/gestural-interfaces-a-step-backwards-in-usability/) "Gestural Interfaces: A Step Backwards In Usability" is the most important critique of gesture-based interfaces and directly relevant to this system's design:

**The discoverability problem:** "Swipes and gestures cannot readily be incorporated in menus; nobody has figured out how to inform the person using the app what the alternatives are." In a traditional GUI, every possible action could be discovered by systematically exploring menus. Gestures have no equivalent discoverability mechanism. Users cannot know what gestures are available without external documentation or accidental discovery.

**The consistency problem:** Different apps treat identical gestures differently. "Some apps allow pinching to change image scale, others use plus/minus boxes." For semantic gestures that carry no real-world referent (what does "pinch" mean for synthesizing knowledge?), there is no ground truth that users can rely on.

**Norman's five principles violated by gestural interfaces:**
1. **Visibility/affordances**: Gestures have no visible signifiers
2. **Feedback**: It is unclear what gesture has been recognized
3. **Consistency**: Same gesture means different things in different contexts
4. **Non-destructive operations**: Semantic gestures are often irreversible
5. **Discoverability**: Users cannot find operations by systematic exploration

**Mitigation strategies for this system:**
- **Gesture hints layer**: An always-available overlay (toggleable, or visible on hover/pause) that shows available gestures in context. This is the canonical solution — gesture documentation embedded in the UI.
- **Progressive disclosure**: Teach basic gestures (pan, zoom, single-node select) first; introduce semantic gestures (pinch-to-synthesize) only after users have demonstrated facility with basic navigation.
- **Gesture ghosting**: When the user begins a gesture that might be semantic (e.g., fingers moving toward each other near two nodes), show a ghost/preview of what will happen before the gesture completes.

### 3.3 Pinch-to-Synthesize

Pinching as a gesture for merging/combining has precedent in multi-device interaction research. [Ohta & Tanaka (2016)](https://www.semanticscholar.org/paper/Using-Pinching-Gesture-to-Relate-Applications-on-Ohta-Tanaka/9fd0147fa7d2a39c9bd79f807427ba8ce819f64f) demonstrated pinch-to-relate for multi-device coordination, finding that the gesture is "intuitive" for combining "multiple partial solutions into one."

**Implementation considerations:**

The macOS trackpad reserves standard pinch for zoom (handled at the system level via `NSMagnificationGestureRecognizer`). A two-finger pinch directed at two specific nodes requires **disambiguation**: the gesture must be interpreted as node-targeting (semantic operation) rather than canvas zooming (navigation operation). 

**Disambiguation heuristic:** If the center of the pinch gesture is within the bounding box of two nodes, and both nodes are within a threshold distance (e.g., 200pt screen-space), interpret as pinch-to-synthesize with those nodes. Otherwise, interpret as canvas zoom. This requires a priority queue over gesture recognizers where context determines interpretation.

**Visual feedback requirements:**
1. During approach (fingers near nodes, before pinch completes): Show connecting arc between targeted nodes, previewing the merge
2. During pinch execution: Show merging animation — nodes approaching each other, text content overlapping, transitioning to a "synthesis preview" state
3. Post-gesture, pre-commit: Present synthesis result (AI-generated or user-editable summary) with Accept / Edit / Reject options
4. On reject: Animate nodes back to original positions (position is preserved in layout state)

**The reversibility requirement:** The synthesis must be logged as a discrete, named action in the undo stack: `SynthesizeNodes(source_ids: [A, B], result_id: C, previous_positions: {...})`. Undo must restore both the original nodes A and B *and* their original spatial positions.

### 3.4 Lasso-to-Summarize

The lasso selection paradigm comes from vector graphics tools (Illustrator, Figma, Photoshop) and is well-established in creative contexts. Adobe's [lasso documentation](https://helpx.adobe.com/photoshop/using/selecting-lasso-tools.html) describes the canonical freeform selection behavior: draw a closed region to select all elements within.

**For knowledge graph application:** The lasso gesture selects a cluster of nodes and triggers a group semantic operation. Key design decisions:

1. **What makes a valid lasso target?** The lasso should work on spatial proximity (all nodes within the closed curve), but offer a "semantic expansion" option that extends the selection to include semantically related nodes just outside the boundary.

2. **The action menu problem:** After lasso completion, what happens? The temptation is to show a context menu, but menus break spatial flow. Better: show a minimal HUD (Heads-Up Display) that floats near the selection center — a small set of radiating buttons for the most common operations (Summarize, Group, Tag, Delete). This preserves spatial context while avoiding menu hierarchy.

3. **Summarize as a distinct semantic operation:** Summarization reduces n nodes to a summary node that contains distilled content. The summary node should expand on tap to reveal the underlying nodes (hierarchical disclosure). The spatial position of the summary node should reflect the centroid of the original nodes.

4. **Persistence of spatial memory:** The original nodes must be preserved (not deleted) when a summary is created. The summary is a *view* over the original cluster, not a replacement. Users must be able to re-expand the summary to regain the full cluster.

### 3.5 Drag-to-Relate

Creating edges by dragging is the most natural and well-understood semantic gesture for graph editing. Research on [pen-and-touch interaction for graph editing](https://www.w3.org/WAI/WCAG21/Understanding/input-modalities.html) confirms that direct manipulation edge creation (drag from source node to target node) is the highest-discoverability approach.

**Implementation specifics:**
- Drag initiation on a node body (not edge): After ~200ms hold, show edge creation indicator (a translucent arrow from the held node toward cursor position)
- During drag: The arrow snaps to nearby nodes (within ~60pt screen radius) with a subtle haptic tap feedback (NSHapticFeedbackManager) to indicate potential edge targets
- Drop on target node: Create edge. Show edge type picker inline (not in a modal): labeled relationship types as pills that appear on the newly created edge
- Drop on empty canvas: Create new node at drop location, pre-connected to source

**Directional semantics:** The direction of drag should encode the edge direction (source → target). For knowledge graphs, this typically means "supports," "contradicts," "examples," or "elaborates." Offer quick-type selection immediately after edge creation, with a default (e.g., "relates to") that degrades gracefully.

### 3.6 Reserved macOS Trackpad Gestures

macOS claims the following trackpad gestures at the system level, requiring special handling or avoidance:

| Gesture | System Assignment | Availability for Apps |
|---------|------------------|----------------------|
| Two-finger scroll | Scroll/pan | Cannot override; use for canvas pan |
| Two-finger pinch | Zoom (Magnification) | Can intercept within app via priority; context-dependent |
| Two-finger rotate | Photo rotation | Available in creative apps; use with care |
| Three-finger swipe left/right | Navigation (browsers) | System-level in Safari; overrideable in custom apps |
| Three-finger swipe up | Mission Control | **System-reserved; cannot override** |
| Three-finger swipe down | App Exposé | **System-reserved; cannot override** |
| Four-finger swipe left/right | Space switching | **System-reserved; cannot override** |
| Two-finger tap | Right-click equivalent | Can intercept |
| Force click | Look up / data detectors | Interceptable |

**Gesture vocabulary for semantic operations:**
- **Two-finger pinch + proximity context** → Synthesize (overloads zoom with context detection)
- **Single-finger lasso** (with stylus) or **two-finger drag from empty space** → Lasso selection
- **One-finger drag on node** → Move node / initiate edge (time-disambiguated)
- **Two-finger tap on selection** → Context action HUD
- **Three-finger tap** → Global command palette (avoids system Mission Control conflict; tap vs. swipe)

Note: For gesture implementation in a native macOS application, `NSGestureRecognizer` subclasses handle disambiguation. Simultaneous recognizers with failure requirements create priority chains. The pinch recognizer should fail if the gesture center is not near a node pair.

### 3.7 Continuous vs. Discrete Interaction

Research on [fluid interaction for creative work](https://dl.acm.org/doi/10.1145/3544548.3581433) distinguishes two modes:
- **Continuous interaction**: Analog, gradual, undo-able at any point during execution (dragging, zooming)
- **Discrete interaction**: Committed, semantic, creates a new state (AI synthesis, edge creation with typed label)

Semantic gesture operations are *discrete* — they produce semantic artifacts (synthesized nodes, summaries, labeled edges) that cannot be reversed by sliding back. The system must clearly signal the transition from continuous to discrete: a "release to commit" moment with distinct visual feedback (a haptic pulse on commit, a distinct animation).

**Fluid gestures for layout exploration:** Consider a "chaos/settle" mode toggle (keyboard shortcut or button in toolbar). In settle mode, physics runs continuously with high damping — the graph gently adjusts to new connections but doesn't dramatically rearrange. In explore mode, physics runs with lower damping — dragging a node pulls its neighbors, allowing cluster inspection by physical perturbation. This maps to the epistemic action model: the user can "shake" the graph to understand its connectivity structure.

---

## Section 4: Metal/GPU Physics Simulation at 120fps

### 4.1 Force-Directed Graph Algorithms at Scale

#### Barnes-Hut O(n log n) Approximation

The [Barnes-Hut simulation](https://en.wikipedia.org/wiki/Barnes%E2%80%93Hut_simulation) reduces the naive O(n²) all-pairs force computation to O(n log n) using a spatial index (quadtree in 2D, octree in 3D). The algorithm:

1. Build a quadtree over all node positions
2. Compute centers of mass bottom-up for all internal tree nodes
3. For each particle: traverse the tree; if `width/distance < θ`, approximate the subtree as a single force from its center of mass; otherwise recurse into children

The critical parameter **θ** controls the accuracy/speed tradeoff. [Jeffrey Heer's interactive analysis](https://jheer.github.io/barnes-hut/) benchmarks across 500–10,000 points:

| θ | Behavior | Error |
|---|----------|-------|
| 0 | Degenerates to O(n²) exact | 0 |
| 0.5 | Not faster than naive until ~6,000 nodes | Low (~5% pixel error avg) |
| 1.0 | **Recommended**: significant speedup, low error | ~5% of single pixel |
| 1.5 | Fastest, similar speedup to θ=1 | Notably higher error |

**For visualization applications where few-pixel errors are imperceptible**, θ=1.0–1.2 is the optimal choice. The [ForceAtlas2 implementation](https://github.com/bhargavchippada/forceatlas2) uses `barnesHutTheta=1.2` as its default.

#### ForceAtlas2 Algorithm

[ForceAtlas2](https://pmc.ncbi.nlm.nih.gov/articles/PMC4051631/) (Jacomy et al., 2014, *PLoS ONE*) is the most practically relevant force-directed algorithm for knowledge graphs in the 100–100,000 node range. Key features:

**Force model:**
- Repulsion: `f_r(n_i, n_j) = k_r · (deg(i)+1) · (deg(j)+1) / d(i,j)²`
- Attraction: `f_a(n_i, n_j) = d(i,j) / k_r` (linear, or log for LinLog mode)
- Gravity: `f_g(n_i) = g · (deg(i)+1) / d(i,0)` toward center

**Degree-dependent repulsion** is the key innovation: hub nodes (high degree) repel more strongly, preventing leaf-node forests from clustering around hubs and reducing visual clutter.

**Adaptive cooling (local + global speed):**
- Per-node *swinging* measure: `s(n, t) = ‖F(n,t) - F(n,t-1)‖` (oscillation detection)
- Per-node speed: `Δt_i = x_s · ‖F(n,t)‖ / (s(n,t) + ε) · Δt` with cap at `10 × Δt`
- Global speed adjusts based on ratio of global traction to global swinging, scaled by tolerance parameter

Default tolerance values by graph size:
- <5,000 nodes: `tolerance = 0.1`
- 5,000–50,000 nodes: `tolerance = 1.0`
- >50,000 nodes: `tolerance = 10.0`

**Benchmark against alternatives** (68 networks, 5–23,133 nodes):

| Algorithm | Avg QO Convergence | Avg QND Time | Notes |
|-----------|-------------------|--------------|-------|
| ForceAtlas2 | 638ms | 68ms | Best balance quality/speed |
| Yifan Hu | 333ms | 98ms | Fastest QO, good for large graphs |
| FA2 LinLog | 1,184ms | 134ms | Best cluster separation |
| Fruchterman-Reingold | 20,201ms | 7,853ms | Best quality, unusable at scale |

#### Multilevel Approaches for Very Large Graphs

For 10K+ nodes, multilevel/hierarchical algorithms avoid the convergence slowdown of single-level force-directed methods:

**FM³ (Fast Multipole Multilevel Method):** [FM³](https://d-nb.info/1251482813/34) achieves O(|V| log |V| + |E|) complexity with linear memory. The algorithm:
1. **Coarsening phase**: Recursively merges nodes into "solar systems" (central sun-node plus orbiting moon-nodes), creating a hierarchy of progressively smaller graphs G₀, G₁, ..., Gₖ
2. **Base layout**: Apply single-level force-directed to the smallest graph Gₖ
3. **Refinement phase**: Iteratively uncoarsen and re-optimize, using the coarser layout as initial positions for the finer graph

FM³ produces "nice drawings of graphs with 100,000 nodes in less than 5 minutes." For interactive use, pre-computing a multilevel hierarchy enables incremental re-layout when nodes/edges change without full recomputation.

**GRIP (Graph drawing with Intelligent Placement):** Similar multilevel approach but uses a "rough layout" heuristic for initial node placement — nearest neighbors in the graph are placed near each other — giving better initial conditions for force-directed refinement.

### 4.2 Metal Compute Shader Architecture for Force Simulation

The physics simulation pipeline on Apple Silicon should run entirely in Metal compute shaders, with the Rust engine managing graph data structures on the CPU while Metal handles all force computation.

**Memory architecture on Apple Silicon unified memory:**

Apple Silicon's unified memory architecture eliminates the CPU-GPU transfer bottleneck. From [Apple's documentation](https://developer.apple.com/documentation/metal/mtlstoragemode/shared), `MTLStorageMode.shared` is the default for `MTLBuffer` instances on Apple Silicon — the same physical memory is accessible from both CPU and GPU with zero-copy semantics.

```rust
// Rust side: create shared MTLBuffer via metal-rs / objc2-metal
let positions_buffer = device.new_buffer_with_data(
    positions.as_ptr() as *const _,
    (positions.len() * std::mem::size_of::<[f32; 2]>()) as u64,
    MTLResourceOptions::StorageModeShared,
);
// GPU can now read/write positions_buffer directly
// CPU can read positions_buffer.contents() without any blit encoder
```

This is critical: on older Intel Macs, you needed a blit encoder to synchronize managed buffers (`didModifyRange:`). On Apple Silicon, a shared buffer is genuinely zero-copy — the [Reddit discussion on Apple Silicon Metal buffers](https://www.reddit.com/r/QuantumPhysics/comments/1rdx4uh/running_lattice_qcd_simulations_on_apple_silicon/) confirms "the zero-copy mechanism between the CPU and GPU streamlines data management compared to the traditional CUDA method."

**Buffer layout for force simulation:**

```metal
// node_data.metal
struct NodeData {
    float2 position;    // current position
    float2 velocity;    // current velocity
    float2 force;       // accumulated force for this step
    float  mass;        // degree+1 (for FA2 repulsion)
    float  pinned;      // 0.0 = free, 1.0 = pinned (ignores forces)
    uint   node_id;
    uint   pad;         // alignment
};

struct EdgeData {
    uint source_id;
    uint target_id;
    float weight;
    float pad;
};
```

**Compute shader pipeline:**

```metal
// Step 1: Repulsion (Barnes-Hut quadtree traversal — O(n log n))
// Each thread handles one node; reads quadtree cells from a cell buffer
kernel void compute_repulsion(
    device NodeData* nodes [[buffer(0)]],
    device QTreeCell* tree [[buffer(1)]],
    constant ForceParams& params [[buffer(2)]],
    uint node_idx [[thread_position_in_grid]]
) {
    // Traverse quadtree, accumulate repulsive forces
    nodes[node_idx].force += barnes_hut_repulsion(
        nodes[node_idx].position,
        nodes[node_idx].mass,
        tree,
        params.theta,
        params.kr
    );
}

// Step 2: Attraction (one thread per edge — O(e))
kernel void compute_attraction(
    device NodeData* nodes [[buffer(0)]],
    device EdgeData* edges [[buffer(1)]],
    constant ForceParams& params [[buffer(2)]],
    uint edge_idx [[thread_position_in_grid]]
) {
    EdgeData e = edges[edge_idx];
    float2 delta = nodes[e.target_id].position - nodes[e.source_id].position;
    float d = length(delta);
    float2 f = (delta / d) * (d / params.kr) * e.weight;
    // Atomic add — race condition between threads updating same node
    atomic_fetch_add_explicit(
        (device atomic_float*)&nodes[e.source_id].force.x, f.x, memory_order_relaxed
    );
    // ... etc
}

// Step 3: Integration (one thread per node)
kernel void integrate(
    device NodeData* nodes [[buffer(0)]],
    constant ForceParams& params [[buffer(2)]],
    uint node_idx [[thread_position_in_grid]]
) {
    if (nodes[node_idx].pinned > 0.5) return;
    // FA2 adaptive speed calculation
    float swinging = length(nodes[node_idx].force - prev_force[node_idx]);
    float speed = params.global_speed * params.xs / (swinging + params.epsilon);
    speed = min(speed, params.xm * params.global_speed);
    nodes[node_idx].velocity += nodes[node_idx].force * speed;
    nodes[node_idx].velocity *= params.damping;  // velocity damping
    nodes[node_idx].position += nodes[node_idx].velocity * params.dt;
}
```

**Atomic operations for attraction:** The attraction kernel has a critical race condition — multiple threads updating the same node's force accumulator simultaneously. The options are:
1. **Atomics** (`atomic_float` in Metal 3): Correct but slower due to memory contention
2. **Sorted edge processing**: Sort edges by source_id, process batches with no conflict; requires edge preprocessing
3. **Repulsion-only GPU, attraction on CPU**: Attraction is O(e), typically much cheaper than O(n²) repulsion; moving attraction to CPU thread removes the atomic issue

Option 3 is pragmatic for graphs up to ~50K edges: GPU handles expensive repulsion (Barnes-Hut, O(n log n)), CPU handles attraction in parallel using Rust's Rayon. The bottleneck shifts to GPU-CPU synchronization, mitigated by Apple Silicon's unified memory (the CPU can read the positions buffer directly without synchronization).

### 4.3 Achieving 120fps: Decoupled Physics and Rendering

The canonical pattern for smooth physics rendering is the **fixed timestep with interpolated rendering** game loop, described in Glenn Fiedler's "Fix Your Timestep" and [confirmed by game development literature](https://stackoverflow.com/questions/43302268/why-use-integration-for-a-fixed-timestep-game-loop-gaffer-on-games):

```rust
// Rust physics loop (separate thread)
const PHYSICS_DT: f64 = 1.0 / 60.0;  // 60Hz physics
let mut accumulator: f64 = 0.0;
let mut previous_state = GraphState::clone(&current_state);

loop {
    let frame_time = clock.elapsed_seconds();
    accumulator += frame_time.min(0.25);  // spiral-of-death prevention
    
    while accumulator >= PHYSICS_DT {
        previous_state = current_state.clone();
        physics_step(&mut current_state, PHYSICS_DT);
        accumulator -= PHYSICS_DT;
    }
    
    // Share interpolated state with render thread
    let alpha = accumulator / PHYSICS_DT;
    let render_state = interpolate(&previous_state, &current_state, alpha);
    render_state_shared.store(render_state);  // atomic swap
}
```

```swift
// Swift render loop (CADisplayLink at 120Hz)
displayLink.preferredFrameRateRange = CAFrameRateRange(
    minimum: 60, maximum: 120, preferred: 120
)

func render(displayLink: CADisplayLink) {
    let renderState = rustPhysicsEngine.getRenderState()  // reads interpolated positions
    // Encode Metal render commands using interpolated positions
    // No physics computation here — pure rendering
}
```

**Why this matters for 120fps ProMotion displays:** Apple's ProMotion displays vary between 24Hz and 120Hz adaptively. If physics and rendering are coupled, the physics timestep varies with the display refresh, causing non-deterministic behavior. Decoupling ensures:
- Physics always runs at a fixed rate (60Hz is stable for graph simulation)
- Rendering runs at whatever rate the display supports (up to 120Hz)
- Interpolation between physics steps produces smooth motion at 120fps even with 60Hz physics

**The rendering thread reads from a triple-buffered position buffer** — the physics thread writes to one buffer while the render thread reads from another, with an atomic swap of the read-write pointers. On Apple Silicon with unified memory, this swap is a pointer swap, not a data copy.

### 4.4 Rust-Metal Integration

As of 2024, [`metal-rs`](https://github.com/gfx-rs/metal-rs) is deprecated in favor of `objc2` and `objc2-metal`. The [LambdaClass blog's Rust-Metal FFT implementation](https://blog.lambdaclass.com/using-metal-and-rust-to-make-fft-even-faster/) demonstrates the practical integration:

```rust
use objc2_metal::*;

// Create Metal device and command queue from Rust
let device = MTLCreateSystemDefaultDevice().unwrap();
let command_queue = device.new_command_queue();

// Compile Metal shader (pre-compiled to .metallib during build)
let library = device.new_library_with_data(
    include_bytes!("../shaders/physics.metallib")
).unwrap();

// Create compute pipeline state
let function = library.new_function_with_name("compute_repulsion").unwrap();
let pipeline = device.new_compute_pipeline_state_with_function(&function).unwrap();
```

**Build system integration:** Pre-compile `.metal` shaders to `.metallib` during Xcode/cargo build steps:
```bash
xcrun -sdk macosx metal -c src/shaders/physics.metal -o target/physics.air
xcrun -sdk macosx metallib target/physics.air -o target/physics.metallib
```

**Architectural split:** The recommended architecture keeps Swift handling all Metal rendering (the render pipeline, viewport management, frame management) while Rust manages the graph data structures and high-level physics coordination. Shared physics state lives in a `MTLBuffer` with `StorageModeShared` that both Swift and Rust can access via the unified memory address.

### 4.5 Level of Detail (LOD) Strategies

For graphs above ~1,000 visible nodes, [interactive LOD rendering research](https://d-nb.info/1096195852/34) shows techniques that enable rendering "up to ~10⁷ nodes and ~10⁶ edges at interactive rates":

**Node LOD tiers:**

| Zoom Level | Node Count Visible | Rendering | Label |
|------------|-------------------|-----------|-------|
| Overview (<0.2x) | All nodes | Points (1–3px) | None |
| Mid (0.2–0.8x) | All nodes | Points (3–8px) + cluster hulls | Cluster labels only |
| Focus (0.8–2x) | All nodes | Small circles | Top-degree nodes only |
| Detail (>2x) | Viewport nodes only | Full node (circle + icon) | All visible nodes |

**Cluster LOD via density-based aggregation:** At overview zoom, compute DBSCAN or k-means clusters from current layout positions. Render each cluster as a single representative node (sized by node count, colored by dominant type) rather than rendering all constituent nodes. This reduces render call count from n to cluster_count (typically 10–50 for large graphs).

**Edge LOD:**
- At overview: Render no edges (or only inter-cluster edges)
- At mid zoom: Render bundled edges (grouped into spline bundles using the [MINGLE algorithm](http://yifanhu.net/PUB/edge_bundling.pdf))
- At detail zoom: Render individual edges for viewport-visible nodes

**[MINGLE edge bundling](http://yifanhu.net/PUB/edge_bundling.pdf)** (Gansner et al., AT&T Labs): Multilevel agglomerative edge bundling achieves O(k|E| log |E|) complexity, bundling 100,000 edges in ~20 seconds. For real-time rendering, pre-compute bundles during idle time (force physics "settle" phase) and cache as spline paths in a Metal vertex buffer.

---

## Section 5: Semantic-Spatial Consistency (Map ≠ Territory)

### 5.1 The Fundamental Tension

The core design tension in a physics-driven thinking canvas is between three competing forces:

1. **Force-directed layout**: Optimizes for graph topology — nodes connected by many short-path hops appear close together. Position reflects graph structure, not semantic meaning.
2. **User's spatial model**: The user arranges nodes to reflect their *mental* model — temporal sequence, conceptual hierarchy, importance, thematic grouping — which may not align with graph topology.
3. **Semantic similarity**: An ideal layout would place semantically similar nodes near each other, which may correlate with graph topology (linked concepts are related) or not (related concepts may not yet be linked).

Alfred Korzybski's general semantics maxim "the map is not the territory" applies precisely here. The spatial layout (map) of the knowledge graph is not the knowledge itself (territory). Users inevitably read meaning into spatial relationships that may be artifacts of physics — a pattern noted as "spatial bias" by practitioners.

The [Kumu documentation](https://docs.kumu.io/guides/layouts/force-directed) acknowledges this tension by offering "pinning" — but as noted in the UNDP Jordan review, pinned positions are not reliably persisted across sessions, which means even explicit user spatial decisions are not reliably encoded in the territory.

### 5.2 Semantic Zooming

[Semantic zooming](https://infovis-wiki.net/wiki/Semantic_Zoom) (distinct from geometric/graphical zoom) changes the *type and meaning* of information displayed, not just its size, as a function of zoom level:

- **Geometric zoom**: Nodes scale uniformly; text shrinks; edges remain proportionally thin
- **Semantic zoom**: At overview, nodes become cluster representatives; at detail, nodes show full content; edge rendering changes type at each zoom level

From [emergentmind.com's synthesis of semantic zoom research](https://www.emergentmind.com/topics/semantic-zoom), the key algorithmic guarantees for a well-implemented semantic zoom:

| Property | Description |
|----------|-------------|
| Persistence | Nodes introduced at a zoom level persist at all more-detailed levels |
| No label overlap | Enforced at each level via repulsion |
| No edge crossings | Planarity preserved at each level |
| Geometric stability | Node positions do not change during pan/zoom within a level |
| Scale-to-layer monotonic | Zoom factor maps to discrete levels; no jitter |

**Empirical results** on the Google Scholar "Topics" graph (5,947 nodes, 26,695 edges): Semantic zoom over 8 levels achieves lower layout stress, lower desired-length deviation, and superior compactness relative to direct non-semantic zooming.

**Implementation strategy:** Precompute layouts at 5–8 zoom level intervals during idle time. When the user zooms past a threshold (e.g., zoom factor crosses 0.5x, 1x, 2x, 4x), cross-fade between the precomputed layout for the new level and the precomputed layout for the previous level. Use spring-damped interpolation for the transition (not linear interpolation) so that nodes approaching their new positions decelerate smoothly.

### 5.3 Handling Force-Directed vs. User-Defined Position Conflict

The canonical solution for hybrid layouts is **pinned nodes with soft constraints**:

**Hard pins:** The user explicitly pins a node (e.g., double-tap to pin, shown with a pin indicator). Physics simulation sets `pinned = 1.0` in the node buffer; the integrate kernel skips update for pinned nodes. Pinned positions must be persisted in the graph serialization format, not computed from physics.

**Soft constraints (bias forces):** For nodes that have been manually repositioned but not pinned, apply a bias force toward their user-set position:

```metal
// In integrate kernel:
float2 user_anchor = nodes[i].user_anchor;  // 0,0 if not set
float anchor_strength = nodes[i].anchor_strength;  // 0.0–1.0
float2 bias_force = (user_anchor - nodes[i].position) * anchor_strength;
nodes[i].force += bias_force;
```

`anchor_strength = 0.0` → fully physics-driven. `anchor_strength = 1.0` → equivalent to hard pin. A value of `0.3–0.5` creates a node that "gravitates" toward its user-set position but can still be displaced by strong topological forces (a new hub connecting to it).

**[User-Guided Force-Directed Layout](https://arxiv.org/html/2506.15860)** (arXiv 2025): A recent approach uses freehand sketching to generate positional constraints that guide force-directed layout. The user draws a rough schematic of desired topology; the algorithm extracts structural information and generates alignment/relative-placement constraints for the force simulation. This is directly applicable to the thinking canvas — a "sketch mode" where the user draws a rough arrangement, which is then refined by physics while honoring the user's spatial intent.

### 5.4 Spatial Memory and Layout Stability

Robertson et al.'s [Data Mountain research](https://dl.acm.org/doi/pdf/10.1145/288392.288596) (Microsoft, 1998) directly established that humans form **spatial memory for document positions** in 3D virtual environments. Retrieval times and error rates were lower when users used spatial memory ("it's back there") compared to title-based search. Later [Czerwinski et al. evaluation](https://www.sciencedirect.com/science/article/abs/pii/S1071581904000096) confirms "3D visualization techniques can lead to improved user memory."

The implication: every time the force-directed layout rearranges nodes, it destroys the spatial memory users have built for where their knowledge lives. This is not a minor annoyance — it erases a cognitive investment.

**Misue et al.'s mental map preservation principles** (referenced in ["A Stable Graph Layout Algorithm for Processes"](https://robinmennens.github.io/Portfolio/files/Mennens%20et%20al.%20-%202019%20-%20A%20stable%20graph%20layout%20algorithm%20for%20processes.pdf)) define four preservation properties:
1. **Relative direction**: Node n's direction to node m should be preserved after layout change
2. **Proximity**: Nodes close together should remain close together
3. **Regional containment**: Nodes in a region should stay in that region
4. **Orthogonality**: If n is above/below/left/right of m, that relationship should be preserved

The paper confirms: "Stability and quality are two conflicting requirements: graph layout stability helps preserve the mental map of the user, but also restricts the graph layout algorithm in optimizing layout quality."

**Resolution:** Use animation to bridge layout changes. Even when positions must change (because a node gained many new connections and needs to relocate for readability), animated transitions allow users to track nodes through their displacement. [Research on animation in dynamic graph layouts](https://www.sciencedirect.com/science/article/abs/pii/S0020025515002856) shows that animation is beneficial "for tasks where drawing stability is important and the positions of nodes remain relatively stable throughout graph evolution."

### 5.5 The Stability-Responsiveness Tradeoff

**Settle mode vs. Explore mode** is the practical resolution to the stability-responsiveness tradeoff:

**Settle mode** (default):
- Physics runs with high damping coefficient (0.98+)
- Only processes incremental changes: newly added nodes arrive near their connected neighbors (not random positions); newly added edges create gentle attraction rather than global rearrangement
- Node positions stabilize within seconds of any change
- Mental map is largely preserved

**Explore mode** (opt-in, explicit toggle):
- Physics runs with lower damping (0.85)
- Force strengths increased → graph responds to node drag as if all connections are springs
- Users can "shake" a region by dragging a node to reveal hidden cluster structure
- Warning indicator when in explore mode (prevents accidental reorganization)

**Incremental layout for new nodes:** Rather than re-running global layout on every node addition, new nodes should be placed:
1. If connected: within the bounding box of their direct neighbors (perturbed slightly to avoid overlap)
2. If unconnected: at the periphery of the existing layout, or at the user's last cursor position

This ensures new nodes don't disrupt existing spatial memory while still entering the layout in a meaningful position.

---

## Section 6: Critical UX Pitfalls

### 6.1 The "Hairball" Problem

The hairball is the catastrophic failure mode of large knowledge graphs. As [EagerEyes documents](https://eagereyes.org/techniques/graphs-hairball), "many techniques have been developed to sort out the clutter: edge bundling, node filtering, edge lenses, many different layout algorithms, but all of them treat the symptoms, not the disease."

[Cambridge Intelligence's practitioner analysis](https://cambridge-intelligence.com/how-to-fix-hairballs/) identifies the root cause: **visualizing the raw graph instead of a derived, purpose-specific view**. The solution is remodeling, not more compute:

- Focus on entities users care about (not all nodes equally)
- Derive relationship metrics (betweenness centrality, clustering coefficient) and display aggregated views
- Use progressive disclosure: start with high-level clusters, drill into detail on demand

**Mitigation strategies ranked by effectiveness:**

1. **Semantic clustering with cluster-level nodes** (most effective): Pre-cluster the graph using community detection (Louvain, Leiden); render each community as a single node at overview zoom; expand on click. This is TheBrain's approach with better automation.

2. **[MINGLE edge bundling](http://yifanhu.net/PUB/edge_bundling.pdf)**: Bundle edges that travel in similar directions into shared splines. Reduces visual clutter by 60–80% for dense graphs. Computationally cheap enough for real-time use at <100K edges.

3. **Degree-dependent node sizing + importance culling**: Hide nodes below a configurable degree threshold. Large degree → large node, always visible. Isolated nodes → hidden by default (they contribute most to hairball without adding value).

4. **Edge culling by weight**: Display only edges above a configurable weight threshold. Most knowledge graphs have a power-law edge weight distribution; removing the long tail of weak connections dramatically reduces visual density.

5. **LOD-based edge rendering** (Section 4.5): No edges at overview; bundled edges at mid zoom; individual edges at detail zoom.

### 6.2 Layout Instability: The Spatial Memory Destroyer

Layout instability is the #1 practical complaint across every force-directed tool (Obsidian, Kumu, Roam). It manifests as:
- Positions not persisted across sessions (Obsidian graph view)
- Dramatic rearrangement when any edge changes (naive force-directed)
- "Bouncing back" after manual positioning (Kumu without persistence)

**Root causes and mitigations:**

| Root Cause | Mitigation |
|------------|-----------|
| Non-deterministic initial positions | Seed random number generator with graph hash; same graph → same initial layout |
| Force simulation runs to different equilibria | Use hierarchical multilevel layout for reproducible results |
| User-set positions overwritten by physics | Hard pin system with serialized positions in graph data |
| Layout changes on edge addition | Incremental layout: only affect the neighborhood of changed nodes |
| Session persistence failure | Serialize all node positions, pin states, and user anchors to graph file on every change |

### 6.3 Performance Cliff: Smooth at 1K, Unusable at 10K

The performance cliff is predictable and must be designed against proactively:

**Benchmarks for planning:**
- **<1K nodes**: Naive O(n²) force works, no GPU required
- **1K–10K nodes**: Barnes-Hut O(n log n) required; GPU compute shaders recommended
- **10K–100K nodes**: GPU mandatory; LOD rendering required; multilevel layout required
- **>100K nodes**: Incremental layout only; LOD with clustering; never run global force simulation

**Progressive degradation strategy:**

```
if visible_nodes > 10_000:
    render_mode = POINT_CLOUD  // no edges, just colored dots
    physics_mode = FREEZE       // pause physics, show last stable layout
    show_cluster_hulls = true
    
elif visible_nodes > 2_000:
    render_mode = SMALL_CIRCLES_NO_LABELS
    physics_mode = DAMPED      // high damping, no exploration
    edge_mode = BUNDLED
    
elif visible_nodes > 500:
    render_mode = CIRCLES_WITH_LABELS_ON_HOVER
    physics_mode = SETTLE
    edge_mode = THIN_LINES
    
else:
    render_mode = FULL          // full rendering, all features
    physics_mode = INTERACTIVE  // all gesture features available
```

**The [mlx-vis benchmark on Apple Silicon](https://arxiv.org/html/2603.04035v3)** (MLX/Metal native) demonstrates that 70K points can be embedded and animated at approximately 5ms per SGD step on an M3 Ultra — establishing that force simulation at 10K nodes is well within the GPU's budget for 120fps rendering.

### 6.4 Gesture Conflicts with macOS System Gestures

The reserved system gestures (Section 3.6) create three specific conflict scenarios:

**Conflict 1: Two-finger pinch (zoom vs. synthesize)**
- System behavior: Zoom canvas (NSMagnificationGestureRecognizer)
- Desired behavior: Synthesize nodes when pinch center is between two nodes
- Resolution: Subclass `NSGestureRecognizer` to recognize the same physical gesture but with node-context detection. Use `recognizer.require(toFail: canvasZoomRecognizer)` only when the context indicates a node-targeting pinch. Use gesture recognizer delegate `gestureRecognizerShouldBegin` to check node proximity before allowing the semantic recognizer to activate.

**Conflict 2: Three-finger swipe up (Mission Control vs. expand cluster)**
- System behavior: Mission Control (non-interceptable)
- Resolution: Use three-finger *tap* (distinct from swipe) for in-app operations; avoid three-finger swipe gestures entirely.

**Conflict 3: Two-finger scroll (canvas pan vs. edge creation)**
- System behavior: Pan the canvas
- Desired behavior: Edge creation via drag from node
- Resolution: Initiate edge creation only from a single-finger long-press (500ms) on a node body; two-finger interactions are reserved for navigation. This creates unambiguous gesture vocabulary.

**Testing matrix:** Every gesture should be tested against the system gesture recognizers using `GestureConflictTests` — programmatically trigger each gesture in context and verify the correct recognizer activates.

### 6.5 The "Accidental Reorganization" Problem

A user performing an explore-mode drag near a cluster can inadvertently rearrange the entire graph. This is the spatial equivalent of accidentally selecting-all-and-deleting.

**Prevention strategies:**

1. **Undo as first principle**: EVERY physics state change must be on the undo stack. This includes: single-node drag, bulk layout change from explore mode, pinch-to-synthesize, lasso-to-summarize. The undo stack stores spatial state (node positions + pin states) as a snapshot diff, not a full copy.

2. **Explicit mode boundaries**: Layout-affecting gestures only work in labeled "edit modes." A prominent mode indicator (like Final Cut Pro's Insert/Overwrite mode toggle) prevents accidental semantic operations during exploration.

3. **Commit-then-settle**: After any drag in physics mode, pause physics for 2 seconds and show "Settle" button. Physics resume only on explicit action. This gives users time to recognize the unintended change before it propagates.

4. **Undo granularity for gestural operations**: As [the "You Don't Know Undo/Redo" analysis](https://dev.to/isaachagoel/you-dont-know-undoredo-4hol) explains, undo stacks must operate at the right scope. Each semantic gesture (pinch-to-synthesize, lasso-to-summarize) should be a single undo step. The position states before and after the gesture should be stored. Node mass moves (dragging multiple selected nodes) should be a single undo step, not n individual steps.

5. **Selection scope for accidental bulk operations**: The lasso must only affect explicitly selected nodes; it should not auto-expand selection based on physics proximity. The spatial scope of operations must be exactly what the user drew, not what the physics engine places nearby.

### 6.6 Spatial Bias: Reading Too Much Into Physics-Derived Positions

Users will interpret physics-derived positions as semantic. Two nodes that are near each other because they share many common neighbors (high Jaccard similarity in the graph) will be read as "semantically related" — which may be true! — but two nodes that are near each other because the physics put them there (random initialization artifact) will also be read as related — which is false.

**The mitigation is transparency, not correction:**

1. **Show position provenance**: Differentiate visually between "user-positioned" nodes (solid border, position persisted) and "physics-positioned" nodes (dashed border or subtle indicator, position is computed). This teaches users the difference between intentional and accidental spatial relationships.

2. **Semantic similarity coloring**: Color edges by semantic similarity score (embedding-based cosine similarity), not just existence. If two linked nodes have low semantic similarity, the edge color communicates this. Users can see when topology and semantics diverge.

3. **"Why are these near each other?" affordance**: A hover interaction on a spatial cluster should show a tooltip explaining whether the proximity reflects link density, user arrangement, or physics artifact.

4. **Resist physics bias toward false clusters**: Use a centroid-gravity toward user-set clusters rather than global gravity toward a single center. This prevents the physics from forcing unrelated but highly connected nodes together.

### 6.7 Accessibility: Gesture-Heavy Interfaces Exclude Users

[WCAG 2.5 Pointer Gestures](https://www.w3.org/WAI/WCAG21/Understanding/input-modalities.html) require that "all functionality that uses multipoint or path-based gestures for operation can be operated with a single pointer without a path-based gesture, unless a multipoint or path-based gesture is essential."

[WCAG 2.5.7 Dragging Movements](https://andrewhick.com/accessibility/humans/) (WCAG 2.2 AA) requires that all drag-and-drop functionality can be achieved with point-and-click.

**Required keyboard alternatives for every gesture:**

| Gesture | Keyboard Alternative |
|---------|---------------------|
| Pinch-to-synthesize (two nodes) | Select two nodes (Shift+click), then Cmd+M (Merge) |
| Lasso-to-summarize | Select nodes (Shift+click multiple), then Cmd+Shift+S (Summarize) |
| Drag-to-relate | Select source node, press Cmd+E (edge), Tab to target node, Enter to create |
| Node drag (position) | Select node, use arrow keys with hold modifier for coarse/fine movement |
| Canvas pan | Keyboard scroll or dedicated arrow key mode |

**Reduced-motion accessibility:** The macOS `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` flag should suppress physics animation when enabled. Provide a "snap to stable layout" mode that shows a static force-equilibrium layout without animation.

**Single-finger alternatives:** Every two-finger gesture should have a tap-then-action equivalent accessible via the gesture hint overlay. Users with limited dexterity should be able to invoke all semantic operations through tap → HUD → action.

---

## Synthesis: Design Principles for the Thinking Canvas

The six sections above converge on the following production-ready design principles:

### Architecture Principles

1. **Physics as epistemic environment, not optimizer**: The physics engine's role is to create an environment where spatial manipulation aids cognition (Kirsh & Maglio), not to find an optimal layout. This means supporting explore-then-commit semantics rather than converge-to-equilibrium.

2. **Spatial state is user data**: Node positions set by users must be persisted with the same priority as edge data. Force-derived positions are cached computation; user positions are intent.

3. **Separate physics tick from render frame**: Fixed 60Hz physics on Rust physics thread; 120Hz interpolated rendering on Metal render thread; zero-copy state sharing via Apple Silicon unified memory MTLBuffer.

4. **Multilevel hierarchy for scale**: Pre-compute cluster hierarchy using Louvain community detection; render at appropriate LOD tier; enable smooth zoom across 4–5 orders of magnitude of detail.

### Interaction Principles

5. **Every semantic gesture is a proposal, not a commitment**: Pinch-to-synthesize shows preview; lasso-to-summarize shows preview; edge creation with type shows picker. Commit requires explicit confirmation. Exploration is always safe.

6. **Gesture discoverability is a first-class feature**: The gesture hint overlay is always accessible (⌘/ or hover-pause on empty canvas). Gesture previews (ghost actions) appear during gesture initiation before commitment.

7. **Undo/redo covers spatial state**: Every node position change, every semantic operation, every layout shift is on the undo stack. The undo operation restores positions and pin states, not just the graph data model.

8. **Mode boundaries are explicit and prominent**: Settle mode (safe, default) vs. Explore mode (physics active, gestures powerful) are clearly differentiated visually. Accidental mode switches are prevented by requiring deliberate toggle.

### Semantic-Spatial Principles

9. **Distinguish physics proximity from semantic proximity**: Visual encoding differentiates user-positioned nodes from physics-positioned nodes. Semantic similarity is visualized independently of spatial proximity.

10. **Settle before semantic operations**: When the user initiates a semantic gesture (pinch, lasso), physics briefly freezes to prevent the target nodes from moving during the gesture. This prevents the failure mode of "I was trying to synthesize these two nodes but the physics moved them apart before I completed the pinch."

11. **Semantic zoom changes the model, not just the scale**: At each zoom level, different semantic entities are primary (nodes at detail, clusters at mid, macro-themes at overview). Transitions between levels are animated with 300–500ms spring animations to preserve mental map continuity.

12. **Incremental layout preserves spatial memory**: New nodes arrive near their neighbors; edge addition creates gentle attraction toward existing positions; layout changes are minimized and animated rather than instantaneous and global.

---

*Research compiled from primary sources in cognitive science, HCI, graph algorithms, and GPU computing. All cited papers and tools were reviewed at the primary source; snippets from aggregator sites were verified against original publications.*

**Primary sources:**
- Kirsh & Maglio (1994): https://adrenaline.ucsd.edu/kirsh/Articles/CogsciJournal/DistinguishingEpi_prag.pdf
- Tversky "Visualizing Thought" (2011): https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1756-8765.2010.01113.x
- Zhang & Norman (1994): https://pages.ucsd.edu/~scoulson/203/zhang.pdf
- Hutchins, Distributed Cognition: https://arl.human.cornell.edu/linked%20docs/Hutchins_Distributed_Cognition.pdf
- Jacomy et al., ForceAtlas2 (2014): https://pmc.ncbi.nlm.nih.gov/articles/PMC4051631/
- Heer, Barnes-Hut visualization: https://jheer.github.io/barnes-hut/
- FM³ algorithm: https://d-nb.info/1251482813/34
- GraphWaGu GPU layouts: https://stevepetruzza.io/pubs/graphwagu-2022.pdf
- Norman, Gestural Interfaces: https://jnd.org/gestural-interfaces-a-step-backwards-in-usability/
- Shneiderman, Direct Manipulation (1997): https://www.cs.umd.edu/~ben/papers/Shneiderman1997Direct.pdf
- Robertson et al., Data Mountain (1998): https://dl.acm.org/doi/pdf/10.1145/288392.288596
- Gansner et al., MINGLE edge bundling: http://yifanhu.net/PUB/edge_bundling.pdf
- Mennens et al., Stable Graph Layout (2019): https://robinmennens.github.io/Portfolio/files/Mennens%20et%20al.%20-%202019%20-%20A%20stable%20graph%20layout%20algorithm%20for%20processes.pdf
- LambdaClass, Rust-Metal FFT: https://blog.lambdaclass.com/using-metal-and-rust-to-make-fft-even-faster/
- Apple, MTLStorageMode.shared: https://developer.apple.com/documentation/metal/mtlstoragemode/shared
- WCAG 2.5, Input Modalities: https://www.w3.org/WAI/WCAG21/Understanding/input-modalities.html
- Obsidian forum, graph view discussion: https://forum.obsidian.md/t/whats-the-point-of-the-graph-view-how-are-you-using-it/71316
- Cosma, About: https://cosma.arthurperret.fr/about.html
- Kumu, Force-directed layout: https://docs.kumu.io/guides/layouts/force-directed
- mlx-vis, Apple Silicon GPU benchmarks: https://arxiv.org/html/2603.04035v3
