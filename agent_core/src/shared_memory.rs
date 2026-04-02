// ── Zero-Copy Shared Memory Bridge ──────────────────────────────────────
//
// POSIX shm_open + mmap data plane for large binary payloads between
// Swift ↔ Rust ↔ Python (Hermes). The JSON-RPC control plane carries
// only a tiny semaphore payload (segment name + byte length).
//
// This avoids the macOS 64KB stdout pipe buffer limit for large payloads
// like codebase ASTs, base64 screenshots, and vector embeddings.

use std::ffi::CString;
use std::io;
use std::ptr;

/// A named POSIX shared memory segment.
///
/// The producer creates and writes to the segment; consumers open and read
/// directly from RAM with zero kernel copies.
pub struct SharedMemorySegment {
    name: String,
    ptr: *mut u8,
    len: usize,
    fd: i32,
    is_owner: bool,
}

// SAFETY: The segment is protected by POSIX semantics — only one writer
// at a time (enforced by the actor/bridge layer). Reads are concurrent-safe
// once the writer signals completion via the control plane.
unsafe impl Send for SharedMemorySegment {}
unsafe impl Sync for SharedMemorySegment {}

impl SharedMemorySegment {
    /// Create a new shared memory segment of the given size.
    ///
    /// The segment name should be unique per payload (e.g., "/epistemos_ast_{session_id}").
    pub fn create(name: &str, size: usize) -> io::Result<Self> {
        let c_name = CString::new(name).map_err(|_| {
            io::Error::new(io::ErrorKind::InvalidInput, "invalid segment name")
        })?;

        // SAFETY: shm_open with O_CREAT|O_RDWR creates or opens the segment.
        // ftruncate sets the size. mmap maps it into our address space.
        unsafe {
            let fd = libc::shm_open(
                c_name.as_ptr(),
                libc::O_RDWR | libc::O_CREAT,
                0o600,
            );
            if fd < 0 {
                return Err(io::Error::last_os_error());
            }

            if libc::ftruncate(fd, size as libc::off_t) != 0 {
                libc::close(fd);
                libc::shm_unlink(c_name.as_ptr());
                return Err(io::Error::last_os_error());
            }

            let ptr = libc::mmap(
                ptr::null_mut(),
                size,
                libc::PROT_READ | libc::PROT_WRITE,
                libc::MAP_SHARED,
                fd,
                0,
            );
            if ptr == libc::MAP_FAILED {
                libc::close(fd);
                libc::shm_unlink(c_name.as_ptr());
                return Err(io::Error::last_os_error());
            }

            Ok(Self {
                name: name.to_string(),
                ptr: ptr as *mut u8,
                len: size,
                fd,
                is_owner: true,
            })
        }
    }

    /// Open an existing shared memory segment for reading.
    pub fn open_read(name: &str, size: usize) -> io::Result<Self> {
        let c_name = CString::new(name).map_err(|_| {
            io::Error::new(io::ErrorKind::InvalidInput, "invalid segment name")
        })?;

        // SAFETY: shm_open with O_RDONLY opens existing segment read-only.
        unsafe {
            let fd = libc::shm_open(c_name.as_ptr(), libc::O_RDONLY, 0);
            if fd < 0 {
                return Err(io::Error::last_os_error());
            }

            let ptr = libc::mmap(
                ptr::null_mut(),
                size,
                libc::PROT_READ,
                libc::MAP_SHARED,
                fd,
                0,
            );
            if ptr == libc::MAP_FAILED {
                libc::close(fd);
                return Err(io::Error::last_os_error());
            }

            Ok(Self {
                name: name.to_string(),
                ptr: ptr as *mut u8,
                len: size,
                fd,
                is_owner: false,
            })
        }
    }

    /// Write data into the shared memory segment.
    ///
    /// Returns the number of bytes written. Panics if data exceeds segment size.
    pub fn write(&self, data: &[u8]) -> usize {
        assert!(
            data.len() <= self.len,
            "data ({}) exceeds segment size ({})",
            data.len(),
            self.len
        );
        // SAFETY: ptr is valid for self.len bytes, and we've asserted data fits.
        unsafe {
            ptr::copy_nonoverlapping(data.as_ptr(), self.ptr, data.len());
        }
        data.len()
    }

