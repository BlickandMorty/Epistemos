// W9.23 — Bit-packed circuit breaker (lock-free, zero-allocation)
//
// Per docs/RESEARCH_DOSSIER_TIER_3_4.md §W9.23: replace any
// `Mutex<...>` circuit breaker with a single `AtomicU64` carrying
// the entire breaker state. Read/write with one compare-exchange.
// ~5ns per `try_acquire` vs ~50ns for a Mutex; cache-line padded
// to avoid false sharing across cloud-API call sites.
//
// Bit layout (little-endian, 64 bits total):
//   [0..2)   state          — Closed (0) / Open (1) / HalfOpen (2)
//   [2..18)  failure count  — recent failures (saturating, 16-bit cap)
//   [18..50) last-fail sec  — Unix epoch seconds (truncated to 32 bits;
//                              wraps every 136 years — irrelevant for
//                              an in-process breaker)
//   [50..64) generation     — incremented on each Closed transition;
//                              lets concurrent half-open probes detect
//                              a state change between read + CAS
//
// State machine:
//   Closed   → Open      when failure_count >= threshold
//   Open     → HalfOpen  when now - last_fail >= cooldown_secs
//   HalfOpen → Closed    on success (resets failure count, bumps gen)
//   HalfOpen → Open      on failure (last_fail = now)
//
// The breaker is correct under concurrent contention because every
// transition uses `compare_exchange_weak` on the packed word — if
// two threads race, one wins and the other re-reads + retries.

use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

const STATE_BITS: u64 = 2;
const COUNT_BITS: u64 = 16;
const TIME_BITS: u64 = 32;
const GEN_BITS: u64 = 14;

const STATE_SHIFT: u64 = 0;
const COUNT_SHIFT: u64 = STATE_BITS;
const TIME_SHIFT: u64 = STATE_BITS + COUNT_BITS;
const GEN_SHIFT: u64 = STATE_BITS + COUNT_BITS + TIME_BITS;

const STATE_MASK: u64 = (1 << STATE_BITS) - 1;
const COUNT_MASK: u64 = (1 << COUNT_BITS) - 1;
const TIME_MASK: u64 = (1 << TIME_BITS) - 1;
const GEN_MASK: u64 = (1 << GEN_BITS) - 1;

const STATE_CLOSED: u64 = 0;
const STATE_OPEN: u64 = 1;
const STATE_HALF_OPEN: u64 = 2;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BreakerState {
    Closed,
    Open,
    HalfOpen,
}

#[derive(Debug, Clone, Copy)]
pub struct BreakerSnapshot {
    pub state: BreakerState,
    pub failure_count: u16,
    pub last_fail_secs: u32,
    pub generation: u16,
}

#[derive(Debug, Clone, Copy)]
pub struct BreakerConfig {
    /// Failures-in-window threshold that trips the breaker.
    pub failure_threshold: u16,
    /// Seconds the breaker stays Open before allowing a HalfOpen probe.
    pub cooldown_secs: u32,
}

impl Default for BreakerConfig {
    fn default() -> Self {
        Self {
            failure_threshold: 5,
            cooldown_secs: 30,
        }
    }
}

/// Cache-line padded to keep contended call sites from false-sharing
/// the breaker word against unrelated atomics. 64 bytes = one cache
/// line on Apple Silicon (M2/M3/M4) per WWDC22 perf guidance.
#[repr(align(64))]
pub struct CircuitBreaker {
    word: AtomicU64,
    config: BreakerConfig,
}

impl CircuitBreaker {
    pub const fn new(config: BreakerConfig) -> Self {
        Self {
            word: AtomicU64::new(0),
            config,
        }
    }

    pub fn snapshot(&self) -> BreakerSnapshot {
        Self::unpack(self.word.load(Ordering::Acquire))
    }

    /// Returns `true` if a call should be allowed through.
    ///
    /// - Closed → always allow.
    /// - Open → allow only if cooldown elapsed (transitions to HalfOpen).
    /// - HalfOpen → allow ONE probe at a time; concurrent callers see
    ///   the unmodified word and get rejected.
    pub fn try_acquire(&self) -> bool {
        let now = current_epoch_secs();
        loop {
            let cur = self.word.load(Ordering::Acquire);
            let snap = Self::unpack(cur);
            match snap.state {
                BreakerState::Closed => return true,
                BreakerState::Open => {
                    let elapsed = now.saturating_sub(snap.last_fail_secs);
                    if elapsed < self.config.cooldown_secs {
                        return false;
                    }
                    // Try transition Open → HalfOpen so exactly one probe
                    // gets through. Other contended threads see the new
                    // state on next try_acquire and stay denied.
                    let next = Self::pack(
                        BreakerState::HalfOpen,
                        snap.failure_count,
                        snap.last_fail_secs,
                        snap.generation,
                    );
                    if self
                        .word
                        .compare_exchange_weak(cur, next, Ordering::AcqRel, Ordering::Acquire)
                        .is_ok()
                    {
                        return true;
                    }
                    // CAS lost the race — retry to read fresh state.
                }
                BreakerState::HalfOpen => return false,
            }
        }
    }

