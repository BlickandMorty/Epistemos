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
void graph_engine_add_edge(
    Engine* engine,
    const char* source_uuid,
    const char* target_uuid,
    float weight
);

/// Commit the graph: loads data into simulation, starts physics.
/// Call after clear + add_node/add_edge sequence.
/// @param entrance 1 for Obsidian-style entrance animation (nodes start clustered at center).
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

/// Set light mode (darker node colors for light backgrounds).
void graph_engine_set_light_mode(Engine* engine, uint8_t enabled);

/// Set graph mode: 0 = global, 1 = page.
void graph_engine_set_mode(Engine* engine, uint8_t mode);

/// Set the note window rect in screen pixels for page mode anchor positioning.
void graph_engine_set_anchor_rect(Engine* engine, float x, float y, float w, float h);

// ── Queries ─────────────────────────────────────────────────────────────────

/// Check if the simulation has settled.
uint8_t graph_engine_is_settled(Engine* engine);

/// Get the UUID of the currently hovered node.
const char* graph_engine_hovered_node_uuid(Engine* engine);

/// Get the UUID of the currently selected node.
const char* graph_engine_selected_node_uuid(Engine* engine);

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
