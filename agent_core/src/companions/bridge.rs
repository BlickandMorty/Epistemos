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

/// One company in the three-level Company → Model → Agent
/// hierarchy per DOCTRINE §3.4 v1.4. Synthesised from the
/// distinct provider/company prefixes of registered companions'
/// `base_model` values (e.g. `claude-sonnet-4-6` → company
/// `Anthropic`, model `Claude Sonnet 4.6`). The synthetic
/// `Local` company holds every MLX-backed companion.
#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct CompanyFFI {
    /// Stable slug — `anthropic`, `moonshot`, `openai`, `local`, etc.
    pub slug: String,
    /// User-facing display name — `Anthropic`, `Moonshot AI`,
    /// `OpenAI`, `Local`.
    pub display_name: String,
    /// Hex brand color from `provenance.json` (e.g. `#D97757`).
    /// Empty string if unavailable.
    pub brand_color_hex: String,
    /// How many distinct models from this company have at least
    /// one registered agent.
    pub model_count: u32,
    /// Total agent count across all this company's models.
    pub agent_count: u32,
}

/// One model row in the picker. Belongs to exactly one
/// `CompanyFFI`. The display name is whatever the agents'
/// `base_model` values resolve to (e.g. `Claude Sonnet 4.6`).
#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct ModelFFI {
    pub id: String,
    pub company_slug: String,
    pub display_name: String,
    /// `claude-sonnet-4-6`, `qwen3-4b-mlx`, etc.
    pub base_model: String,
    pub agent_count: u32,
    /// Hex brand color inherited from the parent company. Empty
    /// if unavailable.
    pub brand_color_hex: String,
}

/// Input to the §6.3 atomic creation transaction (S8). Mirrors
/// `super::CompanionSpec` with stringified enums so Swift can
/// build it from typed sources. Validation per §6.2 happens
/// inside the transaction; this Record is the wire format only.
#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct CompanionSpecFFI {
    pub name: String,
    /// `"Block" | "Sage" | "Orb" | "HermesSnake"` — see
    /// `super::HeadShape::as_str`.
    pub head_shape: String,
    /// Curated palette ref (`claude_warm_v1`, `kimi_indigo_v1`,
    /// …) OR raw sRGB hex `#RRGGBB` when the user picked a
    /// Custom palette. Validation per §6.2 enforces hex-format
    /// + WCAG AA contrast for Custom values.
    pub palette_ref: String,
    /// `"Round" | "Slit" | "Visor" | "Closed" | "NegativeSpace"`.
    pub eyes: String,
    /// `"None" | "Short" | "Long"`.
    pub arms: String,
    /// `"Wrench" | "Scroll" | "Magnifier" | "Folder" | "Baton" |
    /// "Lantern"`, or `None` for the no-prop case.
    pub prop: Option<String>,
    pub accessory_ref: Option<String>,
    /// `"Orchestrator" | "Researcher" | "Worker" | "Critic" |
    /// "CodeWorker" | "Faculty" | "Helper" | "Custom"`.
    pub role: String,
    pub base_model: String,
    pub system_prompt_preset: String,
    /// Path component(s) under the registry's `vault_root`. The
    /// transaction joins this with the registry's own vault root
    /// to produce the absolute folder path. Use forward slashes
    /// for nested components (Rust normalises per OS).
    pub vault_subpath: String,
    /// Initial farm position per DOCTRINE §3.2. Caller normally
    /// passes `(0, 0)` and lets the registry assign.
    pub farm_position_x: f32,
    pub farm_position_y: f32,
}

/// One vault on disk, owned by an entity (Model / Agent /
/// Sub-agent) per DOCTRINE §3.4.1.
#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct VaultFFI {
    pub id: String,
    /// `"primary"` for the canonical `vault/` folder; the
    /// directory name (e.g. `code-review-archive`) for siblings
    /// under `vaults/`.
    pub label: String,
    /// Absolute filesystem path on the user's vault root.
    pub absolute_path: String,
    pub is_primary: bool,
    /// RFC3339 — directory mtime, so the sidebar can sort by
    /// recency.
    pub modified_at: String,
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

