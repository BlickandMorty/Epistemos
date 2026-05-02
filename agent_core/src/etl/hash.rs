// xxh3 content fingerprinting for the ETL change-detection layer.
//
// xxh3 is a non-cryptographic hash optimized for high-throughput
// fingerprinting. On Apple Silicon arm64 it sustains ~30 GB/s.
// Hashing 100k notes averaging 4KB each = ~400MB → <500ms.
//
// We use the 64-bit variant (`xxh3_64`) — sufficient for
// change-detection (collision probability ~2.7e-20 for 1B files);
// 128-bit isn't worth the extra memory.

pub use xxhash_rust::xxh3::xxh3_64;

/// Hash a file's content + path together so the fingerprint changes
/// when the file moves OR its content changes. Returns the 64-bit
/// xxh3 hash.
pub fn fingerprint(path_bytes: &[u8], content_bytes: &[u8]) -> u64 {
    // Combine via two-step seeded hash so neither component bleeds
    // into the other's space.
    let path_h = xxh3_64(path_bytes);
    let content_h = xxh3_64(content_bytes);
    xxh3_64(&[path_h.to_le_bytes(), content_h.to_le_bytes()].concat())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hash_changes_on_content_change() {
        let path = b"notes/n1.md";
        let h1 = fingerprint(path, b"original content");
        let h2 = fingerprint(path, b"modified content");
        assert_ne!(h1, h2);
    }

    #[test]
    fn hash_changes_on_path_change() {
        let content = b"same content";
        let h1 = fingerprint(b"notes/n1.md", content);
        let h2 = fingerprint(b"notes/n2.md", content);
        assert_ne!(h1, h2);
    }

    #[test]
    fn hash_stable_for_same_input() {
        let path = b"notes/n1.md";
        let content = b"hello world";
        assert_eq!(fingerprint(path, content), fingerprint(path, content));
    }
}
