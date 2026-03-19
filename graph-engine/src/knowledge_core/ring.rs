use std::fmt;
use std::mem::{offset_of, size_of};
use std::ptr::{self, NonNull};
use std::sync::atomic::{AtomicU64, Ordering};

use rkyv::api::high::to_bytes_in;
use rkyv::rancor::{Error as RkyvError, Source as _};
use rkyv::ser::{Positional, Writer};

use super::archived::QueryDiffEnvelope;

pub const CACHE_LINE_BYTES: usize = 128;
pub const DEFAULT_SLOT_COUNT: usize = 256;
pub const DEFAULT_SLOT_PAYLOAD_BYTES: usize = 64 * 1024;
const SLOT_ALIGNMENT: usize = 64;

#[derive(Debug)]
pub enum RingError {
    MapFailed,
    InvalidCapacity,
    PayloadTooLarge { len: usize, max: usize },
    Full,
    Serialization(String),
}

#[repr(C, align(128))]
struct CachePaddedAtomicU64 {
    value: AtomicU64,
}

impl CachePaddedAtomicU64 {
    const fn new(value: u64) -> Self {
        Self {
            value: AtomicU64::new(value),
        }
    }

    fn load(&self, ordering: Ordering) -> u64 {
        self.value.load(ordering)
    }

    fn store(&self, value: u64, ordering: Ordering) {
        self.value.store(value, ordering);
    }
}

