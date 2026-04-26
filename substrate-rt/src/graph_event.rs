//! `GraphEvent` — fixed-size POD payload that crosses the SPSC ring.
//!
//! Per Wave 5 plan dpp §5.2: 64-byte payload, `#[repr(C)]`, no padding
//! tricks, no `Drop` (so `rtrb`'s `write_chunk_uninit` is sound).
//!
//! The discriminant `kind` lets a single ring carry every hot-path event
//! family — cursor moves, edit deltas, layout updates, MCP token chunks,
//! agent frame ticks. Each variant gets a slot in the `data` payload that
//! it interprets per its `kind`. New variants append a new `kind` value
//! and may use any of the existing `data` bytes (the slot is opaque to
//! the ring itself).

use std::mem::size_of;

/// Stable u8 discriminant for `GraphEvent.kind`. Numeric values are
/// CONTRACTS — they cross the FFI boundary and may end up in mmap'd
/// raw-thoughts logs (Wave 5.6). Reserved 0 = uninitialised / sentinel.
#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum GraphEventKind {
    /// Sentinel for default-constructed events. Drainers should ignore.
    Sentinel = 0,
    /// Cursor moved in the editor. Payload: NoteId u64 + line u32 + col u32.
    CursorMove = 1,
    /// Text edit delta. Payload: NoteId u64 + byte_offset u32 + len u32 + flags u32.
    EditDelta = 2,
    /// Graph layout updated for one node. Payload: NodeId u64 + x f32 + y f32 + z f32.
    LayoutUpdate = 3,
    /// MCP token chunk arrived. Payload: SessionId u64 + bytes_offset u32 + bytes_len u32.
    McpTokenChunk = 4,
    /// Agent loop frame tick. Payload: SessionId u64 + step u32 + flags u32.
    AgentFrameTick = 5,
}

/// Fixed-size POD event payload. Total size is asserted at compile time
/// to be exactly 64 bytes (the canonical Wave 5 contract — one cache
/// line on x86, half a line on Apple Silicon's 128-byte L2 line which
/// is fine, the producer/consumer atomics are CachePadded separately).
///
/// `#[repr(C)]` lets the Swift caller declare a matching struct directly.
/// `Copy` (no `Drop`) makes `rtrb`'s `write_chunk_uninit` sound —
/// uninitialised slots hold byte-zero `GraphEvent` values that no
/// destructor will ever run on.
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct GraphEvent {
    /// Discriminant — see `GraphEventKind`. Uses raw `u8` instead of the
    /// enum so a future producer can write a kind the consumer hasn't
    /// learned yet without UB; the consumer ignores unknown kinds.
    pub kind: u8,
    /// Reserved padding to align the payload at offset 8. Must be zero
    /// today; future revisions may use this for flags.
    pub _reserved: [u8; 7],
    /// 56-byte opaque payload. Each `kind` interprets these bytes per
    /// its own schema (documented above on each `GraphEventKind`).
    pub data: [u8; 56],
}

impl GraphEvent {
    /// All-zero sentinel. Producers should not push this; consumers
    /// MAY observe it in unused tail slots if they read past the
    /// reported drain count (which they should NOT do).
    pub const SENTINEL: GraphEvent = GraphEvent {
        kind: GraphEventKind::Sentinel as u8,
        _reserved: [0; 7],
        data: [0; 56],
    };

    /// Construct an event with the given kind and an opaque 56-byte payload.
    pub fn new(kind: GraphEventKind, data: [u8; 56]) -> Self {
        Self {
            kind: kind as u8,
            _reserved: [0; 7],
            data,
        }
    }

    /// Decode the discriminant byte back into a typed kind. Returns
    /// `None` for any value the current binary doesn't recognise — the
    /// consumer must tolerate forward-compat events.
    pub fn typed_kind(&self) -> Option<GraphEventKind> {
        match self.kind {
            0 => Some(GraphEventKind::Sentinel),
            1 => Some(GraphEventKind::CursorMove),
            2 => Some(GraphEventKind::EditDelta),
            3 => Some(GraphEventKind::LayoutUpdate),
            4 => Some(GraphEventKind::McpTokenChunk),
            5 => Some(GraphEventKind::AgentFrameTick),
            _ => None,
        }
    }
}

impl Default for GraphEvent {
    fn default() -> Self {
        Self::SENTINEL
    }
}

// Compile-time guard for the 64-byte contract.
const _: () = assert!(size_of::<GraphEvent>() == 64);

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn graph_event_is_64_bytes() {
        assert_eq!(size_of::<GraphEvent>(), 64);
    }

    #[test]
    fn sentinel_kind_round_trips() {
        let ev = GraphEvent::SENTINEL;
        assert_eq!(ev.typed_kind(), Some(GraphEventKind::Sentinel));
    }

    #[test]
    fn typed_kind_handles_every_variant() {
        for variant in [
            GraphEventKind::Sentinel,
            GraphEventKind::CursorMove,
            GraphEventKind::EditDelta,
            GraphEventKind::LayoutUpdate,
            GraphEventKind::McpTokenChunk,
            GraphEventKind::AgentFrameTick,
        ] {
            let ev = GraphEvent::new(variant, [0; 56]);
            assert_eq!(ev.typed_kind(), Some(variant));
        }
    }

    #[test]
    fn typed_kind_returns_none_for_unknown_discriminant() {
        let ev = GraphEvent {
            kind: 99,
            _reserved: [0; 7],
            data: [0; 56],
        };
        assert_eq!(ev.typed_kind(), None);
    }

    #[test]
    fn data_payload_round_trips_56_bytes() {
        let mut payload = [0u8; 56];
        for (i, slot) in payload.iter_mut().enumerate() {
            *slot = i as u8;
        }
        let ev = GraphEvent::new(GraphEventKind::EditDelta, payload);
        assert_eq!(ev.data, payload);
    }
}
