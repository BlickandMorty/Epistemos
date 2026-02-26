#ifndef graph_engine_h
#define graph_engine_h

#include <stdint.h>
#include <stddef.h>

// Opaque engine handle
typedef void GraphEngine;

// Lifecycle
GraphEngine* graph_engine_create(void* metal_device, void* metal_layer);
void graph_engine_destroy(GraphEngine* engine);
void graph_engine_resize(GraphEngine* engine, uint32_t width, uint32_t height);

// Render
void graph_engine_render(GraphEngine* engine);

#endif /* graph_engine_h */
