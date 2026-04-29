//! Simulation Mode companion registry (S1; DOCTRINE §3.1, §3.5, §6).
//!
//! The `CompanionRegistry` is the single Rust-owned source of truth that
//! all three placements (Landing Farm, Graph Live Theater, Notes Sidebar)
//! project from per DOCTRINE I-9. Per DOCTRINE I-7 Swift never mutates
//! it directly — every change goes through this module's API and crosses
//! a typed FFI boundary in later slices.
//!
//! S1 scope: registry CRUD with atomic creation transaction (§6.3
//! step ordering with rollback), audit-log persistence (§6.4),
//! activity-state hysteresis machine (§3.2 table). No FFI exposure to
//! Swift, no sprite rendering, no animation; later slices wire the
//! observer event stream and the FFI surface.
//!
//! Schema lives inline at registry-open time (`CREATE TABLE IF NOT
//! EXISTS`) per the existing `session_persistence.rs` precedent in this
//! crate — substrate-core has no migration infrastructure today, so the
//! plan's `substrate-core/migrations/NNN_companions.sql` reference maps
//! to the existing idempotent `execute_batch` pattern. Schema
//! ownership stays with the data: companions live in agent_core.

pub mod activity;
pub mod audit;
pub mod registry;
pub mod transaction;

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use ulid::Ulid;

pub use activity::{ActivityState, ActivityTracker, ActivityTransition};
pub use audit::{AuditEntry, AuditEventKind};
pub use registry::CompanionRegistry;
pub use transaction::{create_companion, CreationError, FailureInjection};

// =============================================================================
// CompanionId — monotonic ULID, matches DOCTRINE §6.4 audit JSON format.
// =============================================================================

/// Unique companion identifier. Backed by a ULID (monotonic
/// time-ordered, 26-char Crockford base32 — matches the
/// `"01JZ4..."`-shaped IDs in the DOCTRINE §6.4 audit example).
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct CompanionId(pub Ulid);

impl CompanionId {
    /// Generate a new monotonic ULID. Time-ordered, unique within a
    /// process. Not used inside the simulation reducer per I-13 — this
    /// is invoked only from the creation transaction.
    pub fn new_ulid() -> Self {
        Self(Ulid::new())
    }

    /// Parse from a 26-char Crockford base32 string. Returns `None` on
    /// any parse failure (wrong length, invalid character set).
    pub fn parse(s: &str) -> Option<Self> {
        Ulid::from_string(s).ok().map(Self)
    }
}

impl std::fmt::Display for CompanionId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::fmt::Debug for CompanionId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "CompanionId({})", self.0)
    }
}

// =============================================================================
// Body grammar enums (DOCTRINE §5.1, §5.2, §5.4).
// =============================================================================

/// Composable head-shape families per DOCTRINE §5.1. `Block`, `Sage`,
/// `Orb` are the V1 user-pickable shapes; `HermesSnake` is the
/// dedicated atlas for the graph faculty (§8) and not chooseable
/// outside the Hermes preset.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum HeadShape {
    Block,
    Sage,
    Orb,
    HermesSnake,
}

impl HeadShape {
    pub fn as_str(self) -> &'static str {
        match self {
            HeadShape::Block => "Block",
            HeadShape::Sage => "Sage",
            HeadShape::Orb => "Orb",
            HeadShape::HermesSnake => "HermesSnake",
        }
    }
    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "Block" => Some(HeadShape::Block),
            "Sage" => Some(HeadShape::Sage),
            "Orb" => Some(HeadShape::Orb),
            "HermesSnake" => Some(HeadShape::HermesSnake),
            _ => None,
        }
    }
}

/// Eye style overlay per DOCTRINE §5.2.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum EyeStyle {
    Round,
    Slit,
    Visor,
    Closed,
    NegativeSpace,
}

impl EyeStyle {
    pub fn as_str(self) -> &'static str {
        match self {
            EyeStyle::Round => "Round",
            EyeStyle::Slit => "Slit",
            EyeStyle::Visor => "Visor",
            EyeStyle::Closed => "Closed",
            EyeStyle::NegativeSpace => "NegativeSpace",
        }
    }
    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "Round" => Some(EyeStyle::Round),
            "Slit" => Some(EyeStyle::Slit),
            "Visor" => Some(EyeStyle::Visor),
            "Closed" => Some(EyeStyle::Closed),
            "NegativeSpace" => Some(EyeStyle::NegativeSpace),
            _ => None,
        }
    }
}