#[repr(C)]
struct SharedRingHeader {
    head: CachePaddedAtomicU64,
    tail: CachePaddedAtomicU64,
    slot_count: u32,
    slot_payload_bytes: u32,
    slot_stride: u64,
    slots_offset: u64,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct RingLayout {
    pub head_offset: u64,
    pub tail_offset: u64,
    pub slots_offset: u64,
    pub slot_stride: u64,
    pub slot_payload_offset: u64,
    pub slot_count: u32,
    pub slot_payload_bytes: u32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct SharedRegionView {
    pub ptr: *mut u8,
    pub len: u64,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct SlotHeader {
    pub len: u32,
    pub kind: u16,
    pub flags: u16,
    pub version: u64,
}

const _: () = {
    assert!(size_of::<CachePaddedAtomicU64>() == CACHE_LINE_BYTES);
    assert!(std::mem::align_of::<CachePaddedAtomicU64>() == CACHE_LINE_BYTES);
    assert!(offset_of!(SharedRingHeader, head) == 0);
    assert!(offset_of!(SharedRingHeader, tail) == CACHE_LINE_BYTES);
};

#[derive(Debug)]
struct SlotCapacityExceeded;

impl fmt::Display for SlotCapacityExceeded {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("serialized payload exceeded ring slot capacity")
    }
}

impl std::error::Error for SlotCapacityExceeded {}

struct SlotWriter {
    ptr: *mut u8,
    len: usize,
    capacity: usize,
    required_len: usize,
    overflowed: bool,
}

impl SlotWriter {
    fn new(ptr: *mut u8, capacity: usize) -> Self {
        Self {
            ptr,
            len: 0,
            capacity,
            required_len: 0,
            overflowed: false,
        }
    }

    fn required_len(&self) -> usize {
        self.required_len.max(self.len)
    }

    fn overflowed(&self) -> bool {
        self.overflowed
    }
}

impl Positional for SlotWriter {
    fn pos(&self) -> usize {
        self.len
    }
}

impl Writer<RkyvError> for SlotWriter {
    fn write(&mut self, bytes: &[u8]) -> Result<(), RkyvError> {
        let next_len = self.len.saturating_add(bytes.len());
        self.required_len = next_len;
        if next_len > self.capacity {
            self.overflowed = true;
            return Err(RkyvError::new(SlotCapacityExceeded));
        }

        // SAFETY: `self.ptr` points to the reserved slot payload, and the
        // bounds check above guarantees that `next_len <= self.capacity`.
        unsafe {
            ptr::copy_nonoverlapping(bytes.as_ptr(), self.ptr.add(self.len), bytes.len());
        }
        self.len = next_len;
        Ok(())
    }
}

struct MmapRegion {
    ptr: NonNull<u8>,
    len: usize,
}

impl MmapRegion {
    fn new(len: usize) -> Result<Self, RingError> {
        if len == 0 {
            return Err(RingError::InvalidCapacity);
        }
        let ptr = unsafe {
            libc::mmap(
                ptr::null_mut(),
                len,
                libc::PROT_READ | libc::PROT_WRITE,
                libc::MAP_ANON | libc::MAP_SHARED,
                -1,
                0,
            )
        };
        if ptr == libc::MAP_FAILED {
            return Err(RingError::MapFailed);
        }
        Ok(Self {
            ptr: NonNull::new(ptr.cast::<u8>()).ok_or(RingError::MapFailed)?,
            len,
        })
    }
}

impl Drop for MmapRegion {
    fn drop(&mut self) {
        unsafe {
            libc::munmap(self.ptr.as_ptr().cast(), self.len);
        }
    }
}

pub struct SharedRingBuffer {
    region: MmapRegion,
    slots_offset: usize,
    slot_stride: usize,
    slot_payload_bytes: usize,
    slot_count: usize,
}

impl SharedRingBuffer {
    pub fn new(slot_count: usize, slot_payload_bytes: usize) -> Result<Self, RingError> {
        let slot_count = slot_count.max(1);
        let slot_payload_bytes = slot_payload_bytes.max(256);
        let header_size = align_up(size_of::<SharedRingHeader>(), SLOT_ALIGNMENT);
        let slot_stride = align_up(size_of::<SlotHeader>() + slot_payload_bytes, SLOT_ALIGNMENT);
        let total_len = header_size
            .checked_add(
                slot_stride
                    .checked_mul(slot_count)
                    .ok_or(RingError::InvalidCapacity)?,
            )
            .ok_or(RingError::InvalidCapacity)?;
        let region = MmapRegion::new(total_len)?;
        let ring = Self {
            region,
            slots_offset: header_size,
            slot_stride,
            slot_payload_bytes,
            slot_count,
        };
        ring.debug_assert_layout();
        ring.initialize_header();
        Ok(ring)
    }

    pub fn shared_region(&self) -> SharedRegionView {
        SharedRegionView {
            ptr: self.region.ptr.as_ptr(),
            len: self.region.len as u64,
        }
    }

    pub fn layout(&self) -> RingLayout {
        RingLayout {
            head_offset: 0,
            tail_offset: size_of::<CachePaddedAtomicU64>() as u64,
            slots_offset: self.slots_offset as u64,
            slot_stride: self.slot_stride as u64,
            slot_payload_offset: size_of::<SlotHeader>() as u64,
            slot_count: self.slot_count as u32,
            slot_payload_bytes: self.slot_payload_bytes as u32,
        }
    }

    pub fn load_head(&self) -> u64 {
        self.header().head.load(Ordering::Acquire)
    }

    pub fn load_tail(&self) -> u64 {
        self.header().tail.load(Ordering::Acquire)
    }

    pub fn store_tail(&self, tail: u64) {
        self.header().tail.store(tail, Ordering::Release);
    }

    pub fn write_frame(&self, kind: u16, version: u64, payload: &[u8]) -> Result<(), RingError> {
        if payload.len() > self.slot_payload_bytes {
            return Err(RingError::PayloadTooLarge {
                len: payload.len(),
                max: self.slot_payload_bytes,
            });
        }
        let head = self.load_head();
        let tail = self.load_tail();
        if head.wrapping_sub(tail) >= self.slot_count as u64 {
            return Err(RingError::Full);
        }

        let slot_index = (head % self.slot_count as u64) as usize;
        let slot_ptr = self.slot_ptr(slot_index);
        unsafe {
            let header_ptr = slot_ptr.cast::<SlotHeader>();
            let payload_ptr = slot_ptr.add(size_of::<SlotHeader>());
            ptr::copy_nonoverlapping(payload.as_ptr(), payload_ptr, payload.len());
            ptr::write(
                header_ptr,
                SlotHeader {
                    len: payload.len() as u32,
                    kind,
                    flags: 0,
                    version,
                },
            );
        }
        self.header().head.store(head + 1, Ordering::Release);
        Ok(())
    }

    pub(crate) fn write_archived_frame(
        &self,
        kind: u16,
        version: u64,
        value: &QueryDiffEnvelope,
    ) -> Result<(), RingError> {
        let head = self.load_head();
        let tail = self.load_tail();
        if head.wrapping_sub(tail) >= self.slot_count as u64 {
            return Err(RingError::Full);
        }

        let slot_index = (head % self.slot_count as u64) as usize;
        let slot_ptr = self.slot_ptr(slot_index);
        let payload_ptr = unsafe { slot_ptr.add(size_of::<SlotHeader>()) };
        let mut writer = SlotWriter::new(payload_ptr, self.slot_payload_bytes);
        if let Err(error) = to_bytes_in::<&mut SlotWriter, RkyvError>(value, &mut writer) {
            if writer.overflowed() {
                return Err(RingError::PayloadTooLarge {
                    len: writer.required_len(),
                    max: self.slot_payload_bytes,
                });
            }
            return Err(RingError::Serialization(error.to_string()));
        }

        unsafe {
            ptr::write(
                slot_ptr.cast::<SlotHeader>(),
                SlotHeader {
                    len: writer.pos() as u32,
                    kind,
                    flags: 0,
                    version,
                },
            );
        }
        self.header().head.store(head + 1, Ordering::Release);
        Ok(())
    }

    #[cfg(test)]
    fn copy_slot(&self, sequence: u64) -> Option<(SlotHeader, Vec<u8>)> {
        let head = self.load_head();
        let tail = self.load_tail();
        if sequence < tail || sequence >= head {
            return None;
        }
        let slot_index = (sequence % self.slot_count as u64) as usize;
        let slot_ptr = self.slot_ptr(slot_index);
        unsafe {
            let header = ptr::read(slot_ptr.cast::<SlotHeader>());
            let payload_ptr = slot_ptr.add(size_of::<SlotHeader>());
            let payload = std::slice::from_raw_parts(payload_ptr, header.len as usize).to_vec();
            Some((header, payload))
        }
    }

    fn initialize_header(&self) {
        unsafe {
            ptr::write_bytes(self.region.ptr.as_ptr(), 0, self.region.len);
            ptr::write(
                self.region.ptr.as_ptr().cast::<SharedRingHeader>(),
                SharedRingHeader {
                    head: CachePaddedAtomicU64::new(0),
                    tail: CachePaddedAtomicU64::new(0),
                    slot_count: self.slot_count as u32,
                    slot_payload_bytes: self.slot_payload_bytes as u32,
                    slot_stride: self.slot_stride as u64,
                    slots_offset: self.slots_offset as u64,
                },
            );
        }
    }

    fn debug_assert_layout(&self) {
        debug_assert_eq!(
            std::mem::align_of::<CachePaddedAtomicU64>(),
            CACHE_LINE_BYTES
        );
        debug_assert_eq!(size_of::<CachePaddedAtomicU64>(), CACHE_LINE_BYTES);
        debug_assert_eq!(offset_of!(SharedRingHeader, head), 0);
        debug_assert_eq!(offset_of!(SharedRingHeader, tail), CACHE_LINE_BYTES);
        debug_assert_eq!(self.layout().head_offset, 0);
        debug_assert_eq!(
            self.layout().tail_offset,
            size_of::<CachePaddedAtomicU64>() as u64
        );
        debug_assert_eq!(
            self.layout().slot_payload_offset,
            size_of::<SlotHeader>() as u64
        );
        debug_assert_eq!(self.slots_offset % SLOT_ALIGNMENT, 0);
        debug_assert_eq!(self.slot_stride % SLOT_ALIGNMENT, 0);
    }

    fn header(&self) -> &SharedRingHeader {
        unsafe { &*self.region.ptr.as_ptr().cast::<SharedRingHeader>() }
    }

    fn slot_ptr(&self, slot_index: usize) -> *mut u8 {
        unsafe {
            self.region
                .ptr
                .as_ptr()
                .add(self.slots_offset + (slot_index * self.slot_stride))
        }
    }
}

const fn align_up(value: usize, alignment: usize) -> usize {
    let mask = alignment - 1;
    (value + mask) & !mask
}

#[cfg(test)]
mod tests {
    use std::hint::black_box;
    use std::mem::size_of;
    use std::time::Instant;

    use rkyv::{from_bytes, rancor::Error as RkyvError, to_bytes};

    use super::{CACHE_LINE_BYTES, SharedRingBuffer, SlotHeader};
    use crate::knowledge_core::archived::{
        BlockRow, QueryDiffEnvelope, QueryRow, SubscriptionKind,
    };

    #[test]
    fn slot_write_roundtrips() {
        let ring = SharedRingBuffer::new(4, 256).expect("ring should map");
        ring.write_frame(7, 42, b"hello")
            .expect("frame should write");

        assert_eq!(ring.load_head(), 1);
        assert_eq!(ring.load_tail(), 0);

        let (header, payload) = ring.copy_slot(0).expect("slot should be readable");
        assert_eq!(
            header,
            SlotHeader {
                len: 5,
                kind: 7,
                flags: 0,
                version: 42,
            }
        );
        assert_eq!(payload, b"hello");
    }

    #[test]
    fn layout_keeps_head_and_tail_on_separate_cache_lines() {
        let ring = SharedRingBuffer::new(4, 256).expect("ring should map");
        let layout = ring.layout();
        assert_eq!(layout.head_offset, 0);
        assert_eq!(layout.tail_offset, CACHE_LINE_BYTES as u64);
        assert_eq!(layout.slot_payload_offset, size_of::<SlotHeader>() as u64);
    }

    #[test]
    fn archived_frame_roundtrips_without_intermediate_buffer() {
        let ring = SharedRingBuffer::new(4, 1024).expect("ring should map");
        let diff = QueryDiffEnvelope {
            tx_id: 7,
            subscription_id: 11,
            kind: SubscriptionKind::Outline,
            added: vec![QueryRow::Block(BlockRow {
                page_id: "page-a".to_string(),
                block_id: "block-a".to_string(),
                parent_id: String::new(),
                order_key: "a1".to_string(),
                depth: 0,
                content: "hello".to_string(),
            })],
            updated: Vec::new(),
            removed: Vec::new(),
        };

        ring.write_archived_frame(diff.kind.code(), diff.tx_id, &diff)
            .expect("archived frame should write");

        let (header, payload) = ring.copy_slot(0).expect("slot should be readable");
        assert_eq!(header.version, diff.tx_id);
        assert_eq!(header.kind, diff.kind.code());
        let decoded =
            from_bytes::<QueryDiffEnvelope, RkyvError>(&payload).expect("payload should decode");
        assert_eq!(decoded, diff);
    }

    #[test]
    fn archived_frame_rejects_oversized_payload_without_advancing_head() {
        let ring = SharedRingBuffer::new(2, 256).expect("ring should map");
        let diff = QueryDiffEnvelope {
            tx_id: 9,
            subscription_id: 12,
            kind: SubscriptionKind::Outline,
            added: vec![QueryRow::Block(BlockRow {
                page_id: "page".repeat(64),
                block_id: "block".repeat(64),
                parent_id: String::new(),
                order_key: "ord".repeat(64),
                depth: 0,
                content: "payload".repeat(128),
            })],
            updated: Vec::new(),
            removed: Vec::new(),
        };

        let result = ring.write_archived_frame(diff.kind.code(), diff.tx_id, &diff);
        assert!(matches!(
            result,
            Err(super::RingError::PayloadTooLarge { .. })
        ));
        assert_eq!(ring.load_head(), 0);
        assert_eq!(ring.load_tail(), 0);
    }

    #[test]
    fn full_ring_returns_error_without_overwrite() {
        let ring = SharedRingBuffer::new(1, 256).expect("ring should map");
        ring.write_frame(1, 1, b"first")
            .expect("first write should fit");
        let result = ring.write_frame(2, 2, b"second");
        assert!(matches!(result, Err(super::RingError::Full)));

        let (header, payload) = ring.copy_slot(0).expect("first slot should remain");
        assert_eq!(header.kind, 1);
        assert_eq!(payload, b"first");
        assert_eq!(ring.load_head(), 1);
        assert_eq!(ring.load_tail(), 0);
    }

    #[test]
    fn advancing_tail_recovers_capacity_after_full() {
        let ring = SharedRingBuffer::new(1, 256).expect("ring should map");
        ring.write_frame(1, 1, b"first")
            .expect("first write should fit");
        assert!(matches!(
            ring.write_frame(2, 2, b"second"),
            Err(super::RingError::Full)
        ));

        ring.store_tail(1);
        ring.write_frame(3, 3, b"third")
            .expect("capacity should recover after tail advances");

        let (header, payload) = ring.copy_slot(1).expect("new slot should be readable");
        assert_eq!(header.kind, 3);
        assert_eq!(payload, b"third");
        assert_eq!(ring.load_head(), 2);
        assert_eq!(ring.load_tail(), 1);
    }

    #[test]
    #[ignore = "benchmark"]
    fn benchmark_archived_write_vs_temp_buffer_path() {
        let iterations = 20_000u64;
        let ring = SharedRingBuffer::new(1024, 4096).expect("ring should map");
        let diff = QueryDiffEnvelope {
            tx_id: 7,
            subscription_id: 11,
            kind: SubscriptionKind::Outline,
            added: vec![QueryRow::Block(BlockRow {
                page_id: "page-a".to_string(),
                block_id: "block-a".to_string(),
                parent_id: String::new(),
                order_key: "a1".to_string(),
                depth: 0,
                content: "hello world".repeat(8),
            })],
            updated: Vec::new(),
            removed: Vec::new(),
        };

        let start_old = Instant::now();
        for version in 0..iterations {
            let bytes = to_bytes::<RkyvError>(black_box(&diff)).expect("payload should serialize");
            ring.write_frame(diff.kind.code(), version, bytes.as_ref())
                .expect("temp-buffer write should fit");
            ring.store_tail(ring.load_head());
        }
        let old_elapsed = start_old.elapsed();

        let start_new = Instant::now();
        for version in 0..iterations {
            ring.write_archived_frame(diff.kind.code(), version, black_box(&diff))
                .expect("direct archive write should fit");
            ring.store_tail(ring.load_head());
        }
        let new_elapsed = start_new.elapsed();

        let old_ns_per_write = old_elapsed.as_nanos() / u128::from(iterations);
        let new_ns_per_write = new_elapsed.as_nanos() / u128::from(iterations);
        eprintln!(
            "knowledge_core_ring_write old_ns_per_write={} new_ns_per_write={} speedup_x={:.2}",
            old_ns_per_write,
            new_ns_per_write,
            old_elapsed.as_secs_f64() / new_elapsed.as_secs_f64()
        );
    }
}
