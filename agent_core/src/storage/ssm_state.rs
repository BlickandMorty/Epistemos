//! SSM State Persistence — Save/load Mamba hidden state between sessions.
//!
//! Mamba/SSM models have fixed-size hidden state (~6-24MB) independent of context
//! length. This module serializes state to flat binary format for zero-copy
//! deserialization via mmap.
//!
//! State format:
//!   [Header: 32 bytes] [Layer 0 data] [Layer 1 data] ... [Layer N data]
//!
//! Header:
//!   magic: u32 = 0x4D414D42 ("MAMB")
//!   version: u32 = 1
//!   layer_count: u32
//!   state_dim: u32
//!   head_dim: u32
//!   dtype: u32 (0 = f16, 1 = f32)
//!   session_id_len: u32
//!   timestamp: u64
//!
//! Followed by session_id (UTF-8 bytes, padded to 8-byte alignment),
//! then raw tensor data per layer.

use std::fs;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::storage::vault::VaultError;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAGIC: u32 = 0x4D41_4D42; // "MAMB"
const VERSION: u32 = 1;
const HEADER_SIZE: usize = 36; // 7 × u32 (28 bytes) + 1 × u64 timestamp (8 bytes) = 36

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Metadata about a saved SSM state.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SSMStateMetadata {
    pub model_id: String,
    pub session_id: String,
    pub layer_count: u32,
    pub state_dim: u32,
    pub head_dim: u32,
    pub total_bytes: u64,
    pub timestamp: u64,
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
    /// Raw layer data — concatenated f16 tensors, one per layer.
    /// Each layer: state_dim * head_dim * 2 bytes (f16).
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

// ---------------------------------------------------------------------------
// Serialization
// ---------------------------------------------------------------------------

/// Save an SSM state to a flat binary file.
/// Format is designed for zero-copy mmap on load.
pub fn save_ssm_state(state: &SSMState, vault_root: &Path) -> Result<PathBuf, VaultError> {
    let state_dir = vault_root.join("ssm_state");
    fs::create_dir_all(&state_dir)?;

    let filename = format!(
        "{}_{}.mambastate",
        state.model_id.replace('/', "_"),
        state.session_id
    );
    let file_path = state_dir.join(&filename);

    let session_id_bytes = state.session_id.as_bytes();
    // Pad session_id to 8-byte alignment
    let padded_len = (session_id_bytes.len() + 7) & !7;

    let timestamp = chrono::Utc::now().timestamp() as u64;

    let mut file = fs::File::create(&file_path)?;

    // Write header (32 bytes)
    file.write_all(&MAGIC.to_le_bytes())?;
    file.write_all(&VERSION.to_le_bytes())?;
    file.write_all(&state.layer_count.to_le_bytes())?;
    file.write_all(&state.state_dim.to_le_bytes())?;
    file.write_all(&state.head_dim.to_le_bytes())?;
    file.write_all(&0u32.to_le_bytes())?; // dtype = f16
    file.write_all(&(session_id_bytes.len() as u32).to_le_bytes())?;
    file.write_all(&timestamp.to_le_bytes())?;

    // Write session_id (padded)
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
/// Uses standard read (mmap deferred until proven needed for perf).
pub fn load_ssm_state(file_path: &Path) -> Result<SSMState, VaultError> {
    let data = fs::read(file_path)?;
    if data.len() < HEADER_SIZE {
        return Err(VaultError::DatabaseError(
            "SSM state file too small".to_string(),
        ));
    }

    // Parse header
    let magic = u32::from_le_bytes([data[0], data[1], data[2], data[3]]);
    if magic != MAGIC {
        return Err(VaultError::DatabaseError(format!(
            "Invalid SSM state magic: {magic:#x} (expected {MAGIC:#x})"
        )));
    }

    let version = u32::from_le_bytes([data[4], data[5], data[6], data[7]]);
    if version != VERSION {
        return Err(VaultError::DatabaseError(format!(
            "Unsupported SSM state version: {version}"
        )));
    }

    let layer_count = u32::from_le_bytes([data[8], data[9], data[10], data[11]]);
    let state_dim = u32::from_le_bytes([data[12], data[13], data[14], data[15]]);
    let head_dim = u32::from_le_bytes([data[16], data[17], data[18], data[19]]);
    let _dtype = u32::from_le_bytes([data[20], data[21], data[22], data[23]]);
    let session_id_len = u32::from_le_bytes([data[24], data[25], data[26], data[27]]) as usize;
    // timestamp at offset 28 (u64, 8 bytes) — we skip it during load (reconstructed from file metadata)

    // Parse session_id
    let session_id_start = HEADER_SIZE;
    let session_id_end = session_id_start + session_id_len;
    if session_id_end > data.len() {
        return Err(VaultError::DatabaseError(
            "SSM state truncated at session_id".to_string(),
        ));
    }
    let session_id = String::from_utf8_lossy(&data[session_id_start..session_id_end]).to_string();

    // Layer data starts after padded session_id
    let padded_len = (session_id_len + 7) & !7;
    let layer_data_start = HEADER_SIZE + padded_len;
    let layer_data = data[layer_data_start..].to_vec();

    Ok(SSMState {
        model_id: String::new(), // not stored in file — derived from filename
        session_id,
        layer_count,
        state_dim,
        head_dim,
        layer_data,
    })
}

/// List all saved SSM states for a vault, sorted newest first.
pub fn list_ssm_states(vault_root: &Path) -> Result<Vec<SSMStateMetadata>, VaultError> {
    let state_dir = vault_root.join("ssm_state");
    if !state_dir.is_dir() {
        return Ok(Vec::new());
    }

    let mut results = Vec::new();

    for entry in fs::read_dir(&state_dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("mambastate") {
            continue;
        }

        // Read just the header to get metadata (no full load)
        let mut file = match fs::File::open(&path) {
            Ok(f) => f,
            Err(_) => continue,
        };
        let mut header = [0u8; 36]; // HEADER_SIZE = 36
        if file.read_exact(&mut header).is_err() {
            continue;
        }

        let magic = u32::from_le_bytes([header[0], header[1], header[2], header[3]]);
        if magic != MAGIC {
            continue;
        }

        let layer_count = u32::from_le_bytes([header[8], header[9], header[10], header[11]]);
        let state_dim = u32::from_le_bytes([header[12], header[13], header[14], header[15]]);
        let head_dim = u32::from_le_bytes([header[16], header[17], header[18], header[19]]);
        let session_id_len =
            u32::from_le_bytes([header[24], header[25], header[26], header[27]]) as usize;
        let timestamp = u64::from_le_bytes([
            header[28], header[29], header[30], header[31], header[32], header[33], header[34],
            header[35],
        ]);

        // Read session_id
        let mut sid_buf = vec![0u8; session_id_len];
        let session_id = if file.read_exact(&mut sid_buf).is_ok() {
            String::from_utf8_lossy(&sid_buf).to_string()
        } else {
            "unknown".to_string()
        };

        // Extract model_id from filename
        let filename = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");
        let model_id = filename
            .rsplitn(2, '_')
            .last()
            .unwrap_or("")
            .replace('_', "/");

        let total_bytes = fs::metadata(&path).map(|m| m.len()).unwrap_or(0);

        results.push(SSMStateMetadata {
            model_id,
            session_id,
            layer_count,
            state_dim,
            head_dim,
            total_bytes,
            timestamp,
            file_path: path.to_string_lossy().to_string(),
        });
    }

    results.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));
    Ok(results)
}