    /// Read data from the shared memory segment as a byte slice.
    pub fn as_bytes(&self) -> &[u8] {
        // SAFETY: ptr is valid for self.len bytes for the lifetime of self.
        unsafe { std::slice::from_raw_parts(self.ptr, self.len) }
    }

    /// The segment name (for passing via JSON-RPC control plane).
    pub fn name(&self) -> &str {
        &self.name
    }

    /// The segment size in bytes.
    pub fn len(&self) -> usize {
        self.len
    }

    pub fn is_empty(&self) -> bool {
        self.len == 0
    }
}

impl Drop for SharedMemorySegment {
    fn drop(&mut self) {
        // SAFETY: unmapping and closing resources we own.
        unsafe {
            if !self.ptr.is_null() {
                libc::munmap(self.ptr as *mut libc::c_void, self.len);
            }
            if self.fd >= 0 {
                libc::close(self.fd);
            }
            if self.is_owner {
                if let Ok(c_name) = CString::new(self.name.as_str()) {
                    libc::shm_unlink(c_name.as_ptr());
                }
            }
        }
    }
}

/// Control-plane message for shared memory handoff.
/// Sent over JSON-RPC to tell the consumer where the data is.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ShmReference {
    /// POSIX shared memory segment name (e.g., "/epistemos_ast_abc123")
    pub segment_name: String,
    /// Number of valid bytes in the segment
    pub byte_length: usize,
    /// MIME type or content descriptor
    pub content_type: String,
}

// ── ShmPool: Session-Scoped Segment Lifecycle ───────────────────────────
//
// Manages shared memory segments per agent session. Tracks all live segments
// so they can be cleaned up on session end or process death.
//
// The pool uses atomic counters for unique naming and a global registry
// protected by a Mutex for cleanup traversal. The Mutex is only held
// during registry bookkeeping (insert/remove), never during mmap I/O.

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;

/// Global segment counter for unique naming across the process lifetime.
static SEGMENT_COUNTER: AtomicU64 = AtomicU64::new(0);

/// Global registry: session_id → Vec<segment_name>.
/// Protected by Mutex (bookkeeping only, never held during I/O).
static POOL_REGISTRY: Mutex<Option<HashMap<String, Vec<String>>>> = Mutex::new(None);

/// Threshold in bytes above which tool results are offloaded to shm.
/// Chosen to stay well under the macOS 64KB pipe buffer limit.
pub const SHM_OFFLOAD_THRESHOLD: usize = 48 * 1024;

/// Maximum single segment size (16MB safety cap).
const MAX_SEGMENT_SIZE: usize = 16 * 1024 * 1024;

pub struct ShmPool;

impl ShmPool {
    /// Initialize the global registry. Idempotent — safe to call multiple times.
    pub fn init() {
        let mut guard = POOL_REGISTRY.lock().unwrap_or_else(|e| e.into_inner());
        if guard.is_none() {
            *guard = Some(HashMap::new());
        }
    }

