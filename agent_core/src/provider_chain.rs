//! Provider Chain — Ordered Fallback Chain for LLM Providers
//!
//! When the primary provider fails (retries exhausted, auth permanent, etc.),
//! automatically fall back to the next provider in the chain.
//!
//! Reference: Hermes `agent/provider_chain.py`

use std::sync::Arc;

use crate::agent_loop::AgentError;
use crate::provider::AgentProvider;

/// A provider in the fallback chain, with metadata about why it was selected.
pub struct ChainedProvider {
    /// The provider instance.
    pub provider: Arc<dyn AgentProvider>,
    /// Provider name for logging/diagnostics.
    pub name: String,
    /// Why this provider is in the chain (e.g., "primary", "fallback", "cost_optimized").
    pub role: String,
    /// Whether this provider has been tried and failed.
    pub failed: bool,
    /// Reason for failure (if failed).
    pub failure_reason: Option<String>,
}

impl std::fmt::Debug for ChainedProvider {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ChainedProvider")
            .field("name", &self.name)
            .field("role", &self.role)
            .field("failed", &self.failed)
            .field("failure_reason", &self.failure_reason)
            .finish_non_exhaustive()
    }
}

/// An ordered chain of providers to try.
pub struct ProviderChain {
    providers: Vec<ChainedProvider>,
    /// Index of the currently active provider.
    current_index: usize,
    /// Maximum providers to try before giving up.
    max_providers: usize,
}

impl ProviderChain {
    /// Create a new provider chain from a list of providers.
    /// The first provider is the primary; subsequent are fallbacks.
    pub fn new(providers: Vec<(Arc<dyn AgentProvider>, String, String)>) -> Self {
        let chained = providers
            .into_iter()
            .map(|(provider, name, role)| ChainedProvider {
                provider,
                name,
                role,
                failed: false,
                failure_reason: None,
            })
            .collect();

        Self {
            providers: chained,
            current_index: 0,
            max_providers: 3,
        }
    }

    /// Create a chain with a single provider (no fallback).
    pub fn single(provider: Arc<dyn AgentProvider>, name: impl Into<String>) -> Self {
        Self::new(vec![(provider, name.into(), "primary".to_string())])
    }

    /// Get the currently active provider.
    pub fn current(&self) -> Option<&Arc<dyn AgentProvider>> {
        self.providers.get(self.current_index).map(|p| &p.provider)
    }

    /// Get the name of the currently active provider.
    pub fn current_name(&self) -> Option<&str> {
        self.providers.get(self.current_index).map(|p| p.name.as_str())
    }

    /// Mark the current provider as failed and advance to the next.
    /// Returns true if a fallback provider is available.
    pub fn advance(&mut self, reason: impl Into<String>) -> bool {
        if let Some(provider) = self.providers.get_mut(self.current_index) {
            provider.failed = true;
            provider.failure_reason = Some(reason.into());
            tracing::warn!(
                provider = %provider.name,
                reason = %provider.failure_reason.as_ref().unwrap(),
                "Provider failed, attempting fallback"
            );
        }

        // Find next non-failed provider
        for offset in 1..self.providers.len() {
            let next_index = self.current_index + offset;
            if next_index >= self.providers.len() || next_index >= self.max_providers {
                break;
            }
            if !self.providers[next_index].failed {
                self.current_index = next_index;
                tracing::info!(
                    new_provider = %self.providers[next_index].name,
                    role = %self.providers[next_index].role,
                    "Switched to fallback provider"
                );
                return true;
            }
        }

        tracing::error!(
            tried = self.current_index + 1,
            total = self.providers.len(),
            "All providers in chain exhausted"
        );
        false
    }

    /// Check if there are more providers to try.
    pub fn has_fallback(&self) -> bool {
        let next_index = self.current_index + 1;
        next_index < self.providers.len()
            && next_index < self.max_providers
            && !self.providers.get(next_index).map_or(true, |p| p.failed)
    }

    /// Get the full chain status (for diagnostics/FFI).
    pub fn status(&self) -> Vec<(String, String, bool, Option<String>)> {
        self.providers
            .iter()
            .map(|p| {
                (
                    p.name.clone(),
                    p.role.clone(),
                    p.failed,
                    p.failure_reason.clone(),
                )
            })
            .collect()
    }

    /// Reset the chain (e.g., on new session).
    pub fn reset(&mut self) {
        self.current_index = 0;
        for provider in &mut self.providers {
            provider.failed = false;
            provider.failure_reason = None;
        }
    }

    /// Number of providers in the chain.
    pub fn len(&self) -> usize {
        self.providers.len()
    }

    pub fn is_empty(&self) -> bool {
        self.providers.is_empty()
    }
}