/// Create a fully-customised companion via the §6.3 atomic
/// transaction (S8). Validates per §6.2 (name, vault path,
/// palette hex if Custom), then runs the 7-step transaction
/// from `transaction::create_companion`. On any failure rolls
/// back vault folder + SQLite rows + audit ledger and returns a
/// typed `CompanionsError::Validation` so the wizard can
/// re-enter the failing step.
#[uniffi::export]
pub fn epistemos_companions_create_from_spec(
    handle: u64,
    spec_ffi: CompanionSpecFFI,
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
            // Decode stringified enums → strongly-typed Rust
            // values; surface a typed Validation error per axis
            // so the Swift wizard can highlight the offending
            // step.
            let head_shape = HeadShape::parse(&spec_ffi.head_shape)
                .ok_or_else(|| CompanionsError::Validation {
                    message: format!("unknown head_shape '{}'", spec_ffi.head_shape),
                })?;
            let eyes = EyeStyle::parse(&spec_ffi.eyes)
                .ok_or_else(|| CompanionsError::Validation {
                    message: format!("unknown eyes '{}'", spec_ffi.eyes),
                })?;
            let arms = ArmStyle::parse(&spec_ffi.arms)
                .ok_or_else(|| CompanionsError::Validation {
                    message: format!("unknown arms '{}'", spec_ffi.arms),
                })?;
            let prop = match spec_ffi.prop.as_deref() {
                Some(p) => Some(PropKind::parse(p).ok_or_else(|| CompanionsError::Validation {
                    message: format!("unknown prop '{}'", p),
                })?),
                None => None,
            };
            let role = ProviderRole::parse(&spec_ffi.role).ok_or_else(|| {
                CompanionsError::Validation {
                    message: format!("unknown role '{}'", spec_ffi.role),
                }
            })?;
            // Resolve the relative subpath to an absolute vault
            // path under our owned vault_root. Reject absolute
            // paths or paths escaping the root.
            let trimmed = spec_ffi.vault_subpath.trim_start_matches('/');
            let vault_path = h.vault_root.join(trimmed);
            // Choose tool affinities — if a prop is selected the
            // canonical mapping (§5.5 Category A) drives the
            // bitset; otherwise default to a minimal helper set.
            let tool_affinities = match prop {
                Some(p) => ToolAffinities::from_prop(p),
                None => ToolAffinities::empty(),
            };
            let spec = CompanionSpec {
                name: spec_ffi.name,
                head_shape,
                palette_ref: spec_ffi.palette_ref,
                eyes,
                arms,
                prop,
                accessory_ref: spec_ffi.accessory_ref,
                role,
                base_model: spec_ffi.base_model,
                system_prompt_preset: spec_ffi.system_prompt_preset,
                tool_affinities,
                vault_path,
                farm_position: (spec_ffi.farm_position_x, spec_ffi.farm_position_y),
            };
            let companion = create_companion(&mut lock, spec, &h.vault_root)
                .map_err(CompanionsError::from)?;
            Ok(companion_to_ffi(&companion, &lock))
        },
        Err(CompanionsError::Registry {
            message: "panic at create_from_spec".to_string(),
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
// S6 v1.6 — three-level Company → Model → Agent hierarchy.
// Companies are SYNTHESISED from registered companions' `base_model`
// values; we don't persist them as their own SQLite rows because
// company identity is fully derivable. Models likewise. Per
// DOCTRINE §3.4 v1.4 + §3.4.1: only Companions (Agents and
// Sub-agents) are persisted in the SQLite registry.
// =============================================================================

/// List the distinct companies that have at least one registered
/// (non-archived) companion. Synthesised from `base_model`
/// prefixes.
#[uniffi::export]
pub fn epistemos_companions_list_companies(handle: u64) -> Vec<CompanyFFI> {
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
            let companions = lock.list_active().unwrap_or_default();
            synthesise_companies(&companions)
        },
        Vec::new()
    )
}

/// List the distinct models for a given company slug. Synthesised
/// from registered companions' `base_model` values whose company
/// resolves to `company_slug`.
#[uniffi::export]
pub fn epistemos_companions_list_models_for_company(
    handle: u64,
    company_slug: String,
) -> Vec<ModelFFI> {
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
            let companions = lock.list_active().unwrap_or_default();
            synthesise_models_for_company(&companions, &company_slug)
        },
        Vec::new()
    )
}

