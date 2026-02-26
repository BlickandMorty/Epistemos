# Knowledge Graph — Design Document

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A SpriteKit-powered knowledge graph that visualizes all entities in the user's vault — notes, ideas, brain dumps, chats, insights, thinkers, papers, books, sources, concepts, tags, and quotes — with full provenance chains, AI entity extraction, a global Ideas Portal, filter pills, radial context menus, and temporal replay. Designed to outperform Obsidian and Logseq at 5,000+ nodes.

**Architecture:** Three-layer stack — SwiftData persistence (SDGraphNode/SDGraphEdge), pure-Swift graph engine (physics, filtering, entity extraction on background threads), and SwiftUI shell wrapping a SpriteKit viewport with native controls.

**Tech Stack:** SpriteKit, SwiftData, SwiftUI, SKPhysicsBody, Barnes-Hut force simulation, LLM entity extraction (user's configured provider), SF Symbols texture atlas.

---

## 1. Node Universe

### Node Types (13)

| Type | Source | Icon | Color | Description |
|------|--------|------|-------|-------------|
| Note | SDPage | doc.text | Blue | Any note/page in vault |
| Folder | SDFolder | folder | Slate | Notebook/folder container |
| Idea | NoteIdea (.idea) | lightbulb | Amber/Gold | Specific idea anchored to a note |
| Brain Dump | NoteIdea (.brainDump) | brain | Purple | Raw brain dump from a note |
| Chat | SDChat | bubble.left | Green | A conversation thread |
| Insight | AI-extracted from SDChat | sparkle | Teal | Key conclusion from a chat |
| Thinker | AI-extracted + paper authors | person.bust | Warm Orange | A person (philosopher, scientist, author) |
| Paper | SavedPaper / ResearchPaper | doc.richtext | Red | Academic paper or article |
| Book | ResearchBook | book.closed | Brown | A saved book |
| Source | Citation + URLs from chats/notes | link | Indigo | Web URL, citation, or reference |
| Concept | AI-extracted from notes | tag | Pink | Recurring theme across notes |
| Tag | SDPage.tags | number | Gray | Explicit tag from note metadata |
| Quote | AI-extracted from notes/chats | text.quote | Cyan | Significant quoted passage with attribution |

### Edge Types

| Edge | Meaning | Visual |
|------|---------|--------|
| Note -> Folder | "lives in" | Thin gray, dashed |
| Note -> Note | Wikilink / nested / AI-semantic | Solid blue |
| Idea -> Note | "belongs to" | Gold dashed |
| Idea -> Idea | AI-detected thematic link | Gold solid |
| Brain Dump -> Note | "belongs to" | Purple dashed |
| Chat -> Note | "referenced" | Green dotted |
| Insight -> Chat | "extracted from" | Teal thin |
| Insight -> Note | "relates to" | Teal dashed |
| Insight -> Source | "backed by" | Teal solid |
| Thinker -> Paper | "authored" | Orange solid |
| Thinker -> Note | "mentioned in" | Orange dashed |
| Thinker -> Chat | "discussed in" | Orange dotted |
| Thinker -> Quote | "said" | Orange->Cyan |
| Paper -> Note | "cited in" | Red dashed |
| Paper -> Chat | "discovered in" | Red dotted |
| Source -> Chat | "shared in" | Indigo dotted |
| Source -> Note | "referenced in" | Indigo dashed |
| Source -> Paper | "links to" | Indigo solid |
| Quote -> Note | "appears in" | Cyan dashed |
| Quote -> Thinker | "attributed to" | Cyan->Orange |
| Concept -> Note | "appears in" | Pink dotted |
| Concept -> Concept | "related concept" | Pink solid |
| Concept -> Chat | "explored in" | Pink dotted |
| Tag -> Note | "tagged" | Gray thin |

### Obsidian-Killer Differentiators

1. **Full Provenance Chains** — Every node traces its origin (discovered in Chat #12 -> cited in Note Y -> inspired Idea Z -> connects to Concept -> Thinker also wrote about it)
2. **Edge Weight / Strength** — Heavy edges pull nodes closer in physics. A note entirely about Nietzsche clusters tighter than one mentioning him once.
3. **Evidence Grades on Insights** — Gold-ringed A-grade insights vs faded D-grade. Filter to show only high-confidence knowledge.
4. **Research Stage Glow** — Notes at stage 0 (raw) are dim. Stage 5 (fully researched) glow bright. Visual heat map of understanding maturity.
5. **Temporal Replay** — Timeline scrubber to watch knowledge network grow over time.
6. **Cross-Source Intelligence** — Same URL/paper/thinker across multiple chats/notes becomes a hub node (visually larger, more connections).

---

## 2. Three-Layer Architecture

### Layer 1: Data Layer (SwiftData)

**SDGraphNode @Model:**
- id: String (UUID)
- type: String — one of the 13 node types
- label: String — display name
- sourceId: String? — FK to origin (SDPage.id, SDChat.id, etc.)
- metadata: Data? — JSON bag (evidence grade, research stage, URL, author list, quote text)
- weight: Double — importance/centrality (AI-computed, affects node size)
- createdAt: Date
- updatedAt: Date

**SDGraphEdge @Model:**
- id: String (UUID)
- sourceNodeId: String — FK to SDGraphNode
- targetNodeId: String — FK to SDGraphNode
- type: String — edge relationship type
- weight: Double — connection strength (affects thickness + physics pull)
- createdAt: Date

Denormalized string FKs (not @Relationship) for #Predicate query support at scale.

### Layer 2: Graph Engine (Pure Swift, No UI)

**GraphStore** — In-memory adjacency list from SDGraphNode/SDGraphEdge. O(1) neighbor lookup.

**ForceSimulation** — Background thread. Barnes-Hut O(n log n) repulsion, weighted edge attraction, centering force, damping. Auto-sleeps when settled.

**FilterEngine** — Set<String> of active types. Visibility flag flips, O(1) per toggle. BFS for "show connected to X."

**EntityExtractor** — AI scanning pipeline. Initial full scan, incremental on save, deduplication via canonical name index.

### Layer 3: UI Shell (SwiftUI + SpriteKit)

- Graph opens as utility window via UtilityWindowManager (Cmd+G or Command Palette)
- SwiftUI shell: sidebar (Ideas Portal, filters, search, info panel) + SpriteKit viewport
- Floating pills overlay top-right of viewport (type toggles with count badges)
- Timeline scrubber overlay at bottom
- Radial context menu on right-click node
- ~300 active SKNodes max via viewport culling + node pooling

---

## 3. AI Scanning Pipeline

### Initial Vault Scan
- Process all SDPage notes + SDChat threads
- Batch 5 notes per LLM call
- Extract: thinkers, concepts, quotes, sources, insights, related_note_hints
- Create SDGraphNode + SDGraphEdge entries
- Progress bar UI during scan
- Cost: ~$0.80 for 2,000 notes at Haiku pricing

### Incremental Updates
- On note save: re-extract if >10% body delta
- On chat completion: extract insights from new assistant message
- On idea created/deleted: direct node CRUD (no AI needed)

### Deduplication
- Canonical name index: lowercase, strip titles, Levenshtein <= 2
- LLM confirmation for ambiguous matches
- Concepts: LLM asked "are these equivalent to existing ones?"

### AI Clustering (Ideas Hub)
- Batch all NoteIdea objects to LLM
- Returns theme clusters with summaries
- Clusters become Concept nodes with edges to member ideas
- Re-cluster on-demand or periodically

---

## 4. Global Ideas Portal

### Three Views
1. **By Note** — Collapsible note sections, ideas listed under their source note
2. **By Theme** — AI-clustered groups crossing note boundaries
3. **All Ideas** — Flat searchable list with source note shown

### Actions
- Create idea (pick target note)
- Move idea between notes
- Link ideas together (creates Idea->Idea edge)
- Delete idea
- Jump to source (opens note at line anchor)
- Center in graph (pans viewport)
- Re-cluster (re-runs AI grouping)

### Graph Sync
- Select in portal -> node highlights in graph (pulse)
- Select in graph -> portal auto-scrolls to that idea
- Bidirectional, real-time

---

## 5. Visual Design & Performance

### Node Rendering
- Circle SKShapeNode, type-colored fill, size scales with weight
- Small (1-2 connections): 8pt, Medium (3-10): 14pt, Hub (10+): 22pt
- SF Symbol icon inside circle (texture atlas)
- Label below node, visible at zoom > 0.4x

### Node States
- Default: 80% opacity solid fill
- Hovered: glow ring (SKEffectNode bloom), bold label, connected edges brighten
- Selected: accent border, info panel opens, connected nodes pulse
- Dimmed: 20% opacity, no label
- Research stage 4-5: radial gradient glow
- Evidence grade A: thin gold ring

### Edge Rendering
- Quadratic bezier curves (organic, not straight)
- Thickness 0.5pt-3pt based on weight
- Color from source node at 40% opacity
- On node hover: its edges full opacity, all others dim to 10%

### Zoom Levels (LOD)
- < 0.2x: colored dots only, no labels/icons
- 0.2x-0.5x: circles with color, hub labels only
- 0.5x-1.0x: full nodes with icons + labels + hover effects
- > 1.0x: large nodes, edge labels visible

### Interactions
- Pan: two-finger drag / click+drag empty space
- Zoom: pinch / scroll wheel (momentum-based)
- Select: click node
- Multi-select: Cmd+click
- Drag node: detach from physics, reposition, re-attach
- Right-click node: radial context menu
- Space: reset view
- F: focus selected node
- /: focus search
- 1-9: quick-toggle filter pills
- T: toggle timeline scrubber

### Performance (5,000+ nodes)
- Viewport culling: spatial hash, ~300 active SKNodes max
- Node pooling: SKNodes recycled as viewport pans
- Barnes-Hut physics: O(n log n) on background thread at 30fps
- SpriteKit interpolates to 60fps visual
- Physics auto-sleeps on settle, wakes on interaction/topology change
- Adjacency list built in ~50ms for 5,000 nodes
- Filter toggles are in-memory flag flips (no SwiftData IO)
- Texture atlas: all 13 icons pre-rasterized, single draw call

### Aesthetic: "Alive But Calm"
- Physics settling: ~2s elastic easing
- Filter toggle: shrink to zero + fade over 0.3s
- New node: scale from 0 + gentle bounce
- Hover glow: 0.2s in, 0.15s out
- Timeline scrub: 0.1s micro-fade per node
- Camera zoom: trackpad inertia preserved
