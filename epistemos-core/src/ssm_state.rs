//! SSM State Persistence — Save/load Mamba hidden state between sessions.
//!
//! Mamba/SSM models have fixed-size hidden state (~6-24MB) independent of context
//! length. This module serializes state to flat binary format for zero-copy
//! deserialization via mmap.
//!
//! Format v2 adds vault_id and model_hash fields for vault-scoped state.
//!
//! State format:
//!   [Header: 56 bytes] [Session ID (padded)] [Layer data]
//!
//! Header v2 (60 bytes):
//!   magic: u32 = 0x4D414D42 ("MAMB")       [0..4]
//!   version: u32 = 2                        [4..8]
//!   layer_count: u32                        [8..12]
//!   state_dim: u32                          [12..16]
//!   head_dim: u32                           [16..20]
//!   dtype: u32 (0 = f16, 1 = f32)           [20..24]
//!   session_id_len: u32                     [24..28]
//!   timestamp: u64                          [28..36]
//!   vault_id: u64                           [36..44]
//!   model_hash: u64                         [44..52]
//!   flags: u32 (bit 0: has_conv_state)      [52..56]
//!   _reserved: u32                          [56..60]
//!
//! Followed by session_id (UTF-8 bytes, padded to 8-byte alignment),
//! then raw tensor data per layer.

use std::collections::hash_map::DefaultHasher;
use std::fs;
use std::hash::{Hash, Hasher};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAGIC: u32 = 0x4D41_4D42; // "MAMB"
const VERSION_1: u32 = 1;
const VERSION_2: u32 = 2;
const HEADER_V1_SIZE: usize = 36;
const HEADER_V2_SIZE: usize = 60; // v1 (36) + vault_id(8) + model_hash(8) + flags(4) + reserved(4)

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

#[derive(Debug, thiserror::Error)]
pub enum SSMStateError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Invalid state file: {0}")]
    InvalidFormat(String),
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Metadata about a saved SSM state (header-only read).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SSMStateMetadata {
    pub model_id: String,
    pub session_id: String,
    pub layer_count: u32,
    pub state_dim: u32,
    pub head_dim: u32,
    pub total_bytes: u64,
    pub timestamp: u64,
    pub vault_id: u64,
    pub model_hash: u64,
    pub has_conv_state: bool,
    pub file_path: String,
}

/// A complete SSM state ready for serialization.
#[derive(Debug, Clone)]
pub struct SSMState {
    pub model_id: String,
    pub session_id: String,
    pub layer_count: u32,
    pub state_dim: u32,
    pub head_dim: u32,
    pub vault_id: u64,
    pub model_hash: u64,
    pub has_conv_state: bool,
    /// Raw layer data — concatenated f16 tensors, one per layer.
    /// Each layer: state_dim * head_dim * 2 bytes (f16).
    /// If has_conv_state, conv state follows SSM state per layer.
    pub layer_data: Vec<u8>,
}

impl SSMState {
    pub fn bytes_per_layer(&self) -> usize {
        self.state_dim as usize * self.head_dim as usize * 2 // f16 = 2 bytes
    }

    pub fn total_bytes(&self) -> usize {
        self.layer_data.len()
    }
}

/// Compute a stable u64 hash for vault scoping.
pub fn hash_vault_path(vault_root: &str) -> u64 {
    let mut hasher = DefaultHasher::new();
    vault_root.hash(&mut hasher);
    hasher.finish()
}

/// Compute a stable u64 hash for model identity.
pub fn hash_model_id(model_id: &str) -> u64 {
    let mut hasher = DefaultHasher::new();
    model_id.hash(&mut hasher);
    hasher.finish()
}

// ---------------------------------------------------------------------------
// Serialization (v2)
// ---------------------------------------------------------------------------

