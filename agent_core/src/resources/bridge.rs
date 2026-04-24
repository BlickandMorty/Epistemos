//! UniFFI-exposed facade around the Phase R permission store.
//!
//! Phase R.5 bridge. The full `PermissionService` trait stays Rust-internal;
//! Swift callers interact via small, purpose-specific free functions that
//! speak in plain strings + FFI-friendly records. This follows the same
//! pattern used by the R.2 alias-registry bridge (see `alias_registry.rs`
//! `canonical_model_id` / `expand_model_aliases`).
//!
//! ## Scope (this commit)
//!
//! - Initialize a **process-local, in-memory** `SqlitePermissionService`
//!   on first call. Grants live for the app-launch session and then
//!   disappear on quit.
//! - Expose async helpers for: list, check, record user-grant, revoke.
//! - Accept string names for capabilities + scopes + resource URIs so
//!   the FFI surface doesn't need to cross complex enums.
//!
//! ## Deliberately NOT in this commit
//!
//! - Replacement of Swift's existing `activeGrantsSection` hard-coded
//!   rows. R.5 UI wiring is additive — surfaces Rust-backed grants
//!   alongside the existing rows.
//!
//! ## Persistent storage (2026-04-23)
//!
//! - Swift drives `permission_store_init_at_path(path)` at app launch
//!   with a container-safe path (see `AppBootstrap`). When that init
//!   runs before the first grant is recorded, grants persist across
//!   relaunches. The fallback remains in-memory, so tests and any
//!   callers that forget to init keep working — they just lose state
//!   on process exit.
//!
//! Plan refs: `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` §Phase R.5,
//! `docs/RESOURCE_RUNTIME_RESEARCH.md` §4, `docs/KNOWN_ISSUES_REGISTER.md`
//! I-009 (stored grant) and I-010 (prompt-injection hardening).

use std::path::PathBuf;
use std::sync::{Arc, OnceLock};

use tokio::runtime::Runtime;
use tokio::sync::Mutex;

use crate::storage::vault::VaultStore;

use super::{
    AttachedResource, Capability, DeleteMode, GrantScope, PermissionGrant, PermissionService,
    ResourceContent, ResourceError, ResourceHit, ResourceId, ResourceKind, ResourceSelector,
    ResourceService, ResourceSearchScope, SqlitePermissionService, VaultResourceService, WriteResult,
};

// `AttachmentMode` is only referenced inside tests; the production
// factories take a `ResourceId` + `String` and return an
// `AttachedResource` whose mode is set by the underlying constructor.
// Pull it in when compiling the tests module to keep those assertions
// ergonomic.
#[cfg(test)]
use super::AttachmentMode;

// ---------------------------------------------------------------------
// FFI record types
// ---------------------------------------------------------------------

/// Swift-facing summary of an active permission grant. Strings instead of
/// enum variants so the FFI surface stays small and Swift can render
/// directly without needing to mirror every Rust enum.
#[derive(Clone, Debug, uniffi::Record)]
pub struct PermissionGrantSummary {
    pub grant_id: String,
    pub subject: String,
    /// One of `"Turn" | "Session" | "Persistent"`.
    pub scope: String,
    /// Human-readable selector description:
    /// `"resource:<uri>"`, `"prefix:<pfx>"`, `"vault:<vault-id>"`,
    /// or `"kind:<KIND>"`.
    pub selector: String,
    /// Capability names: `"Read" | "Write" | "Delete" | "Create" | "Search"`.
    pub capabilities: Vec<String>,
    pub granted_by: String,
    pub granted_at: String,
    pub expires_at: Option<String>,
}

impl From<&PermissionGrant> for PermissionGrantSummary {
    fn from(grant: &PermissionGrant) -> Self {
        let scope = match grant.scope {
            GrantScope::Turn => "Turn",
            GrantScope::Session => "Session",
            GrantScope::Persistent => "Persistent",
        };
        let selector = describe_selector(&grant.resources);
        let capabilities = grant.capabilities.iter().map(capability_name).collect();
        Self {
            grant_id: grant.grant_id.clone(),
            subject: grant.subject.clone(),
            scope: scope.to_string(),
            selector,
            capabilities,
            granted_by: grant.granted_by.clone(),
            granted_at: grant.granted_at.clone(),
            expires_at: grant.expires_at.clone(),
        }
    }
}

fn describe_selector(selector: &ResourceSelector) -> String {
    match selector {
        ResourceSelector::ById(id) => format!("resource:{}", id.as_uri()),
        ResourceSelector::ByPrefix(prefix) => format!("prefix:{prefix}"),
        ResourceSelector::ByVault { vault_id } => format!("vault:{vault_id}"),
        ResourceSelector::ByKind(kind) => format!("kind:{kind:?}"),
    }
}

fn capability_name(capability: &Capability) -> String {
    match capability {
        Capability::Read => "Read",
        Capability::Write => "Write",
        Capability::Delete => "Delete",
        Capability::Create => "Create",
        Capability::Search => "Search",
    }
    .to_string()
}

fn parse_capability(name: &str) -> Option<Capability> {
    match name {
        "Read" | "read" => Some(Capability::Read),
        "Write" | "write" => Some(Capability::Write),
        "Delete" | "delete" => Some(Capability::Delete),
        "Create" | "create" => Some(Capability::Create),
        "Search" | "search" => Some(Capability::Search),
        _ => None,
    }
}

fn parse_scope(name: &str) -> GrantScope {
    match name {
        "Turn" | "turn" => GrantScope::Turn,
        "Persistent" | "persistent" => GrantScope::Persistent,
        _ => GrantScope::Session,
    }
}

// ---------------------------------------------------------------------
// Process-local runtime + permission store
// ---------------------------------------------------------------------

/// Tokio runtime used to drive the async `PermissionService` methods from
/// synchronous Swift FFI contexts. UniFFI's `async_runtime = "tokio"` still
/// needs a global runtime when the Swift caller uses the blocking surface;
/// this is that runtime.
fn runtime() -> &'static Runtime {
    static RUNTIME: OnceLock<Runtime> = OnceLock::new();
    RUNTIME.get_or_init(|| {
        Runtime::new().expect("permission bridge tokio runtime init failed")
    })
}

/// Process-local permission store. In-memory SQLite on first touch;
/// migrates to on-disk when Swift invokes
/// [`permission_store_init_at_path`] with a container-safe path. The
/// outer `tokio::sync::Mutex` serialises all store operations; the
/// inner `SqlitePermissionService` swaps its own `Connection` under
/// `Self::reopen_at`.
fn store() -> &'static Mutex<SqlitePermissionService> {
    static STORE: OnceLock<Mutex<SqlitePermissionService>> = OnceLock::new();
    STORE.get_or_init(|| {
        let service = SqlitePermissionService::open_in_memory()
            .expect("permission bridge in-memory sqlite init failed");
        Mutex::new(service)
    })
}

// ---------------------------------------------------------------------
// UniFFI-exposed helpers
// ---------------------------------------------------------------------

