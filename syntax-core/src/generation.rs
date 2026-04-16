use std::sync::atomic::{AtomicU64, Ordering};

/// Monotonically increasing generation counter with atomic cancellation support.
///
/// Each `edit()` call increments the generation. Concurrent readers can check
/// `is_stale(expected)` to detect whether the document has changed since they
/// started their work (e.g., viewport highlighting can abort early).
pub struct GenerationCounter {
    value: AtomicU64,
}

impl GenerationCounter {
    pub fn new() -> Self {
        Self {
            value: AtomicU64::new(0),
        }
    }

    pub fn current(&self) -> u64 {
        self.value.load(Ordering::Acquire)
    }

    /// Increments the generation and returns the new value.
    pub fn increment(&self) -> u64 {
        self.value.fetch_add(1, Ordering::AcqRel) + 1
    }

    /// Returns `true` if the current generation does not match `expected`,
    /// meaning the document has been mutated since the caller captured
    /// its generation snapshot.
    pub fn is_stale(&self, expected: u64) -> bool {
        self.current() != expected
    }
}

impl Default for GenerationCounter {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;
    use std::thread;

    #[test]
    fn starts_at_zero() {
        let gen = GenerationCounter::new();
        assert_eq!(gen.current(), 0);
    }

    #[test]
    fn increment_advances() {
        let gen = GenerationCounter::new();
        assert_eq!(gen.increment(), 1);
        assert_eq!(gen.increment(), 2);
        assert_eq!(gen.current(), 2);
    }

    #[test]
    fn is_stale_detects_change() {
        let gen = GenerationCounter::new();
        let snapshot = gen.current();
        assert!(!gen.is_stale(snapshot));

        gen.increment();
        assert!(gen.is_stale(snapshot));
    }

    #[test]
    fn concurrent_increments() {
        let gen = Arc::new(GenerationCounter::new());
        let mut handles = Vec::new();

        for _ in 0..8 {
            let g = Arc::clone(&gen);
            handles.push(thread::spawn(move || {
                for _ in 0..1000 {
                    g.increment();
                }
            }));
        }

        for h in handles {
            h.join().unwrap();
        }

        assert_eq!(gen.current(), 8000);
    }
}
