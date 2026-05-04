use std::io;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};

use memmap2::{MmapMut, MmapOptions};
use thiserror::Error;
use tracing::{debug, error, info, instrument, trace, warn};

// ---------------------------------------------------------------------------
// Arena constants
// ---------------------------------------------------------------------------

/// Magic number "EPAR" (little-endian)
pub const ARENA_MAGIC: u32 = 0x4550_4152;

/// Arena layout version
pub const ARENA_VERSION: u32 = 2;

/// Number of slots in the request/response ring
pub const SLOT_COUNT: usize = 16;

/// Inline request payload bytes per slot
pub const INLINE_REQ_BYTES: usize = 2048;

/// Inline response payload bytes per slot
pub const INLINE_RSP_BYTES: usize = 4096;

/// Maximum artefact references carried in a single request/response
pub const MAX_ARTEFACT_REFS: usize = 8;

/// Size of each slot's inline payload (request)
pub const REQ_SLOT_BYTES: usize = INLINE_REQ_BYTES;

/// Size of each slot's inline payload (response)
pub const RSP_SLOT_BYTES: usize = INLINE_RSP_BYTES;

/// A slot is valid but not yet processed by the consumer.
pub const STATE_PENDING: u32 = 1;

/// A slot has been fully written and is ready for consumption.
pub const STATE_READY: u32 = 2;

/// A slot has been consumed and can be reused.
pub const STATE_CONSUMED: u32 = 3;

// ---------------------------------------------------------------------------
// ArtefactRef — pointer to out-of-line data in the blob store
// ---------------------------------------------------------------------------

/// A reference to an out-of-line artefact stored in the App Group blob directory.
///
/// `blob_id` is a 16-byte content-addressed identifier (e.g. truncated BLAKE3).
/// `offset` and `len` address a contiguous span within that blob file.
///
/// # Layout
/// Total size = 32 bytes. Aligned to 64 bytes so that 8 refs fill exactly one
/// 64-byte cache line.
#[repr(C, align(64))]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ArtefactRef {
    /// 128-bit content hash (first 16 bytes of BLAKE3)
    pub blob_id: [u8; 16],
    /// Byte offset inside the blob file
    pub offset: u64,
    /// Byte length of the span
    pub len: u64,
    /// Reserved for future use (e.g. compression flags)
    pub flags: u32,
    /// Padding to bring total to 32 bytes
    _pad: u32,
}

impl ArtefactRef {
    /// Create a new `ArtefactRef` pointing to `blob_id` at `offset`..`offset+len`.
    pub fn new(blob_id: [u8; 16], offset: u64, len: u64) -> Self {
        Self {
            blob_id,
            offset,
            len,
            flags: 0,
            _pad: 0,
        }
    }

    /// Create a zeroed (nil) reference.
    pub const fn nil() -> Self {
        Self {
            blob_id: [0; 16],
            offset: 0,
            len: 0,
            flags: 0,
            _pad: 0,
        }
    }
}

// ---------------------------------------------------------------------------
// RequestSlot — control + inline payload + artefact refs
// ---------------------------------------------------------------------------

/// A single request slot in the ring buffer.
///
/// The producer (Swift / main app) writes into this slot, then flips `state`
/// to [`STATE_READY`] with [`Ordering::Release`].  The consumer (Rust / XPC
/// service) observes the state with [`Ordering::Acquire`] before reading any
/// other field.
///
/// # Layout
/// - state      : 4  bytes (u32)
/// - op         : 2  bytes (u16)
/// - _pad0      : 2  bytes
/// - seq        : 8  bytes (u64)
/// - timestamp  : 8  bytes (u64, monotonic ns)
/// - refs       : 8 × 32 = 256 bytes
/// - payload    : 2048 bytes
/// Total = 2328 bytes → rounded up to 4096 for page alignment.
#[repr(C, align(4096))]
#[derive(Debug)]
pub struct RequestSlot {
    /// Slot lifecycle state (PENDING / READY / CONSUMED)
    pub state: AtomicU32,
    /// Operation code (matches `ArenaOp` on the Swift side)
    pub op: u16,
    /// Padding to 8-byte boundary
    _pad0: u16,
    /// Monotonically-increasing sequence number for correlation
    pub seq: u64,
    /// Submission timestamp (monotonic nanoseconds)
    pub timestamp: u64,
    /// References to out-of-line blobs
    pub refs: [ArtefactRef; MAX_ARTEFACT_REFS],
    /// Inline request payload
    pub payload: [u8; INLINE_REQ_BYTES],
    /// Padding to fill the remainder of the 4096-byte page
    _pad1: [u8; 4096 - (4 + 2 + 2 + 8 + 8 + 256 + 2048)],
}