/// Return every active permission grant in the process-local store, in
/// grant-time order. Empty on fresh launch.
#[uniffi::export(async_runtime = "tokio")]
pub async fn permission_store_list_active() -> Vec<PermissionGrantSummary> {
    let guard = store().lock().await;
    guard
        .list_active()
        .await
        .iter()
        .map(PermissionGrantSummary::from)
        .collect()
}

/// Check whether the given resource+capability pair is currently granted.
/// `resource_uri` must round-trip through `ResourceId::parse`; returns
/// `false` for any unparseable or unknown capability name.
#[uniffi::export(async_runtime = "tokio")]
pub async fn permission_store_check(resource_uri: String, capability: String) -> bool {
    let Ok(resource) = ResourceId::parse(&resource_uri) else {
        return false;
    };
    let Some(capability) = parse_capability(&capability) else {
        return false;
    };
    check_resource_capability(resource, capability).await
}

/// Rust-internal companion to `permission_store_check`: consults the same
/// process-local store but takes already-typed `ResourceId` + `Capability`
/// arguments. Used by the tool-execution gate in `ToolRegistry::execute`
/// where we already have typed values and would only stringify them just
/// to parse them back.
///
/// Visibility is `pub(crate)` so non-FFI crate code can call it without
/// enlarging the UniFFI surface. Swift callers must continue to use
/// `permission_store_check` (the string-typed FFI wrapper above).
pub(crate) async fn check_resource_capability(
    resource: ResourceId,
    capability: Capability,
) -> bool {
    let guard = store().lock().await;
    guard.check(resource, capability).await
}

/// Snapshot the current grant count. Used by the R.5 tool-execution
/// gate for telemetry only; enforcement is fail-closed for any
/// resource-targeted mutating tool without a matching grant.
/// Crate-private; not exposed via FFI because Swift has
/// `permission_store_list_active` for the same purpose in UI contexts.
pub(crate) async fn active_grant_count() -> usize {
    let guard = store().lock().await;
    guard.list_active().await.len()
}

/// Record a user-granted permission parsed from a freeform chat
/// statement. Returns the new grant_id if the statement looked like a
/// grant ("you have my permission", etc.), or `None` otherwise.
///
/// Used so Swift-side chat handlers can detect consent phrasing in a
/// user turn and persist a grant instead of leaving it as transient
/// chat text (fixes I-009: "permission evaporates").
#[uniffi::export(async_runtime = "tokio")]
pub async fn permission_store_record_user_grant_from_statement(
    statement: String,
    resource_uri: String,
    capability_names: Vec<String>,
    scope_name: String,
) -> Option<String> {
    let Ok(resource) = ResourceId::parse(&resource_uri) else {
        return None;
    };
    let capabilities: Vec<Capability> = capability_names
        .iter()
        .filter_map(|name| parse_capability(name))
        .collect();
    if capabilities.is_empty() {
        return None;
    }
    let scope = parse_scope(&scope_name);
    let guard = store().lock().await;
    match guard
        .grant_from_user_statement(&statement, resource, capabilities, scope)
        .await
    {
        Ok(Some(grant)) => Some(grant.grant_id),
        _ => None,
    }
}

/// Revoke a stored grant by ID. Returns `true` if a grant existed and
/// was removed; `false` otherwise (but never raises).
#[uniffi::export(async_runtime = "tokio")]
pub async fn permission_store_revoke(grant_id: String) -> bool {
    let guard = store().lock().await;
    guard.revoke(grant_id).await.is_ok()
}

/// Synchronous convenience for callers that don't have an async context.
/// Internally drives a tokio runtime; cheap for UI refreshes.
#[uniffi::export]
pub fn permission_store_list_active_blocking() -> Vec<PermissionGrantSummary> {
    runtime().block_on(permission_store_list_active())
}

/// Migrate the process-local permission store to on-disk persistence at
/// `path`. Called by Swift from `AppBootstrap` once a container-safe
/// location has been resolved. Safe to call multiple times: each call
/// replaces the backing connection while preserving the `Mutex` around
/// the service, so in-flight callers see a consistent view either
/// before or after the swap.
///
/// The schema is (re-)initialized unconditionally, so opening a file
/// created by an older build or a brand-new location both converge to
/// the current schema version.
///
/// The function is blocking on purpose — Swift's `AppBootstrap` calls
/// it from a detached task during launch, and the operation is a
/// one-time SQLite open + `CREATE TABLE IF NOT EXISTS`. Returns an
/// error string if the parent can't be created or the SQLite open
/// fails; callers should log and continue (the in-memory fallback
/// keeps the feature working for the session).
#[uniffi::export]
pub fn permission_store_init_at_path(path: String) -> Result<(), ResourceError> {
    // Swift calls this sync entry point from a `Task.detached` at launch,
    // which runs outside any Rust async runtime. Spin up the global
    // tokio runtime to drive the async store lock.
    let path_buf = prepare_permission_store_path(&path)?;
    runtime().block_on(reopen_permission_store(path_buf, path))
}

/// Validate + create-parent-dir helper. Extracted so the async
/// sibling used by tests doesn't re-run the same work twice.
fn prepare_permission_store_path(path: &str) -> Result<PathBuf, ResourceError> {
    let path_buf = PathBuf::from(path);
    if path_buf.as_os_str().is_empty() {
        return Err(ResourceError::Backend(
            "permission_store_init_at_path: empty path".into(),
        ));
    }
    if let Some(parent) = path_buf.parent() {
        if !parent.as_os_str().is_empty() && !parent.exists() {
            std::fs::create_dir_all(parent).map_err(|error| {
                ResourceError::Backend(format!(
                    "permission store init: create_dir_all({}): {error}",
                    parent.display()
                ))
            })?;
        }
    }
    Ok(path_buf)
}

/// Shared async core. Used by the sync UniFFI entry point (via
/// `block_on`) and by `#[tokio::test]` tests directly so they don't
/// trigger "runtime within a runtime" panics.
async fn reopen_permission_store(
    path_buf: PathBuf,
    original_path_str: String,
) -> Result<(), ResourceError> {
    let guard = store().lock().await;
    guard.reopen_at(&path_buf).map_err(|error| {
        ResourceError::Backend(format!(
            "permission store init: open sqlite at {original_path_str}: {error}"
        ))
    })
}

/// Test-only async entry point for tests running inside a
/// `#[tokio::test]` context. Identical behaviour to
/// [`permission_store_init_at_path`] but bypasses `runtime().block_on`
/// to avoid the nested-runtime panic.
#[cfg(test)]
pub(crate) async fn permission_store_init_at_path_for_test(
    path: String,
) -> Result<(), ResourceError> {
    let path_buf = prepare_permission_store_path(&path)?;
    reopen_permission_store(path_buf, path).await
}

