use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2_metal::{
    MTLBuffer, MTLDevice, MTLHeap, MTLHeapDescriptor, MTLResourceOptions, MTLStorageMode,
};
use std::sync::{Arc, Mutex};
use tracing::{debug, trace, warn};

use crate::device::{MetalBuffer, MetalDevice, MetalError, Result};

// ============================================================================
// HeapAllocator
// ============================================================================

/// Wraps `MTLHeap` for efficient buffer suballocation and reuse.
///
/// On Apple Silicon, heaps with shared storage allow the CPU and GPU to
/// share the same physical backing without driver-level synchronization.
/// Suballocating from a pre-grown heap avoids repeated `vm_allocate`
/// overhead during inference loops.
pub struct HeapAllocator {
    inner: Retained<ProtocolObject<dyn MTLHeap>>,
    /// Total capacity of the heap in bytes.
    capacity: usize,
    /// Current high-water mark of allocated bytes (approximate).
    used: Mutex<usize>,
}

impl HeapAllocator {
    /// Create a heap with the given capacity on `device`.
    ///
    /// The heap uses `MTLStorageModeShared` for unified-memory access.
    pub fn new(device: &MetalDevice, capacity: usize) -> Result<Self> {
        let desc = MTLHeapDescriptor::new();
        desc.setSize(capacity as u64);
        desc.setStorageMode(MTLStorageMode::Shared);

        let heap = unsafe {
            device
                .raw()
                .newHeapWithDescriptor(&desc)
        };

        let heap = heap.ok_or_else(|| {
            MetalError::BufferAllocation(format!(
                "failed to create heap of {} bytes",
                capacity
            ))
        })?;

        debug!("created Metal heap: capacity={} bytes", capacity);
        Ok(HeapAllocator {
            inner: heap,
            capacity,
            used: Mutex::new(0),
        })
    }

    /// Allocate a buffer from the heap.
    ///
    /// The buffer is returned as a [`MetalBuffer`] wrapper. It remains valid
    /// as long as the heap is alive; dropping the heap invalidates all
    /// suballocated buffers.
    pub fn allocate_buffer(&self, size: usize) -> Result<MetalBuffer> {
        if size == 0 {
            return Err(MetalError::BufferAllocation(
                "cannot allocate zero-sized buffer".to_string(),
            ));
        }

        let buf = unsafe {
            self.inner.newBufferWithLength_options(
                size,
                MTLResourceOptions::StorageModeShared,
            )
        };

        let buf = buf.ok_or_else(|| {
            MetalError::BufferAllocation(format!(
                "heap allocation failed for {} bytes (capacity={})",
                size, self.capacity
            ))
        })?;

        {
            let mut used = self.used.lock().unwrap();
            *used += size;
            trace!(
                "heap alloc: {} bytes (used={}/{})",
                size,
                *used,
                self.capacity
            );
        }

        Ok(MetalBuffer::new(buf, size))
    }

    /// Return an approximate high-water usage in bytes.
    pub fn used_bytes(&self) -> usize {
        *self.used.lock().unwrap()
    }

    /// Return the heap capacity.
    pub fn capacity(&self) -> usize {
        self.capacity
    }

    /// Purge unused memory back to the OS (best-effort).
    pub fn purge(&self) {
        unsafe { self.inner.setPurgeableState(objc2_metal::MTLPurgeableState::Empty) };
    }

    pub fn raw(&self) -> &ProtocolObject<dyn MTLHeap> {
        &self.inner
    }
}

// ============================================================================
// ResidencyHeap
// ============================================================================

/// Tracks hot/cold residency for L2 memory tier.
///
/// This is a **stub** with TODOs for the `MTLResidencySet` API, which is
/// only available on macOS 15+ / iOS 18+. On older OS versions the residency
/// tracking is emulated in software by reference-counting buffer access
/// patterns.
///
/// The residency set concept allows the GPU to fault in only the buffers
/// that are "resident" for a given command buffer, reducing memory pressure
/// when the working set exceeds physical RAM.
pub struct ResidencyHeap {
    heap: HeapAllocator,
    /// Buffers marked as currently resident (hot).
    hot_buffers: Mutex<Vec<Arc<MetalBuffer>>>,
    /// Buffers that can be evicted (cold).
    cold_buffers: Mutex<Vec<Arc<MetalBuffer>>>,
}

impl ResidencyHeap {
    pub fn new(device: &MetalDevice, capacity: usize) -> Result<Self> {
        let heap = HeapAllocator::new(device, capacity)?;
        Ok(ResidencyHeap {
            heap,
            hot_buffers: Mutex::new(Vec::new()),
            cold_buffers: Mutex::new(Vec::new()),
        })
    }

    /// Allocate a buffer and immediately mark it hot.
    pub fn allocate_hot(&self, size: usize) -> Result<Arc<MetalBuffer>> {
        let buf = Arc::new(self.heap.allocate_buffer(size)?);
        self.hot_buffers.lock().unwrap().push(Arc::clone(&buf));
        trace!("residency: allocated hot buffer: {} bytes", size);
        Ok(buf)
    }

    /// Allocate a buffer and mark it cold (evictable).
    pub fn allocate_cold(&self, size: usize) -> Result<Arc<MetalBuffer>> {
        let buf = Arc::new(self.heap.allocate_buffer(size)?);
        self.cold_buffers.lock().unwrap().push(Arc::clone(&buf));
        trace!("residency: allocated cold buffer: {} bytes", size);
        Ok(buf)
    }

    /// Promote a cold buffer to hot (e.g., prefetch for upcoming layer).
    pub fn promote_to_hot(&self, buf: &Arc<MetalBuffer>) {
        let mut cold = self.cold_buffers.lock().unwrap();
        cold.retain(|b| !Arc::ptr_eq(b, buf));
        let mut hot = self.hot_buffers.lock().unwrap();
        if !hot.iter().any(|b| Arc::ptr_eq(b, buf)) {
            hot.push(Arc::clone(buf));
        }
    }

    /// Evict a hot buffer to cold.
    pub fn demote_to_cold(&self, buf: &Arc<MetalBuffer>) {
        let mut hot = self.hot_buffers.lock().unwrap();
        hot.retain(|b| !Arc::ptr_eq(b, buf));
        let mut cold = self.cold_buffers.lock().unwrap();
        if !cold.iter().any(|b| Arc::ptr_eq(b, buf)) {
            cold.push(Arc::clone(buf));
        }
    }

    /// TODO: Integrate `MTLResidencySet` when targeting macOS 15+.
    /// The residency set API allows the GPU to page-fault buffers in/out
    /// automatically based on command-buffer needs.
    pub fn set_residency_hint(&self, _hint: &str) {
        // Stub: no-op until MTLResidencySet is bound in objc2-metal.
        warn!("ResidencyHeap::set_residency_hint is a stub; MTLResidencySet not yet available");
    }

    pub fn heap(&self) -> &HeapAllocator {
        &self.heap
    }
}
