//! Per-tool circuit breaker (plan §5.3).
//!
//! State machine: `Closed` (count failures) → `Open` after N consecutive
//! failures → `HalfOpen` after cooldown → `Closed` after M consecutive
//! probes succeed, OR back to `Open` on any probe failure.
//!
//! Plan §5.3 wording: "Two consecutive successes → close." So the
//! HalfOpen → Closed transition requires two consecutive successes, not
//! just one. The first probe goes through; second success closes;
//! either failing reopens.

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BreakerState {
    Closed,
    Open,
    HalfOpen,
}

#[derive(Debug, thiserror::Error)]
pub enum BreakerError {
    #[error("circuit breaker open for tool")]
    Open,
}

/// Per-tool circuit breaker. Cheap to construct; cheap to clone (Arc).
#[derive(Clone)]
pub struct CircuitBreaker {
    inner: Arc<Mutex<Inner>>,
    failure_threshold: u32,
    cooldown: Duration,
    successes_to_close: u32,
}

#[derive(Debug)]
struct Inner {
    state: BreakerState,
    consecutive_failures: u32,
    consecutive_successes: u32,
    opened_at: Option<Instant>,
}

impl CircuitBreaker {
    /// Plan-aligned defaults: 5 failures opens the breaker, 30s cooldown
    /// before a probe is allowed, 2 consecutive successes close.
    pub fn new(failure_threshold: u32, cooldown: Duration) -> Self {
        Self::with_close_threshold(failure_threshold, cooldown, 2)
    }

    pub fn with_close_threshold(
        failure_threshold: u32,
        cooldown: Duration,
        successes_to_close: u32,
    ) -> Self {
        Self {
            inner: Arc::new(Mutex::new(Inner {
                state: BreakerState::Closed,
                consecutive_failures: 0,
                consecutive_successes: 0,
                opened_at: None,
            })),
            failure_threshold,
            cooldown,
            successes_to_close,
        }
    }

    /// Pre-flight check before a tool call. Returns `Err(BreakerError::Open)`
    /// when the breaker is Open and still cooling down. When the cooldown
    /// has elapsed, transitions Open → HalfOpen and returns `Ok(())` so a
    /// single probe can run.
    pub fn before_call(&self) -> Result<(), BreakerError> {
        let mut g = self.inner.lock().expect("breaker mutex poisoned");
        match g.state {
            BreakerState::Closed | BreakerState::HalfOpen => Ok(()),
            BreakerState::Open => {
                let opened_at = g.opened_at.expect("Open state must have opened_at");
                if Instant::now().duration_since(opened_at) >= self.cooldown {
                    g.state = BreakerState::HalfOpen;
                    g.consecutive_successes = 0;
                    Ok(())
                } else {
                    Err(BreakerError::Open)
                }
            }
        }
    }

    pub fn record_success(&self) {
        let mut g = self.inner.lock().expect("breaker mutex poisoned");
        match g.state {
            BreakerState::Closed => {
                g.consecutive_failures = 0;
            }
            BreakerState::HalfOpen => {
                g.consecutive_successes += 1;
                if g.consecutive_successes >= self.successes_to_close {
                    g.state = BreakerState::Closed;
                    g.consecutive_failures = 0;
                    g.consecutive_successes = 0;
                    g.opened_at = None;
                }
            }
            BreakerState::Open => {
                // Shouldn't happen — caller is expected to call before_call
                // first. Treat as a no-op rather than panic.
            }
        }
    }

    pub fn record_failure(&self) {
        let mut g = self.inner.lock().expect("breaker mutex poisoned");
        match g.state {
            BreakerState::Closed => {
                g.consecutive_failures += 1;
                if g.consecutive_failures >= self.failure_threshold {
                    g.state = BreakerState::Open;
                    g.opened_at = Some(Instant::now());
                    g.consecutive_successes = 0;
                }
            }
            BreakerState::HalfOpen => {
                g.state = BreakerState::Open;
                g.opened_at = Some(Instant::now());
                g.consecutive_successes = 0;
            }
            BreakerState::Open => {
                // Already open; refresh the timer so a flapping service
                // doesn't get spurious probes.
                g.opened_at = Some(Instant::now());
            }
        }
    }

    pub fn state(&self) -> BreakerState {
        self.inner.lock().expect("breaker mutex poisoned").state
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn closed_breaker_admits_calls() {
        let b = CircuitBreaker::new(3, Duration::from_secs(10));
        assert_eq!(b.state(), BreakerState::Closed);
        b.before_call().unwrap();
    }

    #[test]
    fn opens_after_threshold_failures() {
        let b = CircuitBreaker::new(3, Duration::from_secs(10));
        b.record_failure();
        b.record_failure();
        assert_eq!(b.state(), BreakerState::Closed); // not yet
        b.record_failure();
        assert_eq!(b.state(), BreakerState::Open);
        assert!(b.before_call().is_err());
    }

    #[test]
    fn open_breaker_transitions_to_half_open_after_cooldown() {
        let b = CircuitBreaker::new(1, Duration::from_millis(20));
        b.record_failure();
        assert_eq!(b.state(), BreakerState::Open);
        // Within cooldown → still Open.
        assert!(b.before_call().is_err());
        std::thread::sleep(Duration::from_millis(30));
        // After cooldown → HalfOpen + admits one probe.
        b.before_call().unwrap();
        assert_eq!(b.state(), BreakerState::HalfOpen);
    }

    #[test]
    fn half_open_two_successes_close() {
        let b = CircuitBreaker::with_close_threshold(1, Duration::from_millis(10), 2);
        b.record_failure();
        std::thread::sleep(Duration::from_millis(15));
        b.before_call().unwrap();
        assert_eq!(b.state(), BreakerState::HalfOpen);
        b.record_success();
        assert_eq!(b.state(), BreakerState::HalfOpen, "needs 2 successes");
        b.record_success();
        assert_eq!(b.state(), BreakerState::Closed);
    }

    #[test]
    fn half_open_failure_reopens() {
        let b = CircuitBreaker::new(1, Duration::from_millis(10));
        b.record_failure();
        std::thread::sleep(Duration::from_millis(15));
        b.before_call().unwrap();
        assert_eq!(b.state(), BreakerState::HalfOpen);
        b.record_failure();
        assert_eq!(b.state(), BreakerState::Open);
    }

    #[test]
    fn closed_resets_failure_count_on_success() {
        let b = CircuitBreaker::new(3, Duration::from_secs(10));
        b.record_failure();
        b.record_failure();
        b.record_success();
        b.record_failure();
        b.record_failure();
        // Only 2 consecutive failures — not yet Open.
        assert_eq!(b.state(), BreakerState::Closed);
    }
}