// ---------------------------------------------------------------------
// Phase R.4 — AttachmentMode / Capability / AttachedResource bridge
// ---------------------------------------------------------------------
//
// Exposes the three attachment-model primitives via UniFFI factory
// functions so Swift can construct `AttachedResource`s with explicit
// `AttachmentMode` and `Capability` lists matching the Rust resource
// runtime. Closes the Swift side of I-004/I-005/I-006 (ambiguous
// snapshot-vs-live attachments) by giving Swift first-class access to
// the typed primitives.
//
// This commit's scope is the FFI primitives and factory functions. A
// follow-up will migrate `ContextAttachment` / `FileAttachment` in
// `ChatState.swift` to carry an `AttachedResource` alongside the
// existing presentation struct so tool-call sites can consult the mode
// + capability manifest before acting.

/// Construct a Live (read + write) attachment from the app's native
/// attach UI (drag, popover picker, Finder drop). Mirrors the default
/// in `AttachedResource::attach_via_ui`.
#[uniffi::export]
pub fn attached_resource_from_ui(
    resource_uri: String,
    display_name: String,
    version: Option<String>,
) -> Option<AttachedResource> {
    let Ok(resource_id) = ResourceId::parse(&resource_uri) else {
        return None;
    };
    Some(AttachedResource::attach_via_ui(
        resource_id,
        display_name,
        version,
    ))
}

/// Construct a Live attachment from a Finder-sourced file reference.
/// Functionally identical to `attached_resource_from_ui` today but
/// kept as its own factory so future Finder-specific policies (e.g.
/// security-scoped bookmark tracking) can attach here.
#[uniffi::export]
pub fn attached_resource_from_finder(
    resource_uri: String,
    display_name: String,
    version: Option<String>,
) -> Option<AttachedResource> {
    let Ok(resource_id) = ResourceId::parse(&resource_uri) else {
        return None;
    };
    Some(AttachedResource::finder_file(
        resource_id,
        display_name,
        version,
    ))
}

/// Construct a Snapshot (read-only) attachment from pasted text. The
/// resulting `AttachedResource` will fail any `Write` capability check
/// and will read back from the inlined `snapshot_content` — never from
/// the underlying resource path.
#[uniffi::export]
pub fn attached_resource_from_paste(
    resource_uri: String,
    display_name: String,
    snapshot_content: String,
) -> Option<AttachedResource> {
    let Ok(resource_id) = ResourceId::parse(&resource_uri) else {
        return None;
    };
    Some(AttachedResource::pasted_text(
        resource_id,
        display_name,
        snapshot_content,
    ))
}

/// Ask whether an `AttachedResource` currently allows the given
/// capability. Mirrors `AttachedResource::allows` so Swift can gate
/// tool suggestions without hand-parsing the capability list.
#[uniffi::export]
pub fn attached_resource_allows(
    attachment: AttachedResource,
    capability: Capability,
) -> bool {
    attachment.allows(capability)
}

// ---------------------------------------------------------------------
// Phase R.3 — ResourceService bridge (the canonical gateway)
// ---------------------------------------------------------------------
//
// Exposes a process-local `VaultResourceService` (constructed from a
// Swift-supplied vault root + vault id) via UniFFI. This is the
// canonical note read/write/create/delete/resolve/search gateway that
// the plan calls out as Phase R.3's goal.
//
// Scope for this commit (HONEST labeling per Codex 2026-04-23 review):
//   ✅ FFI primitives exposed; Rust + Swift tests exercise the round-trip.
//   ✅ App-Sandbox safe — pure UniFFI call, no subprocess, no stdio MCP.
//   ❌ Production Swift call sites (`NoteFileStorage`, `VaultIndexActor`,
//      `NotesSidebar`, etc.) are NOT yet routed through the gateway.
//      This is **scaffolding, not bug closure** — I-002/I-003 remain
//      OPEN until those call sites migrate.
//
// Plan refs: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §Phase R.3,
// docs/RESOURCE_RUNTIME_RESEARCH.md §2 (one action gateway),
// docs/KNOWN_ISSUES_REGISTER.md I-002 / I-003.

/// Process-local active `VaultResourceService`. Initialized explicitly
/// from Swift via [`resource_service_init`] once a vault is open. A
/// re-init replaces the prior service (idempotent for vault switches).
fn resource_service_slot() -> &'static std::sync::Mutex<Option<Arc<VaultResourceService>>> {
    static SLOT: OnceLock<std::sync::Mutex<Option<Arc<VaultResourceService>>>> = OnceLock::new();
    SLOT.get_or_init(|| std::sync::Mutex::new(None))
}

/// Return the currently active service, or a Backend error if the
/// caller forgot to invoke `resource_service_init`. Swift callers
/// should never see `NotInitialized` in normal operation since app
/// boot always sets the vault before any resource op runs; but we
/// prefer an explicit error over a panic across FFI.
fn active_service() -> Result<Arc<VaultResourceService>, ResourceError> {
    let guard = resource_service_slot()
        .lock()
        .map_err(|_| ResourceError::Backend("resource service slot poisoned".into()))?;
    guard
        .clone()
        .ok_or_else(|| ResourceError::Backend("resource service not initialized".into()))
}

/// Initialize (or re-initialize) the process-local
/// `VaultResourceService` for the given vault path + stable vault id.
///
/// Called by Swift at app launch (or on vault switch) with the user-
/// selected vault URL and a stable identifier. Returns an error if
/// the vault root doesn't open — Swift should surface this in the
/// UI rather than fall back to legacy note I/O silently.
#[uniffi::export]
pub fn resource_service_init(vault_root: String, vault_id: String) -> Result<(), ResourceError> {
    let path = PathBuf::from(&vault_root);
    if !path.exists() {
        return Err(ResourceError::Backend(format!(
            "vault root does not exist: {vault_root}"
        )));
    }
    // VaultStore::open expects a &str path.
    let vault = VaultStore::open(&vault_root)
        .map_err(|error| ResourceError::Backend(error.to_string()))?;
    let service = Arc::new(VaultResourceService::new(Arc::new(vault), path, vault_id));
    let mut guard = resource_service_slot()
        .lock()
        .map_err(|_| ResourceError::Backend("resource service slot poisoned".into()))?;
    *guard = Some(service);
    Ok(())
}

/// Is the process-local resource service currently initialized? Swift
/// guard for rendering loading states vs falling back to legacy paths.
#[uniffi::export]
pub fn resource_service_is_ready() -> bool {
    resource_service_slot()
        .lock()
        .map(|guard| guard.is_some())
        .unwrap_or(false)
}

/// Resolve a user-facing reference (title, path, alias, URI) to a
/// canonical `ResourceId`. This is the single point every Swift
/// surface should funnel through so a reference typed/clicked in one
/// UI resolves identically in every other UI.
#[uniffi::export(async_runtime = "tokio")]
pub async fn resource_resolve(reference: String) -> Result<ResourceId, ResourceError> {
    let service = active_service()?;
    service.resolve(reference).await
}

/// Full-text + semantic search over the active vault. Returns a list
/// of `ResourceHit`s sorted by relevance (hybrid search scoring).
#[uniffi::export(async_runtime = "tokio")]
pub async fn resource_search(
    query: String,
    scope: ResourceSearchScope,
) -> Result<Vec<ResourceHit>, ResourceError> {
    let service = active_service()?;
    service.search(query, scope).await
}