/// Arm style overlay per DOCTRINE §5.2.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ArmStyle {
    None,
    Short,
    Long,
}

impl ArmStyle {
    pub fn as_str(self) -> &'static str {
        match self {
            ArmStyle::None => "None",
            ArmStyle::Short => "Short",
            ArmStyle::Long => "Long",
        }
    }
    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "None" => Some(ArmStyle::None),
            "Short" => Some(ArmStyle::Short),
            "Long" => Some(ArmStyle::Long),
            _ => None,
        }
    }
}

/// Prop / tool affinity per DOCTRINE §5.5 Category A. The prop
/// drives a default tool-affinity bitset (wrench → code/git, scroll →
/// notes, magnifier → search, folder → vault, baton → routing,
/// lantern → deep-think) per §6.1 step 6.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum PropKind {
    Wrench,
    Scroll,
    Magnifier,
    Folder,
    Baton,
    Lantern,
}

impl PropKind {
    pub fn as_str(self) -> &'static str {
        match self {
            PropKind::Wrench => "Wrench",
            PropKind::Scroll => "Scroll",
            PropKind::Magnifier => "Magnifier",
            PropKind::Folder => "Folder",
            PropKind::Baton => "Baton",
            PropKind::Lantern => "Lantern",
        }
    }
    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "Wrench" => Some(PropKind::Wrench),
            "Scroll" => Some(PropKind::Scroll),
            "Magnifier" => Some(PropKind::Magnifier),
            "Folder" => Some(PropKind::Folder),
            "Baton" => Some(PropKind::Baton),
            "Lantern" => Some(PropKind::Lantern),
            _ => None,
        }
    }
}

/// Provider role per DOCTRINE §5.5 Category A. Drives the system
/// prompt preset, MCP routing rules, and which presets can apply
/// gift-box adapters per §7.2.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ProviderRole {
    Orchestrator,
    Researcher,
    Worker,
    Critic,
    CodeWorker,
    Faculty,
    Helper,
    Custom,
}

impl ProviderRole {
    pub fn as_str(self) -> &'static str {
        match self {
            ProviderRole::Orchestrator => "Orchestrator",
            ProviderRole::Researcher => "Researcher",
            ProviderRole::Worker => "Worker",
            ProviderRole::Critic => "Critic",
            ProviderRole::CodeWorker => "CodeWorker",
            ProviderRole::Faculty => "Faculty",
            ProviderRole::Helper => "Helper",
            ProviderRole::Custom => "Custom",
        }
    }
    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "Orchestrator" => Some(ProviderRole::Orchestrator),
            "Researcher" => Some(ProviderRole::Researcher),
            "Worker" => Some(ProviderRole::Worker),
            "Critic" => Some(ProviderRole::Critic),
            "CodeWorker" => Some(ProviderRole::CodeWorker),
            "Faculty" => Some(ProviderRole::Faculty),
            "Helper" => Some(ProviderRole::Helper),
            "Custom" => Some(ProviderRole::Custom),
            _ => None,
        }
    }
}

/// Tool-affinity bitset per DOCTRINE §5.5 (Category A — drives MCP
/// tool gating per companion). Persisted as raw `u64` little-endian
/// bytes in the SQLite `tool_affinities BLOB` column.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ToolAffinities(pub u64);

/// Canonical tool kinds. Stable ordering: new tools are appended to
/// preserve existing bit positions in persisted bitsets.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum ToolKind {
    CodeEdit = 0,
    CodeRead = 1,
    TestRun = 2,
    Git = 3,
    NoteCreate = 4,
    NoteRead = 5,
    NoteUpdate = 6,
    WebSearch = 7,
    GraphSearch = 8,
    VaultRead = 9,
    VaultWrite = 10,
    Routing = 11,
    Delegate = 12,
    DeepThink = 13,
    Plan = 14,
}

impl ToolAffinities {
    pub const fn empty() -> Self {
        Self(0)
    }

