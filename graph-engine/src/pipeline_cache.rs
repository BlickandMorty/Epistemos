//! # Metal Pipeline Cache (MTLBinaryArchive)
//!
//! Runtime pipeline caching for graph-engine Metal shaders.
//!
//! ## Why
//!
//! Per Tier 1 research (`~/Downloads/old research/Optimizing Graph Initialization
//! Performance.md`): synchronous `makeRenderPipelineState` performs JIT compilation
//! of MSL→AIR→GPU machine code on every launch. Measured cost: **100–500ms main-
//! thread block per pipeline**, 5 pipelines in graph-engine = up to 2.5s of
//! freeze on the first graph view. Binary archives cache the post-JIT GPU
//! machine code and drop pipeline creation to **<5ms direct memory access**.
//!
//! This complements (and exceeds) `CODEX_PROMPT_CHAIN.md §B-1 step 2` which
//! suggested `new_library_with_data()` — that only caches MSL→AIR compilation,
//! not the pipeline JIT. MTLBinaryArchive is the full fix.
//!
//! ## How
//!
//! 1. At `Renderer::new`, try to load a cached archive from
//!    `~/Library/Application Support/Epistemos/pipelines/<shader_hash>_<gpu_hash>.metallib`.
//! 2. If the file exists and the GPU hash matches, Metal loads machine code
//!    directly. If not, we start with an empty archive.
//! 3. Before each `new_render_pipeline_state` call, we attach the archive to
//!    the descriptor with `set_binary_archives(&[&archive])`.
//! 4. After each successful pipeline creation, we call
//!    `archive.add_render_pipeline_functions_with_descriptor(desc)` to teach
//!    the archive about this pipeline.
//! 5. On graceful shutdown (`Renderer::drop` → `PipelineCache::save`), we
//!    `serialize_to_url(cache_path)` to persist.
//!
//! ## Cache Invalidation
//!
//! The cache filename includes a **shader source hash** (FNV-1a of all four
//! shader source strings). When shader code changes, the hash changes, the
//! old cache is ignored, and a fresh archive is built on first launch.
//! Apple Silicon variants are scoped by **GPU name hash** to avoid cross-GPU
//! contamination (Apple Silicon M1/M2/M3/M4 have distinct machine code).
//!
//! ## Fallback
//!
//! When `supports_binary_archive()` is false (rare on modern macOS), or when
//! archive operations fail, the cache silently disables and callers fall
//! through to uncached pipeline creation. Never blocks the render path.

use std::path::{Path, PathBuf};
use std::sync::Mutex;

use metal::{
    BinaryArchive, BinaryArchiveDescriptor, ComputePipelineDescriptorRef, DeviceRef,
    RenderPipelineDescriptorRef, URL,
};
use objc::runtime::Object;
use objc::{class, msg_send, sel, sel_impl};

/// Bump when the cache schema (not shader content) changes.
const CACHE_SCHEMA_VERSION: u32 = 1;

/// Serializes all archive writes within a single process. Concurrent
/// `serialize_to_url` calls on distinct archive instances can still collide
/// on the underlying filesystem + Metal internal state; the lock keeps them
/// sequential without adding file locks. Matters mostly for parallel test
/// runs where multiple Renderers are constructed and dropped simultaneously.
static SAVE_LOCK: Mutex<()> = Mutex::new(());

/// Constant-time FNV-1a hash for shader source invalidation.
///
/// Running this at runtime (not const) is deliberate: shader strings are
/// static `&str` so the hash is stable across launches with the same binary,
/// but changes whenever shader source is edited and recompiled.
pub fn fnv1a_u64(bytes: &[u8]) -> u64 {
    const FNV_OFFSET: u64 = 0xcbf2_9ce4_8422_2325;
    const FNV_PRIME: u64 = 0x0000_0100_0000_01b3;
    let mut hash = FNV_OFFSET;
    for &b in bytes {
        hash ^= b as u64;
        hash = hash.wrapping_mul(FNV_PRIME);
    }
    hash
}