/// Save an SSM state to a flat binary file (v2 format).
/// Directory: {vault_root}/ssm_state/{model_hash_hex}/
pub fn save_ssm_state(
    state: &SSMState,
    vault_root: &Path,
) -> Result<PathBuf, SSMStateError> {
    let model_dir = vault_root
        .join("ssm_state")
        .join(format!("{:016x}", state.model_hash));
    fs::create_dir_all(&model_dir)?;

    let timestamp = chrono::Utc::now().timestamp() as u64;
    let filename = format!("{}_{}.mambastate", state.session_id, timestamp);
    let file_path = model_dir.join(&filename);

    let session_id_bytes = state.session_id.as_bytes();
    let padded_len = (session_id_bytes.len() + 7) & !7;

    let flags: u32 = if state.has_conv_state { 1 } else { 0 };

    let mut file = fs::File::create(&file_path)?;

    // Write v2 header (56 bytes)
    file.write_all(&MAGIC.to_le_bytes())?;
    file.write_all(&VERSION_2.to_le_bytes())?;
    file.write_all(&state.layer_count.to_le_bytes())?;
    file.write_all(&state.state_dim.to_le_bytes())?;
    file.write_all(&state.head_dim.to_le_bytes())?;
    file.write_all(&0u32.to_le_bytes())?; // dtype = f16
    file.write_all(&(session_id_bytes.len() as u32).to_le_bytes())?;
    file.write_all(&timestamp.to_le_bytes())?;
    // v2 extensions
    file.write_all(&state.vault_id.to_le_bytes())?;
    file.write_all(&state.model_hash.to_le_bytes())?;
    file.write_all(&flags.to_le_bytes())?;
    file.write_all(&0u32.to_le_bytes())?; // reserved

    // Write session_id (padded to 8-byte alignment)
    file.write_all(session_id_bytes)?;
    let padding = padded_len - session_id_bytes.len();
    if padding > 0 {
        file.write_all(&vec![0u8; padding])?;
    }

    // Write layer data
    file.write_all(&state.layer_data)?;

    Ok(file_path)
}

/// Load an SSM state from a flat binary file.
/// Supports both v1 and v2 formats.
pub fn load_ssm_state(file_path: &Path) -> Result<SSMState, SSMStateError> {
    let data = fs::read(file_path)?;
    if data.len() < HEADER_V1_SIZE {
        return Err(SSMStateError::InvalidFormat("File too small".to_string()));
    }

    let magic = u32::from_le_bytes([data[0], data[1], data[2], data[3]]);
    if magic != MAGIC {
        return Err(SSMStateError::InvalidFormat(format!(
            "Invalid magic: {magic:#x} (expected {MAGIC:#x})"
        )));
    }

    let version = u32::from_le_bytes([data[4], data[5], data[6], data[7]]);
    let header_size = match version {
        VERSION_1 => HEADER_V1_SIZE,
        VERSION_2 => HEADER_V2_SIZE,
        v => {
            return Err(SSMStateError::InvalidFormat(format!(
                "Unsupported version: {v}"
            )))
        }
    };

    if data.len() < header_size {
        return Err(SSMStateError::InvalidFormat("Truncated header".to_string()));
    }

    let layer_count = u32::from_le_bytes([data[8], data[9], data[10], data[11]]);
    let state_dim = u32::from_le_bytes([data[12], data[13], data[14], data[15]]);
    let head_dim = u32::from_le_bytes([data[16], data[17], data[18], data[19]]);
    let _dtype = u32::from_le_bytes([data[20], data[21], data[22], data[23]]);
    let session_id_len = u32::from_le_bytes([data[24], data[25], data[26], data[27]]) as usize;

    // v2 fields (defaults for v1)
    let (vault_id, model_hash, has_conv_state) = if version >= VERSION_2 {
        let vid = u64::from_le_bytes([
            data[36], data[37], data[38], data[39], data[40], data[41], data[42], data[43],
        ]);
        let mh = u64::from_le_bytes([
            data[44], data[45], data[46], data[47], data[48], data[49], data[50], data[51],
        ]);
        let flags = u32::from_le_bytes([data[52], data[53], data[54], data[55]]);
        (vid, mh, flags & 1 != 0)
    } else {
        (0u64, 0u64, false)
    };

    // Parse session_id
    let session_id_start = header_size;
    let session_id_end = session_id_start + session_id_len;
    if session_id_end > data.len() {
        return Err(SSMStateError::InvalidFormat(
            "Truncated at session_id".to_string(),
        ));
    }
    let session_id = String::from_utf8_lossy(&data[session_id_start..session_id_end]).to_string();

    // Layer data starts after padded session_id
    let padded_len = (session_id_len + 7) & !7;
    let layer_data_start = header_size + padded_len;
    let layer_data = if layer_data_start <= data.len() {
        data[layer_data_start..].to_vec()
    } else {
        Vec::new()
    };

    // Extract model_id from filename
    let model_id = file_path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_string();

    Ok(SSMState {
        model_id,
        session_id,
        layer_count,
        state_dim,
        head_dim,
        vault_id,
        model_hash,
        has_conv_state,
        layer_data,
    })
}

