# Epistemos Retro Edition — Engineering Standards

## MANDATORY: Read This Before Writing ANY Code

This document defines the engineering quality bar for Epistemos Retro Edition.
Every architectural decision must match or exceed what was built on macOS.
**Do NOT default to the easy/web path. Default to the performant/native path.**

---

## THE GOLDEN RULE

> If the macOS version uses Metal + Rust + SIMD, the Windows version uses
> Bevy/wgpu + Rust + ONNX Runtime. NEVER downgrade to D3.js, DOM rendering,
> or JavaScript-based solutions when a native Rust alternative exists.

| DO NOT USE | USE INSTEAD | WHY |
|------------|-------------|-----|
| D3.js for graph rendering | Bevy + wgpu (WebGPU/D3D12/Vulkan) | Native GPU, instanced draw, 10K nodes @ 60fps |
| D3-force for physics | Rapier3D via bevy_rapier3d | True rigid body dynamics, SpringJoint, collision |
| Canvas/SVG for nodes | WGSL custom shaders (SDF circles) | SDF = 3 ALU ops per pixel, anti-aliased, glow |
| DOM text for labels | Bevy cosmic-text + FontAtlas | GPU-instanced text, LOD-gated, frustum culled |
| fetch() for API calls | Tauri invoke() | Direct Rust IPC, no HTTP overhead |
| SSE for streaming | Tauri events (listen/emit) | Native IPC, no HTTP chunked encoding |
| better-sqlite3 (JS) | rusqlite (Rust) | Direct SQLite C API, no JS bridge |
| Drizzle ORM (JS) | Raw rusqlite + hand-written SQL | Zero ORM overhead, prepared statements |
| transformers.js | ort crate (ONNX Runtime) | DirectML NPU/GPU, sub-ms inference |
| JavaScript workers | tokio::spawn / std::thread | Native threads, no event loop overhead |
| React state for physics | Bevy ECS components | Cache-coherent, SoA memory, parallel systems |
| CSS animations for graph | WGSL shaders + Bevy animation | GPU-driven, 60fps guaranteed |

---

## ARCHITECTURE: TAURI + BEVY HYBRID

### Window Layout

```
+================================================================+
|                     Tauri 2.x Application                       |
|================================================================+
|                                                                  |
|  +----------------------------------------------------------+  |
|  |              Native Window (TAO)                          |  |
|  |                                                            |  |
|  |  +------------------------------------------------------+|  |
|  |  |          Bevy + wgpu Render Surface                   ||  |
|  |  |                                                        ||  |
|  |  |  - Rapier3D physics simulation                        ||  |
|  |  |  - WGSL custom shaders (SDF nodes, edge curves)       ||  |
|  |  |  - Instanced rendering (10K+ nodes, single draw call) ||  |
|  |  |  - Frustum culling + LOD (automatic)                  ||  |
|  |  |  - GPU text rendering (cosmic-text FontAtlas)         ||  |
|  |  |  - Bloom post-processing (HDR)                        ||  |
|  |  +------------------------------------------------------+|  |
|  |                                                            |  |
|  |  +------------------------------------------------------+|  |
|  |  |    Transparent Webview Overlay (child)                ||  |
|  |  |    Next.js UI: sidebar, chat, controls, search        ||  |
|  |  |    pointer-events: none on graph area                 ||  |
|  |  +------------------------------------------------------+|  |
|  +----------------------------------------------------------+  |
|                                                                  |
|  +----------------------------------------------------------+  |
|  | Rust Backend (shared across both surfaces)                |  |
|  | pipeline/ | storage/ | graph/ | llm/ | physics/ | vault/ |  |
|  +----------------------------------------------------------+  |
+================================================================+
```

### Tauri 2.x Multi-Webview Setup

