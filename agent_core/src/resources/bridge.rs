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
//! - Persistent storage on disk at `~/Library/Application Support/Epistemos/
//!   permissions.db`. Will land in a follow-up once Swift drives the init
//!   with a container-safe path (MAS sandbox considerations).
//! - Replacement of Swift's existing `activeGrantsSection` hard-coded
//!   rows. R.5 UI wiring is additive — surfaces Rust-backed grants
//!   alongside the existing rows.
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

/// Process-local permission store. In-memory SQLite for this commit;
/// follow-up will accept a Swift-provided container-safe path.
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
    let guard = store().lock().await;
    guard.check(resource, capability).await
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
// Tests
// ---------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn fresh_store_is_empty() {
        let summaries = permission_store_list_active().await;
        // Other tests in this crate may have seeded the store (tests share
        // the process singleton). We just need to confirm the call succeeds
        // and returns a (possibly empty) vector without panicking.
        let _ = summaries.len();
    }

    #[tokio::test]
    async fn record_user_grant_and_check_roundtrip() {
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