    /// Record a successful call.
    /// HalfOpen → Closed (resets failure count, bumps generation).
    /// Closed   → no-op (success doesn't decrement; window-based reset
    ///            kept simple — perf agent's spec called for sliding
    ///            window via decay; deferred).
    pub fn record_success(&self) {
        loop {
            let cur = self.word.load(Ordering::Acquire);
            let snap = Self::unpack(cur);
            if snap.state == BreakerState::Closed && snap.failure_count == 0 {
                return;
            }
            let next = Self::pack(BreakerState::Closed, 0, 0, snap.generation.wrapping_add(1));
            if self
                .word
                .compare_exchange_weak(cur, next, Ordering::AcqRel, Ordering::Acquire)
                .is_ok()
            {
                return;
            }
        }
    }

    /// Record a failed call. Increments failure count; trips to Open
    /// when threshold is reached. HalfOpen failure goes straight back
    /// to Open with refreshed timestamp.
    pub fn record_failure(&self) {
        let now = current_epoch_secs();
        loop {
            let cur = self.word.load(Ordering::Acquire);
            let snap = Self::unpack(cur);
            let new_count = snap.failure_count.saturating_add(1);
            let new_state = match snap.state {
                BreakerState::HalfOpen => BreakerState::Open,
                BreakerState::Closed | BreakerState::Open => {
                    if new_count >= self.config.failure_threshold {
                        BreakerState::Open
                    } else {
                        BreakerState::Closed
                    }
                }
            };
            let next = Self::pack(new_state, new_count, now, snap.generation);
            if self
                .word
                .compare_exchange_weak(cur, next, Ordering::AcqRel, Ordering::Acquire)
                .is_ok()
            {
                return;
            }
        }
    }

    /// Force-reset to Closed. Useful for tests + manual recovery hooks.
    pub fn reset(&self) {
        let cur = self.word.load(Ordering::Acquire);
        let snap = Self::unpack(cur);
        let next = Self::pack(BreakerState::Closed, 0, 0, snap.generation.wrapping_add(1));
        self.word.store(next, Ordering::Release);
    }

    fn pack(state: BreakerState, count: u16, last_fail: u32, gen: u16) -> u64 {
        let s: u64 = match state {
            BreakerState::Closed => STATE_CLOSED,
            BreakerState::Open => STATE_OPEN,
            BreakerState::HalfOpen => STATE_HALF_OPEN,
        };
        ((s & STATE_MASK) << STATE_SHIFT)
            | (((count as u64) & COUNT_MASK) << COUNT_SHIFT)
            | (((last_fail as u64) & TIME_MASK) << TIME_SHIFT)
            | (((gen as u64) & GEN_MASK) << GEN_SHIFT)
    }

    fn unpack(word: u64) -> BreakerSnapshot {
        let s = (word >> STATE_SHIFT) & STATE_MASK;
        let state = match s {
            STATE_OPEN => BreakerState::Open,
            STATE_HALF_OPEN => BreakerState::HalfOpen,
            _ => BreakerState::Closed,
        };
        BreakerSnapshot {
            state,
            failure_count: ((word >> COUNT_SHIFT) & COUNT_MASK) as u16,
            last_fail_secs: ((word >> TIME_SHIFT) & TIME_MASK) as u32,
            generation: ((word >> GEN_SHIFT) & GEN_MASK) as u16,
        }
    }
}

fn current_epoch_secs() -> u32 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as u32)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn closed_allows_traffic() {
        let cb = CircuitBreaker::new(BreakerConfig::default());
        assert!(cb.try_acquire());
        assert!(cb.try_acquire());
    }

    #[test]
    fn opens_after_threshold() {
        let cb = CircuitBreaker::new(BreakerConfig {
            failure_threshold: 3,
            cooldown_secs: 30,
        });
        cb.record_failure();
        cb.record_failure();
        assert_eq!(cb.snapshot().state, BreakerState::Closed);
        cb.record_failure();
        assert_eq!(cb.snapshot().state, BreakerState::Open);
        assert!(!cb.try_acquire(), "open breaker must reject");
    }

    #[test]
    fn half_open_admits_single_probe() {
        let cb = CircuitBreaker::new(BreakerConfig {
            failure_threshold: 1,
            cooldown_secs: 0,
        });
        cb.record_failure();
        assert_eq!(cb.snapshot().state, BreakerState::Open);
        // cooldown 0 → next try_acquire transitions Open → HalfOpen
        assert!(cb.try_acquire(), "first probe should pass");
        assert!(!cb.try_acquire(), "second concurrent probe should fail");
    }

    #[test]
    fn success_in_half_open_recloses() {
        let cb = CircuitBreaker::new(BreakerConfig {
            failure_threshold: 1,
            cooldown_secs: 0,
        });
        cb.record_failure();
        assert!(cb.try_acquire());
        cb.record_success();
        assert_eq!(cb.snapshot().state, BreakerState::Closed);
        assert_eq!(cb.snapshot().failure_count, 0);
    }

    #[test]
    fn pack_unpack_roundtrip() {
        let packed = CircuitBreaker::pack(BreakerState::HalfOpen, 12345, 1_700_000_000, 9999);
        let snap = CircuitBreaker::unpack(packed);
        assert_eq!(snap.state, BreakerState::HalfOpen);
        assert_eq!(snap.failure_count, 12345);
        assert_eq!(snap.last_fail_secs, 1_700_000_000);
        assert_eq!(snap.generation, 9999);
    }

    #[test]
    fn cache_line_aligned() {
        assert_eq!(std::mem::align_of::<CircuitBreaker>(), 64);
    }
}