/// Build a standard fallback chain from provider names.
/// Uses the bridge's `instantiate_provider` to create provider instances.
///
/// # Fallback priority (Hermes-style):
/// 1. Primary provider (user's choice)
/// 2. Claude Sonnet (reliable general-purpose)
/// 3. OpenAI GPT-4o (broad compatibility)
/// 4. Gemini Flash (cost-optimized)
pub fn build_standard_chain(
    primary: &str,
    instantiate: &dyn Fn(&str) -> Result<Arc<dyn AgentProvider>, AgentError>,
) -> Result<ProviderChain, AgentError> {
    let mut providers = Vec::new();

    // Primary
    providers.push((instantiate(primary)?, primary.to_string(), "primary".to_string()));

    // Fallbacks (skip if same as primary)
    let fallbacks = ["claude_sonnet", "openai", "gemini_flash"];
    for fallback in &fallbacks {
        if *fallback != primary {
            match instantiate(fallback) {
                Ok(provider) => providers.push((
                    provider,
                    fallback.to_string(),
                    "fallback".to_string(),
                )),
                Err(e) => {
                    tracing::warn!(
                        fallback = %fallback,
                        error = %e,
                        "Failed to instantiate fallback provider, skipping"
                    );
                }
            }
        }
    }

    Ok(ProviderChain::new(providers))
}

/// Build a cost-optimized chain (cheapest providers first).
pub fn build_cost_optimized_chain(
    instantiate: &dyn Fn(&str) -> Result<Arc<dyn AgentProvider>, AgentError>,
) -> Result<ProviderChain, AgentError> {
    let mut providers = Vec::new();

    // Cost-ordered: cheapest first
    let cost_order = ["gemini_flash", "claude_haiku", "openai_gpt4o_mini", "claude_sonnet"];
    for name in &cost_order {
        match instantiate(name) {
            Ok(provider) => providers.push((
                provider,
                name.to_string(),
                "cost_optimized".to_string(),
            )),
            Err(e) => {
                tracing::warn!(
                    provider = %name,
                    error = %e,
                    "Failed to instantiate cost-optimized provider, skipping"
                );
            }
        }
    }

    if providers.is_empty() {
        return Err(AgentError::Provider(
            "No providers could be instantiated for cost-optimized chain".to_string()
        ));
    }

    Ok(ProviderChain::new(providers))
}

#[cfg(test)]
mod tests {
    use super::*;

    // Mock provider for testing
    struct MockProvider;
    #[async_trait::async_trait]
    impl AgentProvider for MockProvider {
        async fn stream_message(
            &self,
            _messages: &[crate::types::Message],
            _tools: &[crate::types::ToolSchema],
            _config: &crate::agent_loop::AgentConfig,
        ) -> Result<crate::provider::MessageStream, AgentError> {
            unimplemented!()
        }
        async fn compact(&self, _messages: &[crate::types::Message]) -> Result<Vec<crate::types::Message>, AgentError> {
            unimplemented!()
        }
        fn capabilities(&self) -> crate::provider::ProviderCapabilities {
            unimplemented!()
        }
        fn name(&self) -> &'static str {
            "mock"
        }
    }

    #[test]
    fn single_provider_chain() {
        let provider = Arc::new(MockProvider);
        let chain = ProviderChain::single(provider, "claude");
        assert_eq!(chain.current_name(), Some("claude"));
        assert!(!chain.has_fallback());
        assert_eq!(chain.len(), 1);
    }

    #[test]
    fn advance_to_fallback() {
        let p1 = Arc::new(MockProvider);
        let p2 = Arc::new(MockProvider);
        let mut chain = ProviderChain::new(vec![
            (p1, "claude".to_string(), "primary".to_string()),
            (p2, "openai".to_string(), "fallback".to_string()),
        ]);

        assert_eq!(chain.current_name(), Some("claude"));
        assert!(chain.has_fallback());

        assert!(chain.advance("auth failed"));
        assert_eq!(chain.current_name(), Some("openai"));
        assert!(!chain.has_fallback());
    }

    #[test]
    fn all_providers_exhausted() {
        let p1 = Arc::new(MockProvider);
        let p2 = Arc::new(MockProvider);
        let mut chain = ProviderChain::new(vec![
            (p1, "claude".to_string(), "primary".to_string()),
            (p2, "openai".to_string(), "fallback".to_string()),
        ]);

        chain.advance("auth failed");
        assert!(!chain.advance("rate limited")); // No more fallbacks

        let status = chain.status();
        assert!(status[0].2); // claude is failed
        assert!(status[1].2); // openai is failed
    }

    #[test]
    fn reset_clears_failures() {
        let p1 = Arc::new(MockProvider);
        let p2 = Arc::new(MockProvider);
        let mut chain = ProviderChain::new(vec![
            (p1, "claude".to_string(), "primary".to_string()),
            (p2, "openai".to_string(), "fallback".to_string()),
        ]);

        chain.advance("auth failed");
        assert_eq!(chain.current_name(), Some("openai"));

        chain.reset();
        assert_eq!(chain.current_name(), Some("claude"));
        // After reset, p1 is current and p2 is available as fallback
        assert!(chain.has_fallback());
    }
}
