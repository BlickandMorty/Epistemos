//! Plan §7.1 — idle monitor for NightBrain trigger.
//!
//! Tracks user-input timestamps so NightBrain can decide when to admit
//! work: "idle > 60s AND on AC OR battery > 50% AND thermal nominal."
//!
//! Swift wires the actual hooks (NSEvent global monitor for keystrokes,
//! IOPSCopyPowerSourcesInfo for battery state, ProcessInfo.thermalState
//! for thermal). This module owns the Rust-side state machine: the
//! caller (typically bridge.rs) updates it via `mark_user_input()` on
//! every UI event; tasks query `is_idle_for(threshold)` to gate work.

use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::Arc;
use std::time::Duration;

use chrono::{DateTime, Utc};

/// Tracks the most recent user-input timestamp. Cheap (atomic i64) so
/// every UI event can update it without contention.
pub struct IdleMonitor {
    last_input_unix_secs: AtomicI64,
}

impl IdleMonitor {
    pub fn new() -> Arc<Self> {
        Arc::new(Self {
            last_input_unix_secs: AtomicI64::new(Utc::now().timestamp()),
        })
    }

    /// Plan §7.1: "any user input (keystroke, hotkey, capture) within
    /// idle_monitor triggers cancel_all on NightBrain." Call this from
    /// every UI event handler in Swift.
    pub fn mark_user_input(&self) {
        self.last_input_unix_secs
            .store(Utc::now().timestamp(), Ordering::Relaxed);
    }

    /// Last input timestamp.
    pub fn last_input(&self) -> DateTime<Utc> {
        DateTime::from_timestamp(self.last_input_unix_secs.load(Ordering::Relaxed), 0)
            .unwrap_or_else(Utc::now)
    }

    /// Seconds elapsed since the last user input.
    pub fn idle_secs(&self) -> u64 {
        let now = Utc::now().timestamp();
        let last = self.last_input_unix_secs.load(Ordering::Relaxed);
        (now - last).max(0) as u64
    }

    /// `true` when idle ≥ `threshold`. Plan §7.1 default threshold is
    /// 60s for NightBrain admit.
    pub fn is_idle_for(&self, threshold: Duration) -> bool {
        self.idle_secs() >= threshold.as_secs()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread::sleep;

    #[test]
    fn fresh_monitor_is_not_idle_for_more_than_a_second() {
        let m = IdleMonitor::new();
        // Immediately after construction, last_input is "now".
        assert!(m.idle_secs() < 2);
        assert!(!m.is_idle_for(Duration::from_secs(60)));
    }

    #[test]
    fn mark_user_input_resets_idle_clock() {
        let m = IdleMonitor::new();
        // Force the timestamp into the past.
        m.last_input_unix_secs
            .store(Utc::now().timestamp() - 120, Ordering::Relaxed);
        assert!(m.idle_secs() >= 120);
        assert!(m.is_idle_for(Duration::from_secs(60)));
        m.mark_user_input();
        assert!(m.idle_secs() < 2);
        assert!(!m.is_idle_for(Duration::from_secs(60)));
    }

    #[test]
    fn idle_secs_advances_with_real_time() {
        let m = IdleMonitor::new();
        let initial = m.idle_secs();
        sleep(Duration::from_millis(1100));
        assert!(m.idle_secs() > initial);
    }
}
