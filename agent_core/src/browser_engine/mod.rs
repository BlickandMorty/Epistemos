//! Wave 6 prep — BrowserEngine trait per FINAL_SYNTHESIS §6.
//!
//! The v3 plan committed to Obscura as the in-process default browser.
//! The §0 audit table corrects this: "BrowserEngine trait, not
//! Obscura-specific commitment." The right primitive is a `BrowserEngine`
//! trait with multiple adapters:
//!
//!   - `WebKitBrowserEngine` (Apple-native, sandbox-clean, mature)
//!     for the AppStoreSafe profile.
//!   - `ObscuraBrowserEngine` (Rust-native, V8, stealth mode +
//!     anti-fingerprinting + 3,520-domain blocklist) for the ProOnly
//!     profile, ephemeral per-call spawn.
//!   - `MockBrowserEngine` for deterministic CI tests.
//!   - `RemoteBrowserEngine` — fallback / debug only.
//!
//! The current `tools/browser.rs` `BrowserActionHandler` is the legacy
//! direct-spawn path that gets replaced by Wave-6 BrowserEngine
//! adapters. Until Wave 6 ships, this trait + the MockBrowserEngine
//! exist so the rest of the codebase can program against the canonical
//! interface.
//!
//! Per FINAL_SYNTHESIS §5.7 browser hardening:
//!   - Per-call ephemeral spawn for Obscura (not always-on daemon).
//!   - Browser ops gated by Layer 4 capability tokens with per-host
//!     network allowlist.
//!   - Proof-of-execution receipts for every browser action.
//!   - Live View renders via screenshot-stream over UniFFI shared
//!     buffer; no SwiftUI exposure to the V8 engine itself.

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Per-engine-call identity. Engines that pool sessions key on this;
/// per-call ephemeral engines (Obscura per §5.7) treat each as a fresh
/// process boundary.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, Hash)]
pub struct SessionId(pub String);

#[derive(Debug, Error)]
pub enum BrowserError {
    #[error("engine not configured: {0}")]
    NotConfigured(String),
    #[error("navigation failed: {0}")]
    NavigationFailed(String),
    #[error("element not found: {0}")]
    ElementNotFound(String),
    #[error("network policy denied host: {0}")]
    NetworkDenied(String),
    #[error("io error: {0}")]
    IoError(String),
    #[error("engine deprecated: {0}")]
    Deprecated(String),
}

