//! Deterministic event-log replay for Simulation Mode v1.6.

use crate::agent::AgentEvent;

#[derive(Clone, Debug, PartialEq)]
pub struct ReplayEvent {
    pub tick: u64,
    pub seed: u64,
    pub event: AgentEvent,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct ReplayLog {
    pub events: Vec<ReplayEvent>,
}

impl ReplayLog {
    pub fn push(&mut self, event: ReplayEvent) {
        self.events.push(event);
        self.events.sort_by_key(|e| (e.tick, e.seed));
    }

    /// Deterministic digest used as a pixel-identical playback proxy in portable tests.
    #[must_use]
    pub fn digest(&self) -> u64 {
        let mut h = 0xcbf2_9ce4_8422_2325_u64;
        for event in &self.events {
            h ^= event.tick;
            h = h.wrapping_mul(0x1000_0000_01b3);
            h ^= event.seed;
            h = h.wrapping_mul(0x1000_0000_01b3);
        }
        h
    }
}

#[cfg(test)]
mod tests {
    use super::{ReplayEvent, ReplayLog};
    use crate::agent::AgentEvent;

    #[test]
    fn insertion_order_does_not_change_digest() {
        let a = ReplayEvent { tick: 2, seed: 7, event: AgentEvent::SummaryCompleted { task_id: 1 } };
        let b = ReplayEvent { tick: 1, seed: 7, event: AgentEvent::SummaryStarted { task_id: 1 } };
        let mut left = ReplayLog::default();
        left.push(a.clone()); left.push(b.clone());
        let mut right = ReplayLog::default();
        right.push(b); right.push(a);
        assert_eq!(left.digest(), right.digest());
    }
}
