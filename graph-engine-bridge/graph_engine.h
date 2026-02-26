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

void graph_engine_render(GraphEngine* engine);

// ── Data loading ──────────────────────────────────────────────────────────

void graph_engine_clear(GraphEngine* engine);
void graph_engine_add_nodes(GraphEngine* engine, const CNode* nodes, size_t count);
void graph_engine_add_edges(GraphEngine* engine, const CEdge* edges, size_t count);
void graph_engine_commit(GraphEngine* engine);
uint32_t graph_engine_node_count(GraphEngine* engine);
uint32_t graph_engine_edge_count(GraphEngine* engine);

// ── Input handling ────────────────────────────────────────────────────────

void graph_engine_pan(GraphEngine* engine, float dx, float dy);
void graph_engine_zoom(GraphEngine* engine, float factor, float cx, float cy);

#endif /* graph_engine_h */