/// List all saved SSM states, optionally filtered by model hash.
/// Returns sorted newest first.
pub fn list_ssm_states(
    vault_root: &Path,
    model_hash_filter: Option<u64>,
) -> Result<Vec<SSMStateMetadata>, SSMStateError> {
    let state_dir = vault_root.join("ssm_state");
    if !state_dir.is_dir() {
        return Ok(Vec::new());
    }

    let mut results = Vec::new();

    // Walk model subdirectories
    let dirs_to_scan: Vec<PathBuf> = if let Some(mh) = model_hash_filter {
        let specific = state_dir.join(format!("{mh:016x}"));
        if specific.is_dir() {
            vec![specific]
        } else {
            return Ok(Vec::new());
        }
    } else {
        fs::read_dir(&state_dir)?
            .filter_map(|e| e.ok())
            .map(|e| e.path())
            .filter(|p| p.is_dir())
            .collect()
    };

    for dir in dirs_to_scan {
        let entries = match fs::read_dir(&dir) {
            Ok(e) => e,
            Err(_) => continue,
        };

        for entry in entries.filter_map(|e| e.ok()) {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("mambastate") {
                continue;
            }

            let mut file = match fs::File::open(&path) {
                Ok(f) => f,
                Err(_) => continue,
            };

            // Read v2 header (60 bytes — covers both v1 and v2)
            let mut header = [0u8; 60];
            let bytes_read = match file.read(&mut header) {
                Ok(n) => n,
                Err(_) => continue,
            };
            if bytes_read < HEADER_V1_SIZE {
                continue;
            }

            let magic = u32::from_le_bytes([header[0], header[1], header[2], header[3]]);
            if magic != MAGIC {
                continue;
            }

            let version = u32::from_le_bytes([header[4], header[5], header[6], header[7]]);
            let layer_count = u32::from_le_bytes([header[8], header[9], header[10], header[11]]);
            let state_dim = u32::from_le_bytes([header[12], header[13], header[14], header[15]]);
            let head_dim = u32::from_le_bytes([header[16], header[17], header[18], header[19]]);
            let session_id_len =
                u32::from_le_bytes([header[24], header[25], header[26], header[27]]) as usize;
            let timestamp = u64::from_le_bytes([
                header[28], header[29], header[30], header[31], header[32], header[33], header[34],
                header[35],
            ]);

            let (vault_id, model_hash, has_conv_state) = if version >= VERSION_2
                && bytes_read >= HEADER_V2_SIZE
            {
                let vid = u64::from_le_bytes([
                    header[36], header[37], header[38], header[39], header[40], header[41],
                    header[42], header[43],
                ]);
                let mh = u64::from_le_bytes([
                    header[44], header[45], header[46], header[47], header[48], header[49],
                    header[50], header[51],
                ]);
                let flags = u32::from_le_bytes([header[52], header[53], header[54], header[55]]);
                (vid, mh, flags & 1 != 0)
            } else {
                (0, 0, false)
            };

            // Read session_id
            let mut sid_buf = vec![0u8; session_id_len];
            let session_id = if file.read_exact(&mut sid_buf).is_ok() {
                String::from_utf8_lossy(&sid_buf).to_string()
            } else {
                "unknown".to_string()
            };

            // Model ID from parent directory name
            let model_id = dir
                .file_name()
                .and_then(|s| s.to_str())
                .unwrap_or("unknown")
                .to_string();

            let total_bytes = fs::metadata(&path).map(|m| m.len()).unwrap_or(0);

            results.push(SSMStateMetadata {
                model_id,
                session_id,
                layer_count,
                state_dim,
                head_dim,
                total_bytes,
                timestamp,
                vault_id,
                model_hash,
                has_conv_state,
                file_path: path.to_string_lossy().to_string(),
            });
        }
    }

    results.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));
    Ok(results)
}

