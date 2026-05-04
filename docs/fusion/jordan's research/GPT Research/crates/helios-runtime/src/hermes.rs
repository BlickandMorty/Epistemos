//! Hermes boundary protocol. Hermes is non-authoritative and receives only leased capability grants.

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ProviderKind {
    Local,
    OpenAi,
    Anthropic,
    DeepSeek,
    Hermes405B,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CapabilityGrant {
    pub grant_id: u64,
    pub provider: ProviderKind,
    pub can_network: bool,
    pub can_read_vault: bool,
    pub expires_at_unix_ms: u64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct HermesBoundary {
    active_provider: ProviderKind,
    grants: Vec<CapabilityGrant>,
}

impl Default for HermesBoundary {
    fn default() -> Self {
        Self { active_provider: ProviderKind::Local, grants: Vec::new() }
    }
}

impl HermesBoundary {
    #[must_use]
    pub const fn active_provider(&self) -> ProviderKind { self.active_provider }

    pub fn set_provider(&mut self, provider: ProviderKind) { self.active_provider = provider; }

    pub fn issue_grant(&mut self, grant: CapabilityGrant) { self.grants.push(grant); }

    #[must_use]
    pub fn valid_grants(&self, now_unix_ms: u64) -> Vec<&CapabilityGrant> {
        self.grants.iter().filter(|grant| grant.expires_at_unix_ms > now_unix_ms).collect()
    }
}