Use Tauri 2.x `unstable` cargo feature for multi-webview support:
- Main window created by TAO (Tauri's window manager)
- Bevy acquires wgpu render surface from the same window handle
- Transparent child webview layered on top for Next.js UI
- Input routing: CSS `pointer-events: none` on transparent graph area
- Reference: https://github.com/FabianLars/tauri-v2-wgpu

### Fallback (If Overlay Proves Fragile)

If webview overlay has Z-ordering issues on Windows:
- Run Bevy headless (ECS + Rapier3D physics only, no rendering)
- Stream positions to webview via Tauri events at 60fps
- Render graph in webview using WebGPU canvas (NOT D3.js)
- This is the BACKUP plan, not the default

---

## RENDERING: WGSL SHADERS (Metal → WebGPU Translation)

### Shader Quality Tiers (Port from macOS)

The macOS version has 3 quality modes. Replicate exactly:

```wgsl
// node.wgsl — Quality-tiered node rendering

@group(0) @binding(0) var<uniform> globals: Globals;

struct Globals {
    view_proj: mat4x4<f32>,
    viewport: vec2<f32>,
    quality_level: u32,  // 0=cinematic, 1=balanced, 2=performance
    time: f32,
}

@fragment
fn fragment(@location(0) uv: vec2<f32>, @location(1) color: vec4<f32>) -> @location(0) vec4<f32> {
    let centered = (uv - 0.5) * 2.0;
    let dist = length(centered);

    if globals.quality_level == 2u {
        // PERFORMANCE: 3 ALU ops, flat circle
        let alpha = 1.0 - smoothstep(0.85, 1.0, dist);
        return vec4<f32>(color.rgb, alpha);
    } else if globals.quality_level == 1u {
        // BALANCED: SDF + sphere lighting
        let alpha = 1.0 - smoothstep(0.85, 1.0, dist);
        let normal = vec3<f32>(centered, sqrt(max(0.0, 1.0 - dot(centered, centered))));
        let light = dot(normal, normalize(vec3<f32>(0.3, 0.5, 1.0)));
        return vec4<f32>(color.rgb * (0.4 + 0.6 * light), alpha);
    } else {
        // CINEMATIC: SDF + sphere + breathing + perspective
        let breath = sin(globals.time * 1.5) * 0.02;
        let r = 0.85 + breath;
        let alpha = 1.0 - smoothstep(r - 0.02, r, dist);
        let normal = vec3<f32>(centered, sqrt(max(0.0, 1.0 - dot(centered, centered))));
        let light = dot(normal, normalize(vec3<f32>(0.3, 0.5, 1.0)));
        let glow = exp(-dist * dist / 0.3) * 0.4;
        return vec4<f32>(color.rgb * (0.3 + 0.7 * light) + glow, alpha);
    }
}
```

### Instanced Rendering (CRITICAL)

ALL graph nodes rendered in a SINGLE draw call via instancing:

```rust
// Per-instance data sent to GPU
#[repr(C)]
#[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
struct NodeInstance {
    position: [f32; 3],     // from Rapier3D RigidBody
    scale: f32,             // based on link_count / word_count
    color: [f32; 4],        // node_type → color mapping
    glow_intensity: f32,    // hub nodes glow brighter
    depth_tier: f32,        // z-ordering: -0.4, -0.1, 0.12, 0.5
    node_type: u32,
    _padding: u32,
}
```

- 10K nodes = 1 draw call (not 10K draw calls)
- Edges = 1 draw call (instanced line strips or vertex-pulled Bezier)
- Glow halos = 1 additional draw call (rendered behind nodes)
- Total: 3 draw calls for entire graph

### Edge Rendering (Constant Screen-Pixel Width)

Port the macOS pattern: edges maintain constant pixel width regardless of zoom:

```wgsl
// edge.wgsl — Constant-width edges
@vertex
fn vertex(
    @location(0) endpoint_a: vec3<f32>,
    @location(1) endpoint_b: vec3<f32>,
    @location(2) perp_sign: f32,  // -1 or +1 (which side of line)
) -> VertexOutput {
    let ndc_a = globals.view_proj * vec4<f32>(endpoint_a, 1.0);
    let ndc_b = globals.view_proj * vec4<f32>(endpoint_b, 1.0);

    let dir = normalize(ndc_b.xy / ndc_b.w - ndc_a.xy / ndc_a.w);
    let perp = vec2<f32>(-dir.y, dir.x);

    let pixel_to_ndc = 2.0 / globals.viewport;
    let offset = perp * perp_sign * 0.75 * pixel_to_ndc;

    var out: VertexOutput;
    out.position = ndc_a + vec4<f32>(offset, 0.0, 0.0);
    return out;
}
```

### Bloom Post-Processing

Use Bevy's built-in HDR bloom (NOT custom shader):

```rust
commands.spawn((
    Camera3d::default(),
    Camera { hdr: true, ..default() },
    Bloom {
        intensity: 0.3,
        low_frequency_boost: 0.5,
        ..default()
    },
    Transform::from_xyz(0.0, 0.0, 50.0).looking_at(Vec3::ZERO, Vec3::Y),
));
```

### Idle Frame Skipping (Port from macOS)

After graph settles, STOP rendering:

```rust
fn should_render(sim: &PhysicsState) -> bool {
    if sim.is_settled {
        sim.idle_frame_count += 1;
        if sim.idle_frame_count > 3 {
            return false;  // GPU idles completely
        }
    } else {
        sim.idle_frame_count = 0;
    }
    true
}
```

---

## PHYSICS: RAPIER3D VIA BEVY ECS

### Use bevy_rapier3d (NOT raw Rapier3D)

```toml
[dependencies]
bevy = "0.18"
bevy_rapier3d = { version = "0.33", features = [
    "simd-stable",     # SIMD optimizations
    "parallel",        # Rayon parallelism
]}
```

### Graph Node = ECS Entity + RigidBody

```rust
#[derive(Bundle)]
struct GraphNodeBundle {
    // Identity
    node: GraphNode,
    label: NodeLabel,
    // Physics (Rapier3D)
    rigid_body: RigidBody,
    collider: Collider,
    velocity: Velocity,
    external_force: ExternalForce,
    damping: Damping,
    gravity_scale: GravityScale,
    locked_axes: LockedAxes,
    // Rendering (Bevy)
    mesh: Mesh3d,
    material: MeshMaterial3d<NodeMaterial>,
    transform: Transform,
    visibility: Visibility,
    lod: GraphLOD,
}

fn spawn_node(commands: &mut Commands, node: &NodeData) -> Entity {
    commands.spawn(GraphNodeBundle {
        node: GraphNode { id: node.id, node_type: node.node_type },
        label: NodeLabel(node.title.clone()),
        rigid_body: RigidBody::Dynamic,
        collider: Collider::ball(0.5),
        velocity: Velocity::default(),
        external_force: ExternalForce::default(),
        damping: Damping { linear_damping: 2.0, angular_damping: 1.0 },
        gravity_scale: GravityScale(0.0),  // NO gravity in graph space
        locked_axes: LockedAxes::ROTATION_LOCKED,
        // ... rendering components
        lod: GraphLOD::Full,
    }).id()
}
```

### Graph Edge = SpringJoint (NOT custom force code)

```rust
fn spawn_edge(commands: &mut Commands, source: Entity, target: Entity) {
    let mut spring = SpringJoint::new(
        5.0,    // rest_length (edge wants nodes this far apart)
        50.0,   // stiffness (spring constant k)
        10.0,   // damping (prevents oscillation)
    );
    spring.set_spring_model(MotorModel::AccelerationBased);

    commands.spawn(ImpulseJoint::new(source, spring))
        .insert(GraphEdge { source, target });
}
```

### Repulsion Force (Coulomb/Barnes-Hut)

For non-connected nodes, apply repulsion via ExternalForce:

```rust
fn apply_repulsion(
    mut query: Query<(Entity, &Transform, &mut ExternalForce), With<GraphNode>>,
) {
    // Collect positions (parallel-friendly)
    let positions: Vec<(Entity, Vec3)> = query.iter()
        .map(|(e, t, _)| (e, t.translation))
        .collect();

    // O(n²) for < 5K nodes, Barnes-Hut octree for > 5K
    for (entity, transform, mut ext_force) in query.iter_mut() {
        let mut repulsion = Vec3::ZERO;
        for (other, other_pos) in &positions {
            if entity == *other { continue; }
            let delta = transform.translation - *other_pos;
            let dist_sq = delta.length_squared().max(0.01);
            repulsion += delta.normalize_or_zero() * (500.0 / dist_sq);
        }
        ext_force.force = repulsion;
    }
}
```

### Static Layout Threshold (Port from macOS)

Graphs > 1500 nodes: disable physics, use pre-computed layout:

```rust
fn check_static_threshold(
    node_count: Res<NodeCount>,
    mut rapier_config: ResMut<RapierConfiguration>,
) {
    if node_count.0 > 1500 {
        rapier_config.physics_pipeline_active = false;
        // Nodes hold spiral/loaded positions
        // Re-enable when user filters to < 1500 visible nodes
    }
}
```

### LOD System (Multi-Tier)

```rust
#[derive(Component)]
enum GraphLOD {
    Full,        // Mesh + label + glow + SDF shader
    Simplified,  // Simple sphere + label text
    Dot,         // Single pixel quad (no label)
    Hidden,      // Beyond render distance (culled)
}

fn update_lod(
    camera: Query<&Transform, With<Camera3d>>,
    mut nodes: Query<(&Transform, &mut GraphLOD, &mut Visibility), With<GraphNode>>,
) {
    let cam_pos = camera.single().translation;
    for (t, mut lod, mut vis) in nodes.iter_mut() {
        let dist = cam_pos.distance(t.translation);
        *lod = match dist {
            d if d < 20.0  => GraphLOD::Full,
            d if d < 50.0  => GraphLOD::Simplified,
            d if d < 200.0 => GraphLOD::Dot,
            _              => GraphLOD::Hidden,
        };
        *vis = if matches!(*lod, GraphLOD::Hidden) {
            Visibility::Hidden
        } else {
            Visibility::Visible
        };
    }
}
```

### 3D ⊃ 2D (Flat Mode = z=0)

3D is the default. For flat/2D mode, constrain z:

```rust
fn enforce_flat_mode(
    flat_mode: Res<FlatMode>,
    mut query: Query<&mut Transform, With<GraphNode>>,
) {
    if flat_mode.enabled {
        for mut t in query.iter_mut() {
            t.translation.z = 0.0;
        }
    }
}
```

---

## SEARCH: DUAL-LAYER (FST + FTS5)

### Layer 1: Rust FST (Graph Label Search) — Port Directly

The macOS engine uses `fst` crate with Levenshtein automaton + 5-tier scoring.
This code is ALREADY Rust. Copy it directly:

```
graph-engine/src/search.rs → src-tauri/search/fst_search.rs
```

5-tier scoring algorithm (preserve exactly):
1. **Exact match** → score 1.0
2. **Prefix match** → score 0.8
3. **Word-start match** (camelCase/snake_case boundaries) → score 0.6
4. **Contains** (substring) → score 0.4
5. **Subsequence** → score 0.2
6. **FST Levenshtein bonus** → +0.25 for typo corrections

Key crates:
```toml
fst = "0.4"
rustc-hash = "1.1"  # FxHashMap for reverse index
```

### Layer 2: FTS5 Full-Text Search (Note Bodies)

Port from macOS's GRDB-backed SearchIndexService to rusqlite:

```rust
// search/fts5.rs

pub struct FullTextIndex {
    conn: Connection,
}

impl FullTextIndex {
    pub fn new(db_path: &Path) -> Result<Self> {
        let conn = Connection::open(db_path)?;
        conn.execute_batch("
            CREATE TABLE IF NOT EXISTS indexed_pages (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                body TEXT NOT NULL DEFAULT '',
                tags TEXT NOT NULL DEFAULT '',
                updated_at REAL NOT NULL
            );
            CREATE VIRTUAL TABLE IF NOT EXISTS search_fts USING fts5(
                title, body, tags,
                content='indexed_pages',
                content_rowid='rowid',
                tokenize='unicode61 remove_diacritics 2'
            );
            -- Content-sync triggers (same as macOS)
            CREATE TRIGGER IF NOT EXISTS pages_ai AFTER INSERT ON indexed_pages BEGIN
                INSERT INTO search_fts(rowid, title, body, tags)
                VALUES (new.rowid, new.title, new.body, new.tags);
            END;
            CREATE TRIGGER IF NOT EXISTS pages_ad AFTER DELETE ON indexed_pages BEGIN
                INSERT INTO search_fts(search_fts, rowid, title, body, tags)
                VALUES ('delete', old.rowid, old.title, old.body, old.tags);
            END;
            CREATE TRIGGER IF NOT EXISTS pages_au AFTER UPDATE ON indexed_pages BEGIN
                INSERT INTO search_fts(search_fts, rowid, title, body, tags)
                VALUES ('delete', old.rowid, old.title, old.body, old.tags);
                INSERT INTO search_fts(rowid, title, body, tags)
                VALUES (new.rowid, new.title, new.body, new.tags);
            END;
        ")?;
        Ok(Self { conn })
    }

    pub fn search(&self, query: &str, limit: usize) -> Result<Vec<SearchResult>> {
        let sanitized = sanitize_fts5_query(query);
        let mut stmt = self.conn.prepare("
            SELECT ip.id, ip.title,
                   snippet(search_fts, 1, '<mark>', '</mark>', '...', 32) AS snippet,
                   bm25(search_fts, 5.0, 1.0, 2.0) AS rank
            FROM search_fts sf
            JOIN indexed_pages ip ON ip.rowid = sf.rowid
            WHERE search_fts MATCH ?1
            ORDER BY rank
            LIMIT ?2
        ")?;
        // ... collect results
    }

    pub fn upsert(&self, page: &PageIndex) -> Result<()> {
        self.conn.execute(
            "INSERT OR REPLACE INTO indexed_pages (id, title, body, tags, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![page.id, page.title, page.body, page.tags, page.updated_at],
        )?;
        Ok(())
    }
}

/// Sanitize FTS5 query (port from macOS SearchIndexService.sanitizeFTS5Query)
fn sanitize_fts5_query(raw: &str) -> String {
    // Strip special FTS5 operators, wrap terms in quotes if needed
    let cleaned: String = raw.chars()
        .filter(|c| c.is_alphanumeric() || c.is_whitespace())
        .collect();
    if cleaned.contains(' ') {
        cleaned.split_whitespace()
            .map(|w| format!("\"{}\"*", w))
            .collect::<Vec<_>>()
            .join(" ")
    } else {
        format!("\"{}\"*", cleaned)
    }
}
```

### Incremental Index Updates (NOT Full Rebuilds)

```rust
// Vault watcher calls upsert/delete on each file change
fn on_file_changed(index: &FullTextIndex, page: &Page) {
    index.upsert(&PageIndex {
        id: page.id.clone(),
        title: page.title.clone(),
        body: page.body.clone(),
        tags: page.tags.join(" "),
        updated_at: page.updated_at,
    }).ok();
}

fn on_file_deleted(index: &FullTextIndex, page_id: &str) {
    index.delete(page_id).ok();
}
```

### Diff-Sync on Startup (Port from macOS)

On launch, compare FTS5 index freshness vs SQLite pages table:

```rust
fn diff_sync(index: &FullTextIndex, db: &Database) -> Result<()> {
    let indexed: HashMap<String, f64> = index.get_all_timestamps()?;
    let pages = db.list_pages()?;

    for page in &pages {
        match indexed.get(&page.id) {
            None => index.upsert(&page.to_index())?,          // missing: add
            Some(ts) if *ts < page.updated_at => {
                index.upsert(&page.to_index())?;               // stale: update
            }
            _ => {}                                             // fresh: skip
        }
    }
    // Remove entries for deleted pages
    for id in indexed.keys() {
        if !pages.iter().any(|p| p.id == *id) {
            index.delete(id)?;
        }
    }
    Ok(())
}
```

---

## EDITOR: CODEMIRROR 6 (Best-in-Class)

### Why CodeMirror 6

Obsidian uses it. Logseq uses it. It IS the industry standard for markdown editors in desktop apps.

| Feature | CodeMirror 6 | Obsidian's Editor | Epistemos Retro |
|---------|-------------|-------------------|-----------------|
| Vim/Emacs bindings | Yes | Yes | Yes |
| Inline decorations | Yes (Decoration API) | Yes | Yes (block refs, transclusions) |
| Folding | Yes | Yes | Yes |
| Multi-cursor | Yes | Yes | Yes |
| Custom syntax | Yes (Lezer grammar) | Yes | Yes (block refs `(())`) |
| 100K+ lines | Yes (viewport rendering) | Yes | Yes |
| Mobile-friendly | Yes | Yes | N/A (Windows) |

### Critical Extensions to Build

Port these from macOS NSTextView features:

```typescript
// 1. Block Reference Syntax — ((block-id))
import { Decoration, ViewPlugin, WidgetType } from '@codemirror/view';

class BlockRefWidget extends WidgetType {
    constructor(readonly blockId: string, readonly title: string) { super(); }
    toDOM() {
        const span = document.createElement('span');
        span.className = 'block-ref';
        span.textContent = this.title;
        span.onclick = () => invoke('navigate_to_block', { id: this.blockId });
        return span;
    }
}

// 2. Transclusion Overlay — render referenced block content inline
// Port from TransclusionOverlayManager.swift
class TransclusionWidget extends WidgetType {
    constructor(readonly content: string) { super(); }
    toDOM() {
        const div = document.createElement('div');
        div.className = 'transclusion-embed';
        div.innerHTML = renderMarkdown(this.content);
        return div;
    }
}

// 3. Block Ref Autocomplete — triggered by ((
import { autocompletion, CompletionContext } from '@codemirror/autocomplete';

async function blockRefCompletion(context: CompletionContext) {
    const match = context.matchBefore(/\(\([^)]*$/);
    if (!match) return null;
    const query = match.text.slice(2);
    const results = await invoke('search_blocks', { query });
    return {
        from: match.from + 2,
        options: results.map(r => ({
            label: r.content.slice(0, 50),
            apply: `${r.id}))`,
        })),
    };
}
```

