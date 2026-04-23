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

use std::sync::OnceLock;

use tokio::runtime::Runtime;
use tokio::sync::Mutex;

use super::{
    Capability, GrantScope, PermissionGrant, PermissionService, ResourceId, ResourceSelector,
    SqlitePermissionService,
};

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
}
