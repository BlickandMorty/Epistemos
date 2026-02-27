#ifndef graph_engine_h
#define graph_engine_h

#include <stdint.h>
#include <stddef.h>

// Opaque engine handle
typedef void GraphEngine;

// ── C structs for batch data loading ──────────────────────────────────────

typedef struct {
    const char* uuid;
    float x;
    float y;
    uint8_t node_type;
    float weight;
    const char* label;
} CNode;

typedef struct {
    const char* source_uuid;
    const char* target_uuid;
    uint8_t edge_type;
    float weight;
} CEdge;

// ── Lifecycle ─────────────────────────────────────────────────────────────

GraphEngine* graph_engine_create(void* metal_device, void* metal_layer);
void graph_engine_destroy(GraphEngine* engine);
void graph_engine_resize(GraphEngine* engine, uint32_t width, uint32_t height);

// ── Render ────────────────────────────────────────────────────────────────

/// Returns 1 if the view should keep rendering (physics active or camera animating),
/// 0 if the view can go idle (settled).
uint8_t graph_engine_render(GraphEngine* engine);

// ── Data loading ──────────────────────────────────────────────────────────

void graph_engine_clear(GraphEngine* engine);
void graph_engine_add_nodes(GraphEngine* engine, const CNode* nodes, size_t count);
void graph_engine_add_edges(GraphEngine* engine, const CEdge* edges, size_t count);
void graph_engine_commit(GraphEngine* engine);
uint32_t graph_engine_node_count(GraphEngine* engine);
uint32_t graph_engine_edge_count(GraphEngine* engine);

// ── Visibility ───────────────────────────────────────────────────────────

void graph_engine_set_visibility(GraphEngine* engine, const uint8_t* visible, size_t count);

// ── Input handling ────────────────────────────────────────────────────────

void graph_engine_pan(GraphEngine* engine, float dx, float dy);
void graph_engine_zoom(GraphEngine* engine, float factor, float cx, float cy);

// Input — mouse events
// Returns 1 if a node was hit (caller should route drags to mouse_dragged), 0 otherwise.
uint8_t graph_engine_mouse_down(GraphEngine* engine, float x, float y, uint8_t button);
void graph_engine_mouse_dragged(GraphEngine* engine, float x, float y);
void graph_engine_mouse_up(GraphEngine* engine, float x, float y);
void graph_engine_mouse_moved(GraphEngine* engine, float x, float y);

// ── Callback types ───────────────────────────────────────────────────────

typedef void (*GraphNodeCallback)(const char* uuid, void* context);
typedef void (*GraphNodeScreenCallback)(const char* uuid, float screen_x, float screen_y, void* context);
typedef void (*GraphHoverCallback)(const char* uuid_or_null, void* context);

// ── Callback registration ────────────────────────────────────────────────

void graph_engine_set_on_node_selected(GraphEngine* engine, GraphNodeCallback cb, void* ctx);
void graph_engine_set_on_node_right_clicked(GraphEngine* engine, GraphNodeScreenCallback cb, void* ctx);
void graph_engine_set_on_node_hovered(GraphEngine* engine, GraphHoverCallback cb, void* ctx);

// Camera commands
void graph_engine_reset_camera(GraphEngine* engine);
void graph_engine_center_on_node(GraphEngine* engine, const char* uuid);
void graph_engine_fit_all(GraphEngine* engine);

// ── Physics configuration ────────────────────────────────────────────────

typedef struct {
    float center_force;
    float repel_force;
    float link_force;
    float link_distance;
    float velocity_decay;
    float alpha_decay;
} CPhysicsConfig;

void graph_engine_set_physics_config(GraphEngine* engine, const CPhysicsConfig* config);
void graph_engine_get_physics_config(GraphEngine* engine, CPhysicsConfig* out);

#endif /* graph_engine_h */