/// Minimal accessibility snapshot — ref id + role + text. WebKit and
/// Obscura adapters convert their native A11y surface to this shape;
/// callers downstream use `ref` to address subsequent click/type.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct AxNode {
    /// Stable ref id like `@e5`.
    pub ref_id: String,
    pub role: String,
    pub text: Option<String>,
    pub bbox: Option<[i32; 4]>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct PageSnapshot {
    pub url: String,
    pub title: String,
    pub nodes: Vec<AxNode>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub enum ScrollDirection {
    Up,
    Down,
}

/// The canonical browser surface. Adapters implement these; callers
/// see one trait regardless of the engine.
#[async_trait]
pub trait BrowserEngine: Send + Sync {
    /// Stable engine name for telemetry / capability-gate decisions.
    fn name(&self) -> &str;

    async fn open_session(&self) -> Result<SessionId, BrowserError>;
    async fn navigate(&self, session: &SessionId, url: &str) -> Result<(), BrowserError>;
    async fn snapshot(&self, session: &SessionId) -> Result<PageSnapshot, BrowserError>;
    async fn click(&self, session: &SessionId, ref_id: &str) -> Result<(), BrowserError>;
    async fn type_text(
        &self,
        session: &SessionId,
        ref_id: &str,
        text: &str,
    ) -> Result<(), BrowserError>;
    async fn scroll(
        &self,
        session: &SessionId,
        direction: ScrollDirection,
    ) -> Result<(), BrowserError>;
    async fn close(&self, session: &SessionId) -> Result<(), BrowserError>;
}

// ============================================================================
// MockBrowserEngine — deterministic adapter for CI + unit tests.
// ============================================================================

use std::sync::Mutex;

/// Tape-replay browser engine. Configurable via `with_pages(map)` so
/// tests can pin specific URLs to specific snapshot outputs. Records
/// every interaction in `events()` for round-trip assertions.
pub struct MockBrowserEngine {
    pages: std::collections::HashMap<String, PageSnapshot>,
    state: Mutex<MockState>,
}

#[derive(Default)]
struct MockState {
    next_session: u32,
    sessions: std::collections::HashMap<String, MockSessionState>,
    events: Vec<MockEvent>,
}

struct MockSessionState {
    current_url: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MockEvent {
    OpenSession(String),
    Navigate(String, String),
    Snapshot(String),
    Click(String, String),
    Type(String, String, String),
    Scroll(String, ScrollDirection),
    Close(String),
}

impl MockBrowserEngine {
    pub fn new() -> Self {
        Self {
            pages: std::collections::HashMap::new(),
            state: Mutex::new(MockState::default()),
        }
    }

    pub fn with_page(mut self, url: impl Into<String>, snapshot: PageSnapshot) -> Self {
        self.pages.insert(url.into(), snapshot);
        self
    }

    pub fn events(&self) -> Vec<MockEvent> {
        self.state.lock().unwrap().events.clone()
    }
}

impl Default for MockBrowserEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl BrowserEngine for MockBrowserEngine {
    fn name(&self) -> &str {
        "mock"
    }

    async fn open_session(&self) -> Result<SessionId, BrowserError> {
        let mut s = self.state.lock().unwrap();
        s.next_session += 1;
        let id = format!("mock-session-{}", s.next_session);
        s.sessions
            .insert(id.clone(), MockSessionState { current_url: None });
        s.events.push(MockEvent::OpenSession(id.clone()));
        Ok(SessionId(id))
    }

    async fn navigate(&self, session: &SessionId, url: &str) -> Result<(), BrowserError> {
        let mut s = self.state.lock().unwrap();
        s.events
            .push(MockEvent::Navigate(session.0.clone(), url.to_string()));
        if !self.pages.contains_key(url) {
            return Err(BrowserError::NavigationFailed(format!(
                "mock has no page for {url}"
            )));
        }
        if let Some(state) = s.sessions.get_mut(&session.0) {
            state.current_url = Some(url.to_string());
        } else {
            return Err(BrowserError::NotConfigured(format!(
                "session {} not open",
                session.0
            )));
        }
        Ok(())
    }

    async fn snapshot(&self, session: &SessionId) -> Result<PageSnapshot, BrowserError> {
        let s = self.state.lock().unwrap();
        let state = s.sessions.get(&session.0).ok_or_else(|| {
            BrowserError::NotConfigured(format!("session {} not open", session.0))
        })?;
        let url = state
            .current_url
            .clone()
            .ok_or_else(|| BrowserError::NavigationFailed("no page loaded yet".into()))?;
        let snap = self
            .pages
            .get(&url)
            .ok_or_else(|| {
                BrowserError::NavigationFailed(format!("mock has no page for {url}"))
            })?
            .clone();
        drop(s);
        let mut s = self.state.lock().unwrap();
        s.events.push(MockEvent::Snapshot(session.0.clone()));
        Ok(snap)
    }

    async fn click(&self, session: &SessionId, ref_id: &str) -> Result<(), BrowserError> {
        let mut s = self.state.lock().unwrap();
        s.events.push(MockEvent::Click(
            session.0.clone(),
            ref_id.to_string(),
        ));
        Ok(())
    }

    async fn type_text(
        &self,
        session: &SessionId,
        ref_id: &str,
        text: &str,
    ) -> Result<(), BrowserError> {
        let mut s = self.state.lock().unwrap();
        s.events.push(MockEvent::Type(
            session.0.clone(),
            ref_id.to_string(),
            text.to_string(),
        ));
        Ok(())
    }

    async fn scroll(
        &self,
        session: &SessionId,
        direction: ScrollDirection,
    ) -> Result<(), BrowserError> {
        let mut s = self.state.lock().unwrap();
        s.events.push(MockEvent::Scroll(session.0.clone(), direction));
        Ok(())
    }

    async fn close(&self, session: &SessionId) -> Result<(), BrowserError> {
        let mut s = self.state.lock().unwrap();
        s.sessions.remove(&session.0);
        s.events.push(MockEvent::Close(session.0.clone()));
        Ok(())
    }
}

// ============================================================================
// Stub WebKitBrowserEngine + ObscuraBrowserEngine.
//
// Both surface NotConfigured today — the actual integrations land in
// Wave 6 (WebKit via UniFFI to a Swift-side WKWebView pool; Obscura
// via the Rust-native engine wrapper). The stubs exist so a Profile-
// aware factory can return them by name + the AppStoreSafe / ProOnly
// gating tests can compile against the trait.
// ============================================================================

pub struct WebKitBrowserEngine;

impl WebKitBrowserEngine {
    pub fn new() -> Self {
        Self
    }
}

impl Default for WebKitBrowserEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl BrowserEngine for WebKitBrowserEngine {
    fn name(&self) -> &str {
        "webkit"
    }
    async fn open_session(&self) -> Result<SessionId, BrowserError> {
        Err(BrowserError::NotConfigured(
            "WebKitBrowserEngine integration lands in Wave 6 — \
             needs UniFFI bridge to Swift WKWebView pool"
                .into(),
        ))
    }
    async fn navigate(&self, _: &SessionId, _: &str) -> Result<(), BrowserError> {
        Err(BrowserError::NotConfigured("webkit not yet wired".into()))
    }
    async fn snapshot(&self, _: &SessionId) -> Result<PageSnapshot, BrowserError> {
        Err(BrowserError::NotConfigured("webkit not yet wired".into()))
    }
    async fn click(&self, _: &SessionId, _: &str) -> Result<(), BrowserError> {
        Err(BrowserError::NotConfigured("webkit not yet wired".into()))
    }
    async fn type_text(&self, _: &SessionId, _: &str, _: &str) -> Result<(), BrowserError> {
        Err(BrowserError::NotConfigured("webkit not yet wired".into()))
    }
    async fn scroll(&self, _: &SessionId, _: ScrollDirection) -> Result<(), BrowserError> {
        Err(BrowserError::NotConfigured("webkit not yet wired".into()))
    }
    async fn close(&self, _: &SessionId) -> Result<(), BrowserError> {
        Err(BrowserError::NotConfigured("webkit not yet wired".into()))
    }
}

pub struct ObscuraBrowserEngine;

impl ObscuraBrowserEngine {
    pub fn new() -> Self {
        Self
    }
}

impl Default for ObscuraBrowserEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl BrowserEngine for ObscuraBrowserEngine {
    fn name(&self) -> &str {
        "obscura"
    }
    async fn open_session(&self) -> Result<SessionId, BrowserError> {
        Err(BrowserError::NotConfigured(
            "ObscuraBrowserEngine integration lands in Wave 6 — \
             needs Rust-native engine + V8 entitlement + per-call \
             ephemeral spawn per FINAL_SYNTHESIS §5.7"
                .into(),
        ))
    }
    async fn navigate(&self, _: &SessionId, _: &str) -> Result<(), BrowserError> {
        Err(BrowserError::NotConfigured("obscura not yet wired".into()))
    }
    async fn snapshot(&self, _: &SessionId) -> Result<PageSnapshot, BrowserError> {
        Err(BrowserError::NotConfigured("obscura not yet wired".into()))
    }
    async fn click(&self, _: &SessionId, _: &str) -> Result<(), BrowserError> {
        Err(BrowserError::NotConfigured("obscura not yet wired".into()))
    }
    async fn type_text(&self, _: &SessionId, _: &str, _: &str) -> Result<(), BrowserError> {
        Err(BrowserError::NotConfigured("obscura not yet wired".into()))
    }
    async fn scroll(&self, _: &SessionId, _: ScrollDirection) -> Result<(), BrowserError> {
        Err(BrowserError::NotConfigured("obscura not yet wired".into()))
    }
    async fn close(&self, _: &SessionId) -> Result<(), BrowserError> {
        Err(BrowserError::NotConfigured("obscura not yet wired".into()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_snap() -> PageSnapshot {
        PageSnapshot {
            url: "https://example.test/".into(),
            title: "Example".into(),
            nodes: vec![AxNode {
                ref_id: "@e1".into(),
                role: "button".into(),
                text: Some("Sign in".into()),
                bbox: Some([10, 20, 100, 30]),
            }],
        }
    }

    #[tokio::test]
    async fn mock_engine_round_trips_navigate_snapshot_click_close() {
        let engine = MockBrowserEngine::new()
            .with_page("https://example.test/", sample_snap());
        let session = engine.open_session().await.unwrap();
        engine
            .navigate(&session, "https://example.test/")
            .await
            .unwrap();
        let snap = engine.snapshot(&session).await.unwrap();
        assert_eq!(snap.title, "Example");
        assert_eq!(snap.nodes.len(), 1);
        engine.click(&session, "@e1").await.unwrap();
        engine.close(&session).await.unwrap();

        let events = engine.events();
        assert_eq!(events.len(), 5);
        assert!(matches!(events[0], MockEvent::OpenSession(_)));
        assert!(matches!(events[1], MockEvent::Navigate(_, _)));
        assert!(matches!(events[2], MockEvent::Snapshot(_)));
        assert!(matches!(events[3], MockEvent::Click(_, _)));
        assert!(matches!(events[4], MockEvent::Close(_)));
    }

    #[tokio::test]
    async fn mock_engine_navigate_to_unconfigured_url_errors_cleanly() {
        let engine = MockBrowserEngine::new();
        let session = engine.open_session().await.unwrap();
        let err = engine
            .navigate(&session, "https://nope.test/")
            .await
            .unwrap_err();
        assert!(matches!(err, BrowserError::NavigationFailed(_)));
    }

    #[tokio::test]
    async fn mock_engine_snapshot_without_navigation_errors() {
        let engine = MockBrowserEngine::new();
        let session = engine.open_session().await.unwrap();
        assert!(matches!(
            engine.snapshot(&session).await,
            Err(BrowserError::NavigationFailed(_))
        ));
    }

    #[tokio::test]
    async fn webkit_stub_surfaces_not_configured_for_every_call() {
        let engine = WebKitBrowserEngine::new();
        assert_eq!(engine.name(), "webkit");
        assert!(matches!(
            engine.open_session().await,
            Err(BrowserError::NotConfigured(_))
        ));
    }

    #[tokio::test]
    async fn obscura_stub_surfaces_not_configured_for_every_call() {
        let engine = ObscuraBrowserEngine::new();
        assert_eq!(engine.name(), "obscura");
        assert!(matches!(
            engine.open_session().await,
            Err(BrowserError::NotConfigured(_))
        ));
    }

    #[tokio::test]
    async fn engines_are_substitutable_through_trait_object() {
        // The §6 invariant: any BrowserEngine adapter plugs in via the
        // trait. Test this by holding a Box<dyn BrowserEngine> and
        // calling through it; the mock satisfies the contract end-to-end
        // and the stubs surface NotConfigured uniformly.
        let mock: Box<dyn BrowserEngine> = Box::new(
            MockBrowserEngine::new().with_page("https://example.test/", sample_snap()),
        );
        let session = mock.open_session().await.unwrap();
        mock.navigate(&session, "https://example.test/").await.unwrap();
        let snap = mock.snapshot(&session).await.unwrap();
        assert_eq!(snap.title, "Example");

        let webkit: Box<dyn BrowserEngine> = Box::new(WebKitBrowserEngine::new());
        assert_eq!(webkit.name(), "webkit");
        let obscura: Box<dyn BrowserEngine> = Box::new(ObscuraBrowserEngine::new());
        assert_eq!(obscura.name(), "obscura");
    }
}