    /// Write a large payload into a new shared memory segment.
    ///
    /// Returns an `ShmReference` containing the segment name and byte length
    /// for transmission over the JSON-RPC control plane.
    ///
    /// The segment is tracked under `session_id` for lifecycle cleanup.
    pub fn write_payload(
        session_id: &str,
        data: &[u8],
        content_type: &str,
    ) -> io::Result<ShmReference> {
        if data.len() > MAX_SEGMENT_SIZE {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                format!(
                    "payload size {} exceeds max segment size {}",
                    data.len(),
                    MAX_SEGMENT_SIZE
                ),
            ));
        }

        let seq = SEGMENT_COUNTER.fetch_add(1, Ordering::Relaxed);
        let segment_name = format!("/ep_{}_{}", session_id.replace('/', "_"), seq);

        let segment = SharedMemorySegment::create(&segment_name, data.len())?;
        segment.write(data);

        // Track in registry
        {
            let mut guard = POOL_REGISTRY.lock().unwrap_or_else(|e| e.into_inner());
            let registry = guard.get_or_insert_with(HashMap::new);
            registry
                .entry(session_id.to_string())
                .or_default()
                .push(segment_name.clone());
        }

        // Drop the segment handle — the shm stays alive in the kernel until
        // shm_unlink is called (which happens in cleanup_session or cleanup_all).
        // We intentionally leak the mmap here; the consumer will open_read it.
        std::mem::forget(segment);

        Ok(ShmReference {
            segment_name,
            byte_length: data.len(),
            content_type: content_type.to_string(),
        })
    }

    /// Read a payload from a shared memory segment by its reference.
    pub fn read_payload(reference: &ShmReference) -> io::Result<Vec<u8>> {
        let segment =
            SharedMemorySegment::open_read(&reference.segment_name, reference.byte_length)?;
        let data = segment.as_bytes()[..reference.byte_length].to_vec();
        Ok(data)
    }

    /// Clean up all shared memory segments for a given session.
    ///
    /// Called when an agent session ends (success or failure).
    /// Issues `shm_unlink` for each segment, removing it from the kernel.
    pub fn cleanup_session(session_id: &str) -> usize {
        let segments = {
            let mut guard = POOL_REGISTRY.lock().unwrap_or_else(|e| e.into_inner());
            guard
                .as_mut()
                .and_then(|registry| registry.remove(session_id))
                .unwrap_or_default()
        };

        let count = segments.len();
        for name in &segments {
            Self::unlink_segment(name);
        }
        count
    }

    /// Emergency cleanup — unlink ALL tracked segments across all sessions.
    ///
    /// Called on process exit to prevent zombie segments in the macOS kernel.
    pub fn cleanup_all() -> usize {
        let all_segments: Vec<String> = {
            let mut guard = POOL_REGISTRY.lock().unwrap_or_else(|e| e.into_inner());
            guard
                .take()
                .map(|registry| registry.into_values().flatten().collect())
                .unwrap_or_default()
        };

        let count = all_segments.len();
        for name in &all_segments {
            Self::unlink_segment(name);
        }
        count
    }

    /// Number of tracked segments for a session (diagnostics).
    pub fn segment_count(session_id: &str) -> usize {
        let guard = POOL_REGISTRY.lock().unwrap_or_else(|e| e.into_inner());
        guard
            .as_ref()
            .and_then(|registry| registry.get(session_id))
            .map(|v| v.len())
            .unwrap_or(0)
    }

    /// Total tracked segments across all sessions (diagnostics).
    pub fn total_segment_count() -> usize {
        let guard = POOL_REGISTRY.lock().unwrap_or_else(|e| e.into_inner());
        guard
            .as_ref()
            .map(|registry| registry.values().map(|v| v.len()).sum())
            .unwrap_or(0)
    }

    /// Unlink a single segment by name (best-effort, ignores errors).
    fn unlink_segment(name: &str) {
        if let Ok(c_name) = CString::new(name) {
            // SAFETY: shm_unlink removes the segment name from the kernel.
            // Existing mmaps remain valid until munmap'd.
            unsafe {
                libc::shm_unlink(c_name.as_ptr());
            }
        }
    }
}