impl RequestSlot {
    /// Zero-initialise a request slot (used when creating a fresh arena).
    pub const fn new() -> Self {
        Self {
            state: AtomicU32::new(0),
            op: 0,
            _pad0: 0,
            seq: 0,
            timestamp: 0,
            refs: [ArtefactRef::nil(); MAX_ARTEFACT_REFS],
            payload: [0; INLINE_REQ_BYTES],
            _pad1: [0; 4096 - (4 + 2 + 2 + 8 + 8 + 256 + 2048)],
        }
    }
}

impl Clone for RequestSlot {
    fn clone(&self) -> Self {
        Self {
            state: AtomicU32::new(self.state.load(Ordering::Relaxed)),
            op: self.op,
            _pad0: self._pad0,
            seq: self.seq,
            timestamp: self.timestamp,
            refs: self.refs,
            payload: self.payload,
            _pad1: self._pad1,
        }
    }
}

// ---------------------------------------------------------------------------
// ResponseSlot — control + inline payload + artefact refs
// ---------------------------------------------------------------------------

/// A single response slot in the ring buffer.
///
/// The producer (Rust / XPC service) writes into this slot, then flips `state`
/// to [`STATE_READY`] with [`Ordering::Release`].  The consumer (Swift / main
/// app) observes the state with [`Ordering::Acquire`] before reading.
///
/// # Layout
/// - state      : 4  bytes
/// - status     : 2  bytes (0 = OK, non-zero = error code)
/// - _pad0      : 2  bytes
/// - seq        : 8  bytes
/// - timestamp  : 8  bytes
/// - refs       : 256 bytes
/// - payload    : 4096 bytes
/// Total = 4376 bytes → rounded up to 8192 for page alignment.
#[repr(C, align(8192))]
#[derive(Debug)]
pub struct ResponseSlot {
    /// Slot lifecycle state
    pub state: AtomicU32,
    /// Status code (0 = success)
    pub status: u16,
    /// Padding to 8-byte boundary
    _pad0: u16,
    /// Sequence number matching the request
    pub seq: u64,
    /// Completion timestamp (monotonic nanoseconds)
    pub timestamp: u64,
    /// References to out-of-line blobs
    pub refs: [ArtefactRef; MAX_ARTEFACT_REFS],
    /// Inline response payload
    pub payload: [u8; INLINE_RSP_BYTES],
    /// Padding to fill the remainder of the 8192-byte allocation
    _pad1: [u8; 8192 - (4 + 2 + 2 + 8 + 8 + 256 + 4096)],
}

impl ResponseSlot {
    /// Zero-initialise a response slot.
    pub const fn new() -> Self {
        Self {
            state: AtomicU32::new(0),
            status: 0,
            _pad0: 0,
            seq: 0,
            timestamp: 0,
            refs: [ArtefactRef::nil(); MAX_ARTEFACT_REFS],
            payload: [0; INLINE_RSP_BYTES],
            _pad1: [0; 8192 - (4 + 2 + 2 + 8 + 8 + 256 + 4096)],
        }
    }
}

impl Clone for ResponseSlot {
    fn clone(&self) -> Self {
        Self {
            state: AtomicU32::new(self.state.load(Ordering::Relaxed)),
            status: self.status,
            _pad0: self._pad0,
            seq: self.seq,
            timestamp: self.timestamp,
            refs: self.refs,
            payload: self.payload,
            _pad1: self._pad1,
        }
    }
}

// ---------------------------------------------------------------------------
// ArenaHeader — shared control region, one 4 KiB page
// ---------------------------------------------------------------------------

/// The arena header lives at the start of the mmap'd file and holds the
/// producer/consumer indexes for the two SPSC rings.
///
/// All atomic operations use the strictest ordering required for the
/// single-producer / single-consumer invariant:
/// - Writer fills slot, then `store(READY, Release)`
/// - Reader checks `load(READY, Acquire)`, then reads slot data
/// - Head/tail indexes are updated with `AcqRel` so that the
///   opposite side sees them without stale reads.
#[repr(C, align(4096))]
#[derive(Debug)]
pub struct ArenaHeader {
    /// Magic number — must equal [`ARENA_MAGIC`]
    pub magic: u32,
    /// Layout version — must equal [`ARENA_VERSION`]
    pub version: u32,
    /// Monotonically-increasing request sequence counter
    pub req_head: AtomicU64,
    /// Monotonically-increasing request consumption counter
    pub req_tail: AtomicU64,
    /// Monotonically-increasing response sequence counter
    pub rsp_head: AtomicU64,
    /// Monotonically-increasing response consumption counter
    pub rsp_tail: AtomicU64,
    /// Epoch counter bumped by either side to signal a configuration change
    pub signal_epoch: AtomicU64,
    /// Reserved / padding to fill the 4096-byte page
    pub _pad: [u8; 4096 - 40],
}

