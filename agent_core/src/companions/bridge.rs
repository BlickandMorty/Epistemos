//! UniFFI surface for the companion registry (S5 — Landing Farm
//! placement; DOCTRINE §3.2, §3.5; IMPLEMENTATION §3-S5).
//!
//! Per DOCTRINE I-7 Swift never mutates the registry directly —
//! every operation crosses this typed FFI boundary. Per
//! DOCTRINE I-8 the registry surface is **control-plane** (low
//! frequency: list, create, archive); per-frame visual deltas
//! cross via `crate::ffi::delta_ring` instead.
//!
//! This module follows the existing `crate::bridge` pattern:
//! free-function `#[uniffi::export]` decorators wrapped in
//! `ffi_guard_value!` so panics map to safe defaults under
//! `panic = "unwind"`.

use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use super::activity::ActivityState;
use super::transaction::{create_companion, CreationError};
use super::{
    ArmStyle, CompanionRegistry, CompanionSpec, EyeStyle, HeadShape, PropKind,
    ProviderRole, ToolAffinities,
};

// =============================================================================
// FFI safety harness — mirror of crate::bridge / crate::simulation::sim.
// =============================================================================

fn panic_payload_to_string(payload: Box<dyn std::any::Any + Send>) -> String {
    let msg = if let Some(s) = payload.downcast_ref::<&str>() {
        (*s).to_string()
    } else if let Some(s) = payload.downcast_ref::<String>() {
        s.clone()
    } else {
        "unknown panic".to_string()
    };
    std::mem::forget(payload);
    msg
}

macro_rules! ffi_guard_value {
    ($body:expr, $default:expr) => {{
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| $body)) {
            Ok(v) => v,
            Err(payload) => {
                let msg = panic_payload_to_string(payload);
                tracing::error!(
                    "[ffi/companions] PANIC at companion-registry boundary: {}",
                    msg
                );
                $default
            }
        }
    }};
}

// =============================================================================
// Owned handle — Arc<Mutex<CompanionRegistry>>. Swift holds u64
// raw pointer; UniFFI free functions reach in via &*handle.
// =============================================================================

/// Inner: Arc-shared so multiple readers can query without
/// blocking each other (read holds the Mutex briefly). Mutations
/// (create / archive) take the lock.
struct RegistryHandle {
    registry: Mutex<CompanionRegistry>,
    vault_root: PathBuf,
}

// =============================================================================
// FFI Records — Swift sees these as POD structs.
// =============================================================================

/// One companion as the Landing Farm view-model needs it. Rust
/// types are stringified for transport — Swift maps them back to
/// strongly-typed enums on its side.
#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct CompanionFarmEntryFFI {
    /// ULID, 26-char Crockford base32.
    pub id: String,
    pub name: String,
    /// `"Block" | "Sage" | "Orb" | "HermesSnake"`.
    pub head_shape: String,
    /// Palette ID (e.g. `"local_teal_v1"`, `"claude_warm_v1"`).
    pub palette_ref: String,
    /// `"Round" | "Slit" | "Visor" | "Closed" | "NegativeSpace"`.
    pub eyes: String,
    /// `"None" | "Short" | "Long"`.
    pub arms: String,
    /// `"Wrench" | "Scroll" | "Magnifier" | "Folder" | "Baton" | "Lantern"` or `None`.
    pub prop_ref: Option<String>,
    pub accessory_ref: Option<String>,
    /// `"Orchestrator" | "Researcher" | "Worker" | "Critic" | ...`.
    pub role: String,
    pub base_model: String,
    /// `"Active" | "Recent" | "Dormant" | "Parked" | "JustAcquired"`.
    pub activity: String,
    pub farm_position_x: f32,
    pub farm_position_y: f32,
    /// RFC3339 UTC.
    pub created_at: String,
    /// `Some` for archived companions, `None` otherwise.
    pub archived_at: Option<String>,
}

/// Recoverable error from the companion bridge. Mirrors
/// `crate::bridge::AgentErrorFFI` shape so Swift can pattern-match
/// on `case` discriminants.
#[derive(uniffi::Error, thiserror::Error, Debug)]
pub enum CompanionsError {
    #[error("registry: {message}")]
    Registry { message: String },
    #[error("validation: {message}")]
    Validation { message: String },
    #[error("io: {message}")]
    Io { message: String },
}