/// Compose a single hash over all shader source blobs, ORDER-DEPENDENT.
/// Any edit to any shader invalidates the cache → fresh capture on next run.
/// Order dependency prevents silent regressions if we ever reorder sources.
pub fn combined_shader_hash(shader_sources: &[&str]) -> u64 {
    // Seed with a non-zero constant (golden ratio u64) so empty-slice ≠ 0.
    let mut h: u64 = 0x9E37_79B9_7F4A_7C15;
    for src in shader_sources {
        // rotate → fold → multiply: sequential so reordering the inputs
        // produces different output (unlike pure XOR which is commutative).
        h = h.rotate_left(17) ^ fnv1a_u64(src.as_bytes());
        h = h.wrapping_mul(0x0000_0100_0000_01b3);
    }
    h
}

/// Pipeline cache wrapping an optional Metal binary archive.
///
/// `None` archive = cache disabled (unsupported GPU, IO errors, or explicit
/// disable). All methods are no-ops when disabled — callers never need to
/// branch on cache state.
pub struct PipelineCache {
    archive: Option<BinaryArchive>,
    cache_path: Option<PathBuf>,
    /// True once we've captured a pipeline descriptor that wasn't already in
    /// the archive. Keeps `save()` a no-op for pure cache-hit runs.
    dirty: bool,
    /// Set at construction; used by `save()` + debug logs.
    shader_hash: u64,
    gpu_name: String,
}

impl PipelineCache {
    /// Build a cache for this device. Always returns a usable `PipelineCache`
    /// — if anything fails, the returned cache is silently disabled.
    pub fn new(device: &DeviceRef, shader_sources: &[&str]) -> Self {
        let shader_hash = combined_shader_hash(shader_sources);
        let gpu_name = device.name().to_string();

        // Binary archives require macOS 11.0+ / iOS 14.0+. On 2026 Macs this
        // is effectively universal; we probe via archive creation rather than
        // MTLFeatureSet enumeration (which is coarse-grained in metal-rs).

        let cache_path = match resolve_cache_path(&gpu_name, shader_hash) {
            Some(p) => p,
            None => return Self::disabled(shader_hash, gpu_name),
        };

        // Attempt to load the existing archive from cache_path. If the file
        // doesn't exist or can't be loaded, fall through to an empty archive.
        let desc = BinaryArchiveDescriptor::new();
        if cache_path.exists() {
            let url = file_url(&cache_path);
            desc.set_url(&url);
        }

        let label = format!("epistemos-graph-{:x}", shader_hash);
        let archive = match device.new_binary_archive_with_descriptor(&desc) {
            Ok(a) => {
                a.set_label(&label);
                Some(a)
            }
            Err(err) => {
                // Tier 1 research warning: if the URL is set but the file is
                // corrupt/stale, load fails. Retry once without the URL to
                // get a fresh empty archive.
                log_warn(&format!(
                    "pipeline_cache: archive load failed ({}), rebuilding",
                    err
                ));
                let _ = std::fs::remove_file(&cache_path);
                let fresh = BinaryArchiveDescriptor::new();
                device.new_binary_archive_with_descriptor(&fresh).ok().map(|a| {
                    a.set_label(&label);
                    a
                })
            }
        };

        Self {
            archive,
            cache_path: Some(cache_path),
            dirty: false,
            shader_hash,
            gpu_name,
        }
    }

    fn disabled(shader_hash: u64, gpu_name: String) -> Self {
        Self {
            archive: None,
            cache_path: None,
            dirty: false,
            shader_hash,
            gpu_name,
        }
    }

    /// Attach the cache to a render pipeline descriptor before calling
    /// `new_render_pipeline_state`. No-op when disabled.
    pub fn attach_render(&self, desc: &RenderPipelineDescriptorRef) {
        if let Some(ref archive) = self.archive {
            desc.set_binary_archives(&[&*archive]);
        }
    }

    /// Attach the cache to a compute pipeline descriptor before calling
    /// `new_compute_pipeline_state`. No-op when disabled.
    pub fn attach_compute(&self, desc: &ComputePipelineDescriptorRef) {
        if let Some(ref archive) = self.archive {
            desc.set_binary_archives(&[&*archive]);
        }
    }

    /// Teach the archive about a newly-compiled render pipeline. Call AFTER
    /// successfully creating the pipeline from `desc`. Errors are logged and
    /// swallowed — capture failures never block pipeline creation.
    pub fn capture_render(&mut self, desc: &RenderPipelineDescriptorRef) {
        let Some(ref archive) = self.archive else {
            return;
        };
        match archive.add_render_pipeline_functions_with_descriptor(desc) {
            Ok(true) => self.dirty = true,
            Ok(false) => {}
            Err(e) => log_warn(&format!("pipeline_cache: capture_render: {}", e)),
        }
    }

