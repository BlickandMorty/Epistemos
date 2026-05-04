//! `helios-metal` — Metal kernels and dispatch for Apple Silicon.
//!
//! This crate is the performance heart of Epistenos. It provides:
//!
//! * **Device management** — [`MetalDevice`] wraps `MTLDevice` with automatic
//!   default-device selection and unified-memory buffer allocation.
//!
//! * **Pipeline compilation** — [`KernelLibrary`] compiles MSL source at
//!   runtime via [`compile_kernel`](pipeline::compile_kernel). A [`KernelCache`]
//!   provides LRU caching keyed by source hash so kernels are only compiled
//!   once per process lifetime.
//!
//! * **Heap allocation** — [`HeapAllocator`] wraps `MTLHeap` for efficient
//!   suballocation and buffer reuse, reducing driver allocation overhead.
//!
//! * **Kernel dispatch** — [`KernelDispatch`] abstracts 1-D and 2-D compute
//!   dispatches with automatic threadgroup-size calculation from
//!   pipeline-state limits.
//!
//! * **Profiling** — [`KernelProfiler`] captures GPU timestamps and derives
//!   throughput metrics (tokens/s, GB/s, occupancy estimates).
//!
//! ## Kernel architecture
//!
//! Kernels are organized into three tiers that map to the Epistenos
//! abstraction layers:
//!
//! | Tier | Kernels | Purpose |
//! |------|---------|---------|
//! | L0 (elemental) | `eml_softmax_lse` | Fused softmax with eml primitive |
//! | L1 (structural) | `ternary_gemv`, `ternary_proj_residual`, `sherry_pack` | Compressed linear algebra |
//! | L2 (memory) | `count_sketch_update`, `kv_fingerprint` | Approximate memory shadows |
//! | L_SE (self-evolving) | `surprise_grad_step`, `dora_apply` | Online adaptation |
//!
//! All Metal kernels use `half` (fp16) for bandwidth-bound paths and
//! `float` (fp32) for accumulation to avoid precision loss in long
//! reductions or outer-product updates.

pub mod device;
pub mod heaps;
pub mod kernels;
pub mod pipeline;
pub mod profiler;

pub use device::{get_default_device, MetalBuffer, MetalDevice};
pub use heaps::{HeapAllocator, ResidencyHeap};
pub use kernels::{dispatch_1d, dispatch_2d, dispatch_1d_with_constants, KernelDispatch, SetBytesExt, ThreadgroupConfig};
pub use pipeline::{compile_kernel, ComputePipeline, KernelCache, KernelLibrary};
pub use profiler::{KernelProfiler, MetricSnapshot};
