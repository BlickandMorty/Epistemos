use objc2::rc::{autoreleasepool, Retained};
use objc2::runtime::ProtocolObject;
use objc2_foundation::{NSArray, NSString};
use objc2_metal::{
    MTLBuffer, MTLDevice, MTLResourceOptions, MTLStorageMode,
};
use std::ptr::NonNull;
use std::sync::Arc;
use thiserror::Error;
use tracing::{error, info, trace};

/// Errors originating from Metal device or buffer operations.
#[derive(Error, Debug)]
pub enum MetalError {
    #[error("No Metal device available")]
    NoDevice,
    #[error("Buffer allocation failed: {0}")]
    BufferAllocation(String),
    #[error("Device does not support unified memory")]
    NoUnifiedMemory,
}

pub type Result<T> = std::result::Result<T, MetalError>;

// ============================================================================
// MetalDevice
// ============================================================================

/// Wrapper around `MTLDevice` providing safe Rust access.
///
/// The inner `Retained<ProtocolObject<dyn MTLDevice>>` is reference-counted
/// via Objective-C ARC rules and is `Send + Sync` because `MTLDevice` itself
/// is thread-safe for creation and query operations.
#[derive(Clone)]
pub struct MetalDevice {
    inner: Retained<ProtocolObject<dyn MTLDevice>>,
}

impl MetalDevice {
    /// Wrap an existing `MTLDevice` reference.
    pub fn new(device: Retained<ProtocolObject<dyn MTLDevice>>) -> Self {
        Self { inner: device }
    }

    /// Access the underlying `MTLDevice` protocol object.
    pub fn raw(&self) -> &ProtocolObject<dyn MTLDevice> {
        &self.inner
    }

    /// Returns the registry ID (stable across process lifetime).
    pub fn registry_id(&self) -> u64 {
        unsafe { self.inner.registryID() }
    }

    /// Returns the recommended working set size in bytes.
    pub fn recommended_max_working_set_size(&self) -> u64 {
        unsafe { self.inner.recommendedMaxWorkingSetSize() }
    }

    /// Check whether the device has unified memory (Apple Silicon = true).
    pub fn has_unified_memory(&self) -> bool {
        unsafe { self.inner.hasUnifiedMemory() }
    }

    /// Allocate a buffer of `size` bytes with shared storage mode.
    ///
    /// Shared storage allows both CPU and GPU to access the buffer without
    /// copies on Apple Silicon unified-memory architectures.
    pub fn new_buffer(&self, size: usize) -> Result<MetalBuffer> {
        let opts = MTLResourceOptions::StorageModeShared;
        let buf = unsafe {
            self.inner
                .newBufferWithLength_options(size, opts)
        };
        let buf = buf.ok_or_else(|| {
            MetalError::BufferAllocation(format!("failed to allocate {} bytes", size))
        })?;
        trace!("allocated Metal buffer: {} bytes", size);
        Ok(MetalBuffer::new(buf, size))
    }

    /// Allocate a buffer initialized from a byte slice.
    pub fn new_buffer_with_data(&self, data: &[u8]) -> Result<MetalBuffer> {
        let opts = MTLResourceOptions::StorageModeShared;
        let ptr = NonNull::new(data.as_ptr().cast_mut().cast()).unwrap();
        let buf = unsafe {
            self.inner
                .newBufferWithBytes_length_options(ptr, data.len(), opts)
        };
        let buf = buf.ok_or_else(|| {
            MetalError::BufferAllocation(format!(
                "failed to allocate buffer with {} bytes of initial data",
                data.len()
            ))
        })?;
        trace!("allocated Metal buffer with initial data: {} bytes", data.len());
        Ok(MetalBuffer::new(buf, data.len()))
    }
}

// ============================================================================
// get_default_device
// ============================================================================

/// Returns the default Metal device, or `None` if Metal is unavailable.
///
/// On macOS this queries the first device in `MTLCopyAllDevices()`.
/// On iOS this is the single system device.
pub fn get_default_device() -> Option<MetalDevice> {
    autoreleasepool(|_| {
        let devices = unsafe { objc2_metal::MTLCopyAllDevices() };
        let first: Option<Retained<ProtocolObject<dyn MTLDevice>>> =
            unsafe { devices.objectAtIndex(0) };
        first.map(|d| {
            info!(
                "selected Metal device: registry_id={} unified={}",
                unsafe { d.registryID() },
                unsafe { d.hasUnifiedMemory() }
            );
            MetalDevice::new(d)
        })
    })
}

// ============================================================================
// MetalBuffer
// ============================================================================

/// Safe wrapper around `MTLBuffer`.
///
/// On Apple Silicon with unified memory, `contents()` gives a direct CPU
/// pointer to the same physical memory the GPU accesses.
#[derive(Clone)]
pub struct MetalBuffer {
    inner: Retained<ProtocolObject<dyn MTLBuffer>>,
    len: usize,
}

impl MetalBuffer {
    pub fn new(buffer: Retained<ProtocolObject<dyn MTLBuffer>>, len: usize) -> Self {
        Self { inner: buffer, len }
    }

    pub fn raw(&self) -> &ProtocolObject<dyn MTLBuffer> {
        &self.inner
    }

    pub fn len(&self) -> usize {
        self.len
    }

    pub fn is_empty(&self) -> bool {
        self.len == 0
    }

    /// Returns a mutable pointer to the buffer contents (shared storage).
    ///
    /// # Safety
    /// The caller must ensure the GPU is not concurrently reading or writing
    /// the same memory region. Typical pattern: encode command, commit,
    /// wait for completion, then access via this pointer.
    pub fn contents_mut(&self) -> *mut u8 {
        unsafe { self.inner.contents().cast() }
    }

    /// Returns an immutable pointer to the buffer contents.
    pub fn contents(&self) -> *const u8 {
        self.contents_mut().cast_const()
    }

    /// Cast contents to a typed mutable slice after GPU work completes.
    pub fn as_mut_slice<T>(&self) -> &mut [T] {
        let ptr = self.contents_mut().cast::<T>();
        let count = self.len / std::mem::size_of::<T>();
        unsafe { std::slice::from_raw_parts_mut(ptr, count) }
    }

    /// Cast contents to a typed immutable slice.
    pub fn as_slice<T>(&self) -> &[T] {
        let ptr = self.contents().cast::<T>();
        let count = self.len / std::mem::size_of::<T>();
        unsafe { std::slice::from_raw_parts(ptr, count) }
    }
}