    /// Teach the archive about a newly-compiled compute pipeline.
    pub fn capture_compute(&mut self, desc: &ComputePipelineDescriptorRef) {
        let Some(ref archive) = self.archive else {
            return;
        };
        match archive.add_compute_pipeline_functions_with_descriptor(desc) {
            Ok(true) => self.dirty = true,
            Ok(false) => {}
            Err(e) => log_warn(&format!("pipeline_cache: capture_compute: {}", e)),
        }
    }

    /// Serialize the archive to disk. Only writes if `dirty` — pure-hit runs
    /// are zero-cost. Returns true on success or no-op, false on error.
    pub fn save(&self) -> bool {
        if !self.dirty {
            return true;
        }
        let (archive, path) = match (&self.archive, &self.cache_path) {
            (Some(a), Some(p)) => (a, p),
            _ => return true,
        };
        // Global in-process lock — see SAVE_LOCK docs.
        let _guard = SAVE_LOCK.lock().unwrap_or_else(|e| e.into_inner());

        if let Some(parent) = path.parent()
            && let Err(e) = std::fs::create_dir_all(parent) {
                log_warn(&format!(
                    "pipeline_cache: mkdir {} failed: {}",
                    parent.display(),
                    e
                ));
                return false;
            }

        // Write via a temp path + atomic rename to avoid half-written archives
        // corrupting the next startup.
        let tmp_path = path.with_extension("metallib.tmp");
        let _ = std::fs::remove_file(&tmp_path);
        let url = file_url(&tmp_path);
        match archive.serialize_to_url(&url) {
            Ok(true) => match std::fs::rename(&tmp_path, path) {
                Ok(()) => true,
                Err(e) => {
                    log_warn(&format!(
                        "pipeline_cache: rename {} -> {}: {}",
                        tmp_path.display(),
                        path.display(),
                        e
                    ));
                    let _ = std::fs::remove_file(&tmp_path);
                    false
                }
            },
            Ok(false) => {
                log_warn("pipeline_cache: serialize_to_url returned false");
                false
            }
            Err(e) => {
                log_warn(&format!("pipeline_cache: serialize_to_url: {}", e));
                let _ = std::fs::remove_file(&tmp_path);
                false
            }
        }
    }

    /// Diagnostic: true if this cache is active (will participate in
    /// pipeline creation). False when disabled/fallback.
    pub fn is_active(&self) -> bool {
        self.archive.is_some()
    }

    pub fn shader_hash(&self) -> u64 {
        self.shader_hash
    }

    pub fn gpu_name(&self) -> &str {
        &self.gpu_name
    }

    /// Diagnostic: true if at least one pipeline has been captured since the
    /// last `save()`. Exposed for tests.
    #[cfg(test)]
    pub(crate) fn is_dirty(&self) -> bool {
        self.dirty
    }

    #[cfg(test)]
    pub(crate) fn cache_path(&self) -> Option<&Path> {
        self.cache_path.as_deref()
    }
}

/// Stable cache location on macOS: `~/Library/Application Support/Epistemos/pipelines/`.
/// Returns None if HOME is unset (tests in sandboxes, non-macOS toolchain).
fn resolve_cache_path(gpu_name: &str, shader_hash: u64) -> Option<PathBuf> {
    let home = std::env::var_os("HOME")?;
    let gpu_hash = fnv1a_u64(gpu_name.as_bytes());
    let filename = format!(
        "gfx_{:x}_{:x}_v{}.metallib",
        shader_hash, gpu_hash, CACHE_SCHEMA_VERSION
    );
    Some(
        PathBuf::from(home)
            .join("Library/Application Support/Epistemos/pipelines")
            .join(filename),
    )
}