impl From<CreationError> for CompanionsError {
    fn from(e: CreationError) -> Self {
        match e {
            CreationError::Validation(m) => CompanionsError::Validation { message: m },
            CreationError::Io(io) => CompanionsError::Io {
                message: io.to_string(),
            },
            other => CompanionsError::Registry {
                message: other.to_string(),
            },
        }
    }
}

impl From<super::registry::RegistryError> for CompanionsError {
    fn from(e: super::registry::RegistryError) -> Self {
        match e {
            super::registry::RegistryError::Io(io) => CompanionsError::Io {
                message: io.to_string(),
            },
            other => CompanionsError::Registry {
                message: other.to_string(),
            },
        }
    }
}

// =============================================================================
// FFI exports.
// =============================================================================

/// Open or create the companion registry at `<vault_root>/.epistemos/companions.db`.
/// Returns a u64 handle (raw `*const RegistryHandle`) Swift retains
/// until `epistemos_companions_destroy`.
#[uniffi::export]
pub fn epistemos_companions_open(vault_root: String) -> u64 {
    ffi_guard_value!(
        {
            let root = PathBuf::from(&vault_root);
            let db_path = root.join(".epistemos").join("companions.db");
            match CompanionRegistry::open(&db_path) {
                Ok(registry) => {
                    let handle = Arc::new(RegistryHandle {
                        registry: Mutex::new(registry),
                        vault_root: root,
                    });
                    Arc::into_raw(handle) as u64
                }
                Err(e) => {
                    tracing::error!(error = %e, "epistemos_companions_open failed");
                    0
                }
            }
        },
        0
    )
}

/// Reclaim the leaked Arc. Idempotent on `0`.
#[uniffi::export]
pub fn epistemos_companions_destroy(handle: u64) {
    if handle == 0 {
        return;
    }
    ffi_guard_value!(
        {
            // SAFETY: `handle` was returned by Arc::into_raw on
            // the matching `RegistryHandle`. We re-take ownership
            // and drop.
            let _ = unsafe { Arc::from_raw(handle as *const RegistryHandle) };
        },
        ()
    )
}

/// List all non-archived companions for the Landing Farm. Empty
/// vector if `handle == 0` or if the registry is empty.
#[uniffi::export]
pub fn epistemos_companions_list_active(handle: u64) -> Vec<CompanionFarmEntryFFI> {
    if handle == 0 {
        return Vec::new();
    }
    ffi_guard_value!(
        {
            let h = unsafe { &*(handle as *const RegistryHandle) };
            let lock = match h.registry.lock() {
                Ok(g) => g,
                Err(p) => p.into_inner(),
            };
            match lock.list_active() {
                Ok(rows) => rows
                    .into_iter()
                    .map(|c| companion_to_ffi(&c, &lock))
                    .collect(),
                Err(e) => {
                    tracing::error!(error = %e, "list_active failed");
                    Vec::new()
                }
            }
        },
        Vec::new()
    )
}

/// List every companion including archived ones (for the Audit
/// View — DOCTRINE §3.5 archive surface).
#[uniffi::export]
pub fn epistemos_companions_list_all(handle: u64) -> Vec<CompanionFarmEntryFFI> {
    if handle == 0 {
        return Vec::new();
    }
    ffi_guard_value!(
        {
            let h = unsafe { &*(handle as *const RegistryHandle) };
            let lock = match h.registry.lock() {
                Ok(g) => g,
                Err(p) => p.into_inner(),
            };
            match lock.list_all() {
                Ok(rows) => rows
                    .into_iter()
                    .map(|c| companion_to_ffi(&c, &lock))
                    .collect(),
                Err(e) => {
                    tracing::error!(error = %e, "list_all failed");
                    Vec::new()
                }
            }
        },
        Vec::new()
    )
}

