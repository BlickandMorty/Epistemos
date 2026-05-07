//! File-backed arena foundation for future AgentXPC / ProviderXPC data planes.
//!
//! This is the canonical Epistemos re-derivation of Kimi's arena mockup. It
//! keeps the useful substrate law - a fixed-size, page-aligned, mmap-backed
//! control ring - while avoiding the donor's typoed App Group identifier and
//! deferring Swift/XPC integration to the next slice.

pub mod container;

use std::fs::OpenOptions;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::atomic::{fence, AtomicU32, AtomicU64, Ordering};

use memmap2::{MmapMut, MmapOptions};
use thiserror::Error;

pub use container::{AppGroupContainer, APP_GROUP_ID, ARENA_FILE_NAME, LEGACY_DIR};

pub const ARENA_MAGIC: u32 = 0x4550_4152;
pub const ARENA_VERSION: u32 = 2;
pub const SLOT_COUNT: usize = 16;
pub const INLINE_REQ_BYTES: usize = 2_048;
pub const INLINE_RSP_BYTES: usize = 4_096;
pub const MAX_ARTEFACT_REFS: usize = 8;
pub const STATE_EMPTY: u32 = 0;
pub const STATE_PENDING: u32 = 1;
pub const STATE_READY: u32 = 2;
pub const STATE_CONSUMED: u32 = 3;
pub const HEADER_BYTES: usize = 4_096;

#[repr(C)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ArtefactRef {
    pub blob_id: [u8; 16],
    pub offset: u64,
    pub len: u64,
    pub flags: u32,
    pad: u32,
}

impl ArtefactRef {
    pub const fn new(blob_id: [u8; 16], offset: u64, len: u64) -> Self {
        Self {
            blob_id,
            offset,
            len,
            flags: 0,
            pad: 0,
        }
    }

    pub const fn nil() -> Self {
        Self::new([0; 16], 0, 0)
    }
}

pub const ARTEFACT_REF_BYTES: usize = std::mem::size_of::<ArtefactRef>();
pub const ARTEFACT_REFS_BYTES: usize = MAX_ARTEFACT_REFS * ARTEFACT_REF_BYTES;

#[repr(C, align(4096))]
#[derive(Debug)]
pub struct RequestSlot {
    pub state: AtomicU32,
    pub op: u16,
    pad0: u16,
    pub seq: u64,
    pub timestamp: u64,
    pub refs: [ArtefactRef; MAX_ARTEFACT_REFS],
    pub payload_len: u32,
    pad1: u32,
    pub payload: [u8; INLINE_REQ_BYTES],
    pad2: [u8; 4096 - (4 + 2 + 2 + 8 + 8 + ARTEFACT_REFS_BYTES + 4 + 4 + INLINE_REQ_BYTES)],
}

impl RequestSlot {
    pub const fn empty() -> Self {
        Self {
            state: AtomicU32::new(STATE_EMPTY),
            op: 0,
            pad0: 0,
            seq: 0,
            timestamp: 0,
            refs: [ArtefactRef::nil(); MAX_ARTEFACT_REFS],
            payload_len: 0,
            pad1: 0,
            payload: [0; INLINE_REQ_BYTES],
            pad2: [0; 4096 - (4 + 2 + 2 + 8 + 8 + ARTEFACT_REFS_BYTES + 4 + 4 + INLINE_REQ_BYTES)],
        }
    }

    pub fn new(
        op: u16,
        timestamp: u64,
        payload: &[u8],
        refs: [ArtefactRef; MAX_ARTEFACT_REFS],
    ) -> Result<Self, ArenaError> {
        if payload.len() > INLINE_REQ_BYTES {
            return Err(ArenaError::PayloadTooLarge {
                len: payload.len(),
                max: INLINE_REQ_BYTES,
            });
        }
        let mut slot = Self::empty();
        slot.state.store(STATE_PENDING, Ordering::Relaxed);
        slot.op = op;
        slot.timestamp = timestamp;
        slot.refs = refs;
        slot.payload_len = payload.len() as u32;
        slot.payload[..payload.len()].copy_from_slice(payload);
        Ok(slot)
    }
}

