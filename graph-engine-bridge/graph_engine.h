#ifndef GRAPH_ENGINE_H
#define GRAPH_ENGINE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque engine handle.
typedef struct Engine Engine;

// ── Lifecycle ───────────────────────────────────────────────────────────────

/// Create a new graph engine.
/// @param device_ptr  MTLDevice pointer (id<MTLDevice>)
/// @param layer_ptr   CAMetalLayer pointer (CAMetalLayer*)
/// @return Engine pointer, or NULL on failure.
Engine* graph_engine_create(void* device_ptr, void* layer_ptr);

/// Destroy the engine and free all resources.
void graph_engine_destroy(Engine* engine);

// ── Graph Data Loading ──────────────────────────────────────────────────────

/// Clear all nodes and edges. Call before re-populating.
void graph_engine_clear(Engine* engine);

/// Add a node to the graph.
/// @param uuid       Null-terminated UTF-8 string.
/// @param x, y       Initial position.
/// @param node_type  0=Note, 1=Chat, 2=Idea, 3=Source, 4=Folder, 5=Quote, 6=Tag.
/// @param link_count Number of edges (used for radius sizing).
/// @param label      Null-terminated UTF-8 string.
void graph_engine_add_node(
    Engine* engine,
    const char* uuid,
    float x, float y,
    uint8_t node_type,
    uint32_t link_count,
    const char* label
);

/// Add an edge between two nodes by UUID.
/// @param edge_type 0-11 matching GraphEdgeType (0=reference, 4=cites, 9=contradicts, etc.).
void graph_engine_add_edge(
    Engine* engine,
    const char* source_uuid,
    const char* target_uuid,
    float weight,
    uint8_t edge_type
);

/// Batch-add nodes to the graph in a single FFI call.
/// All arrays must have length `count`.
void graph_engine_add_nodes_batch(
    Engine* engine,
    const char** uuids,
    const float* xs,
    const float* ys,
    const uint8_t* node_types,
    const uint32_t* link_counts,
    const char** labels,
    uint32_t count
);

/// Batch-add edges to the graph in a single FFI call.
void graph_engine_add_edges_batch(
    Engine* engine,
    const char** source_uuids,
    const char** target_uuids,
    const float* weights,
    const uint8_t* edge_types,
    uint32_t count
);

/// Commit the graph: loads data into simulation, starts physics.
/// Call after clear + add_node/add_edge sequence.
/// @param entrance 1 to use spiral initial layout for node positions.
void graph_engine_commit(Engine* engine, uint8_t entrance);

// ── Rendering ───────────────────────────────────────────────────────────────

/// Render one frame.
/// @return 1 if another frame is needed, 0 if GPU can idle.
uint32_t graph_engine_render(Engine* engine, uint32_t width, uint32_t height);

// ── Input Events ────────────────────────────────────────────────────────────

/// Mouse/trackpad button pressed.
/// @param shift 1 if shift key held (neighbor highlighting), 0 otherwise.
void graph_engine_mouse_down(Engine* engine, float screen_x, float screen_y, uint8_t shift);

/// Mouse/trackpad moved.
void graph_engine_mouse_moved(Engine* engine, float screen_x, float screen_y);

/// Mouse/trackpad button released.
void graph_engine_mouse_up(Engine* engine);

/// Two-finger scroll: pan the camera.
void graph_engine_scroll(Engine* engine, float delta_x, float delta_y);

/// Pinch-to-zoom toward cursor position.
void graph_engine_magnify(Engine* engine, float screen_x, float screen_y, float magnification);

// ── Force Parameters ────────────────────────────────────────────────────────

/// Update the 4 user-adjustable force parameters and reheat.
void graph_engine_set_force_params(
    Engine* engine,
    float link_distance,
    float charge_strength,
    float charge_range,
    float link_strength
);

/// Update extended physics parameters (velocity decay, center gravity, collision).
void graph_engine_set_extended_force_params(
    Engine* engine,
    float velocity_decay,
    float center_strength,
    float collision_radius
);

// ── Highlighting ────────────────────────────────────────────────────────────

/// Highlight a node and its neighbors (shift+click behavior).
void graph_engine_highlight_neighbors(Engine* engine, const char* uuid);

/// Clear neighbor highlighting.
void graph_engine_clear_highlight(Engine* engine);