/// Delete old SSM states for a specific model, keeping only the most recent `keep_count`.
pub fn prune_ssm_states(
    vault_root: &Path,
    model_hash: Option<u64>,
    keep_count: usize,
) -> Result<u32, SSMStateError> {
    let states = list_ssm_states(vault_root, model_hash)?;
    let mut removed = 0u32;

    for state in states.iter().skip(keep_count) {
        if fs::remove_file(&state.file_path).is_ok() {
            removed += 1;
        }
    }

    Ok(removed)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn make_test_state(session_id: &str, model_id: &str) -> SSMState {
        let state_dim = 64u32;
        let head_dim = 32u32;
        let layer_count = 4u32;
        let bytes_per_layer = state_dim as usize * head_dim as usize * 2;
        let total_bytes = bytes_per_layer * layer_count as usize;

        SSMState {
            model_id: model_id.to_string(),
            session_id: session_id.to_string(),
            layer_count,
            state_dim,
            head_dim,
            vault_id: hash_vault_path("/test/vault"),
            model_hash: hash_model_id(model_id),
            has_conv_state: false,
            layer_data: vec![0x42; total_bytes],
        }
    }

    #[test]
    fn save_and_load_roundtrip_v2() {
        let tmp = TempDir::new().unwrap();
        let state = make_test_state("sess_001", "lfm2-1.2b");
        let path = save_ssm_state(&state, tmp.path()).unwrap();

        assert!(path.exists());

        let loaded = load_ssm_state(&path).unwrap();
        assert_eq!(loaded.session_id, "sess_001");
        assert_eq!(loaded.layer_count, 4);
        assert_eq!(loaded.state_dim, 64);
        assert_eq!(loaded.head_dim, 32);
        assert_eq!(loaded.vault_id, state.vault_id);
        assert_eq!(loaded.model_hash, state.model_hash);
        assert!(!loaded.has_conv_state);
        assert_eq!(loaded.layer_data.len(), state.layer_data.len());
        assert_eq!(loaded.layer_data[0], 0x42);
    }

    #[test]
    fn list_and_prune() {
        let tmp = TempDir::new().unwrap();
        for i in 0..5 {
            let state = make_test_state(&format!("sess_{i}"), "lfm2-1.2b");
            save_ssm_state(&state, tmp.path()).unwrap();
            std::thread::sleep(std::time::Duration::from_millis(10));
        }

        let all = list_ssm_states(tmp.path(), None).unwrap();
        assert_eq!(all.len(), 5);

        let mh = hash_model_id("lfm2-1.2b");
        let removed = prune_ssm_states(tmp.path(), Some(mh), 2).unwrap();
        assert_eq!(removed, 3);

        let remaining = list_ssm_states(tmp.path(), Some(mh)).unwrap();
        assert_eq!(remaining.len(), 2);
    }

    #[test]
    fn invalid_magic_rejected() {
        let tmp = TempDir::new().unwrap();
        let bad_file = tmp.path().join("ssm_state").join("bad").join("bad.mambastate");
        fs::create_dir_all(bad_file.parent().unwrap()).unwrap();
        fs::write(&bad_file, &[0u8; 64]).unwrap();

        assert!(load_ssm_state(&bad_file).is_err());
    }

    #[test]
    fn empty_vault() {
        let tmp = TempDir::new().unwrap();
        let states = list_ssm_states(tmp.path(), None).unwrap();
        assert!(states.is_empty());
    }

    #[test]
    fn hash_stability() {
        let h1 = hash_vault_path("/Users/jojo/vault");
        let h2 = hash_vault_path("/Users/jojo/vault");
        assert_eq!(h1, h2);

        let h3 = hash_vault_path("/Users/jojo/other");
        assert_ne!(h1, h3);
    }
}
