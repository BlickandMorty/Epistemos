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
/// @param delta_x Horizontal scroll delta (screen points).
/// @param delta_y Vertical scroll delta (screen points).
void graph_engine_scroll(Engine* engine, float delta_x, float delta_y);

/// Pinch-to-zoom toward cursor position.
/// @param magnification Scale delta from NSEvent (e.g. +0.02 = 2% zoom in).
void graph_engine_magnify(Engine* engine, float screen_x, float screen_y, float magnification);

// ── Force Parameters ────────────────────────────────────────────────────────

/// Update the 4 user-adjustable force parameters and reheat.
/// LogSeq defaults: link_distance=180, charge_strength=-600,
///                  charge_range=600, link_strength=0 (auto).
void graph_engine_set_force_params(
    Engine* engine,
    float link_distance,
    float charge_strength,
    float charge_range,
    float link_strength
);

/// Update extended physics parameters.
void graph_engine_set_extended_force_params(
    Engine* engine,
    float velocity_decay,
    float center_strength,
    float collision_radius,
    float warmth,
    float orbital
);

// ── Highlighting ────────────────────────────────────────────────────────────

/// Highlight a node and its neighbors (shift+click behavior).
void graph_engine_highlight_neighbors(Engine* engine, const char* uuid);

/// Clear neighbor highlighting.
void graph_engine_clear_highlight(Engine* engine);

/// Highlight nodes matching a search query (case-insensitive label match).
/// Empty query clears highlighting.
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
/// Call when hologram overlay is hidden.
void graph_engine_pause(Engine* engine);

/// Resume the engine: restart physics thread.
/// Call when hologram overlay is shown again.
void graph_engine_resume(Engine* engine);

// ── Cluster Parameters ──────────────────────────────────────────────────────

/// Set cluster cohesion strength (0 = off, 1 = strong bubbles).
void graph_engine_set_cluster_params(Engine* engine, float cluster_strength);

/// Set center force mode: 0 = attract, 1 = off, 2 = repel.
void graph_engine_set_center_mode(Engine* engine, uint8_t mode);

// ── Cursor Attractor ────────────────────────────────────────────────────────

/// Set the attractor target in world coordinates.
void graph_engine_set_attract_target(Engine* engine, float x, float y);

/// Set the attractor target from screen coordinates (auto-converts to world).
void graph_engine_set_attract_target_screen(Engine* engine, float screen_x, float screen_y);

/// Convert screen pixel coordinates to world coordinates.
/// @param screen_x  Screen x in pixels.
/// @param screen_y  Screen y in pixels.
/// @param out_world_x  On return, receives the world-space x coordinate (may be NULL).
/// @param out_world_y  On return, receives the world-space y coordinate (may be NULL).
void graph_engine_screen_to_world(Engine *engine, float screen_x, float screen_y, float *out_world_x, float *out_world_y);

/// Mark nodes (by UUID) as attracted to the current target.
/// @param uuids  Array of null-terminated UTF-8 strings.
/// @param count  Number of UUIDs in the array.
void graph_engine_set_attracted_nodes(Engine* engine, const char** uuids, uint32_t count);

/// Clear the attractor (target + attracted nodes).
void graph_engine_clear_attract(Engine* engine);

/// Set the attractor strength (0-1).
void graph_engine_set_attract_strength(Engine* engine, float strength);

// ── Display Settings ────────────────────────────────────────────────────────

/// Set the clear color (use transparent for hologram overlay).
void graph_engine_set_clear_color(Engine* engine, double r, double g, double b, double a);

/// Set light mode (darker node colors for light backgrounds).
void graph_engine_set_light_mode(Engine* engine, uint8_t enabled);

/// Set graph mode: 0 = global, 1 = page.
void graph_engine_set_mode(Engine* engine, uint8_t mode);

/// Set the note window rect in screen pixels for page mode anchor positioning.
/// Nodes will cluster near this rect instead of dead center.
void graph_engine_set_anchor_rect(Engine* engine, float x, float y, float w, float h);

// ── Queries ─────────────────────────────────────────────────────────────────

/// Check if the simulation has settled.
/// @return 1 if settled, 0 if still running.
uint8_t graph_engine_is_settled(Engine* engine);

/// Get the UUID of the currently hovered node.
/// @return Null-terminated string, or NULL if no node hovered.
///         Valid until the next UUID query call.
const char* graph_engine_hovered_node_uuid(Engine* engine);

/// Get the UUID of the currently selected node.
/// @return Null-terminated string, or NULL if no node selected.
///         Valid until the next UUID query call.
const char* graph_engine_selected_node_uuid(Engine* engine);

// ── Markdown Parser ────────────────────────────────────────────────────

/// Style span returned by the markdown parser.
/// Byte offsets are into the UTF-8 source text.
typedef struct {
    uint32_t start;    ///< Byte offset (inclusive).
    uint32_t end;      ///< Byte offset (exclusive).
    uint8_t  style;    ///< StyleKind enum value.
    uint8_t  depth;    ///< Nesting depth.
    uint8_t  group;    ///< Semantic group (e.g. 0=syntax, 1=text, 2=url for links).
    uint8_t  _pad;
} StyleSpan;

/// Parse markdown text and return an array of styled spans.
/// @param text       Null-terminated UTF-8 string.
/// @param text_len   Length in bytes (excluding null terminator). Currently unused.
/// @param out_spans  On success, receives a pointer to the spans array (caller must free).
/// @param out_count  On success, receives the number of spans.
/// @return 0 on success, 1 on error (null input or invalid UTF-8).
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