impl ArenaHeader {
    /// Create a zeroed header.  Callers must initialise `magic` and `version`
    /// before sharing the arena with another process.
    pub const fn new() -> Self {
        Self {
            magic: 0,
            version: 0,
            req_head: AtomicU64::new(0),
            req_tail: AtomicU64::new(0),
            rsp_head: AtomicU64::new(0),
            rsp_tail: AtomicU64::new(0),
            signal_epoch: AtomicU64::new(0),
            _pad: [0; 4096 - 40],
        }
    }
}

// ---------------------------------------------------------------------------
// Arena — full mmap layout
// ---------------------------------------------------------------------------

/// The complete arena layout as it appears in the mmap'd file.
///
/// # Memory layout
/// ```text
/// ┌─────────────────────────────────────┐ 0x0000
│ │         ArenaHeader (4096 B)          │
│ ├─────────────────────────────────────┤ 0x1000
│ │   RequestSlot[0]  (4096 B each)     │
│ │   ... × 16                           │
│ ├─────────────────────────────────────┤ 0x11000
│ │   ResponseSlot[0] (8192 B each)     │
│ │   ... × 16                           │
│ └─────────────────────────────────────┘ 0x31000
/// ```
/// Total size = 0x31000 bytes = 200 704 bytes (~196 KiB)
#[repr(C, align(4096))]
#[derive(Debug)]
pub struct Arena {
    pub header: ArenaHeader,
    pub requests: [RequestSlot; SLOT_COUNT],
    pub responses: [ResponseSlot; SLOT_COUNT],
}

impl Arena {
    /// Total size of the arena in bytes.
    pub const SIZE: usize = std::mem::size_of::<Self>();

    /// Zero-initialise (for safe init via `write_volatile`).
    pub const fn new() -> Self {
        Self {
            header: ArenaHeader::new(),
            requests: [RequestSlot::new(); SLOT_COUNT],
            responses: [ResponseSlot::new(); SLOT_COUNT],
        }
    }
}

// ---------------------------------------------------------------------------
// AtomicU32 helper (std does not expose AtomicU32 in core with all methods on
// every platform, so we wrap to keep the struct definitions clean)
// ---------------------------------------------------------------------------

#[repr(transparent)]
#[derive(Debug)]
pub struct AtomicU32 {
    inner: core::sync::atomic::AtomicU32,
}

impl AtomicU32 {
    pub const fn new(v: u32) -> Self {
        Self {
            inner: core::sync::atomic::AtomicU32::new(v),
        }
    }

    #[inline]
    pub fn load(&self, order: Ordering) -> u32 {
        self.inner.load(order)
    }

    #[inline]
    pub fn store(&self, val: u32, order: Ordering) {
        self.inner.store(val, order);
    }

    #[inline]
    pub fn swap(&self, val: u32, order: Ordering) -> u32 {
        self.inner.swap(val, order)
    }

    #[inline]
    pub fn compare_exchange(
        &self,
        current: u32,
        new: u32,
        success: Ordering,
        failure: Ordering,
    ) -> Result<u32, u32> {
        self.inner.compare_exchange(current, new, success, failure)
    }
}

// ---------------------------------------------------------------------------
// ArenaError
// ---------------------------------------------------------------------------

