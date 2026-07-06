// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// PLACEMENT AMENDMENT — the v1 presence HUB lives in SWIFT (CompanionState.swift, @Observable,
// clock-guarded), NOT in agent_core. Producers: (a) the 1Code Node backend via the /host ws
// (ExperimentalHostBridge.swift:50-73 — persistent, reconnecting, backend→Swift JSON frames; add
// ONE case "presence:state" to handle(kind:payload:) at :84); (b) native events (KEELSTONE
// reconcile states per its F3 seam). This file stays as the CRDT rules + wire schema (one entry,
// monotonic clock, apply iff strictly greater, coalesce ~33ms, 30s stale / 15s re-broadcast —
// Yjs awareness constants). UniFFI PresenceSink is deferred with the Rust placement.
// ════════════════════════════════════════════════════════════════════════════════════════════════
//! presence.rs — EPI-RP-05-KINDRED · F3 presence + F6 state bus (BINDING).
//!
//! ONE source of truth for a companion's live state, fanned out to four surfaces with NO
//! double truth. The model is Yjs's awareness protocol: one entry per companion, a
//! monotonic clock, last-writer-wins (apply iff incoming clock strictly greater), and
//! coalesced fan-out (one sample per ~33ms tick, Figma-style) so we never storm the bus.

use serde::{Deserialize, Serialize};
use super::run_state::RunState;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum Surface {
    LandingRoster,
    MainChat,
    EpdocBubble,
    EpdocMinichat,
}

/// Where the companion is "working" — drives the jump-to-where-it-works behavior and the
/// roster's "currently editing <note>" line.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Location {
    pub surface: Surface,
    pub note_id: Option<String>,
    pub range: Option<(u32, u32)>,   // the active edit range (feeds the embodied sprite)
}

/// "What I did for you" — the attachment substrate. Reads back from the provenance ledger.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Obligation {
    pub turn_id: String,
    pub summary: String,
    pub note_id: Option<String>,
    pub at_ms: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CompanionPresence {
    pub companion_id: String,
    pub activity: RunState,
    pub emote: String,                    // maps to a Rive state-machine input name
    pub location: Location,
    pub obligation_history: Vec<Obligation>,
    pub clock: u64,                       // monotonic; apply iff incoming > local
}

/// Implemented by each surface's sink: the native @Observable consumer (Swift) and the
/// WebView bridge (presence-bridge.ts). The fan-out coalesces before calling this.
pub trait PresenceSink: Send + Sync {
    fn on_presence(&self, presence: CompanionPresence);
}

/// The bus. `publish` applies the clock guard once, then coalesces, then fans out.
pub struct PresenceBus {
    sinks: Vec<Box<dyn PresenceSink>>,
    last_clock: u64,
}

impl PresenceBus {
    pub fn new() -> Self {
        Self { sinks: Vec::new(), last_clock: 0 }
    }

    pub fn register(&mut self, sink: Box<dyn PresenceSink>) {
        self.sinks.push(sink);
    }

    /// Idempotent + clock-guarded (Yjs rule). A dropped message self-heals on the next tick.
    pub fn publish(&mut self, presence: CompanionPresence) {
        if presence.clock <= self.last_clock {
            return; // stale or duplicate
        }
        self.last_clock = presence.clock;
        // TODO: coalesce to a ~33ms tick before fan-out (Figma pattern) to avoid storms.
        for sink in &self.sinks {
            sink.on_presence(presence.clone());
        }
    }
}

impl Default for PresenceBus {
    fn default() -> Self { Self::new() }
}
