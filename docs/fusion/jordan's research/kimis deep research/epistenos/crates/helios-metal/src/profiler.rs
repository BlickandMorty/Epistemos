use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2_metal::{
    MTLCommandBuffer, MTLCommandQueue, MTLComputeCommandEncoder, MTLDevice,
};
use std::time::{Duration, Instant};
use tracing::{debug, info};

use crate::device::{MetalDevice, MetalError, Result};

// ============================================================================
// MetricSnapshot
// ============================================================================

/// Snapshot of kernel execution metrics.
#[derive(Debug, Clone, Copy, Default)]
pub struct MetricSnapshot {
    /// Wall-clock time measured on CPU (includes queue submit latency).
    pub cpu_elapsed: Duration,
    /// GPU active time measured via timestamp counters (more accurate).
    pub gpu_elapsed: Option<Duration>,
    /// Estimated memory bandwidth achieved (GB/s).
    pub gbps: f64,
    /// Estimated throughput in tokens (elements) per second.
    pub tok_per_sec: f64,
    /// Estimated occupancy (fraction of theoretical peak occupancy).
    pub occupancy: f64,
    /// Number of threads dispatched.
    pub threads: u64,
}

impl MetricSnapshot {
    /// Print a human-readable summary.
    pub fn report(&self, label: &str) {
        info!(
            "[{}] cpu={:?} gpu={:?} gbps={:.2} tok/s={:.1e} occupancy={:.1}% threads={}",
            label,
            self.cpu_elapsed,
            self.gpu_elapsed,
            self.gbps,
            self.tok_per_sec,
            self.occupancy * 100.0,
            self.threads
        );
    }
}

// ============================================================================
// KernelProfiler
// ============================================================================

/// Captures GPU timestamps and derives throughput metrics.
///
/// Usage:
/// ```rust,ignore
/// let profiler = KernelProfiler::new(&device);
/// let snap = profiler.profile_kernel(|| {
///     // encode and commit kernel work
/// });
/// snap.report("my_kernel");
/// ```
pub struct KernelProfiler {
    queue: Retained<ProtocolObject<dyn MTLCommandQueue>>,
}

impl KernelProfiler {
    pub fn new(device: &MetalDevice) -> Self {
        let queue = unsafe { device.raw().newCommandQueue() };
        let queue = queue.expect("failed to create command queue for profiling");
        Self { queue }
    }

    /// Profile a kernel dispatch closure.
    ///
    /// The closure receives a fresh `MTLCommandBuffer` and should encode all
    /// work into it. The profiler commits the buffer, waits for completion,
    /// and samples GPU timestamps.
    pub fn profile_kernel<F>(&self, f: F) -> MetricSnapshot
    where
        F: FnOnce(&ProtocolObject<dyn MTLCommandBuffer>),
    {
        let start_cpu = Instant::now();

        let cmdbuf = unsafe { self.queue.commandBuffer() };
        let cmdbuf = cmdbuf.expect("failed to create command buffer");

        // Encode user work
        f(&cmdbuf);

        unsafe { cmdbuf.commit() };
        unsafe { cmdbuf.waitUntilCompleted() };

        let cpu_elapsed = start_cpu.elapsed();

        // Read GPU timestamps (CFTimeInterval = f64 seconds)
        let gpu_elapsed = {
            let start = unsafe { cmdbuf.GPUStartTime() };
            let end = unsafe { cmdbuf.GPUEndTime() };
            let secs = end - start;
            if secs > 0.0 {
                Some(Duration::from_secs_f64(secs))
            } else {
                None
            }
        };

        MetricSnapshot {
            cpu_elapsed,
            gpu_elapsed,
            gbps: 0.0,
            tok_per_sec: 0.0,
            occupancy: 0.0,
            threads: 0,
        }
    }

    /// Profile a kernel and estimate bandwidth from bytes transferred.
    ///
    /// `bytes_transferred` is the sum of read + write bytes touched by the
    /// kernel (a rough model).
    pub fn profile_with_bandwidth<F>(&self, bytes_transferred: u64, threads: u64, f: F) -> MetricSnapshot
    where
        F: FnOnce(&ProtocolObject<dyn MTLCommandBuffer>),
    {
        let mut snap = self.profile_kernel(f);
        snap.threads = threads;

        let elapsed_secs = snap
            .gpu_elapsed
            .unwrap_or(snap.cpu_elapsed)
            .as_secs_f64();

        if elapsed_secs > 0.0 {
            // Memory bandwidth model
            snap.gbps = (bytes_transferred as f64) / (elapsed_secs * 1e9);

            // Throughput model: one "token" = one thread output element
            snap.tok_per_sec = (threads as f64) / elapsed_secs;

            // Occupancy heuristic: Apple Silicon peak ~300-400 GB/s practical.
            const PEAK_GBPS: f64 = 300.0;
            snap.occupancy = (snap.gbps / PEAK_GBPS).clamp(0.0, 1.0);
        }

        snap
    }
}
