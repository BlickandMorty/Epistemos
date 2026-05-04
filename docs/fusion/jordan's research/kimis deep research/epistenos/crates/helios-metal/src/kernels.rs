use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2_metal::{
    MTLCommandBuffer, MTLComputeCommandEncoder, MTLComputePipelineState, MTLSize,
};
use std::ptr::NonNull;
use tracing::{debug, trace};

use crate::device::MetalBuffer;
use crate::pipeline::ComputePipeline;

// ============================================================================
// ThreadgroupConfig
// ============================================================================

/// Automatic threadgroup-size calculation based on pipeline limits.
///
/// Apple Silicon prefers threadgroup sizes that are multiples of 32
/// (the SIMD-group width) up to the pipeline's `maxTotalThreadsPerThreadgroup`.
#[derive(Debug, Clone, Copy)]
pub struct ThreadgroupConfig {
    pub x: u64,
    pub y: u64,
    pub z: u64,
}

impl ThreadgroupConfig {
    /// Compute an optimal 1-D threadgroup size.
    ///
    /// Returns a size that is:
    /// * A multiple of `alignment` (default 32)
    /// * No larger than `max_threads`
    /// * A power-of-two friendly value (256 is typical sweet spot on AS)
    pub fn for_1d(pipeline: &ComputePipeline) -> Self {
        let max_threads = pipeline.max_threads_per_threadgroup();
        let alignment = pipeline.threadgroup_size_alignment();

        // Heuristic: use 256 threads per group for 1-D kernels on Apple Silicon.
        let mut tg = 256usize;
        tg = tg.min(max_threads);
        tg = (tg / alignment) * alignment; // round down to multiple of alignment
        tg = tg.max(alignment);              // at least one SIMD group

        Self {
            x: tg as u64,
            y: 1,
            z: 1,
        }
    }

    /// Compute a 2-D threadgroup size.
    ///
    /// Distributes threads across X and Y while keeping total within limits.
    pub fn for_2d(pipeline: &ComputePipeline, preferred_x: usize) -> Self {
        let max_threads = pipeline.max_threads_per_threadgroup();
        let alignment = pipeline.threadgroup_size_alignment();

        let mut x = preferred_x.min(max_threads);
        x = (x / alignment) * alignment;
        x = x.max(alignment);

        let mut y = max_threads / x;
        y = y.max(1);

        // Ensure total does not exceed limit
        while x * y > max_threads {
            if y > 1 {
                y -= 1;
            } else {
                x -= alignment;
            }
        }

        Self {
            x: x as u64,
            y: y as u64,
            z: 1,
        }
    }

    pub fn total(&self) -> u64 {
        self.x * self.y * self.z
    }
}

// ============================================================================
// KernelDispatch
// ============================================================================

/// High-level kernel dispatch helper.
///
/// This struct holds a command buffer reference and provides ergonomic
/// methods to set pipeline, buffers, and thread counts before dispatch.
pub struct KernelDispatch<'a> {
    encoder: Retained<ProtocolObject<dyn MTLComputeCommandEncoder>>,
    _marker: std::marker::PhantomData<&'a ()>,
}

impl<'a> KernelDispatch<'a> {
    /// Begin encoding on a command buffer.
    pub fn new(cmdbuf: &'a ProtocolObject<dyn MTLCommandBuffer>) -> Self {
        let encoder = unsafe { cmdbuf.computeCommandEncoder() };
        let encoder = encoder.expect("failed to create compute command encoder");
        Self {
            encoder,
            _marker: std::marker::PhantomData,
        }
    }

    /// Set the compute pipeline state.
    pub fn set_pipeline(&self, pipeline: &ComputePipeline) {
        unsafe {
            self.encoder.setComputePipelineState(pipeline.raw());
        }
    }

    /// Set a buffer at the given index.
    pub fn set_buffer(&self, index: usize, buffer: &MetalBuffer, offset: usize) {
        unsafe {
            self.encoder.setBuffer_offset_atIndex(
                Some(buffer.raw()),
                offset,
                index,
            );
        }
    }

    /// Set multiple buffers starting at index 0.
    pub fn set_buffers(&self, buffers: &[&MetalBuffer]) {
        for (i, buf) in buffers.iter().enumerate() {
            self.set_buffer(i, buf, 0);
        }
    }

    /// Dispatch threads with the specified grid and threadgroup sizes.
    pub fn dispatch_threads(&self, grid: MTLSize, threadgroup: MTLSize) {
        trace!(
            "dispatch: grid=({}, {}, {}) tg=({}, {}, {})",
            grid.width, grid.height, grid.depth,
            threadgroup.width, threadgroup.height, threadgroup.depth
        );
        self.encoder.dispatchThreads_threadsPerThreadgroup(grid, threadgroup);
    }

    /// End encoding.
    pub fn end_encoding(self) {
        unsafe { self.encoder.endEncoding() }
    }
}

// ============================================================================
// Convenience dispatch functions
// ============================================================================