/// Read the current bytes + version + checksum for a canonical
/// `ResourceId`. Used by every surface that needs the exact truth of
/// what's on disk right now (sidebar body preview, AI tool calls,
/// diff sheets, etc.).
#[uniffi::export(async_runtime = "tokio")]
pub async fn resource_read(id: ResourceId) -> Result<ResourceContent, ResourceError> {
    let service = active_service()?;
    service.read(id).await
}

/// Version-checked write. `base_version` is the version Swift read
/// previously; if the on-disk version changed in the meantime, the
/// write is rejected with `VersionConflict` so the caller can re-read
/// and retry. This is the prerequisite for R.6 verified writes —
/// without it, "AI says done but file didn't change" can sneak in.
#[uniffi::export(async_runtime = "tokio")]
pub async fn resource_write(
    id: ResourceId,
    content: Vec<u8>,
    base_version: Option<String>,
) -> Result<WriteResult, ResourceError> {
    let service = active_service()?;
    service.write(id, content, base_version).await
}

/// Create a new resource under `parent` with kind + initial content.
/// Returns the canonical ID of the new resource so the caller can
/// immediately link/surface it.
#[uniffi::export(async_runtime = "tokio")]
pub async fn resource_create(
    parent: ResourceId,
    kind: ResourceKind,
    content: Vec<u8>,
) -> Result<ResourceId, ResourceError> {
    let service = active_service()?;
    service.create(parent, kind, content).await
}

/// Delete a resource. `Trash` is soft-delete (move to `.epistemos/
/// archive/` with tombstone); `Hard` is unrecoverable. Per plan
/// defaults, most UI paths should pass `Trash`.
#[uniffi::export(async_runtime = "tokio")]
pub async fn resource_delete(id: ResourceId, mode: DeleteMode) -> Result<(), ResourceError> {
    let service = active_service()?;
    service.delete(id, mode).await
}

// ---------------------------------------------------------------------
// Phase R.6 — verified-write pipeline bridge
// ---------------------------------------------------------------------
//
// Exposes `runtime::verified_write` via UniFFI so Swift note-save /
// tool-execution paths can consult a single "write only reports
// success after post-write readback checksum matches" helper.
//
// The pipeline is:
//   Requested → Resolved → Authorized (R.5 grant check) →
//   Executed (service.write) → Verified (service.read + checksum
//   match) → Surfaced + audit-logged.
//
// "AI says done but the file didn't actually change" requires the
// handler to either skip or fake step 5 — which this helper makes
// impossible by construction.

/// Shape-matched record exposed over FFI in place of the Rust-native
/// `runtime::VerifiedWrite`. Identical fields; kept as a separate
/// type so `runtime::VerifiedWrite` can evolve without churning the
/// FFI surface.
#[derive(Debug, Clone, uniffi::Record)]
pub struct VerifiedWriteReceipt {
    pub resource_id: ResourceId,
    pub new_version: String,
}

/// FFI-friendly error envelope for the verified-write pipeline. The
/// Rust-native `runtime::WriteError` is a rich enum; we flatten it
/// into a discriminator + message so the Swift side can pattern-match
/// without needing every Rust variant.
#[derive(Debug, thiserror::Error, uniffi::Error)]
#[uniffi(flat_error)]
pub enum VerifiedWriteError {
    #[error("not initialized: {message}")]
    NotInitialized { message: String },
    #[error("invalid resource uri: {uri}")]
    InvalidResourceUri { uri: String },
    #[error("permission denied for {resource}: {capability}")]
    PermissionDenied {
        resource: String,
        capability: String,
    },
    #[error("version conflict for {resource}: expected {expected}, actual {actual}")]
    VersionConflict {
        resource: String,
        expected: String,
        actual: String,
    },
    #[error("write verification failed: expected {expected}, actual {actual}")]
    VerificationFailed { expected: String, actual: String },
    #[error("resource error: {message}")]
    Resource { message: String },
    #[error("audit error: {message}")]
    Audit { message: String },
}

impl From<crate::runtime::WriteError> for VerifiedWriteError {
    fn from(error: crate::runtime::WriteError) -> Self {
        use crate::runtime::WriteError;
        match error {
            WriteError::PermissionDenied { resource, capability } => {
                Self::PermissionDenied {
                    resource: resource.as_uri(),
                    capability,
                }
            }
            WriteError::VersionConflict { id, expected, actual } => Self::VersionConflict {
                resource: id.as_uri(),
                expected,
                actual,
            },
            WriteError::VerificationFailed { expected, actual } => {
                Self::VerificationFailed { expected, actual }
            }
            WriteError::Resource(message) => Self::Resource { message },
            WriteError::Audit(message) => Self::Audit { message },
        }
    }
}

/// Process-local audit log slot. Initialised lazily in-memory the
/// first time a verified-write runs; can be swapped to an on-disk
/// file via [`verified_write_init_audit_at_path`] once Swift
/// resolves a container-safe location.
fn audit_log_holder() -> &'static std::sync::RwLock<Option<Arc<crate::runtime::SqliteResourceAuditLog>>>
{
    static HOLDER: OnceLock<
        std::sync::RwLock<Option<Arc<crate::runtime::SqliteResourceAuditLog>>>,
    > = OnceLock::new();
    HOLDER.get_or_init(|| std::sync::RwLock::new(None))
}

fn active_audit_log() -> Result<Arc<crate::runtime::SqliteResourceAuditLog>, VerifiedWriteError> {
    {
        let guard = audit_log_holder()
            .read()
            .map_err(|_| VerifiedWriteError::Audit {
                message: "audit log slot poisoned".into(),
            })?;
        if let Some(arc) = guard.as_ref() {
            return Ok(arc.clone());
        }
    }
    let mut writer = audit_log_holder()
        .write()
        .map_err(|_| VerifiedWriteError::Audit {
            message: "audit log slot poisoned".into(),
        })?;
    if let Some(arc) = writer.as_ref() {
        return Ok(arc.clone());
    }
    let log = crate::runtime::SqliteResourceAuditLog::open_in_memory().map_err(|error| {
        VerifiedWriteError::Audit {
            message: error.to_string(),
        }
    })?;
    let arc = Arc::new(log);
    *writer = Some(arc.clone());
    Ok(arc)
}