    pub fn add(&mut self, tool: ToolKind) {
        self.0 |= 1u64 << tool as u8;
    }

    pub fn has(self, tool: ToolKind) -> bool {
        (self.0 & (1u64 << tool as u8)) != 0
    }

    /// Default bitset for a given prop, per DOCTRINE §6.1 step 6 +
    /// §5.5 mapping. Used as the seed when a user picks a prop in the
    /// creation flow; the user can refine afterwards.
    pub fn from_prop(prop: PropKind) -> Self {
        let mut s = Self::empty();
        match prop {
            PropKind::Wrench => {
                s.add(ToolKind::CodeEdit);
                s.add(ToolKind::CodeRead);
                s.add(ToolKind::Git);
                s.add(ToolKind::TestRun);
            }
            PropKind::Scroll => {
                s.add(ToolKind::NoteCreate);
                s.add(ToolKind::NoteRead);
                s.add(ToolKind::NoteUpdate);
            }
            PropKind::Magnifier => {
                s.add(ToolKind::WebSearch);
                s.add(ToolKind::GraphSearch);
            }
            PropKind::Folder => {
                s.add(ToolKind::VaultRead);
                s.add(ToolKind::VaultWrite);
            }
            PropKind::Baton => {
                s.add(ToolKind::Routing);
                s.add(ToolKind::Delegate);
            }
            PropKind::Lantern => {
                s.add(ToolKind::DeepThink);
                s.add(ToolKind::Plan);
            }
        }
        s
    }

    pub fn to_le_bytes(self) -> [u8; 8] {
        self.0.to_le_bytes()
    }

    pub fn from_le_bytes(bytes: [u8; 8]) -> Self {
        Self(u64::from_le_bytes(bytes))
    }
}

// =============================================================================
// CompanionSpec — input to the creation transaction (DOCTRINE §6.1).
// =============================================================================

/// Input spec for creating a new companion. Validated by
/// `transaction::create_companion` per DOCTRINE §6.2 before any
/// persistent state is written. Cosmetic-only fields (palette tint,
/// accessory slot) are kept distinct from configuration fields
/// (role, base_model, system_prompt_preset, tool_affinities) so the
/// audit ledger can label each change correctly per DOCTRINE §5.5.
#[derive(Debug, Clone)]
pub struct CompanionSpec {
    pub name: String,
    pub head_shape: HeadShape,
    pub palette_ref: String,
    pub eyes: EyeStyle,
    pub arms: ArmStyle,
    pub prop: Option<PropKind>,
    pub accessory_ref: Option<String>,
    pub role: ProviderRole,
    pub base_model: String,
    pub system_prompt_preset: String,
    pub tool_affinities: ToolAffinities,
    /// Vault folder path (typically `<vault_root>/Companions/<name>/`).
    /// Per DOCTRINE §6.2 must be under the vault root and not collide
    /// with another companion's vault path.
    pub vault_path: PathBuf,
    /// Initial farm position per DOCTRINE §3.2. Persisted across
    /// app restarts; user can re-arrange in Pro profile only.
    pub farm_position: (f32, f32),
}

// =============================================================================
// Companion — the persisted record returned from registry queries.
// =============================================================================

/// Persisted companion record. Mirrors the `companions` table row
/// plus computed derived fields. Never instantiated outside the
/// registry — this is what callers see when querying.
#[derive(Debug, Clone)]
pub struct Companion {
    pub id: CompanionId,
    pub name: String,
    pub head_shape: HeadShape,
    pub palette_ref: String,
    pub eyes: EyeStyle,
    pub arms: ArmStyle,
    pub prop: Option<PropKind>,
    pub accessory_ref: Option<String>,
    pub role: ProviderRole,
    pub base_model: String,
    pub system_prompt_preset: String,
    pub tool_affinities: ToolAffinities,
    pub vault_path: PathBuf,
    /// Synthetic graph-slice slug. At S1 this is just a unique handle
    /// (`slice_<id>`); when graph-engine integration lands in a later
    /// slice it'll resolve to a real subgraph allocation.
    pub graph_slice: String,
    pub created_at: String,
    pub updated_at: String,
    pub archived_at: Option<String>,
    pub farm_position: (f32, f32),
    pub config_version: u32,
}
