#ifndef GRAPH_ENGINE_BOLT_H
#define GRAPH_ENGINE_BOLT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque engine handle (same as graph_engine.h).
typedef struct Engine Engine;

// ── Typed Buffer Structs ────────────────────────────────────────────────────

/// Contiguous node record for batch loading via the Bolt path.
/// String fields use borrowed (ptr, len) pairs — the caller must keep the
/// backing memory alive for the duration of the bolt_graph_load_nodes call.
typedef struct {
    const uint8_t* id_ptr;      ///< UTF-8 string pointer (borrowed).
    uint32_t       id_len;      ///< Byte length of the UUID string.
    const uint8_t* label_ptr;   ///< UTF-8 string pointer (borrowed).
    uint32_t       label_len;   ///< Byte length of the label string.
    uint8_t        node_type;   ///< 0=Note … 13=Resource.
    float          x;           ///< Initial X position.
    float          y;           ///< Initial Y position.
    float          size;        ///< Size hint (link count for radius).
    uint32_t       color_rgba;  ///< Packed RGBA color (reserved).
} BoltNodeRecord;

/// Contiguous edge record using index-based node addressing.
typedef struct {
    uint32_t source_idx;  ///< Index into the node array.
    uint32_t target_idx;  ///< Index into the node array.
    uint8_t  edge_type;   ///< 0=reference … 11=questions.
    float    weight;      ///< Edge weight.
} BoltEdgeRecord;

/// Output position record written by bolt_graph_query_positions.
typedef struct {
    float x;
    float y;
} BoltPositionRecord;

// ── Bolt Graph FFI Functions ────────────────────────────────────────────────

/// Load a contiguous array of BoltNodeRecord structs into the graph.
/// @param engine      Engine pointer.
/// @param buffer_ptr  Pointer to `count` contiguous BoltNodeRecord structs.
/// @param count       Number of records.
void bolt_graph_load_nodes(
    Engine* engine,
    const BoltNodeRecord* buffer_ptr,
    uint32_t count
);

/// Load a contiguous array of BoltEdgeRecord structs into the graph.
/// source_idx/target_idx refer to indices in the node_uuids array.
/// @param engine          Engine pointer.
/// @param buffer_ptr      Pointer to `count` contiguous BoltEdgeRecord structs.
/// @param count           Number of edge records.
/// @param node_uuids      Parallel array of null-terminated UUID strings
///                        (same order as the nodes loaded by bolt_graph_load_nodes).
/// @param node_uuid_count Number of entries in node_uuids.
void bolt_graph_load_edges(
    Engine* engine,
    const BoltEdgeRecord* buffer_ptr,
    uint32_t count,
    const char* const* node_uuids,
    uint32_t node_uuid_count
);

/// Fill a pre-allocated buffer with current node positions.
/// @param engine    Engine pointer.
/// @param out_ptr   Pre-allocated buffer for output positions.
/// @param max_count Capacity of the output buffer.
/// @return Number of positions actually written (≤ max_count).
uint32_t bolt_graph_query_positions(
    Engine* engine,
    BoltPositionRecord* out_ptr,
    uint32_t max_count
);

// ── Shared Position Buffers (feature: shared-position-buffers) ───────────────

/// Register a shared MTLBuffer pointer for triple-buffered zero-copy rendering.
/// @param engine          Engine pointer.
/// @param index           Buffer index (0, 1, or 2).
/// @param ptr             MTLBuffer.contents() pointer — must be .storageModeShared.
/// @param capacity_floats Number of floats the buffer can hold (node_count * 2).
void graph_engine_set_shared_position_buffer(
    Engine* engine,
    uint32_t index,
    float* ptr,
    uint32_t capacity_floats
);

/// Unregister a shared position buffer.
void graph_engine_unset_shared_position_buffer(Engine* engine, uint32_t index);

/// Write current node positions into the specified shared buffer.
/// Positions are interleaved as [x, y, x, y, ...].
/// @return Number of nodes written. 0 on error or empty graph.
uint32_t graph_engine_write_positions_to_shared(
    Engine* engine,
    uint32_t buffer_index
);

#ifdef __cplusplus
}
#endif

#endif /* GRAPH_ENGINE_BOLT_H */