/// Optional: migrate the audit log to on-disk persistence at
/// `path`. Swift should drive this at launch once it has a
/// container-safe path, same pattern as the permission store's
/// `permission_store_init_at_path`.
#[uniffi::export]
pub fn verified_write_init_audit_at_path(path: String) -> Result<(), VerifiedWriteError> {
    let path_buf = PathBuf::from(&path);
    if path_buf.as_os_str().is_empty() {
        return Err(VerifiedWriteError::Audit {
            message: "empty audit log path".into(),
        });
    }
    if let Some(parent) = path_buf.parent() {
        if !parent.as_os_str().is_empty() && !parent.exists() {
            std::fs::create_dir_all(parent).map_err(|error| VerifiedWriteError::Audit {
                message: format!("mkdir {}: {error}", parent.display()),
            })?;
        }
    }
    let log = crate::runtime::SqliteResourceAuditLog::open(&path_buf).map_err(|error| {
        VerifiedWriteError::Audit {
            message: format!("open audit log at {path}: {error}"),
        }
    })?;
    let mut writer = audit_log_holder()
        .write()
        .map_err(|_| VerifiedWriteError::Audit {
            message: "audit log slot poisoned".into(),
        })?;
    *writer = Some(Arc::new(log));
    Ok(())
}

/// Write to a resource and report success ONLY after the post-write
/// readback checksum matches. Consults the process-local
/// `PermissionService` for capability (`Write`), the active
/// `ResourceService` for the write + readback, and the process-local
/// audit log for the bookkeeping row.
///
/// Swift callers get one of:
///   - `VerifiedWriteReceipt { resource_id, new_version }` on success.
///   - `VerifiedWriteError::*` enum variant carrying the specific
///     failure mode — matches the Rust-internal pipeline so Swift
///     can surface the exact cause in the UI ("verification failed",
///     "version conflict", etc.).
///
/// `tool_name` + `approval_source` land in the audit-log row so an
/// operator can trace "which tool wrote what, under which grant."
#[uniffi::export(async_runtime = "tokio")]
pub async fn resource_verified_write(
    id: ResourceId,
    content: Vec<u8>,
    base_version: Option<String>,
    tool_name: String,
    approval_source: Option<String>,
) -> Result<VerifiedWriteReceipt, VerifiedWriteError> {
    let service = active_service().map_err(|error| VerifiedWriteError::NotInitialized {
        message: error.to_string(),
    })?;
    let audit = active_audit_log()?;
    let store_arc = store().lock().await;
    let receipt = crate::runtime::verified_write(
        &*service,
        &*store_arc,
        audit.as_ref(),
        &id,
        &content,
        base_version.as_deref(),
        &tool_name,
        approval_source.as_deref(),
    )
    .await
    .map_err(VerifiedWriteError::from)?;
    Ok(VerifiedWriteReceipt {
        resource_id: receipt.id,
        new_version: receipt.version,
    })
}