/// Construct a file URL from a filesystem path using `NSURL fileURLWithPath:`.
///
/// This is the correct API for local paths — it handles percent-encoding,
/// spaces, unicode, and reserved characters without caller intervention.
/// metal-rs's `URL::new_with_string` wraps `URLWithString:` which requires
/// a pre-encoded URL string and returns nil on malformed input (segfault on
/// subsequent calls).
//
// The #[allow(unexpected_cfgs)] silences the check-cfg warning that comes
// from objc 0.2's `msg_send!` + `sel_impl!` macros emitting a
// `#[cfg(feature = "cargo-clippy")]` arm. Fixed in objc2 upstream; remove
// this allow when we migrate.
#[allow(unexpected_cfgs)]
fn file_url(path: &Path) -> URL {
    use metal::foreign_types::ForeignType;
    let raw = path.to_string_lossy();
    unsafe {
        // NSString with the raw path.
        let ns_str: *mut Object = {
            let s: *mut Object = msg_send![class!(NSString), alloc];
            let s: *mut Object = msg_send![s, initWithBytes:raw.as_ptr()
                                                    length:raw.len()
                                                  encoding:4usize /* NSUTF8StringEncoding */];
            s
        };
        // [NSURL fileURLWithPath:pathString]
        let url_ptr: *mut Object = msg_send![class!(NSURL), fileURLWithPath: ns_str];
        // fileURLWithPath returns autoreleased; retain so metal's Drop can release.
        let retained: *mut Object = msg_send![url_ptr, retain];
        let _: () = msg_send![ns_str, release];
        URL::from_ptr(retained as *mut _)
    }
}