### Markdown Syntax Highlighting (Custom Lezer Grammar)

Port the macOS MarkdownTextStorage regex patterns to a Lezer grammar:

```typescript
// Extensions to add to CodeMirror
const epistemosExtensions = [
    // Core markdown
    markdown({ base: markdownLanguage }),
    // Block references: (( ... ))
    blockRefHighlight,
    // Tags: #tag
    tagHighlight,
    // Wiki links: [[ ... ]]
    wikiLinkHighlight,
    // Vim mode (optional, user preference)
    vim(),
    // Autocomplete
    autocompletion({ override: [blockRefCompletion] }),
    // Theme (port from Tailwind themes)
    epistemosTheme,
];
```

### Editor ↔ Rust Sync (Block Parser)

The macOS version uses BlockParser + BlockReconciler for outliner functionality.
On Windows, the same Rust code runs — CodeMirror sends markdown to Rust, Rust returns blocks:

```typescript
// On editor change (debounced 300ms)
const body = editor.state.doc.toString();
const blocks = await invoke('parse_blocks', { body, pageId });
// Blocks have stable UUIDs via Jaccard similarity matching
```

---

## EMBEDDINGS: ONNX RUNTIME (NOT transformers.js)

### Direct Rust Inference (No HTTP)

```rust
use ort::{Session, SessionBuilder, ExecutionProvider};

pub struct EmbeddingService {
    session: Session,
}

impl EmbeddingService {
    pub fn new(model_path: &Path) -> Result<Self> {
        let session = SessionBuilder::new()?
            .with_execution_providers([
                // Auto-select: DirectML (NPU/GPU) > CUDA > CPU
                ExecutionProvider::DirectML(Default::default()),
                ExecutionProvider::CUDA(Default::default()),
                ExecutionProvider::CPU(Default::default()),
            ])?
            .with_model_from_file(model_path)?;
        Ok(Self { session })
    }

    /// Embed single text — sub-millisecond on NPU
    pub fn embed(&self, text: &str) -> Result<Vec<f32>> {
        let tokens = tokenize(text);  // all-MiniLM-L6-v2 tokenizer
        let output = self.session.run(ort::inputs![tokens]?)?;
        Ok(output[0].try_extract_tensor::<f32>()?.to_vec())
    }

    /// Batch embed — amortizes kernel launch overhead
    pub fn embed_batch(&self, texts: &[&str]) -> Result<Vec<Vec<f32>>> {
        // Batch 100 texts at once for GPU efficiency
        // Single ONNX kernel launch instead of 100
    }

    /// Cosine similarity with cached norms
    pub fn similarity(a: &[f32], norm_a: f32, b: &[f32], norm_b: f32) -> f32 {
        let dot: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
        dot / (norm_a * norm_b)
    }
}
```

