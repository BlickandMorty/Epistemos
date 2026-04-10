//! Rate Limit Tracker — Per-Provider Quota Management
//!
//! Reference: Hermes `agent/rate_limit_tracker.py`
//!
//! Tracks remaining API quota per provider from HTTP response headers.
//! Provides intelligent backoff recommendations when limits are approached.
//! Consulted by the agent loop before each API call.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, SystemTime};

use serde::{Deserialize, Serialize};

/// Global rate limit tracker (thread-safe singleton pattern).
pub struct RateLimitTracker {
    providers: Mutex<HashMap<String, ProviderLimits>>,
}

/// Rate limit state for a single provider.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderLimits {
    /// Remaining API requests in current window (from headers).
    pub requests_remaining: Option<u32>,
    /// Remaining tokens in current window.
    pub tokens_remaining: Option<u32>,
    /// When the current rate limit window resets.
    pub reset_at: Option<SystemTime>,
    /// Last time we received a 429 from this provider.
    pub last_429_at: Option<SystemTime>,
    /// Consecutive 429 errors (for exponential backoff).
    pub consecutive_429s: u32,
    /// Total requests made in this session.
    pub total_requests: u64,
    /// Total 429s received in this session.
    pub total_429s: u32,
}

impl Default for ProviderLimits {
    fn default() -> Self {
        Self {
            requests_remaining: None,
            tokens_remaining: None,
            reset_at: None,
            last_429_at: None,
            consecutive_429s: 0,
            total_requests: 0,
            total_429s: 0,
        }
    }
}

impl RateLimitTracker {
    pub fn new() -> Self {
        Self {
            providers: Mutex::new(HashMap::new()),
        }
    }

    /// Update rate limits from HTTP response headers.
    /// Standard headers: x-ratelimit-remaining-requests, x-ratelimit-remaining-tokens,
    /// x-ratelimit-reset-requests, retry-after
    pub fn update_from_headers(&self, provider: &str, headers: &[(String, String)]) {
        let mut providers = match self.providers.lock() {
            Ok(p) => p,
            Err(_) => return,
        };
        let limits = providers.entry(provider.to_string()).or_default();
        limits.total_requests += 1;

        for (key, value) in headers {
            let key_lower = key.to_lowercase();
            match key_lower.as_str() {
                "x-ratelimit-remaining-requests" => {
                    limits.requests_remaining = value.parse().ok();
                }
                "x-ratelimit-remaining-tokens" => {
                    limits.tokens_remaining = value.parse().ok();
                }
                "x-ratelimit-reset-requests" | "x-ratelimit-reset-tokens" => {
                    // Parse duration strings like "1s", "60s", "1m"
                    if let Some(secs) = parse_duration_str(value) {
                        limits.reset_at = Some(SystemTime::now() + Duration::from_secs(secs));
                    }
                }
                "retry-after" => {
                    if let Ok(secs) = value.parse::<u64>() {
                        limits.reset_at = Some(SystemTime::now() + Duration::from_secs(secs));
                    }
                }
                _ => {}
            }
        }
    }

    /// Record a 429 rate limit error for a provider.
    pub fn record_429(&self, provider: &str) {
        let mut providers = match self.providers.lock() {
            Ok(p) => p,
            Err(_) => return,
        };
        let limits = providers.entry(provider.to_string()).or_default();
        limits.last_429_at = Some(SystemTime::now());
        limits.consecutive_429s += 1;
        limits.total_429s += 1;
    }

    /// Record a successful API call (resets consecutive 429 counter).
    pub fn record_success(&self, provider: &str) {
        let mut providers = match self.providers.lock() {
            Ok(p) => p,
            Err(_) => return,
        };
        let limits = providers.entry(provider.to_string()).or_default();
        limits.consecutive_429s = 0;
        limits.total_requests += 1;
    }

    /// Check if we should wait before making another call to this provider.
    /// Returns None if safe to proceed, Some(duration) if we should wait.
    pub fn should_wait(&self, provider: &str) -> Option<Duration> {
        let providers = self.providers.lock().ok()?;
        let limits = providers.get(provider)?;

        // If we know the reset time and it's in the future, wait until then
        if let Some(reset_at) = limits.reset_at {
            if let Ok(remaining) = reset_at.duration_since(SystemTime::now()) {
                if limits.requests_remaining == Some(0) {
                    return Some(remaining);
                }
            }
        }

        // Exponential backoff on consecutive 429s
        if limits.consecutive_429s > 0 {
            let backoff_secs = (2u64.pow(limits.consecutive_429s.min(6))).min(120);
            if let Some(last_429) = limits.last_429_at {
                let elapsed = last_429.elapsed().unwrap_or_default();
                let backoff = Duration::from_secs(backoff_secs);
                if elapsed < backoff {
                    return Some(backoff - elapsed);
                }
            }
        }

        None
    }

    /// Get current rate limit state for a provider (for UI display).
    pub fn get_state(&self, provider: &str) -> Option<ProviderLimits> {
        self.providers.lock().ok()?.get(provider).cloned()
    }

    /// Get all provider states (for diagnostics).
    pub fn all_states(&self) -> HashMap<String, ProviderLimits> {
        self.providers.lock().ok().map(|p| p.clone()).unwrap_or_default()
    }
}

impl Default for RateLimitTracker {
    fn default() -> Self {
        Self::new()
    }
}

/// Parse duration strings like "1s", "60s", "1m", "5m30s"
fn parse_duration_str(s: &str) -> Option<u64> {
    let s = s.trim();
    if let Ok(secs) = s.parse::<u64>() {
        return Some(secs);
    }
    if s.ends_with('s') {
        return s[..s.len() - 1].parse().ok();
    }
    if s.ends_with('m') {
        return s[..s.len() - 1].parse::<u64>().ok().map(|m| m * 60);
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_wait_for_unknown_provider() {
        let tracker = RateLimitTracker::new();
        assert!(tracker.should_wait("unknown").is_none());
    }

    #[test]
    fn success_resets_consecutive_429s() {
        let tracker = RateLimitTracker::new();
        tracker.record_429("claude");
        tracker.record_429("claude");
        tracker.record_success("claude");
        let state = tracker.get_state("claude").unwrap();
        assert_eq!(state.consecutive_429s, 0);
        assert_eq!(state.total_429s, 2);
    }

    #[test]
    fn exponential_backoff_on_429s() {
        let tracker = RateLimitTracker::new();
        tracker.record_429("claude");
        // After 1 consecutive 429, should recommend 2s wait
        let wait = tracker.should_wait("claude");
        assert!(wait.is_some());
        assert!(wait.unwrap().as_secs() <= 2);
    }

    #[test]
    fn headers_update_remaining() {
        let tracker = RateLimitTracker::new();
        tracker.update_from_headers("claude", &[
            ("x-ratelimit-remaining-requests".into(), "5".into()),
            ("x-ratelimit-remaining-tokens".into(), "100000".into()),
        ]);
        let state = tracker.get_state("claude").unwrap();
        assert_eq!(state.requests_remaining, Some(5));
        assert_eq!(state.tokens_remaining, Some(100_000));
    }

    #[test]
    fn parse_duration_handles_formats() {
        assert_eq!(parse_duration_str("30"), Some(30));
        assert_eq!(parse_duration_str("30s"), Some(30));
        assert_eq!(parse_duration_str("2m"), Some(120));
        assert_eq!(parse_duration_str("invalid"), None);
    }
}