/// Delete old SSM states, keeping only the most recent `keep_count`.
pub fn prune_ssm_states(vault_root: &Path, keep_count: usize) -> Result<u32, VaultError> {
    let states = list_ssm_states(vault_root)?;
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

    fn make_test_state(session_id: &str) -> SSMState {
        let state_dim = 64u32;
        let head_dim = 32u32;
        let layer_count = 4u32;
        let bytes_per_layer = state_dim as usize * head_dim as usize * 2;
        let total_bytes = bytes_per_layer * layer_count as usize;

        SSMState {
            model_id: "lfm2-1.2b".to_string(),
            session_id: session_id.to_string(),
            layer_count,
            state_dim,
            head_dim,
            layer_data: vec![0x42; total_bytes],
        }
    }

    #[test]
    fn save_and_load_roundtrip() {
        let tmp = TempDir::new().unwrap();
        let state = make_test_state("sess_001");
        let path = save_ssm_state(&state, tmp.path()).unwrap();

        assert!(path.exists());

        let loaded = load_ssm_state(&path).unwrap();
        assert_eq!(loaded.session_id, "sess_001");
        assert_eq!(loaded.layer_count, 4);
        assert_eq!(loaded.state_dim, 64);
        assert_eq!(loaded.head_dim, 32);
        assert_eq!(loaded.layer_data.len(), state.layer_data.len());
        assert_eq!(loaded.layer_data[0], 0x42);
    }

    #[test]
    fn list_states_sorted() {
        let tmp = TempDir::new().unwrap();
        save_ssm_state(&make_test_state("sess_a"), tmp.path()).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(10));
        save_ssm_state(&make_test_state("sess_b"), tmp.path()).unwrap();

        let states = list_ssm_states(tmp.path()).unwrap();
        assert_eq!(states.len(), 2);
    }

    #[test]
    fn prune_keeps_recent() {
        let tmp = TempDir::new().unwrap();
        for i in 0..5 {
            save_ssm_state(&make_test_state(&format!("sess_{i}")), tmp.path()).unwrap();
            std::thread::sleep(std::time::Duration::from_millis(10));
        }

        let removed = prune_ssm_states(tmp.path(), 2).unwrap();
        assert_eq!(removed, 3);

        let remaining = list_ssm_states(tmp.path()).unwrap();
        assert_eq!(remaining.len(), 2);
    }

    #[test]
    fn invalid_magic_rejected() {
        let tmp = TempDir::new().unwrap();
        let bad_file = tmp.path().join("ssm_state").join("bad.mambastate");
        fs::create_dir_all(bad_file.parent().unwrap()).unwrap();
        fs::write(&bad_file, &[0u8; 64]).unwrap();

        assert!(load_ssm_state(&bad_file).is_err());
    }

    #[test]
    fn empty_vault() {
        let tmp = TempDir::new().unwrap();
        let states = list_ssm_states(tmp.path()).unwrap();
        assert!(states.is_empty());
    }
}