### KNN Search (Top-K Nearest Neighbors)

```rust
pub fn find_semantic_neighbors(
    query_embedding: &[f32],
    all_embeddings: &[(String, Vec<f32>, f32)],  // (id, vec, cached_norm)
    k: usize,
) -> Vec<(String, f32)> {
    let query_norm = l2_norm(query_embedding);
    let mut scores: Vec<(String, f32)> = all_embeddings.iter()
        .map(|(id, emb, norm)| {
            let sim = EmbeddingService::similarity(query_embedding, query_norm, emb, *norm);
            (id.clone(), sim)
        })
        .collect();
    // Partial sort: only need top-k, not full sort
    scores.sort_unstable_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
    scores.truncate(k);
    scores
}
```

---

## PIPELINE: STREAMING + BACKGROUND ENRICHMENT

### Three-Pass Architecture (Port Exactly from macOS)

```rust
pub async fn run_pipeline(
    app: AppHandle,
    query: String,
    llm: Arc<dyn LlmClient>,
    state: Arc<Mutex<AppState>>,
) -> Result<()> {
    // PASS 1: Stream direct answer (user sees immediately)
    let stream = llm.stream(messages, &config).await?;
    tokio::spawn({
        let app = app.clone();
        async move {
            pin_mut!(stream);
            while let Some(token) = stream.next().await {
                app.emit("pipeline:text-delta", &token?)?;
            }
            app.emit("pipeline:pass1-complete", &())?;
        }
    });

    // PASS 2: Background enrichment (runs while user reads)
    let app2 = app.clone();
    tokio::spawn(async move {
        let enrichment = llm.structured_output::<Enrichment>(&prompt, &schema).await;
        if let Ok(e) = enrichment {
            app2.emit("pipeline:enrichment", &e).ok();
        }
    });

    // PASS 3: Truth assessment (runs after Pass 2)
    let app3 = app.clone();
    tokio::spawn(async move {
        let truth = llm.structured_output::<TruthAssessment>(&prompt, &schema).await;
        if let Ok(t) = truth {
            app3.emit("pipeline:truth", &t).ok();
        }
    });

    Ok(())
}
```