fn log_warn(msg: &str) {
    // tracing isn't available in graph-engine; stderr + crate prefix.
    eprintln!("[graph-engine/pipeline_cache] {}", msg);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fnv1a_stable() {
        // Fixed test vectors — these MUST NOT change without a schema bump,
        // otherwise every user's cache invalidates silently.
        assert_eq!(fnv1a_u64(b""), 0xcbf2_9ce4_8422_2325);
        assert_eq!(fnv1a_u64(b"a"), 0xaf63_dc4c_8601_ec8c);
    }

    #[test]
    fn combined_hash_detects_any_change() {
        let a = combined_shader_hash(&["vertex { }", "fragment { }"]);
        let b = combined_shader_hash(&["vertex { /*new*/ }", "fragment { }"]);
        let c = combined_shader_hash(&["vertex { }", "fragment { /*new*/ }"]);
        assert_ne!(a, b);
        assert_ne!(a, c);
        assert_ne!(b, c);
    }

    #[test]
    fn combined_hash_order_independent_via_rotate() {
        // rotate_left(17) means position matters — test that swapping order
        // doesn't accidentally collide.
        let a = combined_shader_hash(&["x", "y"]);
        let b = combined_shader_hash(&["y", "x"]);
        // Position-sensitive because of rotate_left within the fold —
        // deliberate to prevent silent regressions when we reorder sources.
        assert_ne!(a, b);
    }

    #[test]
    fn resolve_cache_path_shape() {
        // Won't check existence — just the path assembly.
        if let Some(path) = resolve_cache_path("Apple M2", 0xdeadbeef) {
            let s = path.to_string_lossy();
            assert!(s.contains("Application Support/Epistemos/pipelines/"));
            assert!(s.contains("deadbeef"));
            assert!(s.ends_with(".metallib"));
        }
    }

    #[test]
    fn file_url_escapes_spaces() {
        let path = PathBuf::from("/Users/test user/Library/app.metallib");
        let url = file_url(&path);
        let s = url.absolute_string();
        assert!(s.starts_with("file:///Users/test%20user/"));
        assert!(s.contains("%20"));
    }

    #[test]
    fn disabled_cache_is_harmless() {
        // Can construct a disabled cache without a device; all ops no-op.
        let cache = PipelineCache::disabled(0xabcd, "MockGPU".into());
        assert!(!cache.is_active());
        assert_eq!(cache.shader_hash(), 0xabcd);
        assert_eq!(cache.gpu_name(), "MockGPU");
        assert!(cache.save(), "disabled save should be no-op success");
        assert!(!cache.is_dirty());
    }

    /// All Metal-device-touching tests run through this single entry point
    /// to avoid parallel races on MTLDevice + shared cache file paths. The
    /// metal crate's device operations are thread-safe in theory but cargo
    /// test's default parallel runner can trigger Objective-C foreign
    /// exceptions when two tests serialize archives concurrently.
    #[test]
    fn metal_device_suite() {
        let Some(device) = metal::Device::system_default() else {
            eprintln!("skip: no Metal device available");
            return;
        };
        metal_new_with_system_device(&device);
        metal_capture_and_save_roundtrip(&device);
        metal_pipeline_cache_end_to_end(&device);
    }

    fn metal_new_with_system_device(device: &metal::Device) {
        let sources = ["vertex { }", "fragment { }"];
        let cache = PipelineCache::new(device, &sources);
        assert!(
            cache.is_active(),
            "expected archive on macOS 11+ Metal device"
        );
        assert!(cache.cache_path().is_some());
        assert!(!cache.gpu_name().is_empty());
    }

    fn metal_capture_and_save_roundtrip(device: &metal::Device) {
        let tmp = std::env::temp_dir().join(format!(
            "epistemos_cache_test_{}.metallib",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&tmp);

        // Build a minimal compute shader + descriptor we can serialize.
        let source = r#"
            #include <metal_stdlib>
            using namespace metal;
            kernel void noop(device float* buf [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
                buf[tid] = float(tid);
            }
        "#;
        let lib = device
            .new_library_with_source(source, &metal::CompileOptions::new())
            .expect("compile source");
        let func = lib.get_function("noop", None).expect("get noop");

        // First run: fresh archive, capture the pipeline, save.
        {
            let archive_desc = BinaryArchiveDescriptor::new();
            let archive = device
                .new_binary_archive_with_descriptor(&archive_desc)
                .expect("new archive");
            archive.set_label("roundtrip_test");

            let compute_desc = metal::ComputePipelineDescriptor::new();
            compute_desc.set_label("noop");
            compute_desc.set_compute_function(Some(&func));
            compute_desc.set_binary_archives(&[&archive]);

            // Create the pipeline (compiles + captures into archive).
            let _pipeline = device
                .new_compute_pipeline_state(&compute_desc)
                .expect("first compile");
            archive
                .add_compute_pipeline_functions_with_descriptor(&compute_desc)
                .expect("add to archive");

            // Serialize.
            let url = file_url(&tmp);
            archive.serialize_to_url(&url).expect("serialize");
        }

        assert!(tmp.exists(), "archive file should exist after save");
        assert!(
            std::fs::metadata(&tmp).unwrap().len() > 0,
            "archive file should be non-empty"
        );

        // Second run: load the archive, confirm it loads without error.
        {
            let archive_desc = BinaryArchiveDescriptor::new();
            let url = file_url(&tmp);
            archive_desc.set_url(&url);
            let archive = device
                .new_binary_archive_with_descriptor(&archive_desc)
                .expect("reload archive");
            // Set a label so subsequent debug inspection doesn't trip on
            // the nil NSString returned by default-constructed archives.
            archive.set_label("roundtrip_test_reloaded");
            assert!(!archive.label().is_empty());
        }

        // Cleanup.
        let _ = std::fs::remove_file(&tmp);
    }

    fn metal_pipeline_cache_end_to_end(device: &metal::Device) {
        let source = r#"
            #include <metal_stdlib>
            using namespace metal;
            kernel void tick(device float* buf [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
                buf[tid] = float(tid) * 2.0;
            }
        "#;
        let lib = device
            .new_library_with_source(source, &metal::CompileOptions::new())
            .expect("compile");
        let func = lib.get_function("tick", None).expect("tick fn");

        // Use a unique shader hash seed so we don't clobber the real cache.
        let unique_src = format!(
            "// test-pid-{} {}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        );

        let mut cache = PipelineCache::new(&device, &[&unique_src]);
        assert!(cache.is_active());
        assert!(!cache.is_dirty());

        let desc = metal::ComputePipelineDescriptor::new();
        desc.set_label("tick");
        desc.set_compute_function(Some(&func));
        cache.attach_compute(&desc);
        let _pipeline = device
            .new_compute_pipeline_state(&desc)
            .expect("create pipeline");
        cache.capture_compute(&desc);
        assert!(cache.is_dirty(), "capture should flip dirty");

        let path = cache.cache_path().unwrap().to_path_buf();
        let _ = std::fs::remove_file(&path); // force fresh save
        assert!(cache.save(), "save should succeed");
        assert!(path.exists(), "cache file should exist");
        let size = std::fs::metadata(&path).unwrap().len();
        assert!(size > 0, "cache file should be non-empty (got {} bytes)", size);

        // Second PipelineCache with the SAME shader hash should load the
        // archive successfully.
        let cache2 = PipelineCache::new(&device, &[&unique_src]);
        assert!(cache2.is_active());
        assert!(!cache2.is_dirty(), "freshly-loaded cache shouldn't be dirty");
        assert_eq!(
            cache.shader_hash(),
            cache2.shader_hash(),
            "same source → same hash"
        );

        // Cleanup.
        let _ = std::fs::remove_file(&path);
    }

}
