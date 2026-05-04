//! Residency planning for Apple GPU resources.

use helios_core::TierState;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ResidencyClass {
    AlwaysResident,
    DecodeHot,
    Evictable,
    MmapBacked,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ResidencyPlan {
    pub tier: TierState,
    pub class: ResidencyClass,
    pub byte_budget: u64,
}

impl ResidencyPlan {
    #[must_use]
    pub const fn for_tier(tier: TierState, byte_budget: u64) -> Self {
        let class = match tier {
            TierState::Hot => ResidencyClass::AlwaysResident,
            TierState::Residual => ResidencyClass::DecodeHot,
            TierState::Shadow => ResidencyClass::Evictable,
            TierState::Ssd => ResidencyClass::MmapBacked,
            TierState::Cloud | TierState::SelfEvolving => ResidencyClass::Evictable,
        };
        Self { tier, class, byte_budget }
    }
}