### Stage Events (for UI Progress)

```rust
app.emit("pipeline:stage", StageEvent { stage: "triage", status: "running" })?;
let triage = classify_query(&query).await?;
app.emit("pipeline:stage", StageEvent { stage: "triage", status: "completed" })?;
```

### Signal System

```rust
#[derive(Serialize)]
pub struct SignalUpdate {
    pub confidence: f64,
    pub entropy: f64,
    pub dissonance: f64,
    pub health_score: f64,
    pub safety_state: String,
}

// Emit per-stage
app.emit("pipeline:signal", &signal)?;
```

---

## LOCAL AI: THREE-LAYER STACK

### Triage Router (CRITICAL — Decides Which Hardware)

```rust
pub enum Provider {
    FoundryLocal,  // NPU (~50ms, 1.5W)
    Ollama,        // GPU (~500ms, RTX 4060)
    Cloud(String), // Claude/GPT (~3-8s)
}

impl TriageRouter {
    pub fn route(&self, task: &PipelineTask) -> Provider {
        match task.complexity() {
            Complexity::Low => {
                // Triage, classification, query parsing, summarization
                if self.foundry_available { Provider::FoundryLocal }
                else { Provider::Cloud(self.default_cloud.clone()) }
            }
            Complexity::Medium => {
                // Entity extraction, moderate generation
                if self.ollama_available { Provider::Ollama }
                else { Provider::Cloud(self.default_cloud.clone()) }
            }
            Complexity::High => {
                // Deep analysis, truth assessment, frontier reasoning
                Provider::Cloud(self.default_cloud.clone())
            }
        }
    }
}
```

