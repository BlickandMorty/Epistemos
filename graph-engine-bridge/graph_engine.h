#ifndef GRAPH_ENGINE_H
#define GRAPH_ENGINE_H

#include <stdint.h>
#include <stdbool.h>

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

/// Remove a node by UUID (also removes all touching edges).
/// Returns 1 if removed, 0 if not found.
uint8_t graph_engine_remove_node(Engine* engine, const char* uuid);

/// Remove edges between two nodes by UUID (both directions).
/// Returns number of edges removed.
uint32_t graph_engine_remove_edge(
    Engine* engine,
    const char* source_uuid,
    const char* target_uuid
);

/// Batch-remove nodes by UUID array.
/// Returns count of nodes successfully removed.
uint32_t graph_engine_remove_nodes_batch(
    Engine* engine,
    const char** uuids,
    uint32_t count
);

/// Lightweight commit after incremental adds/removes.
/// Preserves node positions (no BFS layout). Use after add/remove operations.
void graph_engine_commit_incremental(Engine* engine);

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

/// Get a node's screen pixel position by UUID.
/// Writes 2 floats (x, y) into `out`. Returns 1 if found, 0 if not.
uint8_t graph_engine_node_screen_pos(Engine *engine, const char *uuid, float *out);

/// Get cumulative drift (total distance traveled) for a node by UUID.
/// Returns drift value, or -1.0 if node not found.
float graph_engine_node_drift(Engine *engine, const char *uuid);

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

/// Set visual theme: 0 = Dialogue (default), 1 = Classic.
void graph_engine_set_visual_theme(Engine* engine, uint8_t theme);

/// Set per-node color override by UUID. Pass alpha=0 to clear.
void graph_engine_set_node_color_override(Engine* engine, const char* uuid, float r, float g, float b, float a);

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

/// Clear all stored semantic embeddings and neighbor pairs.
void graph_engine_clear_embeddings(Engine* engine);

/// Return the number of stored semantic embeddings.
uint32_t graph_engine_embedding_count(Engine* engine);

/// Return the active semantic embedding dimension.
uint32_t graph_engine_embedding_dimension(Engine* engine);

/// Reset the semantic embedding dimension and clear stored vectors/neighbors.
/// Returns 1 when the dimension changed, 0 when the request was invalid or unchanged.
uint8_t graph_engine_reset_embedding_dimension(Engine* engine, uint32_t dim);

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