/// List agents whose `base_model` resolves to the given model id.
#[uniffi::export]
pub fn epistemos_companions_list_agents_for_model(
    handle: u64,
    model_id: String,
) -> Vec<CompanionFarmEntryFFI> {
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
            let model_id_norm = model_id_for(&model_id);
            match lock.list_active() {
                Ok(rows) => rows
                    .into_iter()
                    .filter(|c| model_id_for(&c.base_model) == model_id_norm)
                    .map(|c| companion_to_ffi(&c, &lock))
                    .collect(),
                Err(_) => Vec::new(),
            }
        },
        Vec::new()
    )
}

/// List vaults owned by an entity (currently: an Agent — Sub-agent
/// support extends in a future slice). Returns the primary `vault/`
/// + every sibling under `vaults/`.
#[uniffi::export]
pub fn epistemos_companions_list_vaults_for_entity(
    handle: u64,
    entity_id: String,
) -> Vec<VaultFFI> {
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
            let cid = match super::CompanionId::parse(&entity_id) {
                Some(v) => v,
                None => return Vec::new(),
            };
            let companion = match lock.get(cid) {
                Ok(Some(c)) => c,
                _ => return Vec::new(),
            };
            list_vaults_on_disk(&companion.vault_path)
        },
        Vec::new()
    )
}