/// Helper: if a tool result exceeds `SHM_OFFLOAD_THRESHOLD`, offload it
/// to shared memory and return the ShmReference JSON instead.
///
/// If the result is small enough, returns it unchanged.
pub fn maybe_offload_to_shm(
    session_id: &str,
    result: String,
    content_type: &str,
) -> String {
    if result.len() <= SHM_OFFLOAD_THRESHOLD {
        return result;
    }

    match ShmPool::write_payload(session_id, result.as_bytes(), content_type) {
        Ok(reference) => {
            // Return a compact JSON pointer instead of the massive payload
            serde_json::to_string(&reference).unwrap_or(result)
        }
        Err(_) => {
            // Fallback: truncate to stay under pipe limits
            let truncated = &result[..SHM_OFFLOAD_THRESHOLD];
            format!(
                "{}\n\n[TRUNCATED: result was {} bytes, shm offload failed]",
                truncated,
                result.len()
            )
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Mutex, MutexGuard, OnceLock};

    struct ShmTestScope {
        _guard: MutexGuard<'static, ()>,
    }

    impl ShmTestScope {
        fn new() -> Self {
            static TEST_MUTEX: OnceLock<Mutex<()>> = OnceLock::new();

            let guard = TEST_MUTEX
                .get_or_init(|| Mutex::new(()))
                .lock()
                .unwrap_or_else(|e| e.into_inner());

            ShmPool::cleanup_all();
            Self { _guard: guard }
        }
    }

    impl Drop for ShmTestScope {
        fn drop(&mut self) {
            ShmPool::cleanup_all();
        }
    }

    #[test]
    fn roundtrip_shared_memory() {
        let _scope = ShmTestScope::new();
        let name = "/epistemos_test_shm_roundtrip";
        let data = b"Hello from shared memory!";

        let writer = SharedMemorySegment::create(name, 4096).expect("create failed");
        writer.write(data);

        let reader = SharedMemorySegment::open_read(name, 4096).expect("open failed");
        let read_data = &reader.as_bytes()[..data.len()];
        assert_eq!(read_data, data);

        drop(reader);
        drop(writer);
    }

    #[test]
    fn shm_reference_serializes() {
        let _scope = ShmTestScope::new();
        let reference = ShmReference {
            segment_name: "/epistemos_ast_abc123".to_string(),
            byte_length: 65536,
            content_type: "application/json".to_string(),
        };
        let json = serde_json::to_string(&reference).unwrap();
        assert!(json.contains("epistemos_ast_abc123"));
    }

    #[test]
    fn shm_pool_write_and_read_payload() {
        let _scope = ShmTestScope::new();
        ShmPool::init();
        let data = b"zero-copy payload for the MCP bridge";
        let reference =
            ShmPool::write_payload("test_session_1", data, "text/plain").expect("write failed");

        assert!(reference.segment_name.contains("test_session_1"));
        assert_eq!(reference.byte_length, data.len());
        assert_eq!(reference.content_type, "text/plain");

        let read_back = ShmPool::read_payload(&reference).expect("read failed");
        assert_eq!(&read_back, data);

        let cleaned = ShmPool::cleanup_session("test_session_1");
        assert_eq!(cleaned, 1);
    }

    #[test]
    fn shm_pool_cleanup_all() {
        let _scope = ShmTestScope::new();
        ShmPool::init();
        ShmPool::write_payload("sess_a", b"alpha", "text/plain").expect("write failed");
        ShmPool::write_payload("sess_a", b"bravo", "text/plain").expect("write failed");
        ShmPool::write_payload("sess_b", b"charlie", "text/plain").expect("write failed");

        assert!(ShmPool::total_segment_count() >= 3);

        let cleaned = ShmPool::cleanup_all();
        assert!(cleaned >= 3);
        assert_eq!(ShmPool::total_segment_count(), 0);
    }

    #[test]
    fn shm_pool_unique_segment_names() {
        let _scope = ShmTestScope::new();
        ShmPool::init();
        let r1 = ShmPool::write_payload("uniq", b"a", "text/plain").expect("write failed");
        let r2 = ShmPool::write_payload("uniq", b"b", "text/plain").expect("write failed");
        assert_ne!(r1.segment_name, r2.segment_name);
        ShmPool::cleanup_session("uniq");
    }

    #[test]
    fn shm_pool_rejects_oversized_payload() {
        let _scope = ShmTestScope::new();
        ShmPool::init();
        let huge = vec![0u8; MAX_SEGMENT_SIZE + 1];
        let result = ShmPool::write_payload("oversize", &huge, "application/octet-stream");
        assert!(result.is_err());
    }

    #[test]
    fn maybe_offload_small_payload_passes_through() {
        let _scope = ShmTestScope::new();
        let small = "x".repeat(1024);
        let result = maybe_offload_to_shm("sess_small", small.clone(), "text/plain");
        assert_eq!(result, small);
    }

    #[test]
    fn maybe_offload_large_payload_returns_shm_reference() {
        let _scope = ShmTestScope::new();
        ShmPool::init();
        let large = "x".repeat(SHM_OFFLOAD_THRESHOLD + 1);
        let result = maybe_offload_to_shm("sess_large", large, "application/json");
        // Should be a JSON ShmReference
        let parsed: ShmReference = serde_json::from_str(&result).expect("should be ShmReference JSON");
        assert!(parsed.segment_name.contains("sess_large"));
        assert!(parsed.byte_length > SHM_OFFLOAD_THRESHOLD);
        ShmPool::cleanup_session("sess_large");
    }
}