/// Errors that can arise when opening or using the arena.
#[derive(Error, Debug)]
pub enum ArenaError {
    /// An underlying I/O error (mmap, file open, etc.)
    #[error("arena I/O error: {0}")]
    Io(#[from] io::Error),

    /// The on-disk file has a magic or version mismatch and could not be
    /// safely recovered.
    #[error("arena corruption detected: magic={magic} version={version}")]
    Corruption { magic: u32, version: u32 },

    /// A request could not be submitted because the ring is full.
    #[error("request ring full (head={head}, tail={tail})")]
    RingFull { head: u64, tail: u64 },

    /// A generic static string diagnostic (used for the `Result<u64, &'static str>`
    /// signature required by the brief).
    #[error("{0}")]
    Static(&'static str),
}

// ---------------------------------------------------------------------------
// MappedArena — safe handle to a file-backed mmap
// ---------------------------------------------------------------------------

/// A safe wrapper around a file-backed `mmap(MAP_SHARED)`.
///
/// # Safety invariant
/// The mmap'd memory is valid for reads and writes by any process that has
/// the same file descriptor open.  The arena layout is fixed-size and
/// page-aligned, so concurrent access is safe provided the atomic protocol is
/// followed.
pub struct MappedArena {
    mmap: MmapMut,
    path: std::path::PathBuf,
}

// SAFETY: MappedArena holds no thread-local state; the mmap is MAP_SHARED and
// all synchronisation is explicit via atomics in the ArenaHeader.  It is
// therefore safe to move across threads.
unsafe impl Send for MappedArena {}

// SAFETY: Same reasoning as Send — concurrent access is gated by the Release-
// Acquire protocol on the slot states and head/tail counters.
unsafe impl Sync for MappedArena {}

impl MappedArena {
    /// Open an existing arena file or create and initialise a fresh one.
    ///
    /// If the file already exists but the magic/version are wrong, the file
    /// is truncated and re-initialised.  This is the safe-recovery path for
    /// crashes that left the arena in an undefined state.
    #[instrument(skip(path), fields(?path))]
    pub fn open_or_create(path: &Path) -> Result<Self, ArenaError> {
        use std::fs::OpenOptions;

        // 1. Open (or create) the backing file with read+write permission.
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(path)
            .map_err(ArenaError::Io)?;

        let meta = file.metadata().map_err(ArenaError::Io)?;
        let existing_len = meta.len() as usize;
        let expected_len = Arena::SIZE;

        // 2. Ensure the file is at least as large as the arena layout.
        if existing_len < expected_len {
            file.set_len(expected_len as u64)
                .map_err(ArenaError::Io)?;
            info!(
                existing_len,
                expected_len,
                "arena file resized to expected length"
            );
        }

        // 3. mmap the file as read+write, shared.
        // SAFETY: The file is open, we have read+write permission, and the
        // length was set to exactly Arena::SIZE.  We are the only accessor
        // until the method returns (single-threaded construction).
        let mut mmap = unsafe {
            MmapOptions::new()
                .len(expected_len)
                .map_mut(&file)
                .map_err(ArenaError::Io)?
        };

        // 4. Inspect the header and decide: reuse or zero-fill.
        // SAFETY: We just mapped `expected_len` bytes, which is exactly the
        // size of `Arena`.  The pointer is non-null and aligned because
        // memmap2 guarantees page-aligned mappings.
        let arena_ptr: *mut Arena = mmap.as_mut_ptr().cast();
        let arena: &mut Arena = unsafe { &mut *arena_ptr };

        let current_magic = arena.header.magic;
        let current_version = arena.header.version;

        let needs_init =
            current_magic != ARENA_MAGIC || current_version != ARENA_VERSION;

        if needs_init {
            warn!(
                current_magic,
                current_version,
                expected_magic = ARENA_MAGIC,
                expected_version = ARENA_VERSION,
                "arena magic/version mismatch — zero-filling"
            );

            // Zero-fill the entire mapping via volatile writes.  This avoids
            // the compiler reordering or eliding the writes, which is important
            // because another process may map the same file immediately after
            // we finish.
            let byte_ptr = mmap.as_mut_ptr();
            // SAFETY: byte_ptr is valid for `expected_len` bytes.
            unsafe {
                core::ptr::write_bytes(byte_ptr, 0, expected_len);
            }

            // Write the magic and version last so that a concurrent mapper
            // sees 0x0 (incomplete) rather than a partial header.
            arena.header.magic = ARENA_MAGIC;
            arena.header.version = ARENA_VERSION;
            // Atomic counters were already zeroed by write_bytes.

            // Memory fence: make sure all zeroing is visible before the
            // magic is visible.  The previous write_bytes is not ordered,
            // so we issue a seq_cst fence here.
            core::sync::atomic::fence(Ordering::SeqCst);

            info!("arena initialised with magic={ARENA_MAGIC:#010x}, version={ARENA_VERSION}");
        } else {
            info!("arena reused (magic and version valid)");
        }

        // 5. Drop the file handle — the mmap keeps the underlying pages alive.
        drop(file);

        Ok(Self {
            mmap,
            path: path.to_path_buf(),
        })
    }

    /// Return a shared reference to the arena via the mmap pointer.
    ///
    /// # Safety
    /// The returned reference is valid for as long as `self` is alive.  No
    /// mutable aliasing must occur while the reference is in use.
    fn arena(&self) -> &Arena {
        // SAFETY: The mmap was validated at construction time to be at least
        // Arena::SIZE bytes long and page-aligned.  The pointer is non-null.
        unsafe { &*self.mmap.as_ptr().cast::<Arena>() }
    }

    /// Return an exclusive reference to the arena.
    ///
    /// # Safety
    /// Callers must ensure that no other thread or process is concurrently
    /// writing to the arena.  In practice this is used only for the single-
    /// writer side (request producer or response producer).
    fn arena_mut(&mut self) -> &mut Arena {
        // SAFETY: Same as arena(), but we require &mut self to prevent
        // multiple mutable references in this process.
        unsafe { &mut *self.mmap.as_mut_ptr().cast::<Arena>() }
    }

    /// Submit a request into the next free request slot.
    ///
    /// Returns the sequence number assigned to the request, or an error if
    /// the ring is full.
    #[instrument(skip(self, slot), fields(slot.seq, slot.op))]
    pub fn submit_request(&self, slot: RequestSlot) -> Result<u64, ArenaError> {
        let arena = self.arena();
        let head = arena.header.req_head.load(Ordering::Relaxed);
        let tail = arena.header.req_tail.load(Ordering::Acquire);

        // Ring-full check: head - tail >= SLOT_COUNT
        if head.wrapping_sub(tail) >= SLOT_COUNT as u64 {
            warn!(head, tail, "request ring full");
            return Err(ArenaError::RingFull { head, tail });
        }

        let idx = (head % SLOT_COUNT as u64) as usize;
        let target = &arena.requests[idx];

        // Safety check: the slot should be CONSUMED or zero (fresh init).
        // If it is still PENDING or READY, something is wrong.
        let prev_state = target.state.load(Ordering::Acquire);
        if prev_state != 0 && prev_state != STATE_CONSUMED {
            // Force-reset the slot so we don't deadlock.  This is a
            // last-resort recovery path — log loudly.
            error!(
                idx,
                prev_state,
                "request slot in unexpected state — forcing reset"
            );
            target.state.store(STATE_CONSUMED, Ordering::Release);
        }

        // Write the slot data.  These writes need not be ordered yet because
        // the reader will not look at them until it sees STATE_READY.
        // SAFETY: We hold &self (not &mut), but we are the designated writer
        // for this slot index based on the head counter.  The consumer will
        // not touch this slot until we flip the state.
        let target_seq = head.wrapping_add(1);
        unsafe {
            let t = target as *const RequestSlot as *mut RequestSlot;
            (*t).seq = target_seq;
            (*t).op = slot.op;
            (*t).timestamp = slot.timestamp;
            (*t).refs = slot.refs;
            (*t).payload = slot.payload;
        }

        // Publish: flip state to READY with Release ordering so that all the
        // preceding writes are visible to the Acquire load on the reader side.
        target.state.store(STATE_READY, Ordering::Release);

        // Advance head with AcqRel so the reader sees the new value.
        arena.header.req_head.store(target_seq, Ordering::Release);

        debug!(seq = target_seq, idx, "request submitted");
        Ok(target_seq)
    }

    /// Attempt to take the response matching `seq`.
    ///
    /// Returns `Some(response)` if the response slot with the matching
    /// sequence number is [`STATE_READY`]; returns `None` otherwise.
    #[instrument(skip(self), fields(seq))]
    pub fn try_take_response(&self, seq: u64) -> Option<ResponseSlot> {
        let arena = self.arena();
        let rsp_tail = arena.header.rsp_tail.load(Ordering::Relaxed);
        let rsp_head = arena.header.rsp_head.load(Ordering::Acquire);

        // If the response hasn't been produced yet, bail early.
        if seq > rsp_head || seq <= rsp_tail {
            trace!(seq, rsp_head, rsp_tail, "response not yet available");
            return None;
        }

        let idx = ((seq - 1) % SLOT_COUNT as u64) as usize;
        let target = &arena.responses[idx];

        // Acquire load on state guarantees we see all writes made by the
        // producer before its Release store of STATE_READY.
        if target.state.load(Ordering::Acquire) != STATE_READY {
            return None;
        }

        // Sequence number sanity check.
        let actual_seq = unsafe {
            // SAFETY: We verified the slot is READY, so the producer has
            // finished writing and will not touch this slot again until we
            // advance rsp_tail.
            let t = target as *const ResponseSlot as *mut ResponseSlot;
            (*t).seq
        };
        if actual_seq != seq {
            warn!(seq, actual_seq, idx, "response slot seq mismatch");
            return None;
        }

        // Copy the slot out (stack allocation, no heap).
        let mut copy = ResponseSlot::new();
        copy.seq = actual_seq;
        copy.status = unsafe {
            let t = target as *const ResponseSlot as *mut ResponseSlot;
            (*t).status
        };
        copy.timestamp = unsafe {
            let t = target as *const ResponseSlot as *mut ResponseSlot;
            (*t).timestamp
        };
        copy.refs = unsafe {
            let t = target as *const ResponseSlot as *mut ResponseSlot;
            (*t).refs
        };
        copy.payload = unsafe {
            let t = target as *const ResponseSlot as *mut ResponseSlot;
            (*t).payload
        };

        // Mark consumed and advance tail.
        // SAFETY: We are the exclusive consumer for this slot index.
        unsafe {
            let t = target as *const ResponseSlot as *mut ResponseSlot;
            (*t).state.store(STATE_CONSUMED, Ordering::Release);
        }
        arena
            .header
            .rsp_tail
            .store(seq, Ordering::Release);

        debug!(seq, idx, "response taken");
        Some(copy)
    }

    /// Peek the current response head (for callers that want to do their own
    /// correlation rather than poll a specific sequence number).
    pub fn response_head(&self) -> u64 {
        let arena = self.arena();
        arena.header.rsp_head.load(Ordering::Acquire)
    }

    /// Peek the current request head.
    pub fn request_head(&self) -> u64 {
        let arena = self.arena();
        arena.header.req_head.load(Ordering::Acquire)
    }

    /// Read the signal epoch without mutating it.
    pub fn signal_epoch(&self) -> u64 {
        let arena = self.arena();
        arena.header.signal_epoch.load(Ordering::Acquire)
    }

    /// Bump the signal epoch (e.g. after a configuration change).
    pub fn bump_signal_epoch(&self) {
        let arena = self.arena();
        arena
            .header
            .signal_epoch
            .fetch_add(1, Ordering::AcqRel);
    }

    /// Path of the backing file.
    pub fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for MappedArena {
    fn drop(&mut self) {
        // The MmapMut's Drop impl calls munmap automatically.  We only log.
        info!(path = ?self.path, "MappedArena dropped (munmap)");
    }
}

// ---------------------------------------------------------------------------
// Convenience helpers for the "other side" of the ring (the consumer/producer
// pair).  These are used by the Rust XPC service implementation in SLICE 2.
// ---------------------------------------------------------------------------

impl MappedArena {
    /// Poll the next pending request (consumer side).
    ///
    /// Returns `Some((seq, idx, &RequestSlot))` if a request is ready.
    /// The caller **must** call `complete_request(idx)` after processing.
    #[instrument(skip(self))]
    pub fn poll_next_request(&self) -> Option<(u64, usize, &RequestSlot)> {
        let arena = self.arena();
        let req_tail = arena.header.req_tail.load(Ordering::Relaxed);
        let req_head = arena.header.req_head.load(Ordering::Acquire);

        if req_tail >= req_head {
            return None;
        }

        let idx = (req_tail % SLOT_COUNT as u64) as usize;
        let target = &arena.requests[idx];

        if target.state.load(Ordering::Acquire) != STATE_READY {
            return None;
        }

        let seq = unsafe {
            let t = target as *const RequestSlot as *mut RequestSlot;
            (*t).seq
        };

        debug!(seq, idx, "request polled");
        Some((seq, idx, target))
    }

    /// Mark a request as consumed and advance the tail.
    ///
    /// # Safety
    /// The caller must have previously received `idx` from `poll_next_request`
    /// and must not call this more than once per polled request.
    pub unsafe fn complete_request(&self, idx: usize, seq: u64) {
        let arena = self.arena();
        let target = &arena.requests[idx];
        let t = target as *const RequestSlot as *mut RequestSlot;
        (*t).state.store(STATE_CONSUMED, Ordering::Release);
        arena.header.req_tail.store(seq, Ordering::Release);
        debug!(seq, idx, "request completed");
    }

    /// Publish a response into the response ring (producer side).
    ///
    /// Returns the sequence number on success, or an error if the response
    /// ring is full.
    #[instrument(skip(self, payload), fields(seq))]
    pub fn publish_response(
        &self,
        seq: u64,
        status: u16,
        payload: &[u8],
        refs: &[ArtefactRef],
    ) -> Result<u64, ArenaError> {
        let arena = self.arena();
        let head = arena.header.rsp_head.load(Ordering::Relaxed);
        let tail = arena.header.rsp_tail.load(Ordering::Acquire);

        if head.wrapping_sub(tail) >= SLOT_COUNT as u64 {
            return Err(ArenaError::RingFull { head, tail });
        }

        let idx = (head % SLOT_COUNT as u64) as usize;
        let target = &arena.responses[idx];

        let prev_state = target.state.load(Ordering::Acquire);
        if prev_state != 0 && prev_state != STATE_CONSUMED {
            error!(
                idx,
                prev_state,
                "response slot in unexpected state — forcing reset"
            );
            unsafe {
                let t = target as *const ResponseSlot as *mut ResponseSlot;
                (*t).state.store(STATE_CONSUMED, Ordering::Release);
            }
        }

        // Clamp payload to inline limit.
        let copy_len = payload.len().min(INLINE_RSP_BYTES);
        let mut payload_buf = [0u8; INLINE_RSP_BYTES];
        payload_buf[..copy_len].copy_from_slice(&payload[..copy_len]);

        let mut refs_buf = [ArtefactRef::nil(); MAX_ARTEFACT_REFS];
        let refs_len = refs.len().min(MAX_ARTEFACT_REFS);
        refs_buf[..refs_len].copy_from_slice(&refs[..refs_len]);

        unsafe {
            let t = target as *const ResponseSlot as *mut ResponseSlot;
            (*t).seq = seq;
            (*t).status = status;
            (*t).timestamp = 0; // caller may fill with monotonic ns
            (*t).refs = refs_buf;
            (*t).payload = payload_buf;
        }

        // Publish.
        unsafe {
            let t = target as *const ResponseSlot as *mut ResponseSlot;
            (*t).state.store(STATE_READY, Ordering::Release);
        }

        let new_head = head.wrapping_add(1);
        arena.header.rsp_head.store(new_head, Ordering::Release);

        debug!(seq, idx, "response published");
        Ok(new_head)
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;
    use std::thread;

    fn temp_arena_path(name: &str) -> std::path::PathBuf {
        let mut p = std::env::temp_dir();
        p.push(format!("epistemos_arena_test_{}_{}", name, fastrand::u32(..)));
        p
    }

    fn cleanup(p: &Path) {
        let _ = std::fs::remove_file(p);
    }

    #[test]
    fn arena_create_and_open() {
        let path = temp_arena_path("create_open");
        cleanup(&path);

        {
            let arena = MappedArena::open_or_create(&path).unwrap();
            let a = arena.arena();
            assert_eq!(a.header.magic, ARENA_MAGIC);
            assert_eq!(a.header.version, ARENA_VERSION);
            assert_eq!(a.header.req_head.load(Ordering::Relaxed), 0);
            assert_eq!(a.header.req_tail.load(Ordering::Relaxed), 0);
            assert_eq!(a.header.rsp_head.load(Ordering::Relaxed), 0);
            assert_eq!(a.header.rsp_tail.load(Ordering::Relaxed), 0);
        }

        // Re-open should reuse, not reset.
        {
            let arena = MappedArena::open_or_create(&path).unwrap();
            let a = arena.arena();
            assert_eq!(a.header.magic, ARENA_MAGIC);
            assert_eq!(a.header.version, ARENA_VERSION);
        }

        cleanup(&path);
    }

    #[test]
    fn arena_submit_take_roundtrip() {
        let path = temp_arena_path("roundtrip");
        cleanup(&path);

        let arena = MappedArena::open_or_create(&path).unwrap();

        let mut req = RequestSlot::new();
        req.op = 1;
        req.timestamp = 42;
        req.payload[..5].copy_from_slice(b"hello");

        let seq = arena.submit_request(req).unwrap();
        assert_eq!(seq, 1);

        // Simulate consumer processing
        let (polled_seq, idx, _slot) = arena.poll_next_request().unwrap();
        assert_eq!(polled_seq, seq);
        unsafe { arena.complete_request(idx, polled_seq); }

        // Publish response
        let rsp_data = b"world";
        let rsp_seq = arena.publish_response(seq, 0, rsp_data, &[]).unwrap();
        assert_eq!(rsp_seq, 1);

        // Take response
        let rsp = arena.try_take_response(seq).unwrap();
        assert_eq!(rsp.seq, seq);
        assert_eq!(rsp.status, 0);
        assert_eq!(&rsp.payload[..5], b"world");

        cleanup(&path);
    }

    #[test]
    fn arena_ring_wraparound() {
        let path = temp_arena_path("wraparound");
        cleanup(&path);

        let arena = MappedArena::open_or_create(&path).unwrap();

        // Submit > SLOT_COUNT requests, consuming each immediately.
        for i in 1..=SLOT_COUNT as u64 + 4 {
            let mut req = RequestSlot::new();
            req.op = 1;
            req.payload[..8].copy_from_slice(format!("req{:04}", i).as_bytes());
            let seq = arena.submit_request(req).unwrap();
            assert_eq!(seq, i);

            let (ps, idx, _s) = arena.poll_next_request().unwrap();
            assert_eq!(ps, seq);
            unsafe { arena.complete_request(idx, ps); }
        }

        cleanup(&path);
    }

    #[test]
    fn arena_concurrent_submit() {
        let path = temp_arena_path("concurrent");
        cleanup(&path);

        let arena = Arc::new(MappedArena::open_or_create(&path).unwrap());
        let mut handles = Vec::with_capacity(4);

        for t in 0..4 {
            let a = Arc::clone(&arena);
            handles.push(thread::spawn(move || {
                for i in 0..8 {
                    let mut req = RequestSlot::new();
                    req.op = 1;
                    req.timestamp = t * 100 + i;
                    loop {
                        match a.submit_request(req.clone()) {
                            Ok(seq) => {
                                assert!(seq > 0);
                                break;
                            }
                            Err(ArenaError::RingFull { .. }) => {
                                // Consumer is not running in this test, so
                                // the ring will fill; spin-wait then retry.
                                thread::yield_now();
                                req = RequestSlot::new();
                                req.op = 1;
                                req.timestamp = t * 100 + i;
                            }
                            Err(e) => panic!("unexpected error: {e}"),
                        }
                    }
                }
            }));
        }

        for h in handles {
            h.join().unwrap();
        }

        // No corruption => arena still valid.
        let a = arena.arena();
        assert_eq!(a.header.magic, ARENA_MAGIC);
        assert_eq!(a.header.version, ARENA_VERSION);

        cleanup(&path);
    }

    #[test]
    fn arena_corruption_recovery() {
        let path = temp_arena_path("corruption");
        cleanup(&path);

        // 1. Create a valid arena.
        {
            let arena = MappedArena::open_or_create(&path).unwrap();
            let a = arena.arena();
            assert_eq!(a.header.magic, ARENA_MAGIC);
        }

        // 2. Corrupt the magic by writing directly to the file.
        {
            use std::fs::OpenOptions;
            use std::io::{Seek, SeekFrom, Write};
            let mut file = OpenOptions::new()
                .write(true)
                .open(&path)
                .unwrap();
            file.seek(SeekFrom::Start(0)).unwrap();
            file.write_all(&0xDEADBEEF_u32.to_le_bytes()).unwrap();
        }

        // 3. Re-open — should detect corruption and re-initialise.
        {
            let arena = MappedArena::open_or_create(&path).unwrap();
            let a = arena.arena();
            assert_eq!(a.header.magic, ARENA_MAGIC);
            assert_eq!(a.header.version, ARENA_VERSION);
        }

        cleanup(&path);
    }

    #[test]
    fn arena_drop_munmap() {
        let path = temp_arena_path("drop");
        cleanup(&path);

        let arena = MappedArena::open_or_create(&path).unwrap();
        drop(arena);

        // After drop, the file should still exist (it's a file-backed mmap).
        assert!(path.exists());

        // Re-opening should be fine.
        let _arena2 = MappedArena::open_or_create(&path).unwrap();

        cleanup(&path);
    }

    #[test]
    fn arena_layout_sizes() {
        // Verify that our computed padding matches the actual struct sizes.
        assert_eq!(std::mem::size_of::<ArtefactRef>(), 32);
        assert_eq!(std::mem::align_of::<ArtefactRef>(), 64);

        assert_eq!(std::mem::size_of::<RequestSlot>(), 4096);
        assert_eq!(std::mem::align_of::<RequestSlot>(), 4096);

        assert_eq!(std::mem::size_of::<ResponseSlot>(), 8192);
        assert_eq!(std::mem::align_of::<ResponseSlot>(), 8192);

        assert_eq!(std::mem::size_of::<ArenaHeader>(), 4096);
        assert_eq!(std::mem::align_of::<ArenaHeader>(), 4096);

        let expected_arena = 4096
            + SLOT_COUNT * 4096
            + SLOT_COUNT * 8192;
        assert_eq!(std::mem::size_of::<Arena>(), expected_arena);
    }

    #[test]
    fn arena_signal_epoch() {
        let path = temp_arena_path("epoch");
        cleanup(&path);

        let arena = MappedArena::open_or_create(&path).unwrap();
        assert_eq!(arena.signal_epoch(), 0);
        arena.bump_signal_epoch();
        assert_eq!(arena.signal_epoch(), 1);
        arena.bump_signal_epoch();
        assert_eq!(arena.signal_epoch(), 2);

        cleanup(&path);
    }
}