#[repr(C, align(8192))]
#[derive(Debug)]
pub struct ResponseSlot {
    pub state: AtomicU32,
    pub status: u16,
    pad0: u16,
    pub seq: u64,
    pub timestamp: u64,
    pub refs: [ArtefactRef; MAX_ARTEFACT_REFS],
    pub payload_len: u32,
    pad1: u32,
    pub payload: [u8; INLINE_RSP_BYTES],
    pad2: [u8; 8192 - (4 + 2 + 2 + 8 + 8 + ARTEFACT_REFS_BYTES + 4 + 4 + INLINE_RSP_BYTES)],
}

impl ResponseSlot {
    pub const fn empty() -> Self {
        Self {
            state: AtomicU32::new(STATE_EMPTY),
            status: 0,
            pad0: 0,
            seq: 0,
            timestamp: 0,
            refs: [ArtefactRef::nil(); MAX_ARTEFACT_REFS],
            payload_len: 0,
            pad1: 0,
            payload: [0; INLINE_RSP_BYTES],
            pad2: [0; 8192 - (4 + 2 + 2 + 8 + 8 + ARTEFACT_REFS_BYTES + 4 + 4 + INLINE_RSP_BYTES)],
        }
    }
}

#[repr(C, align(4096))]
#[derive(Debug)]
pub struct ArenaHeader {
    pub magic: u32,
    pub version: u32,
    pub req_head: AtomicU64,
    pub req_tail: AtomicU64,
    pub rsp_head: AtomicU64,
    pub rsp_tail: AtomicU64,
    pub signal_epoch: AtomicU64,
    pad: [u8; HEADER_BYTES - 48],
}