/// Highlight nodes matching a search query (case-insensitive label match).
void graph_engine_search_highlight(Engine* engine, const char* query);

/// Poll haptic event flag: 0=None, 1=Light snap, 2=Heavy collision.
uint8_t graph_engine_poll_haptic(Engine* engine);

/// Enable/disable bullet-time search physics (slow-motion drift during search).
void graph_engine_set_search_active(Engine* engine, uint8_t active);

/// Update laboratory physics toggles and tuning knobs.
void graph_engine_set_lab_params(
    Engine* engine,
    uint8_t enable_fluid,
    uint8_t enable_torsion,
    uint8_t enable_elastic,
    uint8_t enable_tension,
    float fluid_viscosity,
    float edge_elasticity,
    float torsion_rigidity,
    float boids_cohesion,
    float wind_x,
    float wind_y,
    uint8_t enable_orbital,
    float orbital_speed
);

// ── Camera ──────────────────────────────────────────────────────────────────

/// Animate camera to center on visible nodes.
void graph_engine_center_camera(Engine* engine);

/// Center camera on a specific node by UUID (zooms in moderately).
void graph_engine_center_on_node(Engine* engine, const char* uuid);

/// Zoom to fit all visible nodes.
void graph_engine_zoom_to_fit(Engine* engine);

// ── Lifecycle ───────────────────────────────────────────────────────────────

/// Pause the engine: stop physics thread to free CPU.
void graph_engine_pause(Engine* engine);

/// Resume the engine: restart physics thread.
void graph_engine_resume(Engine* engine);

/// User-controlled physics freeze: 1 = freeze (stop all forces), 0 = unfreeze (reheat).
void graph_engine_set_user_frozen(Engine* engine, uint8_t frozen);

// ── Cluster Parameters ──────────────────────────────────────────────────────

/// Set cluster cohesion strength (0 = off, 1 = strong bubbles).
void graph_engine_set_cluster_params(Engine* engine, float cluster_strength);

/// Set center force mode: 0 = attract, 1 = off, 2 = repel.
void graph_engine_set_center_mode(Engine* engine, uint8_t mode);

// ── Coordinate Conversion ───────────────────────────────────────────────────

/// Convert screen pixel coordinates to world coordinates.
void graph_engine_screen_to_world(Engine *engine, float screen_x, float screen_y, float *out_world_x, float *out_world_y);

// ── Visibility (Lightweight Filtering) ──────────────────────────────────────

/// Toggle a node's visibility by UUID.
/// Call graph_engine_refresh_visibility once after all toggles.
void graph_engine_set_node_visible(Engine* engine, const char* uuid, uint8_t visible);

/// Apply visibility changes: re-upload renderer + reload simulation.
void graph_engine_refresh_visibility(Engine* engine);

// ── Display Settings ────────────────────────────────────────────────────────

/// Set the clear color (use transparent for hologram overlay).
void graph_engine_set_clear_color(Engine* engine, double r, double g, double b, double a);

/// Set graph mode: 0 = global, 1 = page.
void graph_engine_set_mode(Engine* engine, uint8_t mode);

/// Set lite rendering mode: 0 = full (3D, effects), 1 = lite (2D flat, no glow).
void graph_engine_set_lite_mode(Engine* engine, uint8_t enabled);

/// Set light/dark mode color palette: 0 = dark, 1 = light.
void graph_engine_set_light_mode(Engine* engine, uint8_t enabled);

/// Set quality level: 0 = Cinematic, 1 = Balanced, 2 = Performance.
void graph_engine_set_quality_level(Engine* engine, uint8_t level);

/// Set the note window rect in screen pixels for page mode anchor positioning.
void graph_engine_set_anchor_rect(Engine* engine, float x, float y, float w, float h);

// ── Queries ─────────────────────────────────────────────────────────────────

/// Check if the simulation has settled.
uint8_t graph_engine_is_settled(Engine* engine);

/// Check if physics is disabled (static layout for graphs > 1500 nodes).
/// Returns 1 if static (physics off), 0 if physics is active.
uint8_t graph_engine_is_static_layout(Engine* engine);

/// Get the UUID of the currently hovered node.
const char* graph_engine_hovered_node_uuid(Engine* engine);

/// Get the UUID of the currently selected node.
const char* graph_engine_selected_node_uuid(Engine* engine);

// ── Search ──────────────────────────────────────────────────────────────────