/// Create a Local Helper preset companion (DOCTRINE §5.4 table).
/// Convenient for the S5 acceptance gate "companion creation
/// makes the new companion appear with rainbow-flash entrance"
/// — Swift wires this to a "+" button in the Farm view's empty
/// state.
#[uniffi::export]
pub fn epistemos_companions_create_local_helper(
    handle: u64,
    name: String,
) -> Result<CompanionFarmEntryFFI, CompanionsError> {
    if handle == 0 {
        return Err(CompanionsError::Validation {
            message: "registry handle is null".to_string(),
        });
    }
    ffi_guard_value!(
        {
            let h = unsafe { &*(handle as *const RegistryHandle) };
            let mut lock = match h.registry.lock() {
                Ok(g) => g,
                Err(p) => p.into_inner(),
            };

            // Stable layout: hash the name into a 4-column grid
            // so each new companion lands in a distinct slot.
            let (px, py) = farm_position_for(&name, lock.list_active().map(|v| v.len()).unwrap_or(0));

            let spec = CompanionSpec {
                name: name.clone(),
                head_shape: HeadShape::Block,
                palette_ref: "local_teal_v1".to_string(),
                eyes: EyeStyle::Round,
                arms: ArmStyle::Short,
                prop: Some(PropKind::Folder),
                accessory_ref: None,
                role: ProviderRole::Helper,
                base_model: "qwen3-4b-mlx".to_string(),
                system_prompt_preset: "local_helper_v1".to_string(),
                tool_affinities: ToolAffinities::from_prop(PropKind::Folder),
                vault_path: h.vault_root.join("Companions").join(&name),
                farm_position: (px, py),
            };
            let companion = create_companion(&mut lock, spec, &h.vault_root)
                .map_err(CompanionsError::from)?;
            Ok(companion_to_ffi(&companion, &lock))
        },
        Err(CompanionsError::Registry {
            message: "panic at create_local_helper".to_string(),
        })
    )
}

/// Archive a companion (soft-delete; DOCTRINE §3.5). Vault on
/// disk is preserved; the companion no longer appears in
/// `list_active`.
#[uniffi::export]
pub fn epistemos_companions_archive(
    handle: u64,
    id: String,
    reason: Option<String>,
) -> Result<(), CompanionsError> {
    if handle == 0 {
        return Err(CompanionsError::Validation {
            message: "registry handle is null".to_string(),
        });
    }
    ffi_guard_value!(
        {
            let h = unsafe { &*(handle as *const RegistryHandle) };
            let mut lock = match h.registry.lock() {
                Ok(g) => g,
                Err(p) => p.into_inner(),
            };
            let companion_id =
                super::CompanionId::parse(&id).ok_or(CompanionsError::Validation {
                    message: format!("invalid companion id '{}'", id),
                })?;
            lock.archive(companion_id, reason.as_deref())
                .map_err(CompanionsError::from)
        },
        Err(CompanionsError::Registry {
            message: "panic at archive".to_string(),
        })
    )
}

// =============================================================================
// Helpers.
// =============================================================================

/// Map a persisted `Companion` plus the live `ActivityTracker`
/// state into the FFI record Swift consumes.
fn companion_to_ffi(
    c: &super::Companion,
    registry: &CompanionRegistry,
) -> CompanionFarmEntryFFI {
    let activity = registry
        .activity()
        .state(c.id)
        .unwrap_or(ActivityState::Dormant);
    CompanionFarmEntryFFI {
        id: c.id.to_string(),
        name: c.name.clone(),
        head_shape: c.head_shape.as_str().to_string(),
        palette_ref: c.palette_ref.clone(),
        eyes: c.eyes.as_str().to_string(),
        arms: c.arms.as_str().to_string(),
        prop_ref: c.prop.map(|p| p.as_str().to_string()),
        accessory_ref: c.accessory_ref.clone(),
        role: c.role.as_str().to_string(),
        base_model: c.base_model.clone(),
        activity: activity.as_str().to_string(),
        farm_position_x: c.farm_position.0,
        farm_position_y: c.farm_position.1,
        created_at: c.created_at.clone(),
        archived_at: c.archived_at.clone(),
    }
}