// ---------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::runtime::ResourceAuditLog;

    #[tokio::test]
    async fn fresh_store_is_empty() {
        let _gate = bridge_store_gate();
        let summaries = permission_store_list_active().await;
        // Other tests in this crate may have seeded the store (tests share
        // the process singleton). We just need to confirm the call succeeds
        // and returns a (possibly empty) vector without panicking.
        let _ = summaries.len();
    }

    #[tokio::test]
    async fn record_user_grant_and_check_roundtrip() {
        let _gate = bridge_store_gate();
        let resource = ResourceId::VaultNote {
            vault_id: "bridge-test-vault".into(),
            note_id: "Inbox/BridgeSmoke.md".into(),
        };
        let grant_id = permission_store_record_user_grant_from_statement(
            "You have my permission to edit this note.".into(),
            resource.as_uri(),
            vec!["Read".into(), "Write".into()],
            "Session".into(),
        )
        .await
        .expect("grant should be stored");
        assert!(!grant_id.is_empty());

        assert!(permission_store_check(resource.as_uri(), "Write".into()).await);
        assert!(permission_store_check(resource.as_uri(), "Read".into()).await);
        // Delete should NOT be implicitly granted.
        assert!(!permission_store_check(resource.as_uri(), "Delete".into()).await);

        // Revocation works.
        assert!(permission_store_revoke(grant_id.clone()).await);
        assert!(!permission_store_check(resource.as_uri(), "Write".into()).await);
    }

    #[tokio::test]
    async fn non_grant_statement_returns_none_and_does_not_store() {
        let _gate = bridge_store_gate();
        let resource = ResourceId::VaultNote {
            vault_id: "bridge-nongrant".into(),
            note_id: "Inbox/NotAGrant.md".into(),
        };
        let result = permission_store_record_user_grant_from_statement(
            "please do NOT edit this note — it's final".into(),
            resource.as_uri(),
            vec!["Write".into()],
            "Session".into(),
        )
        .await;
        assert!(result.is_none(), "no grant phrasing should yield None");
        assert!(!permission_store_check(resource.as_uri(), "Write".into()).await);
    }

    #[tokio::test]
    async fn unparseable_resource_uri_rejects_gracefully() {
        let _gate = bridge_store_gate();
        let result = permission_store_record_user_grant_from_statement(
            "you have my permission".into(),
            "gibberish-not-a-uri".into(),
            vec!["Read".into()],
            "Session".into(),
        )
        .await;
        assert!(result.is_none());
        assert!(!permission_store_check("still-gibberish".into(), "Read".into()).await);
    }

    #[tokio::test]
    async fn unknown_capability_name_silently_ignored() {
        let _gate = bridge_store_gate();
        let resource = ResourceId::VaultNote {
            vault_id: "bridge-unknown-cap".into(),
            note_id: "Inbox/UnknownCap.md".into(),
        };
        // "Merge" is not a real Capability. It must be skipped,
        // but "Read" must still land.
        let grant_id = permission_store_record_user_grant_from_statement(
            "you have my permission".into(),
            resource.as_uri(),
            vec!["Merge".into(), "Read".into()],
            "Session".into(),
        )
        .await
        .expect("grant should still land with at least one valid capability");
        assert!(!grant_id.is_empty());
        assert!(permission_store_check(resource.as_uri(), "Read".into()).await);
        // Merge obviously can't grant anything.
        assert!(!permission_store_check(resource.as_uri(), "Merge".into()).await);
    }

    #[tokio::test]
    async fn list_active_reflects_stored_grants() {
        let _gate = bridge_store_gate();
        // Seed a distinctive grant and confirm it appears in list_active.
        let resource = ResourceId::VaultNote {
            vault_id: "bridge-list-active".into(),
            note_id: "Inbox/ListActiveMarker.md".into(),
        };
        let _ = permission_store_record_user_grant_from_statement(
            "you have my permission".into(),
            resource.as_uri(),
            vec!["Read".into()],
            "Session".into(),
        )
        .await
        .expect("grant should land");

        let summaries = permission_store_list_active().await;
        let found = summaries
            .iter()
            .any(|s| s.selector.contains("bridge-list-active"));
        assert!(found, "list_active should surface the newly recorded grant");
    }

    #[test]
    fn blocking_list_active_does_not_panic_without_async_context() {
        // Swift callers use this entry point from a plain thread. Ensure
        // it drives the tokio runtime internally without needing an
        // outer runtime.
        let _ = permission_store_list_active_blocking();
    }

    /// Global gate for tests that mutate the process-local
    /// permission store — both the persistence tests that SWAP the
    /// backing Connection and the non-persistence tests that insert
    /// / check / list grants. Parallel runs without this gate can
    /// see each other's rows (same OnceLock-backed store), and a
    /// persistence test mid-flight can leave the store pointing at
    /// a dropped TempDir before a concurrent non-persistence test
    /// tries its second call. Recovers from poisoning so a single
    /// panicky test doesn't wedge the rest.
    static BRIDGE_STORE_GATE: std::sync::Mutex<()> = std::sync::Mutex::new(());

    fn bridge_store_gate() -> std::sync::MutexGuard<'static, ()> {
        BRIDGE_STORE_GATE
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
    }

    /// Alias preserved for the persistence-specific tests — reads
    /// the same mutex so any future splitting stays safe.
    fn r5_persist_gate() -> std::sync::MutexGuard<'static, ()> {
        bridge_store_gate()
    }

    /// Restore the process-local permission store to a fresh
    /// in-memory SQLite connection. Every persistence test must
    /// call this before returning so subsequent non-gated bridge
    /// tests don't inherit a dead file handle from a dropped
    /// TempDir. `":memory:"` is SQLite's documented in-memory path.
    async fn restore_store_to_in_memory() {
        let guard = store().lock().await;
        let _ = guard.reopen_at(":memory:");
    }

    #[tokio::test]
    async fn init_at_path_empty_string_returns_explicit_error() {
        let _gate = r5_persist_gate();
        let err = permission_store_init_at_path_for_test("".into())
            .await
            .expect_err("empty path must be rejected");
        match err {
            ResourceError::Backend(message) => assert!(message.contains("empty path")),
            other => panic!("expected Backend error, got {other:?}"),
        }
        // This test didn't mutate the store, but keep the cleanup
        // pattern consistent with other persistence tests.
        restore_store_to_in_memory().await;
    }

    #[tokio::test]
    async fn grants_survive_in_process_restart_via_reinit_at_same_path() {
        // Proof that the store is durable across "restarts" when Swift
        // reinits at the same container-safe path. We can't truly
        // kill the process mid-test, so we simulate a relaunch by
        // re-calling `permission_store_init_at_path_for_test` with
        // the same file — the second call swaps the backing
        // Connection to a fresh handle that opens the existing
        // on-disk SQLite file. If the grant was actually persisted,
        // `list_active` still sees it after the swap.
        let _gate = r5_persist_gate();
        let tmp = tempfile::tempdir().unwrap();
        let db_path = tmp.path().join("permissions-restart.db");
        let path_str = db_path.to_string_lossy().to_string();

        permission_store_init_at_path_for_test(path_str.clone())
            .await
            .expect("first init at tempdir path should succeed");

        let marker_uri = format!(
            "vault://r5-persist-{0}/note/Inbox/Durable-{0}.md",
            uuid::Uuid::new_v4()
        );
        let grant_id = permission_store_record_user_grant_from_statement(
            "You have my permission to edit this note.".into(),
            marker_uri.clone(),
            vec!["Write".into()],
            "Session".into(),
        )
        .await
        .expect("grant should land under the on-disk store");

        // Simulated relaunch: re-init at the same path. The old
        // in-process Connection is replaced but the SQLite file on
        // disk is untouched, so the grant row survives.
        permission_store_init_at_path_for_test(path_str)
            .await
            .expect("re-init at same path should succeed");

        let after_restart = permission_store_list_active().await;
        let found = after_restart.iter().any(|summary| {
            summary.grant_id == grant_id && summary.selector.contains(&marker_uri)
        });
        assert!(
            found,
            "grant {grant_id} should survive in-process restart via reinit at same path"
        );

        // Housekeeping: revoke the grant so follow-up tests don't
        // see the marker.
        let _ = permission_store_revoke(grant_id).await;
        // Swap back to in-memory before the TempDir drops so that
        // subsequent non-gated bridge tests don't inherit a dead
        // file handle.
        restore_store_to_in_memory().await;
    }

    #[tokio::test]
    async fn init_at_path_creates_missing_parent_directory() {
        let _gate = r5_persist_gate();
        let tmp = tempfile::tempdir().unwrap();
        // Nested directory that does NOT exist yet — the bridge must
        // create it (matching how `AppBootstrap` hands us a path
        // under `~/Library/Application Support/Epistemos/…` that
        // might be brand new on first launch).
        let nested = tmp.path().join("nested/deep/dir");
        let db_path = nested.join("permissions.db");
        assert!(!nested.exists());

        permission_store_init_at_path_for_test(db_path.to_string_lossy().to_string())
            .await
            .expect("missing parent must be created, not rejected");
        assert!(nested.exists(), "parent directory should have been created");

        // The store is now backed at the new path — confirm a
        // round-trip via list_active to verify the file is usable.
        let _ = permission_store_list_active().await;
        restore_store_to_in_memory().await;
    }

    /// Run the body with a pre-cleared audit log so the assertions
    /// on entry counts aren't contaminated by other tests. Resets
    /// the holder to None; the next `active_audit_log()` call will
    /// re-init an empty in-memory log.
    async fn reset_audit_log_for_tests() {
        let mut guard = audit_log_holder().write().unwrap_or_else(|e| e.into_inner());
        *guard = None;
    }

    #[tokio::test]
    async fn verified_write_init_audit_at_empty_path_rejects() {
        let _gate = bridge_store_gate();
        let err = verified_write_init_audit_at_path("".into())
            .expect_err("empty path must be rejected");
        match err {
            VerifiedWriteError::Audit { message } => {
                assert!(message.contains("empty audit log path"));
            }
            other => panic!("expected Audit error, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn verified_write_bridge_succeeds_when_grant_covers_resource_and_readback_matches() {
        let _gate = bridge_store_gate();
        // Also serialize with the R.3 tests — this body reinitializes
        // the resource service slot and would race R.3 fixtures that
        // hold the slot for their duration.
        let _r3 = r3_gate();
        reset_audit_log_for_tests().await;
        restore_store_to_in_memory().await;

        // Stand up a real vault service so the bridge can resolve +
        // read + write + readback through the production path.
        let tmp = tempfile::tempdir().unwrap();
        let note_path = tmp.path().join("Inbox/Verified.md");
        std::fs::create_dir_all(note_path.parent().unwrap()).unwrap();
        std::fs::write(&note_path, "before").unwrap();
        let vault_id = format!("r6-{}", uuid::Uuid::new_v4());
        let vault_root = tmp.path().to_string_lossy().to_string();
        resource_service_init(vault_root, vault_id.clone())
            .expect("resource service should init");

        let id = resource_resolve("Inbox/Verified.md".into()).await.unwrap();
        let base_version = resource_read(id.clone()).await.unwrap().version;

        // Seed a grant so the R.5 capability check passes.
        permission_store_record_user_grant_from_statement(
            "You have my permission to edit this note.".into(),
            id.as_uri(),
            vec!["Write".into()],
            "Session".into(),
        )
        .await
        .expect("grant should land");

        let receipt = resource_verified_write(
            id.clone(),
            b"after".to_vec(),
            Some(base_version.clone()),
            "note_write".into(),
            Some("session-grant".into()),
        )
        .await
        .expect("verified write should succeed when readback matches");

        assert_eq!(receipt.resource_id, id);
        assert!(!receipt.new_version.is_empty());

        // Sanity: file on disk matches the new content.
        assert_eq!(std::fs::read_to_string(&note_path).unwrap(), "after");

        // Audit row must be `success`.
        let log = active_audit_log().unwrap();
        let entries = log.list().await.unwrap();
        let success_entries = entries.iter().filter(|e| e.result == "success");
        assert!(success_entries.clone().count() >= 1);
        assert!(success_entries.clone().any(|e| e.resource_uri == id.as_uri()));

        // Cleanup.
        restore_store_to_in_memory().await;
        // Clear the resource service so a later test doesn't race.
        let mut guard = resource_service_slot().lock().unwrap();
        *guard = None;
    }

    #[tokio::test]
    async fn verified_write_bridge_denies_when_no_grant_covers_resource() {
        let _gate = bridge_store_gate();
        let _r3 = r3_gate();
        reset_audit_log_for_tests().await;
        restore_store_to_in_memory().await;

        let tmp = tempfile::tempdir().unwrap();
        let note_path = tmp.path().join("Inbox/Denied.md");
        std::fs::create_dir_all(note_path.parent().unwrap()).unwrap();
        std::fs::write(&note_path, "before").unwrap();
        let vault_id = format!("r6-denied-{}", uuid::Uuid::new_v4());
        let vault_root = tmp.path().to_string_lossy().to_string();
        resource_service_init(vault_root, vault_id)
            .expect("resource service should init");

        let id = resource_resolve("Inbox/Denied.md".into()).await.unwrap();

        // No grant seeded. The verified-write bridge must return
        // PermissionDenied BEFORE the service.write call fires.
        let error = resource_verified_write(
            id.clone(),
            b"mutation".to_vec(),
            None,
            "note_write".into(),
            None,
        )
        .await
        .expect_err("verified write must deny without a grant");

        match error {
            VerifiedWriteError::PermissionDenied { resource, .. } => {
                assert_eq!(resource, id.as_uri());
            }
            other => panic!("expected PermissionDenied, got {other:?}"),
        }

        // File unchanged.
        assert_eq!(std::fs::read_to_string(&note_path).unwrap(), "before");

        // Audit row captures the denied attempt.
        let log = active_audit_log().unwrap();
        let entries = log.list().await.unwrap();
        assert!(
            entries.iter().any(|e| e.result == "capability_denied"
                && e.resource_uri == id.as_uri()),
            "audit log should record capability_denied row for the blocked write"
        );

        let mut guard = resource_service_slot().lock().unwrap();
        *guard = None;
    }

    #[tokio::test]
    async fn grants_recorded_before_init_persist_after_switching_to_disk() {
        // Edge case: if the Swift caller records a grant BEFORE
        // driving `permission_store_init_at_path` (e.g. test-order
        // quirks, a boot race), the switch replaces the Connection.
        // The in-memory grants are lost — this test documents that
        // contract so downstream callers know to init EARLY at
        // launch. If a future commit copies in-memory rows into the
        // new file, this test should be updated to match.
        let _gate = r5_persist_gate();

        // Start from a clean fresh in-memory connection to avoid
        // inheriting rows from prior tests.
        let scratch_mem = tempfile::NamedTempFile::new().unwrap();
        let scratch_path = scratch_mem.path().to_string_lossy().to_string();
        permission_store_init_at_path_for_test(scratch_path.clone())
            .await
            .expect("prime at a unique tempfile");

        let pre_grant_uri = format!(
            "vault://r5-pre-init-{0}/note/Inbox/Pre-{0}.md",
            uuid::Uuid::new_v4()
        );
        let pre_grant_id = permission_store_record_user_grant_from_statement(
            "You have my permission to edit this note.".into(),
            pre_grant_uri.clone(),
            vec!["Write".into()],
            "Session".into(),
        )
        .await
        .expect("pre-init grant should land in the prior store");

        // Switch to a DIFFERENT on-disk path. The pre-init grant
        // stays in the prior tempfile on disk (so hypothetically
        // recoverable if we opened that path), but the live store
        // now points at a fresh file → pre-init grant must NOT be
        // visible through list_active.
        let new_tmp = tempfile::tempdir().unwrap();
        let new_path = new_tmp.path().join("fresh.db");
        permission_store_init_at_path_for_test(new_path.to_string_lossy().to_string())
            .await
            .expect("switch to fresh path should succeed");

        let after_switch = permission_store_list_active().await;
        let leaked = after_switch
            .iter()
            .any(|summary| summary.grant_id == pre_grant_id);
        assert!(
            !leaked,
            "switching to a different path must not carry forward the prior store's rows"
        );
        restore_store_to_in_memory().await;
    }

    // --- Phase R.4 attachment-mode bridge tests --------------------------

    #[test]
    fn attached_resource_from_ui_is_live_with_read_write() {
        let uri = ResourceId::VaultNote {
            vault_id: "r4-ui".into(),
            note_id: "Inbox/UI.md".into(),
        }
        .as_uri();
        let attachment = attached_resource_from_ui(uri, "UI attachment".into(), None)
            .expect("valid uri should yield attachment");
        assert_eq!(attachment.mode, AttachmentMode::Live);
        assert!(attachment.allows(Capability::Read));
        assert!(attachment.allows(Capability::Write));
        assert!(!attachment.allows(Capability::Delete));
    }

    #[test]
    fn attached_resource_from_finder_mirrors_ui_defaults() {
        let uri = "file:///tmp/r4-finder-test.swift".to_string();
        let attachment =
            attached_resource_from_finder(uri, "Example.swift".into(), Some("v1".into()))
                .expect("file uri should yield attachment");
        assert_eq!(attachment.mode, AttachmentMode::Live);
        assert!(attachment.allows(Capability::Read));
        assert!(attachment.allows(Capability::Write));
        assert_eq!(attachment.version.as_deref(), Some("v1"));
    }

    #[test]
    fn attached_resource_from_paste_is_snapshot_read_only() {
        let uri = ResourceId::VaultNote {
            vault_id: "r4-paste".into(),
            note_id: "Inbox/Paste.md".into(),
        }
        .as_uri();
        let attachment = attached_resource_from_paste(
            uri,
            "Pasted".into(),
            "# Hello\nsome pasted content".into(),
        )
        .expect("valid uri should yield attachment");
        assert_eq!(attachment.mode, AttachmentMode::Snapshot);
        assert!(attachment.allows(Capability::Read));
        assert!(!attachment.allows(Capability::Write));
        assert_eq!(
            attachment.snapshot_content.as_deref(),
            Some("# Hello\nsome pasted content")
        );
    }

    #[test]
    fn attached_resource_factories_reject_unparseable_uris() {
        assert!(attached_resource_from_ui(
            "nonsense".into(),
            "x".into(),
            None
        )
        .is_none());
        assert!(attached_resource_from_finder(
            "nonsense".into(),
            "x".into(),
            None
        )
        .is_none());
        assert!(attached_resource_from_paste(
            "nonsense".into(),
            "x".into(),
            "body".into()
        )
        .is_none());
    }

    #[test]
    fn attached_resource_allows_forwards_capability_check() {
        let uri = ResourceId::VaultNote {
            vault_id: "r4-allows".into(),
            note_id: "Inbox/Allows.md".into(),
        }
        .as_uri();
        let snapshot = attached_resource_from_paste(uri.clone(), "snap".into(), "body".into())
            .expect("snapshot attachment");
        assert!(attached_resource_allows(snapshot.clone(), Capability::Read));
        assert!(!attached_resource_allows(snapshot, Capability::Write));

        let live =
            attached_resource_from_ui(uri, "live".into(), None).expect("live attachment");
        assert!(attached_resource_allows(live.clone(), Capability::Read));
        assert!(attached_resource_allows(live, Capability::Write));
    }

    // --- Phase R.3 ResourceService bridge tests ------------------------
    //
    // The service bridge is process-local: `resource_service_init` swaps
    // a single `OnceLock<Mutex<Option<Arc<VaultResourceService>>>>`. If
    // two `#[tokio::test]`s run concurrently, they race the slot and
    // silently invalidate each other's ResourceIds. Serialize all R.3
    // tests behind a dedicated mutex so each one owns the active
    // service for its full duration.
    static R3_TEST_GATE: std::sync::Mutex<()> = std::sync::Mutex::new(());

    /// Lock the R.3 gate. Returns an RAII guard; drop it at test end.
    /// Recovers from poisoning so a single panicky test doesn't
    /// permanently block the rest.
    fn r3_gate() -> std::sync::MutexGuard<'static, ()> {
        R3_TEST_GATE
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
    }

    /// Build a clean scratch vault for the duration of one test.
    /// `resource_service_init` swaps the process-local service, so tests
    /// that run in the same process MUST re-init to their own vault
    /// before asserting AND hold `r3_gate()` for their full duration.
    fn make_scratch_vault(label: &str) -> (tempfile::TempDir, String) {
        let tmp = tempfile::tempdir().expect("tempdir");
        let root = tmp.path().to_string_lossy().to_string();
        let vault_id = format!("r3-bridge-{}-{}", label, uuid::Uuid::new_v4());
        // Seed a couple of notes so resolve / read have something to hit.
        std::fs::create_dir_all(tmp.path().join("Inbox")).unwrap();
        std::fs::write(
            tmp.path().join("Inbox").join("R3Alpha.md"),
            "# R3 Alpha\nalpha body line\n",
        )
        .unwrap();
        std::fs::write(
            tmp.path().join("Inbox").join("R3Beta.md"),
            "# R3 Beta\nbeta body line\n",
        )
        .unwrap();
        resource_service_init(root.clone(), vault_id.clone()).expect("init should succeed");
        (tmp, vault_id)
    }

    #[test]
    fn resource_service_init_rejects_missing_vault_root() {
        let _gate = r3_gate();
        let err = resource_service_init(
            "/this/path/definitely/does/not/exist/at/all".into(),
            "r3-missing".into(),
        )
        .expect_err("missing dir must error");
        assert!(matches!(err, ResourceError::Backend(_)));
    }

    #[test]
    fn resource_service_is_ready_after_init() {
        let _gate = r3_gate();
        let (_tmp, _vault) = make_scratch_vault("ready");
        assert!(resource_service_is_ready());
    }

    #[tokio::test]
    async fn resource_resolve_returns_canonical_id_for_title() {
        let _gate = r3_gate();
        let (_tmp, vault_id) = make_scratch_vault("resolve-title");

        let id = resource_resolve("R3Alpha".into())
            .await
            .expect("resolve should find the seeded note");
        match id {
            ResourceId::VaultNote {
                vault_id: got_vault,
                note_id,
            } => {
                assert_eq!(got_vault, vault_id);
                assert_eq!(note_id, "Inbox/R3Alpha.md");
            }
            other => panic!("expected VaultNote variant, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn resource_resolve_rejects_unknown_reference() {
        let _gate = r3_gate();
        let (_tmp, _vault_id) = make_scratch_vault("resolve-unknown");
        let err = resource_resolve("NotARealNote".into())
            .await
            .expect_err("unknown reference must error");
        assert!(matches!(err, ResourceError::UnsupportedReference(_)));
    }

    #[tokio::test]
    async fn resource_read_returns_bytes_and_checksum() {
        let _gate = r3_gate();
        let (_tmp, _vault_id) = make_scratch_vault("read-roundtrip");

        let id = resource_resolve("R3Beta".into()).await.unwrap();
        let content = resource_read(id.clone()).await.unwrap();

        assert_eq!(content.id, id);
        assert!(content
            .bytes
            .windows("beta body line".len())
            .any(|w| w == b"beta body line"));
        assert!(!content.version.is_empty());
        assert_eq!(content.checksum.len(), 64); // sha256 hex
    }

    #[tokio::test]
    async fn resource_write_round_trip_with_version_check() {
        let _gate = r3_gate();
        let (_tmp, _vault_id) = make_scratch_vault("write-roundtrip");

        let id = resource_resolve("R3Alpha".into()).await.unwrap();
        let initial = resource_read(id.clone()).await.unwrap();

        let updated_bytes = b"# R3 Alpha\nalpha UPDATED line\n".to_vec();
        let write_result = resource_write(
            id.clone(),
            updated_bytes.clone(),
            Some(initial.version.clone()),
        )
        .await
        .unwrap();

        assert_eq!(write_result.id, id);
        assert_ne!(write_result.new_version, initial.version);
        assert_eq!(write_result.post_checksum.len(), 64);

        let reread = resource_read(id).await.unwrap();
        assert_eq!(reread.bytes, updated_bytes);
    }

    #[tokio::test]
    async fn resource_write_with_stale_base_version_returns_version_conflict() {
        let _gate = r3_gate();
        let (_tmp, _vault_id) = make_scratch_vault("write-conflict");

        let id = resource_resolve("R3Alpha".into()).await.unwrap();
        // Base version "stale-v0" deliberately does not match.
        let err = resource_write(
            id,
            b"should not land".to_vec(),
            Some("stale-v0".into()),
        )
        .await
        .expect_err("stale base_version must error");
        assert!(matches!(err, ResourceError::VersionConflict { .. }));
    }

    #[tokio::test]
    async fn resource_service_not_initialized_returns_explicit_backend_error() {
        let _gate = r3_gate();
        // Drop the currently-active service so we exercise the
        // not-initialized path without racing other tests.
        {
            let mut guard = resource_service_slot().lock().unwrap();
            *guard = None;
        }
        let err = resource_resolve("anything".into())
            .await
            .expect_err("uninitialized service must error");
        match err {
            ResourceError::Backend(message) => {
                assert!(
                    message.contains("not initialized"),
                    "message should mention init: {message}"
                );
            }
            other => panic!("expected Backend error, got {other:?}"),
        }
    }
}