### Foundry Local Client (NPU/GPU Auto-Routed)

```rust
pub struct FoundryClient {
    endpoint: String,  // http://localhost:{PORT}/v1
    model: String,     // "phi-3.5-mini"
    client: reqwest::Client,
}

impl LlmClient for FoundryClient {
    async fn stream(&self, messages: Vec<ChatMessage>, config: &LlmConfig)
        -> Result<impl Stream<Item = Result<String>>>
    {
        // Same OpenAI-compatible format as ollama.rs
        let resp = self.client.post(format!("{}/chat/completions", self.endpoint))
            .json(&json!({
                "model": self.model,
                "messages": messages,
                "stream": true,
            }))
            .send().await?;
        // Parse SSE stream
    }
}
```

---

## TAURI IPC: BATCH OPERATIONS (CRITICAL)

### NEVER Do Per-Item invoke() Calls

```typescript
// BAD: 10K invoke calls (100ms+ IPC overhead)
for (const node of nodes) {
    await invoke('add_node', { node });
}

// GOOD: 1 invoke call (5ms total)
await invoke('add_nodes_batch', { nodes });
```

### Rust Side: Batch Commands

```rust
#[tauri::command]
fn add_nodes_batch(
    state: State<'_, AppState>,
    nodes: Vec<NodeData>,
) -> Result<(), String> {
    let mut engine = state.engine.lock().unwrap();
    for node in &nodes {
        engine.add_node(node);
    }
    engine.commit();
    Ok(())
}
```

