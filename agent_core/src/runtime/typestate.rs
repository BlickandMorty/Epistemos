// W9.22 — Typestate Islands foundation
//
// Per docs/RESEARCH_DOSSIER_TIER_3_4.md §W9.22: phantom-type
// state machine that enforces correct lifecycle order at compile
// time for MLX inference sessions, Hermes Python subprocess, and
// AFM session pool entries.
//
// FOUNDATION (this commit):
//   - the generic `Lifecycle<S>` newtype with `PhantomData<S>` marker
//   - the canonical Loaded → Warm → Generating → Disposed state set
//   - blueprint impls showing the consumed-self transition pattern
//
// FOLLOW-UPS (per the dossier's plan + W9.21 dependency):
//   - Concrete `MlxSession`, `HermesProcess`, `AFMPoolEntry` wrappers
//     that hold the W9.21 honest-FFI Arc handles
//   - Swift `~Copyable` mirrors so the same invariants hold across
//     the FFI boundary (caveat: actor isolation + ~Copyable doesn't
//     compose well in Swift 6.2; spike before the rewrite)
//
// Design notes:
//   - Each state marker is a zero-sized type (ZST) — `PhantomData<S>`
//     adds zero runtime cost
//   - Methods are gated by `impl Lifecycle<SpecificState>` blocks;
//     a method on `Disposed` literally cannot be called because no
//     such impl exists
//   - Transitions consume `self` and return `Lifecycle<Next>` so the
//     compiler's borrow checker enforces the linear progression
//   - Fallible transitions return `Result<Lifecycle<Next>,
//     Lifecycle<Same>>` so the caller decides whether to retry
//     in-place or move to a Disposed state

use std::marker::PhantomData;

// MARK: - State markers (zero-sized types)

pub struct Loaded;
pub struct Warm;
pub struct Generating;
pub struct Disposed;

// MARK: - Generic typestate wrapper

/// Carries an inner value `T` plus a phantom state marker `S`.
/// All transitions consume `self` so the previous state cannot be
/// reused after the move.
pub struct Lifecycle<T, S> {
    inner: T,
    _state: PhantomData<S>,
}

impl<T, S> Lifecycle<T, S> {
    /// Internal constructor — only the impl blocks for specific
    /// states should call this so transitions stay disciplined.
    fn wrap(inner: T) -> Self {
        Self {
            inner,
            _state: PhantomData,
        }
    }

    /// Borrow the inner value (read-only) without consuming the
    /// lifecycle. Available in every state.
    pub fn peek(&self) -> &T {
        &self.inner
    }
}

// MARK: - Loaded

impl<T> Lifecycle<T, Loaded> {
    pub fn new_loaded(inner: T) -> Self {
        Self::wrap(inner)
    }

    /// Loaded → Warm transition. Consumes self; the caller no
    /// longer holds a Loaded handle.
    pub fn warm_up(self) -> Lifecycle<T, Warm> {
        Lifecycle::wrap(self.inner)
    }

    /// Loaded → Disposed (skipping Warm) — useful for early
    /// teardown without paying the warm-up cost.
    pub fn dispose(self) -> Lifecycle<T, Disposed> {
        Lifecycle::wrap(self.inner)
    }
}

// MARK: - Warm

impl<T> Lifecycle<T, Warm> {
    /// Warm → Generating. Consumes self.
    pub fn begin(self) -> Lifecycle<T, Generating> {
        Lifecycle::wrap(self.inner)
    }

    /// Warm → Disposed.
    pub fn dispose(self) -> Lifecycle<T, Disposed> {
        Lifecycle::wrap(self.inner)
    }
}

// MARK: - Generating

impl<T> Lifecycle<T, Generating> {
    /// Generating → Warm. Caller "returns" the session to the pool.
    pub fn finish(self) -> Lifecycle<T, Warm> {
        Lifecycle::wrap(self.inner)
    }

    /// Generating → Disposed (e.g. cancellation mid-stream).
    pub fn dispose(self) -> Lifecycle<T, Disposed> {
        Lifecycle::wrap(self.inner)
    }
}

// MARK: - Disposed
// (Intentionally NO transition methods — Disposed is a terminal
// state. Calling .step() / .warm_up() / etc. on a Disposed handle
// is a compile error because no such impl exists.)

impl<T> Lifecycle<T, Disposed> {
    /// Allow the caller to recover the inner value at the end of life
    /// for cleanup (e.g. drop ordering with Arc::decrement_strong_count).
    pub fn into_inner(self) -> T {
        self.inner
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn happy_path_loaded_to_disposed() {
        let session = Lifecycle::<u32, Loaded>::new_loaded(42);
        let warm = session.warm_up();
        let gen = warm.begin();
        let warm_again = gen.finish();
        let disposed = warm_again.dispose();
        assert_eq!(disposed.into_inner(), 42);
    }

    #[test]
    fn early_dispose_from_loaded() {
        let session = Lifecycle::<&str, Loaded>::new_loaded("never warmed");
        let disposed = session.dispose();
        assert_eq!(disposed.into_inner(), "never warmed");
    }

    #[test]
    fn early_dispose_from_generating() {
        let session = Lifecycle::<i32, Loaded>::new_loaded(7);
        let disposed = session.warm_up().begin().dispose();
        assert_eq!(disposed.into_inner(), 7);
    }

    #[test]
    fn peek_works_in_any_state() {
        let session = Lifecycle::<u32, Loaded>::new_loaded(99);
        assert_eq!(*session.peek(), 99);
        let warm = session.warm_up();
        assert_eq!(*warm.peek(), 99);
    }

    /// Compile-time test (commented out — uncomment to verify the
    /// type system enforces the invariants):
    ///
    /// ```compile_fail
    /// use agent_core::runtime::typestate::*;
    /// let s = Lifecycle::<u32, Disposed>::new_loaded(0); // would compile
    /// // s.warm_up();  // <-- this would NOT compile (no warm_up impl on Disposed)
    /// ```
    #[test]
    fn _compile_time_invariants_documented() {
        // The doctest above documents the negative space; this test
        // just confirms the module compiles.
    }
}