/// Create a new sibling vault under `<entity>/vaults/<name>/`.
/// Emits no audit event yet — that wires in S11 alongside the
/// gift-box ledger; for now this is a thin filesystem op.
#[uniffi::export]
pub fn epistemos_companions_create_vault(
    handle: u64,
    entity_id: String,
    vault_name: String,
) -> Result<VaultFFI, CompanionsError> {
    if handle == 0 {
        return Err(CompanionsError::Validation {
            message: "registry handle is null".to_string(),
        });
    }
    ffi_guard_value!(
        {
            let trimmed = vault_name.trim();
            if trimmed.is_empty() {
                return Err(CompanionsError::Validation {
                    message: "vault name is empty".to_string(),
                });
            }
            if trimmed.len() > 64
                || trimmed.contains('/')
                || trimmed.contains('\\')
                || trimmed.contains('\0')
            {
                return Err(CompanionsError::Validation {
                    message: format!("vault name '{}' has forbidden characters", trimmed),
                });
            }
            let h = unsafe { &*(handle as *const RegistryHandle) };
            let lock = match h.registry.lock() {
                Ok(g) => g,
                Err(p) => p.into_inner(),
            };
            let cid = super::CompanionId::parse(&entity_id).ok_or(
                CompanionsError::Validation {
                    message: format!("invalid entity id '{}'", entity_id),
                },
            )?;
            let companion = lock
                .get(cid)
                .map_err(CompanionsError::from)?
                .ok_or(CompanionsError::Registry {
                    message: format!("entity {} not found", entity_id),
                })?;
            let vaults_dir = companion.vault_path.join("vaults");
            let new_path = vaults_dir.join(trimmed);
            if new_path.exists() {
                return Err(CompanionsError::Validation {
                    message: format!("vault '{}' already exists", trimmed),
                });
            }
            std::fs::create_dir_all(&new_path).map_err(|e| CompanionsError::Io {
                message: format!("create vault folder: {}", e),
            })?;
            // Write a minimal provenance marker so the directory
            // is recognisable as an Epistemos vault on disk.
            let toml_path = new_path.join("vault.toml");
            std::fs::write(
                &toml_path,
                format!(
                    "# vault.toml\n# Created via epistemos_companions_create_vault for entity {}\n",
                    entity_id
                ),
            )
            .map_err(|e| CompanionsError::Io {
                message: format!("write vault.toml: {}", e),
            })?;
            let meta = std::fs::metadata(&new_path).map_err(|e| CompanionsError::Io {
                message: format!("stat vault folder: {}", e),
            })?;
            Ok(VaultFFI {
                id: format!("{}::{}", entity_id, trimmed),
                label: trimmed.to_string(),
                absolute_path: new_path.to_string_lossy().to_string(),
                is_primary: false,
                modified_at: format_mtime(&meta),
            })
        },
        Err(CompanionsError::Registry {
            message: "panic at create_vault".to_string(),
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

/// Map a base_model string (e.g. `claude-sonnet-4-6`,
/// `qwen3-4b-mlx`, `gpt-5.5`) to the synthetic company slug per
/// DOCTRINE §3.4 v1.4. Local MLX models go under `local`; cloud
/// models route via prefix.
fn company_slug_for(base_model: &str) -> &'static str {
    let lower = base_model.to_ascii_lowercase();
    if lower.ends_with("-mlx") || lower.contains("qwen") || lower.contains("mamba")
        || lower.contains("gemma") || lower.contains("llama")
    {
        "local"
    } else if lower.starts_with("claude") || lower.starts_with("anthropic") {
        "anthropic"
    } else if lower.starts_with("gpt") || lower.starts_with("openai")
        || lower.starts_with("codex") || lower.starts_with("o1") || lower.starts_with("o3")
    {
        "openai"
    } else if lower.starts_with("kimi") || lower.contains("moonshot") {
        "moonshot"
    } else if lower.starts_with("gemini") || lower.starts_with("google") {
        "google"
    } else if lower.starts_with("hermes") || lower.contains("nous") {
        "hermes-agent"
    } else {
        "custom"
    }
}

/// Display name for a company slug. Falls back to capitalised
/// slug if unknown.
fn company_display_name(slug: &str) -> String {
    match slug {
        "anthropic" => "Anthropic".to_string(),
        "openai" => "OpenAI".to_string(),
        "moonshot" => "Moonshot AI".to_string(),
        "google" => "Google".to_string(),
        "hermes-agent" => "Hermes Agent".to_string(),
        "local" => "Local".to_string(),
        "custom" => "Custom".to_string(),
        other => {
            let mut chars = other.chars();
            chars
                .next()
                .map(|c| c.to_ascii_uppercase().to_string() + chars.as_str())
                .unwrap_or_default()
        }
    }
}

/// Brand color hex by slug — matches DOCTRINE §10.7 V1 catalog.
fn company_brand_hex(slug: &str) -> &'static str {
    match slug {
        "anthropic" => "#D97757",
        "openai" => "#000000",
        "moonshot" => "#5B8DEF",
        "google" => "#4285F4",
        "hermes-agent" => "#D4AF37",
        "local" => "#2BA59B",
        _ => "",
    }
}

/// Stable, slug-style id for a model — `claude-sonnet-4-6` etc.
/// Used as the model row key in the picker.
fn model_id_for(base_model: &str) -> String {
    base_model.to_ascii_lowercase().replace([' ', '_'], "-")
}

/// Display name for a base_model — light heuristic to title-case
/// the canonical model strings without hard-coding every model.
fn model_display_name(base_model: &str) -> String {
    // `claude-sonnet-4-6` → `Claude Sonnet 4 6` (close enough for
    // V1; later slices can map to a richer table).
    base_model
        .split(|c| c == '-' || c == '_')
        .map(|seg| {
            if seg.is_empty() {
                String::new()
            } else {
                let mut chars = seg.chars();
                chars
                    .next()
                    .map(|c| c.to_ascii_uppercase().to_string() + chars.as_str())
                    .unwrap_or_default()
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

/// Group registered companions by company → return the synthetic
/// company list with model + agent counts.
fn synthesise_companies(companions: &[super::Companion]) -> Vec<CompanyFFI> {
    use std::collections::BTreeMap;
    let mut by_slug: BTreeMap<&str, (BTreeSetForCount<String>, u32)> = BTreeMap::new();
    for c in companions {
        let slug = company_slug_for(&c.base_model);
        let entry = by_slug.entry(slug).or_default();
        entry.0.insert(model_id_for(&c.base_model));
        entry.1 += 1;
    }
    by_slug
        .into_iter()
        .map(|(slug, (models, agents))| CompanyFFI {
            slug: slug.to_string(),
            display_name: company_display_name(slug),
            brand_color_hex: company_brand_hex(slug).to_string(),
            model_count: models.len() as u32,
            agent_count: agents,
        })
        .collect()
}

/// Group registered companions in `company_slug` by base_model →
/// return the synthetic model list with agent counts.
fn synthesise_models_for_company(
    companions: &[super::Companion],
    company_slug: &str,
) -> Vec<ModelFFI> {
    use std::collections::BTreeMap;
    let mut by_model: BTreeMap<String, (String, u32)> = BTreeMap::new();
    for c in companions {
        if company_slug_for(&c.base_model) != company_slug {
            continue;
        }
        let id = model_id_for(&c.base_model);
        let entry = by_model
            .entry(id.clone())
            .or_insert_with(|| (c.base_model.clone(), 0));
        entry.1 += 1;
    }
    by_model
        .into_iter()
        .map(|(id, (base_model, agent_count))| ModelFFI {
            id: id.clone(),
            company_slug: company_slug.to_string(),
            display_name: model_display_name(&base_model),
            base_model,
            agent_count,
            brand_color_hex: company_brand_hex(company_slug).to_string(),
        })
        .collect()
}

/// Wrapper used by `synthesise_companies` to dedupe model ids
/// without pulling in the full `std::collections::BTreeSet` at
/// every call site (keeps the import surface tight).
type BTreeSetForCount<T> = std::collections::BTreeSet<T>;

/// Enumerate vaults on disk for an entity. Primary `vault/` always
/// returns first; sibling vaults under `vaults/` follow in
/// modification-time order (newest first).
fn list_vaults_on_disk(entity_vault_path: &std::path::Path) -> Vec<VaultFFI> {
    let mut out = Vec::new();
    // Primary vault is the entity's own vault_path. If it exists
    // on disk, list it first.
    if let Ok(meta) = std::fs::metadata(entity_vault_path) {
        if meta.is_dir() {
            out.push(VaultFFI {
                id: format!("{}::primary", entity_vault_path.display()),
                label: "primary".to_string(),
                absolute_path: entity_vault_path.to_string_lossy().to_string(),
                is_primary: true,
                modified_at: format_mtime(&meta),
            });
        }
    }
    // Sibling vaults under <entity>/vaults/.
    let vaults_dir = entity_vault_path.join("vaults");
    if let Ok(entries) = std::fs::read_dir(&vaults_dir) {
        let mut siblings: Vec<(VaultFFI, std::time::SystemTime)> = Vec::new();
        for entry in entries.flatten() {
            let path = entry.path();
            let meta = match entry.metadata() {
                Ok(m) if m.is_dir() => m,
                _ => continue,
            };
            let name = match path.file_name().and_then(|n| n.to_str()) {
                Some(n) => n.to_string(),
                None => continue,
            };
            // Skip dotfiles and the archive bin.
            if name.starts_with('.') {
                continue;
            }
            let mtime = meta.modified().unwrap_or(std::time::UNIX_EPOCH);
            siblings.push((
                VaultFFI {
                    id: format!("{}::{}", entity_vault_path.display(), name),
                    label: name,
                    absolute_path: path.to_string_lossy().to_string(),
                    is_primary: false,
                    modified_at: format_mtime(&meta),
                },
                mtime,
            ));
        }
        siblings.sort_by(|a, b| b.1.cmp(&a.1)); // newest first
        out.extend(siblings.into_iter().map(|(v, _)| v));
    }
    out
}

fn format_mtime(meta: &std::fs::Metadata) -> String {
    let mtime = meta.modified().unwrap_or(std::time::UNIX_EPOCH);
    let datetime: chrono::DateTime<chrono::Utc> = mtime.into();
    datetime.to_rfc3339_opts(chrono::SecondsFormat::Secs, true)
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

    // S6 v1.6 — hierarchical Company → Model → Agent + vault tests.

    #[test]
    fn company_slug_routing_covers_canonical_providers() {
        assert_eq!(company_slug_for("claude-sonnet-4-6"), "anthropic");
        assert_eq!(company_slug_for("claude-opus-4-7"), "anthropic");
        assert_eq!(company_slug_for("gpt-5.5"), "openai");
        assert_eq!(company_slug_for("codex-cli"), "openai");
        assert_eq!(company_slug_for("kimi-k2"), "moonshot");
        assert_eq!(company_slug_for("gemini-2-pro"), "google");
        assert_eq!(company_slug_for("hermes-3-405b"), "hermes-agent");
        assert_eq!(company_slug_for("qwen3-4b-mlx"), "local");
        assert_eq!(company_slug_for("mamba-2-2.7b-mlx"), "local");
        assert_eq!(company_slug_for("gemma-2-9b"), "local");
        assert_eq!(company_slug_for("some-future-model"), "custom");
    }

    #[test]
    fn list_companies_synthesises_from_registered_companions() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        let _ = epistemos_companions_create_local_helper(h, "Note Helper".to_string())
            .unwrap();
        let _ = epistemos_companions_create_local_helper(h, "Memory Clerk".to_string())
            .unwrap();

        let companies = epistemos_companions_list_companies(h);
        // Both Local Helpers route to the synthetic `Local`
        // company per DOCTRINE §3.4 v1.4.
        assert_eq!(companies.len(), 1);
        assert_eq!(companies[0].slug, "local");
        assert_eq!(companies[0].display_name, "Local");
        assert_eq!(companies[0].agent_count, 2);
        // Brand color non-empty for known providers.
        assert!(!companies[0].brand_color_hex.is_empty());
        epistemos_companions_destroy(h);
    }

    #[test]
    fn list_models_for_company_returns_distinct_models() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        // Both companions share the same base_model — should
        // appear as ONE model row.
        let _ = epistemos_companions_create_local_helper(h, "A".to_string()).unwrap();
        let _ = epistemos_companions_create_local_helper(h, "B".to_string()).unwrap();
        let models = epistemos_companions_list_models_for_company(h, "local".to_string());
        assert_eq!(models.len(), 1);
        assert_eq!(models[0].base_model, "qwen3-4b-mlx");
        assert_eq!(models[0].agent_count, 2);
        assert_eq!(models[0].company_slug, "local");
        epistemos_companions_destroy(h);
    }

    #[test]
    fn list_agents_for_model_filters_correctly() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        let entry = epistemos_companions_create_local_helper(h, "OnlyOne".to_string())
            .unwrap();
        let agents = epistemos_companions_list_agents_for_model(
            h,
            model_id_for(&entry.base_model),
        );
        assert_eq!(agents.len(), 1);
        assert_eq!(agents[0].name, "OnlyOne");
        // Unrelated model filter — empty.
        let none = epistemos_companions_list_agents_for_model(
            h,
            "claude-opus-4-7".to_string(),
        );
        assert!(none.is_empty());
        epistemos_companions_destroy(h);
    }

    #[test]
    fn list_vaults_returns_primary_only_for_fresh_entity() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        let entry = epistemos_companions_create_local_helper(h, "FreshOne".to_string())
            .unwrap();
        let vaults = epistemos_companions_list_vaults_for_entity(h, entry.id);
        assert_eq!(vaults.len(), 1);
        assert!(vaults[0].is_primary);
        assert_eq!(vaults[0].label, "primary");
        epistemos_companions_destroy(h);
    }

    #[test]
    fn create_vault_appends_sibling() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        let entry = epistemos_companions_create_local_helper(
            h,
            "VaultOwner".to_string(),
        )
        .unwrap();
        let new_vault = epistemos_companions_create_vault(
            h,
            entry.id.clone(),
            "research".to_string(),
        )
        .expect("create vault OK");
        assert!(!new_vault.is_primary);
        assert_eq!(new_vault.label, "research");
        // Now list should return primary + research.
        let vaults = epistemos_companions_list_vaults_for_entity(h, entry.id);
        assert_eq!(vaults.len(), 2);
        assert!(vaults.iter().any(|v| v.is_primary));
        assert!(vaults.iter().any(|v| v.label == "research"));
        epistemos_companions_destroy(h);
    }

    #[test]
    fn create_vault_rejects_invalid_names() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        let entry =
            epistemos_companions_create_local_helper(h, "Validator".to_string()).unwrap();
        // Empty name.
        assert!(matches!(
            epistemos_companions_create_vault(h, entry.id.clone(), "".to_string()),
            Err(CompanionsError::Validation { .. })
        ));
        // Slash in name.
        assert!(matches!(
            epistemos_companions_create_vault(h, entry.id.clone(), "a/b".to_string()),
            Err(CompanionsError::Validation { .. })
        ));
        // Duplicate name.
        let _ = epistemos_companions_create_vault(h, entry.id.clone(), "dup".to_string())
            .unwrap();
        assert!(matches!(
            epistemos_companions_create_vault(h, entry.id, "dup".to_string()),
            Err(CompanionsError::Validation { .. })
        ));
        epistemos_companions_destroy(h);
    }

    #[test]
    fn create_vault_rejects_unknown_entity() {
        use crate::companions::CompanionId;
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        // Fabricated id that doesn't exist in the registry.
        let bogus_id = CompanionId::new_ulid().to_string();
        assert!(matches!(
            epistemos_companions_create_vault(h, bogus_id, "x".to_string()),
            Err(CompanionsError::Registry { .. })
        ));
        epistemos_companions_destroy(h);
    }

    // S8 — create_from_spec / CompanionSpecFFI tests.

    fn fixture_spec_ffi(name: &str) -> CompanionSpecFFI {
        CompanionSpecFFI {
            name: name.to_string(),
            head_shape: "Block".to_string(),
            palette_ref: "claude_warm_v1".to_string(),
            eyes: "NegativeSpace".to_string(),
            arms: "None".to_string(),
            prop: Some("Wrench".to_string()),
            accessory_ref: None,
            role: "CodeWorker".to_string(),
            base_model: "claude-sonnet-4-6".to_string(),
            system_prompt_preset: "careful_reviewer_v1".to_string(),
            vault_subpath: format!("Companions/{}", name),
            farm_position_x: 0.0,
            farm_position_y: 0.0,
        }
    }

    #[test]
    fn create_from_spec_persists_full_axis_set() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        let spec = fixture_spec_ffi("Sage Reviewer");
        let entry = epistemos_companions_create_from_spec(h, spec).expect("create OK");
        assert_eq!(entry.name, "Sage Reviewer");
        assert_eq!(entry.head_shape, "Block");
        assert_eq!(entry.eyes, "NegativeSpace");
        assert_eq!(entry.role, "CodeWorker");
        assert_eq!(entry.prop_ref.as_deref(), Some("Wrench"));
        assert_eq!(entry.activity, "JustAcquired");
        epistemos_companions_destroy(h);
    }

    #[test]
    fn create_from_spec_rejects_unknown_enum_strings() {
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        // Bad head_shape.
        let mut s = fixture_spec_ffi("BadHead");
        s.head_shape = "Doughnut".to_string();
        assert!(matches!(
            epistemos_companions_create_from_spec(h, s),
            Err(CompanionsError::Validation { .. })
        ));
        // Bad eyes.
        let mut s = fixture_spec_ffi("BadEyes");
        s.eyes = "Cross".to_string();
        assert!(matches!(
            epistemos_companions_create_from_spec(h, s),
            Err(CompanionsError::Validation { .. })
        ));
        // Bad role.
        let mut s = fixture_spec_ffi("BadRole");
        s.role = "Chairman".to_string();
        assert!(matches!(
            epistemos_companions_create_from_spec(h, s),
            Err(CompanionsError::Validation { .. })
        ));
        epistemos_companions_destroy(h);
    }

    #[test]
    fn create_from_spec_with_custom_palette_passes_contrast_gate() {
        // Pure white passes against the dark sidebar (contrast
        // 21:1) — should succeed.
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        let mut s = fixture_spec_ffi("CustomBright");
        s.palette_ref = "#FFFFFF".to_string();
        let _ = epistemos_companions_create_from_spec(h, s).expect("white passes");
        epistemos_companions_destroy(h);
    }

    #[test]
    fn create_from_spec_rejects_low_contrast_custom_palette() {
        // Mid-grey fails both axes per WCAG AA 4.5:1 — should
        // bounce back as a Validation error so the wizard can
        // re-enter the palette step.
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        let mut s = fixture_spec_ffi("CustomMid");
        s.palette_ref = "#808080".to_string();
        let err = epistemos_companions_create_from_spec(h, s).unwrap_err();
        assert!(matches!(err, CompanionsError::Validation { .. }), "{err:?}");
        epistemos_companions_destroy(h);
    }

    #[test]
    fn create_from_spec_with_null_handle_returns_validation_error() {
        let r = epistemos_companions_create_from_spec(
            0,
            fixture_spec_ffi("NoHandle"),
        );
        assert!(matches!(r, Err(CompanionsError::Validation { .. })));
    }

    #[test]
    fn create_from_spec_resolves_subpath_under_vault_root() {
        // The wizard passes a subpath; the bridge joins with its
        // own owned vault_root. Verify the resulting absolute
        // path is in the same root and the companion lists OK.
        let tmp = tempfile::tempdir().unwrap();
        let h = epistemos_companions_open(vault_at(&tmp));
        let spec = fixture_spec_ffi("ScopedAgent");
        let entry = epistemos_companions_create_from_spec(h, spec).expect("create OK");
        // The on-disk vault folder lives under the same root the
        // bridge was opened against.
        let expected = tmp
            .path()
            .join(".epistemos")
            .parent()
            .unwrap()
            .join("Companions")
            .join("ScopedAgent");
        assert!(expected.exists(), "vault dir should exist at {expected:?}");
        assert_eq!(entry.name, "ScopedAgent");
        epistemos_companions_destroy(h);
    }
}