/// Search result from graph_engine_search.
typedef struct {
    const char* uuid;
    const char* label;
    uint8_t node_type;
    float score;
} GraphSearchResult;

/// Search node labels with fuzzy matching. Returns array of results.
/// Caller must free with graph_engine_free_search_results.
GraphSearchResult* graph_engine_search(
    Engine* engine,
    const char* query,
    uint32_t limit,
    uint32_t* out_count
);

/// Free search results.
void graph_engine_free_search_results(GraphSearchResult* results, uint32_t count);

// ── Semantic Clustering ─────────────────────────────────────────────────────

/// Set semantic cluster IDs. Overrides Louvain-detected clusters.
/// @param uuids       Array of null-terminated UUID strings.
/// @param cluster_ids Parallel array of cluster IDs.
/// @param count       Number of entries in both arrays.
void graph_engine_set_cluster_ids(
    Engine* engine,
    const char** uuids,
    const uint32_t* cluster_ids,
    uint32_t count
);

// ── Embeddings ──────────────────────────────────────────────────────────────

/// Set the embedding vector for a node.
/// @param uuid  Node UUID.
/// @param data  Pointer to `dim` contiguous f32 values.
/// @param dim   Embedding dimension (must match store, typically 512).
void graph_engine_set_node_embedding(
    Engine* engine,
    const char* uuid,
    const float* data,
    uint32_t dim
);

/// Set semantic attraction strength (0 = off, 1 = strong).
void graph_engine_set_semantic_strength(Engine* engine, float strength);

/// Recompute semantic neighbor pairs from current embeddings.
/// Call after batch-setting embeddings. Results drive semantic attraction force.
/// @param k         Number of neighbors per node (typically 8).
/// @param threshold Minimum cosine similarity (typically 0.3).
void graph_engine_recompute_semantic_neighbors(
    Engine* engine,
    uint32_t k,
    float threshold
);

// ── Temporal Index ──────────────────────────────────────────────────────────

/// Set timestamps for a node (Unix epoch seconds). 0.0 = not set.
void graph_engine_set_node_time(
    Engine* engine,
    const char* uuid,
    double created_at,
    double updated_at
);

/// Apply time filter: nodes with created_at outside [min_ts, max_ts] become invisible.
/// Nodes with created_at == 0.0 remain always visible.
/// Pass (0.0, 1e18) to clear the filter.
void graph_engine_set_time_filter(Engine* engine, double min_ts, double max_ts);

// ── Confidence ─────────────────────────────────────────────────────────────

/// Set a node's confidence score (0.0–1.0).
void graph_engine_set_node_confidence(
    Engine* engine,
    const char* uuid,
    float confidence
);

// ── Version Chain ──────────────────────────────────────────────────────────

/// Add a version to a node's hash-linked version chain.
/// Returns 1 on success, 0 if orphan/duplicate rejected.
uint8_t graph_engine_add_version(
    Engine* engine,
    const char* node_uuid,
    uint64_t hash,
    uint64_t parent_hash,
    double timestamp
);

/// Get the number of versions in a node's chain.
uint32_t graph_engine_get_version_count(
    Engine* engine,
    const char* node_uuid
);

/// Semantic search: find nodes most similar to a query embedding.
/// Returns same SearchResult type as text search. Free with graph_engine_free_search_results.
GraphSearchResult* graph_engine_semantic_search(
    Engine* engine,
    const float* query_data,
    uint32_t dim,
    uint32_t limit,
    uint32_t* out_count
);

// ── Markdown Parser ────────────────────────────────────────────────────

/// Style span returned by the markdown parser.
typedef struct {
    uint32_t start;    ///< Byte offset (inclusive).
    uint32_t end;      ///< Byte offset (exclusive).
    uint8_t  style;    ///< StyleKind enum value.
    uint8_t  depth;    ///< Nesting depth.
    uint8_t  group;    ///< Semantic group (e.g. 0=syntax, 1=text, 2=url for links).
    uint8_t  _pad;
} StyleSpan;

/// Parse markdown text and return an array of styled spans.
uint8_t markdown_parse(
    const char* text,
    uint32_t text_len,
    StyleSpan** out_spans,
    uint32_t* out_count
);

/// Free a spans array previously returned by markdown_parse.
void markdown_free_spans(StyleSpan* spans, uint32_t count);

#ifdef __cplusplus
}
#endif

#endif /* GRAPH_ENGINE_H */
