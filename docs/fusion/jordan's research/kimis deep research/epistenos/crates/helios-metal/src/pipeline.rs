use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2_foundation::NSString;
use objc2_metal::{
    MTLCompileOptions, MTLComputePipelineState, MTLDevice, MTLFunction, MTLLibrary,
    MTLPipelineOption,
};
use std::collections::HashMap;
use std::hash::{Hash, Hasher};
use std::sync::Mutex;
use tracing::{debug, error, info, warn};

use crate::device::{MetalDevice, MetalError, Result};

// ============================================================================
// KernelLibrary
// ============================================================================

/// Wraps a compiled `MTLLibrary` and its source hash.
pub struct KernelLibrary {
    inner: Retained<ProtocolObject<dyn MTLLibrary>>,
    source_hash: u64,
}

impl KernelLibrary {
    /// Compile MSL source into a Metal library at runtime.
    ///
    /// # Errors
    /// Returns `MetalError::BufferAllocation` (used as generic compilation error)
    /// if the MSL source contains syntax errors or unsupported features.
    pub fn compile(device: &MetalDevice, msl_source: &str) -> Result<Self> {
        let src_ns = NSString::from_str(msl_source);
        let options = MTLCompileOptions::new();

        let result = unsafe {
            device
                .raw()
                .newLibraryWithSource_options_error(&src_ns, Some(&options))
        };

        match result {
            Ok(library) => {
                let hash = compute_hash(msl_source);
                debug!("compiled Metal library: hash={:016x}", hash);
                Ok(KernelLibrary {
                    inner: library,
                    source_hash: hash,
                })
            }
            Err(err) => {
                let desc = err.localizedDescription().to_string();
                error!("MSL compilation failed: {}", desc);
                Err(MetalError::BufferAllocation(desc))
            }
        }
    }

    pub fn raw(&self) -> &ProtocolObject<dyn MTLLibrary> {
        &self.inner
    }

    pub fn source_hash(&self) -> u64 {
        self.source_hash
    }

    /// Retrieve a function from the library by name.
    pub fn get_function(&self, name: &str) -> Option<Retained<ProtocolObject<dyn MTLFunction>>> {
        let name_ns = NSString::from_str(name);
        unsafe { self.inner.newFunctionWithName(&name_ns) }
    }
}

// ============================================================================
// ComputePipeline
// ============================================================================

/// Wraps `MTLComputePipelineState` with its associated function name.
pub struct ComputePipeline {
    inner: Retained<ProtocolObject<dyn MTLComputePipelineState>>,
    function_name: String,
    max_threads_per_threadgroup: usize,
    threadgroup_size_alignment: usize,
}

impl ComputePipeline {
    /// Create a pipeline state from a library and function name.
    pub fn from_library(library: &KernelLibrary, function_name: &str) -> Result<Self> {
        let func = library
            .get_function(function_name)
            .ok_or_else(|| {
                MetalError::BufferAllocation(format!(
                    "function '{}' not found in library",
                    function_name
                ))
            })?;

        let result = unsafe {
            library
                .raw()
                .device()
                .newComputePipelineStateWithFunction_error(&func)
        };

        match result {
            Ok(pipeline) => {
                let max_threads = unsafe { pipeline.maxTotalThreadsPerThreadgroup() } as usize;
                let alignment = 32usize;

                info!(
                    "created pipeline '{}' : max_threads_per_tg={} alignment={}",
                    function_name, max_threads, alignment
                );

                Ok(ComputePipeline {
                    inner: pipeline,
                    function_name: function_name.to_string(),
                    max_threads_per_threadgroup: max_threads,
                    threadgroup_size_alignment: alignment,
                })
            }
            Err(err) => {
                let desc = err.localizedDescription().to_string();
                Err(MetalError::BufferAllocation(desc))
            }
        }
    }

    pub fn raw(&self) -> &ProtocolObject<dyn MTLComputePipelineState> {
        &self.inner
    }

    pub fn max_threads_per_threadgroup(&self) -> usize {
        self.max_threads_per_threadgroup
    }

    pub fn threadgroup_size_alignment(&self) -> usize {
        self.threadgroup_size_alignment
    }

    pub fn function_name(&self) -> &str {
        &self.function_name
    }
}

// ============================================================================
// KernelCache
// ============================================================================

/// LRU cache of compiled compute pipelines keyed by source hash.
///
/// The cache stores both the `KernelLibrary` and the `ComputePipeline`
/// so that multiple functions from the same library share one compilation.
/// In practice we cache at the (source_hash, function_name) granularity.
pub struct KernelCache {
    entries: Mutex<HashMap<(u64, String), ComputePipeline>>,
    capacity: usize,
}

impl KernelCache {
    pub fn with_capacity(capacity: usize) -> Self {
        Self {
            entries: Mutex::new(HashMap::with_capacity(capacity)),
            capacity,
        }
    }

    /// Retrieve a cached pipeline, or compile and insert.
    pub fn get_or_compile(
        &self,
        device: &MetalDevice,
        name: &str,
        msl_source: &str,
    ) -> Result<ComputePipeline> {
        let hash = compute_hash(msl_source);
        let key = (hash, name.to_string());

        {
            let guard = self.entries.lock().unwrap();
            if let Some(pipeline) = guard.get(&key) {
                debug!("kernel cache hit: {}:{:016x}", name, hash);
                return Ok(ComputePipeline {
                    inner: unsafe { std::ptr::read(&pipeline.inner) },
                    function_name: pipeline.function_name.clone(),
                    max_threads_per_threadgroup: pipeline.max_threads_per_threadgroup,
                    threadgroup_size_alignment: pipeline.threadgroup_size_alignment,
                });
            }
        }

        // Compile
        let library = KernelLibrary::compile(device, msl_source)?;
        let pipeline = ComputePipeline::from_library(&library, name)?;

        let mut guard = self.entries.lock().unwrap();
        if guard.len() >= self.capacity {
            warn!("kernel cache full, evicting half");
            let keys_to_remove: Vec<_> = guard.keys().take(guard.len() / 2).cloned().collect();
            for k in keys_to_remove {
                guard.remove(&k);
            }
        }
        guard.insert(key, ComputePipeline {
            inner: unsafe { std::ptr::read(&pipeline.inner) },
            function_name: pipeline.function_name.clone(),
            max_threads_per_threadgroup: pipeline.max_threads_per_threadgroup,
            threadgroup_size_alignment: pipeline.threadgroup_size_alignment,
        });
        info!("kernel cached: {}:{:016x}", name, hash);
        Ok(pipeline)
    }

    /// Clear all cached entries.
    pub fn clear(&self) {
        let mut guard = self.entries.lock().unwrap();
        guard.clear();
    }
}

// ============================================================================
// compile_kernel helper
// ============================================================================

/// Convenience function: compile a kernel by name from MSL source.
///
/// This does **not** cache; use [`KernelCache`] for repeated invocations.
pub fn compile_kernel(device: &MetalDevice, name: &str, msl_source: &str) -> Result<ComputePipeline> {
    let library = KernelLibrary::compile(device, msl_source)?;
    ComputePipeline::from_library(&library, name)
}

// ============================================================================
// Hash helper
// ============================================================================

fn compute_hash(s: &str) -> u64 {
    use std::collections::hash_map::DefaultHasher;
    let mut h = DefaultHasher::new();
    s.hash(&mut h);
    h.finish()
}