/// Dispatch a 1-D kernel with automatic threadgroup sizing.
///
/// # Arguments
/// * `cmdbuf` — command buffer to encode into
/// * `pipeline` — compiled compute pipeline
/// * `buffers` — buffers to bind at indices 0, 1, 2, ...
/// * `thread_count` — total number of threads in the grid
///
/// # Example
/// ```rust,ignore
/// dispatch_1d(&cmdbuf, &pipeline, &[&buf_a, &buf_b], 1024);
/// ```
pub fn dispatch_1d(
    cmdbuf: &ProtocolObject<dyn MTLCommandBuffer>,
    pipeline: &ComputePipeline,
    buffers: &[&MetalBuffer],
    thread_count: usize,
) {
    let tg = ThreadgroupConfig::for_1d(pipeline);
    let grid = MTLSize {
        width: thread_count as u64,
        height: 1,
        depth: 1,
    };
    let tg_size = MTLSize {
        width: tg.x,
        height: tg.y,
        depth: tg.z,
    };

    let dispatch = KernelDispatch::new(cmdbuf);
    dispatch.set_pipeline(pipeline);
    dispatch.set_buffers(buffers);
    dispatch.dispatch_threads(grid, tg_size);
    dispatch.end_encoding();

    debug!(
        "dispatched 1D kernel '{}' : threads={} tg={}",
        pipeline.function_name(),
        thread_count,
        tg.total()
    );
}

/// Dispatch a 2-D kernel with automatic threadgroup sizing.
///
/// # Arguments
/// * `cmdbuf` — command buffer to encode into
/// * `pipeline` — compiled compute pipeline
/// * `buffers` — buffers to bind at indices 0, 1, 2, ...
/// * `width` — grid width (X dimension)
/// * `height` — grid height (Y dimension)
///
/// # Example
/// ```rust,ignore
/// dispatch_2d(&cmdbuf, &pipeline, &[&buf_a, &buf_out], 512, 64);
/// ```
pub fn dispatch_2d(
    cmdbuf: &ProtocolObject<dyn MTLCommandBuffer>,
    pipeline: &ComputePipeline,
    buffers: &[&MetalBuffer],
    width: usize,
    height: usize,
) {
    let tg = ThreadgroupConfig::for_2d(pipeline, 16);
    let grid = MTLSize {
        width: width as u64,
        height: height as u64,
        depth: 1,
    };
    let tg_size = MTLSize {
        width: tg.x,
        height: tg.y,
        depth: tg.z,
    };

    let dispatch = KernelDispatch::new(cmdbuf);
    dispatch.set_pipeline(pipeline);
    dispatch.set_buffers(buffers);
    dispatch.dispatch_threads(grid, tg_size);
    dispatch.end_encoding();

    debug!(
        "dispatched 2D kernel '{}' : grid=({},{}) tg=({},{}) total_threads={}",
        pipeline.function_name(),
        width,
        height,
        tg.x,
        tg.y,
        width * height
    );
}

// ============================================================================
// Dispatch with constant arguments
// ============================================================================

/// Extension trait for setting small constant data (push constants).
///
/// Metal does not have Vulkan-style push constants, but small values can be
/// passed via `setBytes` which copies them into the command buffer.
pub trait SetBytesExt {
    /// Set raw bytes at a buffer index.
    fn set_bytes(&self, index: usize, bytes: &[u8]);
}

impl SetBytesExt for KernelDispatch<'_> {
    fn set_bytes(&self, index: usize, bytes: &[u8]) {
        let ptr = NonNull::new(bytes.as_ptr().cast_mut().cast()).unwrap();
        unsafe {
            self.encoder.setBytes_length_atIndex(
                ptr,
                bytes.len(),
                index,
            );
        }
    }
}

/// Dispatch a 1-D kernel with constant arguments (e.g., dimensions).
///
/// `constants` is a slice of `(buffer_index, byte_slice)` tuples that are
/// passed via `setBytes`.
pub fn dispatch_1d_with_constants(
    cmdbuf: &ProtocolObject<dyn MTLCommandBuffer>,
    pipeline: &ComputePipeline,
    buffers: &[&MetalBuffer],
    constants: &[(usize, &[u8])],
    thread_count: usize,
) {
    let tg = ThreadgroupConfig::for_1d(pipeline);
    let grid = MTLSize {
        width: thread_count as u64,
        height: 1,
        depth: 1,
    };
    let tg_size = MTLSize {
        width: tg.x,
        height: tg.y,
        depth: tg.z,
    };

    let dispatch = KernelDispatch::new(cmdbuf);
    dispatch.set_pipeline(pipeline);

    // Set buffers first
    dispatch.set_buffers(buffers);

    // Set constants at specified indices
    for (idx, bytes) in constants {
        dispatch.set_bytes(*idx, bytes);
    }

    dispatch.dispatch_threads(grid, tg_size);
    dispatch.end_encoding();
}