---

## VAULT SYNC: BIDIRECTIONAL WITH FILE WATCHER

### Use `notify` Crate (NOT polling)

```rust
use notify::{Watcher, RecursiveMode, Event, EventKind};

pub fn start_vault_watcher(
    vault_path: &Path,
    tx: mpsc::Sender<VaultEvent>,
) -> Result<impl Watcher> {
    let mut watcher = notify::recommended_watcher(move |event: Result<Event, _>| {
        if let Ok(event) = event {
            match event.kind {
                EventKind::Create(_) | EventKind::Modify(_) => {
                    for path in event.paths {
                        if path.extension().map_or(false, |e| e == "md") {
                            tx.send(VaultEvent::Changed(path)).ok();
                        }
                    }
                }
                EventKind::Remove(_) => {
                    for path in event.paths {
                        tx.send(VaultEvent::Deleted(path)).ok();
                    }
                }
                _ => {}
            }
        }
    })?;
    watcher.watch(vault_path, RecursiveMode::Recursive)?;
    Ok(watcher)
}
```

### Debounce File Changes (300ms)

Don't process every keystroke save — debounce:

```rust
let mut pending: HashMap<PathBuf, Instant> = HashMap::new();
loop {
    if let Ok(event) = rx.try_recv() {
        pending.insert(event.path, Instant::now());
    }
    // Process events older than 300ms
    let now = Instant::now();
    pending.retain(|path, time| {
        if now.duration_since(*time) > Duration::from_millis(300) {
            process_file_change(path);
            false  // remove from pending
        } else {
            true   // keep waiting
        }
    });
    thread::sleep(Duration::from_millis(50));
}
```

---

## THREADING MODEL

### Thread Architecture

```
Main Thread (Tauri)
  ├── Webview event loop
  ├── IPC handler (invoke commands)
  └── Tauri event emission

Bevy Thread (dedicated)
  ├── ECS systems (Update schedule)
  ├── Rapier3D physics stepping
  ├── Rendering (wgpu)
  └── Input handling (graph area)

Tokio Runtime (async tasks)
  ├── LLM streaming (Passes 1-3)
  ├── HTTP clients (Anthropic, OpenAI, etc.)
  ├── Foundry Local / Ollama calls
  └── Background enrichment

Vault Watcher Thread (dedicated)
  ├── notify file system events
  ├── Debounced change processing
  └── FTS5 index updates

Embedding Thread (spawn_blocking)
  ├── ONNX Runtime inference
  ├── Batch embedding computation
  └── KNN search
```

### Shared State Pattern

```rust
pub struct AppState {
    pub db: Arc<Mutex<Database>>,
    pub search: Arc<FullTextIndex>,
    pub embeddings: Arc<EmbeddingService>,
    pub engine: Arc<Mutex<GraphEngine>>,
    pub pipeline_config: Arc<RwLock<PipelineConfig>>,
}
```

- Use `parking_lot::Mutex` (not std — no poisoning, faster)
- Use `RwLock` for config (many readers, rare writers)
- Use `Arc` for thread-safe sharing

---

## CRATE DEPENDENCIES (Definitive List)