impl ArenaHeader {
    pub const fn empty() -> Self {
        Self {
            magic: 0,
            version: 0,
            req_head: AtomicU64::new(0),
            req_tail: AtomicU64::new(0),
            rsp_head: AtomicU64::new(0),
            rsp_tail: AtomicU64::new(0),
            signal_epoch: AtomicU64::new(0),
            pad: [0; HEADER_BYTES - 48],
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RequestSnapshot {
    pub op: u16,
    pub seq: u64,
    pub timestamp: u64,
    pub payload: Vec<u8>,
}

#[derive(Error, Debug)]
pub enum ArenaError {
    #[error("arena I/O error: {0}")]
    Io(#[from] io::Error),
    #[error("request ring full (head={head}, tail={tail})")]
    RingFull { head: u64, tail: u64 },
    #[error("payload too large: {len} > {max}")]
    PayloadTooLarge { len: usize, max: usize },
    #[error("arena sequence not ready: {0}")]
    SequenceNotReady(u64),
}

pub struct MappedArena {
    mmap: MmapMut,
    path: PathBuf,
}

// SAFETY: The mmap is file-backed shared memory. Mutable access in this module
// is restricted to `&mut self`; cross-process coordination is through atomics.
unsafe impl Send for MappedArena {}

impl MappedArena {
    pub const SIZE: usize = HEADER_BYTES
        + SLOT_COUNT * std::mem::size_of::<RequestSlot>()
        + SLOT_COUNT * std::mem::size_of::<ResponseSlot>();

    pub fn open_or_create(path: &Path) -> Result<Self, ArenaError> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(path)?;
        if file.metadata()?.len() < Self::SIZE as u64 {
            file.set_len(Self::SIZE as u64)?;
        }

        // SAFETY: the file is opened read-write and sized to the full arena.
        let mmap = unsafe { MmapOptions::new().len(Self::SIZE).map_mut(&file)? };
        let mut mapped = Self {
            mmap,
            path: path.to_path_buf(),
        };
        if !mapped.header_is_valid() {
            mapped.initialize();
        }
        Ok(mapped)
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn flush(&self) -> Result<(), ArenaError> {
        self.mmap.flush()?;
        Ok(())
    }

    pub fn header(&self) -> &ArenaHeader {
        // SAFETY: the mmap is at least HEADER_BYTES and begins with ArenaHeader.
        unsafe { &*self.mmap.as_ptr().cast::<ArenaHeader>() }
    }

    pub fn submit_request(&mut self, mut slot: RequestSlot) -> Result<u64, ArenaError> {
        let head = self.header().req_head.load(Ordering::Relaxed);
        let tail = self.header().req_tail.load(Ordering::Acquire);
        if head.wrapping_sub(tail) >= SLOT_COUNT as u64 {
            return Err(ArenaError::RingFull { head, tail });
        }

        let seq = head.wrapping_add(1);
        let idx = (head % SLOT_COUNT as u64) as usize;
        slot.seq = seq;
        slot.state.store(STATE_READY, Ordering::Release);

        // SAFETY: idx is ring-bounded and this method has &mut self, making this
        // process the single writer for the chosen slot.
        unsafe {
            std::ptr::write(self.request_slot_mut(idx), slot);
        }
        self.header().req_head.store(seq, Ordering::Release);
        Ok(seq)
    }

    pub fn request_snapshot(&self, seq: u64) -> Option<RequestSnapshot> {
        if seq == 0 {
            return None;
        }
        let idx = ((seq - 1) % SLOT_COUNT as u64) as usize;
        let slot = self.request_slot(idx);
        if slot.seq != seq || slot.state.load(Ordering::Acquire) != STATE_READY {
            return None;
        }
        let payload_len = (slot.payload_len as usize).min(INLINE_REQ_BYTES);
        Some(RequestSnapshot {
            op: slot.op,
            seq: slot.seq,
            timestamp: slot.timestamp,
            payload: slot.payload[..payload_len].to_vec(),
        })
    }

    pub fn mark_request_consumed(&mut self, seq: u64) -> Result<(), ArenaError> {
        let idx = ((seq.saturating_sub(1)) % SLOT_COUNT as u64) as usize;
        let slot = self.request_slot(idx);
        if seq == 0 || slot.seq != seq || slot.state.load(Ordering::Acquire) != STATE_READY {
            return Err(ArenaError::SequenceNotReady(seq));
        }
        slot.state.store(STATE_CONSUMED, Ordering::Release);
        self.header().req_tail.store(seq, Ordering::Release);
        Ok(())
    }

    fn header_is_valid(&self) -> bool {
        self.header().magic == ARENA_MAGIC && self.header().version == ARENA_VERSION
    }

    fn initialize(&mut self) {
        self.mmap.fill(0);
        let header = self.header_mut();
        header.magic = ARENA_MAGIC;
        header.version = ARENA_VERSION;
        fence(Ordering::SeqCst);
    }

    fn header_mut(&mut self) -> &mut ArenaHeader {
        // SAFETY: the mmap is at least HEADER_BYTES and begins with ArenaHeader.
        unsafe { &mut *self.mmap.as_mut_ptr().cast::<ArenaHeader>() }
    }

    fn request_slot(&self, idx: usize) -> &RequestSlot {
        debug_assert!(idx < SLOT_COUNT);
        // SAFETY: request slots start after the header and idx is bounded.
        unsafe { &*self.request_slot_ptr(idx).cast_const() }
    }

    unsafe fn request_slot_mut(&mut self, idx: usize) -> *mut RequestSlot {
        debug_assert!(idx < SLOT_COUNT);
        self.request_slot_ptr(idx)
    }

    fn request_slot_ptr(&self, idx: usize) -> *mut RequestSlot {
        let offset = HEADER_BYTES + idx * std::mem::size_of::<RequestSlot>();
        // SAFETY: pointer arithmetic stays inside the mmap by construction.
        unsafe { self.mmap.as_ptr().add(offset).cast::<RequestSlot>() as *mut RequestSlot }
    }
}