/// Deterministic farm-grid layout per DOCTRINE §3.2. Positions
/// are returned in scene-space pixels (S4-renderer-compatible)
/// so the TheaterMTKView Camera transforms them naturally.
/// 4 columns × N rows, 96px spacing.
fn farm_position_for(name: &str, current_count: usize) -> (f32, f32) {
    use std::hash::{DefaultHasher, Hash, Hasher};
    let mut h = DefaultHasher::new();
    name.hash(&mut h);
    let nudge = (h.finish() % 12) as f32; // 0..11 px wobble
    let cols = 4usize;
    let col = current_count % cols;
    let row = current_count / cols;
    let x = 64.0 + (col as f32) * 96.0 + nudge;
    let y = 64.0 + (row as f32) * 96.0 + nudge;
    (x, y)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn vault_at(tmp: &tempfile::TempDir) -> String {
        tmp.path().to_string_lossy().to_string()
    }

    #[test]
    fn open_destroy_round_trip() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        assert_ne!(h, 0);
        epistemos_companions_destroy(h);
        epistemos_companions_destroy(0); // no-op
    }

    #[test]
    fn fresh_registry_has_no_active_companions() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        assert!(epistemos_companions_list_active(h).is_empty());
        epistemos_companions_destroy(h);
    }

    #[test]
    fn create_local_helper_persists_and_appears_in_list() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        let entry = epistemos_companions_create_local_helper(h, "Note Helper".to_string())
            .expect("create OK");
        assert_eq!(entry.name, "Note Helper");
        assert_eq!(entry.head_shape, "Block");
        assert_eq!(entry.role, "Helper");
        assert_eq!(entry.activity, "JustAcquired");
        assert_eq!(entry.archived_at, None);
        let active = epistemos_companions_list_active(h);
        assert_eq!(active.len(), 1);
        assert_eq!(active[0].id, entry.id);
        epistemos_companions_destroy(h);
    }

    #[test]
    fn create_with_null_handle_returns_validation_error() {
        let r = epistemos_companions_create_local_helper(0, "X".to_string());
        assert!(matches!(r, Err(CompanionsError::Validation { .. })));
    }

    #[test]
    fn restart_persists_companions_as_dormant_per_finding_4() {
        let tmp = tempfile::tempdir().unwrap();
        let vault = vault_at(&tmp);
        // First session — create a companion (JustAcquired).
        let h1 = epistemos_companions_open(vault.clone());
        let entry = epistemos_companions_create_local_helper(h1, "Persisted".to_string())
            .expect("create OK");
        assert_eq!(entry.activity, "JustAcquired");
        epistemos_companions_destroy(h1);

        // Second session — same vault, reopen.
        let h2 = epistemos_companions_open(vault);
        let active = epistemos_companions_list_active(h2);
        assert_eq!(active.len(), 1);
        assert_eq!(active[0].name, "Persisted");
        // Per audit Finding #4 the activity restores as Dormant
        // (NOT JustAcquired — that would flash the rainbow
        // entrance on every launch).
        assert_eq!(active[0].activity, "Dormant");
        epistemos_companions_destroy(h2);
    }

    #[test]
    fn archive_removes_from_active_list_but_keeps_in_all() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        let entry =
            epistemos_companions_create_local_helper(h, "ToArchive".to_string()).unwrap();
        assert_eq!(epistemos_companions_list_active(h).len(), 1);
        epistemos_companions_archive(h, entry.id.clone(), Some("test".to_string()))
            .expect("archive OK");
        assert_eq!(epistemos_companions_list_active(h).len(), 0);
        let all = epistemos_companions_list_all(h);
        assert_eq!(all.len(), 1);
        assert!(all[0].archived_at.is_some());
        epistemos_companions_destroy(h);
    }

    #[test]
    fn farm_position_distributes_across_grid() {
        let (x0, y0) = farm_position_for("a", 0);
        let (x1, y1) = farm_position_for("b", 1);
        let (x4, y4) = farm_position_for("c", 4);
        // Same row, different columns 0 and 1.
        assert!(x1 > x0 - 12.0 || y1 != y0);
        // Wraps to second row at index 4 (cols=4).
        assert!(y4 > y0);
    }
}