```toml
[dependencies]
# App shell
tauri = { version = "2", features = ["unstable"] }

# Rendering + Physics
bevy = "0.18"
bevy_rapier3d = { version = "0.33", features = ["simd-stable", "parallel"] }

# Storage
rusqlite = { version = "0.31", features = ["bundled", "fts5"] }

# Search
fst = "0.4"
rustc-hash = "1.1"

# AI/ML
ort = "1.20"                    # ONNX Runtime (NPU/GPU embeddings)
foundry-local = "0.1"          # Microsoft Foundry Local model management
reqwest = { version = "0.12", features = ["json", "stream"] }

# Async
tokio = { version = "1", features = ["full"] }
futures = "0.3"

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# Utilities
uuid = { version = "1", features = ["v4"] }
chrono = { version = "0.4", features = ["serde"] }
notify = "6"                    # File system watcher
parking_lot = "0.12"           # Fast mutex (no poisoning)
regex = "1"                     # Block ref parsing
bytemuck = { version = "1", features = ["derive"] }  # GPU buffer casting
```

---

## PERFORMANCE TARGETS

| Metric | Target | macOS Baseline |
|--------|--------|---------------|
| 10K node render | 16ms (60fps) | 16ms (Metal) |
| 10K node physics | < 2ms/tick | 1.2ms (Rust d3-force) |
| Graph load (10K nodes) | < 10ms | 5ms (batch FFI) |
| FST search | < 1ms | < 1ms (identical Rust) |
| FTS5 search | < 5ms | < 5ms (same engine) |
| Embedding (512-dim) | < 1ms | 20µs (NEON SIMD) |
| KNN (10K vectors, k=8) | < 10ms | 5ms (NEON) |
| First token (stream) | < 200ms | 100-200ms |
| Cold start | < 2s | < 1s |
| Memory (idle) | < 300MB | ~150MB |
| GPU VRAM (graph) | < 200MB | ~100MB (Metal) |

---

## ANTI-PATTERNS (What Claude Gets Wrong)

### 1. "Let's use D3.js for the graph"
NO. D3 is a DOM manipulation library. It creates SVG/Canvas elements. For 10K nodes, that's 10K DOM nodes = layout thrashing, GC pauses, 15fps. Use Bevy + wgpu with instanced rendering = 1 draw call = 60fps.

### 2. "Let's add a REST API between frontend and backend"
NO. Tauri invoke() is direct IPC. No HTTP overhead. No serialization to JSON over TCP. The frontend calls Rust functions directly.

### 3. "Let's use a JavaScript physics library"
NO. Physics runs in Rust (Rapier3D) on a dedicated thread. JavaScript cannot match Rust physics performance. Not even close.

### 4. "Let's poll for updates"
NO. Use Tauri events (listen/emit). Push-based, not pull-based. No wasted cycles.

### 5. "Let's rebuild the search index on every change"
NO. Incremental FTS5 upsert/delete. Content-sync triggers. Diff-sync on startup. Never full rebuild unless explicitly requested.

### 6. "Let's use setTimeout for debouncing"
This is a web frontend pattern and is acceptable ONLY in the webview layer (CodeMirror editor debounce). For Rust backend debouncing, use `Instant::now()` + `Duration` comparisons.

### 7. "Let's use a simple list for graph nodes"
NO. Bevy ECS with components. Cache-coherent SoA memory layout. Parallel system execution. The ECS IS the performance architecture.

### 8. "Let's render text with HTML overlays"
NO for graph labels. Use Bevy's cosmic-text + FontAtlas for GPU-instanced text. HTML overlays break at 1K+ labels. Exception: the editor (CodeMirror) IS HTML — that's correct.

### 9. "Let's use JavaScript for embeddings"
NO. ONNX Runtime via `ort` crate with DirectML. NPU acceleration. Sub-millisecond. transformers.js is 100x slower.

### 10. "Let's handle one node at a time in IPC"
NO. ALWAYS batch. `add_nodes_batch(10K)` = 1 IPC call. Not 10K calls.

---

## CHECKLIST: Before Each PR

- [ ] No D3.js used for graph rendering (Bevy/wgpu only)
- [ ] No per-item IPC calls (all batch)
- [ ] Physics runs in Bevy ECS thread (not JavaScript)
- [ ] Search uses FST + FTS5 (not naive string matching)
- [ ] Embeddings use ort crate (not JavaScript)
- [ ] Streaming uses Tauri events (not SSE/polling)
- [ ] Shaders have quality tiers (performance/balanced/cinematic)
- [ ] LOD implemented for nodes > 5K
- [ ] Idle frame skipping implemented
- [ ] Static layout threshold at 1500 nodes
- [ ] Editor uses CodeMirror 6 (not textarea/contentEditable)
- [ ] Block refs use Decoration API (not regex replace in DOM)
- [ ] File watcher uses notify crate (not polling)
- [ ] Debouncing implemented (300ms for file changes, 150ms for search)