/// Batch-set timestamps and confidence in one FFI crossing.
/// All arrays must have length `count`.
void graph_engine_set_node_metadata_batch(
    Engine* engine,
    const char** uuids,
    const double* created_ats,
    const double* updated_ats,
    const float* confidences,
    uint32_t count
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

/// Load a built prepared retrieval index manifest into the engine.
/// Returns 1 on success, 0 on failure.
uint8_t graph_engine_load_prepared_retrieval_index(
    Engine* engine,
    const char* manifest_path
);

/// Clear the loaded prepared retrieval index runtime.
void graph_engine_clear_prepared_retrieval_index(Engine* engine);

/// Return the loaded prepared retrieval index embedding dimension, or 0 when unavailable.
uint32_t graph_engine_prepared_retrieval_dimension(Engine* engine);

/// Search the loaded prepared retrieval index with a query embedding.
/// Returns page IDs in the `uuid` field of GraphSearchResult. Free with graph_engine_free_search_results.
GraphSearchResult* graph_engine_prepared_retrieval_search(
    Engine* engine,
    const float* query_data,
    uint32_t dim,
    uint32_t limit,
    uint32_t* out_count
);

/// Score a fixed set of page IDs against the loaded prepared retrieval index.
/// Returns page IDs in the `uuid` field of GraphSearchResult. Free with graph_engine_free_search_results.
GraphSearchResult* graph_engine_prepared_retrieval_score_page_ids(
    Engine* engine,
    const float* query_data,
    uint32_t dim,
    const char* const* page_ids,
    uint32_t page_id_count,
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

/// Structure span for paragraph-level classification.
/// One span per line — array index is the line number.
/// para_type: 0=body, 1=heading, 2=orderedList, 3=unorderedList,
///            4=taskList, 5=blockQuote, 6=codeBlock, 7=table,
///            8=horizontalRule, 9=htmlComment.
/// metadata:  heading level (1-6), list depth (high byte), etc.
typedef struct {
    uint8_t  para_type;
    uint8_t  _pad;
    uint16_t metadata;
} StructureSpan;

/// Parse markdown structure: one StructureSpan per line, written to caller's buffer.
/// @param text       Null-terminated UTF-8 markdown text.
/// @param out_spans  Pre-allocated buffer for output spans.
/// @param max_spans  Capacity of the output buffer.
/// @return Number of lines (spans written). 0 on null/invalid input.
uint32_t markdown_parse_structure(
    const char* text,
    StructureSpan* out_spans,
    uint32_t max_spans
);

/// Code token — 12 bytes. One per syntax-highlighted span in a code block.
typedef struct {
    uint32_t start;
    uint32_t end;
    uint8_t  token_type;
    uint8_t  _pad[3];
} CodeToken;

/// Tokenize a code block for syntax highlighting.
/// @param code        UTF-8 code string (not null-terminated required — length given).
/// @param code_len    Length of code in bytes.
/// @param language    Null-terminated language identifier (e.g. "swift", "rust").
/// @param out_tokens  Pre-allocated buffer for output tokens.
/// @param max_tokens  Capacity of the output buffer.
/// @return Number of tokens written. 0 on null/invalid input.
uint32_t markdown_parse_code_tokens(
    const char* code,
    uint32_t code_len,
    const char* language,
    CodeToken* out_tokens,
    uint32_t max_tokens
);

// ── Non-Destructive Fold State ───────────────────────────────────────────────

/// Set fold state for a heading line. folded=true to fold, false to unfold.
void markdown_set_fold(uint32_t line_index, bool folded);

/// Query whether a heading line is folded.
bool markdown_is_folded(uint32_t line_index);

/// Clear all fold state.
void markdown_clear_all_folds(void);

/// Get the line range that would be hidden when folding a heading.
/// @param text         Null-terminated UTF-8 markdown text.
/// @param heading_line Line index of the heading.
/// @param out_start    Output: first hidden line (inclusive).
/// @param out_end      Output: last hidden line (exclusive).
/// @return true if heading_line is a heading, false otherwise.
bool markdown_fold_range(
    const char* text,
    uint32_t heading_line,
    uint32_t* out_start,
    uint32_t* out_end
);

// ── Block Transaction Kernel (BTK) ───────────────────────────────────────────

/// Block FFI struct for loading existing blocks from SwiftData
typedef struct {
    uint8_t  id[16];
    uint8_t  parent_id[16];
    const char* content_ptr;
    uint16_t depth;
    uint32_t order;
} BlockFFI;

/// Owned byte buffer returned by BTK subscription/snapshot FFI.
/// Ownership: Rust allocates, Swift must release with graph_engine_free_bytes.
typedef struct {
    uint8_t* ptr;
    uint64_t len;
    uint64_t capacity;
} GraphEngineByteBuffer;

/// Borrowed UTF-8 slice into an archived BTK subscription buffer.
/// Lifetime: valid only while the owning GraphEngineByteBuffer remains alive.
typedef struct {
    const uint8_t* ptr;
    uint32_t len;
} GraphEngineStringSlice;

/// One row inside an archived BTK subscription payload.
typedef struct {
    GraphEngineStringSlice page_id;
    GraphEngineStringSlice block_id;
    GraphEngineStringSlice parent_id;
    GraphEngineStringSlice target_id;
    GraphEngineStringSlice content;
    GraphEngineStringSlice property_key;
    GraphEngineStringSlice property_value;
    GraphEngineStringSlice task_marker;
    GraphEngineStringSlice order_key;
    uint16_t depth;
    uint8_t ref_type;
    uint8_t task_done;
    uint8_t hop_count;
} BtkSubscriptionRowFFI;

typedef struct {
    uint64_t version;
    uint8_t kind;
    uint8_t _pad[3];
    uint32_t added_count;
    uint32_t updated_count;
    uint32_t removed_count;
} BtkSubscriptionPayloadSummaryFFI;

/// Initialize BTK for a page. Call once when a page is opened.
uint8_t graph_engine_btk_init(Engine* engine, const char* page_id);

/// Load existing blocks from Swift (migration from SDBlock).
/// blocks_ptr is a pointer to an array of BlockFFI structs.
uint8_t graph_engine_btk_load_blocks(
    Engine* engine,
    const char* page_id,
    const BlockFFI* blocks_ptr,
    uint32_t count
);

/// Translate a text edit into block ops and apply them.
/// Returns the number of ops applied.
uint32_t graph_engine_btk_translate_edit(
    Engine* engine,
    const char* page_id,
    uint32_t edit_offset,
    uint32_t old_length,
    const char* new_text
);

/// Get the current markdown projection for a page.
/// Returns a C string that must be freed with graph_engine_free_string.
const char* graph_engine_btk_get_markdown(Engine* engine, const char* page_id);

/// Directly update a block's content by block_id.
/// block_id_bytes: pointer to 16 bytes (UUID). Returns 1 on success, 0 on failure.
uint8_t graph_engine_btk_update_block(
    Engine* engine,
    const char* page_id,
    const uint8_t* block_id_bytes,
    const char* new_content
);

/// Free a string returned by graph_engine_btk_get_markdown.
void graph_engine_free_string(char* s);

/// Query BTK trees for blocks matching a property filter.
/// Returns a length-prefixed byte buffer of page_ids.
/// op: 0=eq, 1=neq, 2=lt, 3=gt, 4=lte, 5=gte, 6=contains
/// val_type: 0=string, 1=float, 2=int, 3=bool
GraphEngineByteBuffer graph_engine_btk_query_property(
    Engine* engine,
    const char* key,
    uint8_t op,
    uint8_t val_type,
    const char* val_str
);

/// Query BTK trees for blocks matching a depth filter.
/// Returns a length-prefixed byte buffer of page_ids.
/// op: 0=eq, 1=neq, 2=lt, 3=gt, 4=lte, 5=gte
GraphEngineByteBuffer graph_engine_btk_query_depth(
    Engine* engine,
    uint8_t op,
    uint32_t depth
);

/// Free a byte buffer returned by graph_engine_btk_take_subscription_update or
/// graph_engine_btk_snapshot_subscription.
void graph_engine_free_bytes(GraphEngineByteBuffer buffer);

/// Register an outline subscription for a page.
/// Returns 0 on failure, otherwise a stable subscription id.
uint64_t graph_engine_btk_subscribe_outline(Engine* engine, const char* page_id);

/// Register a property subscription.
/// Pass NULL for `value` to match any value for the key.
uint64_t graph_engine_btk_subscribe_property(
    Engine* engine,
    const char* key,
    const char* value
);

/// Register a link traversal subscription rooted at `block_id`.
uint64_t graph_engine_btk_subscribe_links(
    Engine* engine,
    const char* block_id,
    uint8_t max_depth
);

/// Remove a BTK subscription. Returns 1 if removed, 0 if not found.
uint8_t graph_engine_btk_unsubscribe(Engine* engine, uint64_t subscription_id);

/// Take the latest archived subscription diff and clear the pending state.
/// Ownership: caller must release the returned buffer with graph_engine_free_bytes.
GraphEngineByteBuffer graph_engine_btk_take_subscription_update(
    Engine* engine,
    uint64_t subscription_id
);

/// Query a historical snapshot for a subscription at a BTK transaction version.
/// Ownership: caller must release the returned buffer with graph_engine_free_bytes.
GraphEngineByteBuffer graph_engine_btk_snapshot_subscription(
    Engine* engine,
    uint64_t subscription_id,
    uint64_t version
);

/// Latest BTK fact-runtime transaction version.
uint64_t graph_engine_btk_latest_subscription_seq(Engine* engine);

/// Inspect archived subscription payload metadata.
uint64_t graph_engine_btk_payload_version(const uint8_t* data, uint64_t len);
uint8_t graph_engine_btk_payload_kind(const uint8_t* data, uint64_t len);
uint8_t graph_engine_btk_payload_summary(
    const uint8_t* data,
    uint64_t len,
    BtkSubscriptionPayloadSummaryFFI* out
);

/// Row count for payload sections: 0=added, 1=updated, 2=removed.
uint32_t graph_engine_btk_payload_row_count(
    const uint8_t* data,
    uint64_t len,
    uint8_t section
);

/// Read one payload row into `out`.
/// Returns 1 on success, 0 on invalid section/index/buffer.
uint8_t graph_engine_btk_payload_row(
    const uint8_t* data,
    uint64_t len,
    uint8_t section,
    uint32_t index,
    BtkSubscriptionRowFFI* out
);

/// Read a contiguous batch of payload rows into `out`.
uint32_t graph_engine_btk_payload_rows(
    const uint8_t* data,
    uint64_t len,
    uint8_t section,
    uint32_t start_index,
    BtkSubscriptionRowFFI* out,
    uint32_t max_rows
);

// ── Knowledge Core (Shared-Memory Reactive FFI) ────────────────────────────

typedef struct KnowledgeCore KnowledgeCore;

typedef struct {
    uint8_t* ptr;
    uint64_t len;
} GraphEngineSharedMemoryRegion;

typedef struct {
    uint64_t head_offset;
    uint64_t tail_offset;
    uint64_t slots_offset;
    uint64_t slot_stride;
    uint64_t slot_payload_offset;
    uint32_t slot_count;
    uint32_t slot_payload_bytes;
} GraphEngineRingLayout;

typedef struct {
    uint8_t row_kind;
    uint8_t _pad[3];
    GraphEngineStringSlice page_id;
    GraphEngineStringSlice block_id;
    GraphEngineStringSlice parent_id;
    GraphEngineStringSlice target_id;
    GraphEngineStringSlice content;
    GraphEngineStringSlice property_key;
    GraphEngineStringSlice property_value;
    GraphEngineStringSlice task_marker;
    GraphEngineStringSlice order_key;
    uint16_t depth;
    uint8_t ref_type;
    uint8_t task_done;
} KnowledgeQueryRowFFI;

typedef struct {
    uint64_t tx_id;
    uint64_t subscription_id;
    uint8_t kind;
    uint8_t _pad[3];
    uint32_t added_count;
    uint32_t updated_count;
    uint32_t removed_count;
} KnowledgePayloadSummaryFFI;

typedef struct {
    uint64_t published_frames;
    uint64_t dropped_frames;
    uint64_t coalesced_frames;
    uint64_t ring_full_failures;
} KnowledgeCoreTransportStatsFFI;

/// Create a shared-memory knowledge core.
KnowledgeCore* graph_engine_kc_create(
    uint32_t slot_count,
    uint32_t slot_payload_bytes,
    uint64_t peer_id
);

/// Destroy a knowledge core and release the mapped ring buffer.
void graph_engine_kc_destroy(KnowledgeCore* core);

/// Return the mapped shared-memory region backing the SPSC ring.
GraphEngineSharedMemoryRegion graph_engine_kc_ring_region(KnowledgeCore* core);

/// Return offsets and capacities for reading ring slots from Swift.
GraphEngineRingLayout graph_engine_kc_ring_layout(KnowledgeCore* core);

/// Atomic ring index helpers.
uint64_t graph_engine_kc_ring_head(KnowledgeCore* core);
uint64_t graph_engine_kc_ring_tail(KnowledgeCore* core);
void graph_engine_kc_ring_set_tail(KnowledgeCore* core, uint64_t tail);

/// Register subscriptions. Initial snapshots are emitted into the ring.
uint64_t graph_engine_kc_subscribe_outline(KnowledgeCore* core, const char* page_id);
uint64_t graph_engine_kc_subscribe_tasks(KnowledgeCore* core, const char* page_id);
uint64_t graph_engine_kc_subscribe_properties(
    KnowledgeCore* core,
    const char* page_id,
    const char* key
);
uint8_t graph_engine_kc_unsubscribe(KnowledgeCore* core, uint64_t subscription_id);

/// Ingest or mutate document state. format: 0 = Markdown, 1 = Org.
uint8_t graph_engine_kc_ingest_document(
    KnowledgeCore* core,
    const char* page_id,
    uint8_t format,
    const char* text
);
uint8_t graph_engine_kc_insert_block(
    KnowledgeCore* core,
    const char* page_id,
    const char* block_id,
    const char* parent_id,
    uint32_t index,
    const char* content
);
uint8_t graph_engine_kc_move_block(
    KnowledgeCore* core,
    const char* page_id,
    const char* block_id,
    const char* new_parent_id,
    uint32_t index
);
uint8_t graph_engine_kc_delete_block(
    KnowledgeCore* core,
    const char* page_id,
    const char* block_id
);

/// Last staged knowledge-core error code for this core:
/// 0 = none
/// 1 = invalid argument
/// 2 = ring full
/// 3 = payload too large
/// 4 = generic ring error
/// 5 = missing block
/// 6 = missing outline node
/// 7 = generic store error
/// 8 = generic outline error
/// 9 = serialization error
uint8_t graph_engine_kc_last_error_code(KnowledgeCore* core);

/// Borrowed UTF-8 message for the last staged knowledge-core error.
/// The slice remains valid until the next knowledge-core call on `core`.
GraphEngineStringSlice graph_engine_kc_last_error_message(KnowledgeCore* core);

/// Current staged backpressure mode.
/// 0 = fail-fast
uint8_t graph_engine_kc_backpressure_policy(KnowledgeCore* core);

/// Read transport counters for the staged shared-memory bridge.
KnowledgeCoreTransportStatsFFI graph_engine_kc_transport_stats(KnowledgeCore* core);

/// Map ring frame kind values back to query domains:
/// 0 = outline, 1 = tasks, 2 = properties, 3 = links, 255 = invalid.
uint8_t graph_engine_kc_subscription_kind(uint16_t kind);

/// Inspect archived knowledge-core payload metadata.
uint64_t graph_engine_kc_payload_tx_id(const uint8_t* data, uint64_t len);
uint64_t graph_engine_kc_payload_subscription_id(const uint8_t* data, uint64_t len);
uint16_t graph_engine_kc_payload_kind(const uint8_t* data, uint64_t len);
uint8_t graph_engine_kc_payload_summary(
    const uint8_t* data,
    uint64_t len,
    KnowledgePayloadSummaryFFI* out
);
uint32_t graph_engine_kc_payload_row_count(
    const uint8_t* data,
    uint64_t len,
    uint8_t section
);
uint8_t graph_engine_kc_payload_row(
    const uint8_t* data,
    uint64_t len,
    uint8_t section,
    uint32_t index,
    KnowledgeQueryRowFFI* out
);
uint32_t graph_engine_kc_payload_rows(
    const uint8_t* data,
    uint64_t len,
    uint8_t section,
    uint32_t start_index,
    KnowledgeQueryRowFFI* out,
    uint32_t max_rows
);

// ── Dialogue ────────────────────────────────────────────────────────────────

/// Open dialogue on a node (activates face geometry + dialogue box).
void graph_engine_dialogue_open(Engine* engine, const char* node_uuid);

/// Close dialogue (deactivates face + box).
void graph_engine_dialogue_close(Engine* engine);

/// Set streaming state (animates mouth when true).
void graph_engine_dialogue_set_streaming(Engine* engine, uint8_t streaming);

/// Get dialogue box screen rect (x, y, w, h). Writes 4 floats into `out`.
void graph_engine_dialogue_screen_rect(Engine* engine, float* out);

/// Get dialogue node screen position (x, y). Writes 2 floats into `out`.
void graph_engine_dialogue_node_screen_pos(Engine* engine, float* out);

/// Check if dialogue is currently active. Returns 1 if active, 0 if not.
uint8_t graph_engine_dialogue_is_active(Engine* engine);

#ifdef __cplusplus
}
#endif

#endif /* GRAPH_ENGINE_H */
