//! HELIOS V5 — MAS / Pro / Research capability lattice (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-MAS-CAPABILITY-LATTICE guard
//!
//! Per HELIOS v4 preservation `source_docs/mac_store_edition.md`
//! §"MAS-safe architecture" — the capability lattice that defines
//! which agent capabilities belong in each deployment tier.
//!
//! The lattice operationalizes the MAS-First Focus Doctrine
//! (see auto-memory `project_mas_first_focus_2026_05_03.md`):
//!
//! > "Active surface = MAS-shippable only. Pro = feature-gated stubs.
//! >  DO NOT actively develop Pro; DO NOT delete Pro geometry. The
//! >  phrase: 'part of the plan, not on the critical path.'"
//!
//! ## Three deployment tiers
//!
//! - **MAS Core** — bounded cognitive substrate; App Sandbox first;
//!   single shared App Group container; SwiftUI shell + UniFFI
//!   Rust core + XPC services. Reviewable, supportable, narrow
//!   entitlement posture.
//! - **Pro** — same architecture, wider capability envelopes;
//!   broader networking; more helper roles; Direct distribution
//!   (NOT Mac App Store).
//! - **Research** — private APIs, raw memory inspection, ANE
//!   experimentation, unrestricted automation, unsafe model
//!   surgery. NEVER product.
//!
//! Per the doctrine: "do not fork the architecture. Keep one
//! substrate and vary only the capability lattice and required
//! entitlements."
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.
//! This module documents the lattice; the actual capability
//! enforcement lives in the build-feature topology
//! (`mas-build` ⊕ `pro-build` ⊕ `research`) and the entitlement
//! plist files for each deployment.

use serde::{Deserialize, Serialize};

/// The three deployment tiers per the MAS-First Focus Doctrine.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DeploymentTier {
    /// Bounded cognitive substrate; App Sandbox first; reviewable.
    /// Distributed via Mac App Store.
    MasCore,
    /// Wider capability envelopes; Direct distribution (not MAS).
    /// "Same architecture, wider envelopes" — not a fork.
    Pro,
    /// Private APIs / raw ANE / unsandboxed helpers; never product.
    Research,
}

/// One agent capability per the `mac_store_edition.md` lattice.
/// Twelve canonical capabilities cover the agent surface across
/// retrieval, identity, sharing, IPC, manifests, providers, and
/// the four risky surfaces (downloaded skills, shells, automation,
/// ANE).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Capability {
    /// Selected-vault retrieval and summarization (security-scoped
    /// bookmarks; user-granted folders only).
    SelectedVaultRetrieval,
    /// Touch ID gating for open/write/export/send actions.
    TouchIdGating,
    /// App Group shared substrate (file-backed mmap arena).
    AppGroupSharedSubstrate,
    /// Sandboxed XPC helper service (privilege separation primitive).
    SandboxedXpcHelper,
    /// Curated local tool manifests (typed; first-party only in MAS).
    CuratedLocalToolManifests,
    /// First-party cloud provider adapters (Anthropic / OpenAI /
    /// Perplexity / Google etc., bounded in MAS).
    FirstPartyCloudProviderAdapters,
    /// Arbitrary downloaded skills / code (extension marketplaces).
    ArbitraryDownloadedSkills,
    /// Shell / Docker / arbitrary subprocess orchestration.
    ShellOrSubprocessOrchestration,
    /// Cross-app automation via Apple Events (System Events / OSA).
    AppleEventsAutomation,
    /// Browser automation / computer-use frameworks (CDP / Selenium).
    BrowserAutomation,
    /// Raw ANE / private frameworks / memory control room.
    RawAneOrPrivateFrameworks,
    /// Unrestricted Wasm / JIT plugin runtime.
    UnrestrictedWasmOrJit,
}

/// Per-tier availability of one capability. Mirrors the doc's
/// ✅ / ⚠️ / ❌ / "defer" / "bounded" / "if justified" matrix.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CapabilityAvailability {
    /// ✅ — fully available.
    Available,
    /// ✅, bounded — available but with explicit boundaries.
    AvailableBounded,
    /// ✅ if notarized + disclosed — Pro ladder for risky helpers.
    AvailableIfNotarizedAndDisclosed,
    /// ✅ if justified and stable — Apple Events Pro path.
    AvailableIfJustified,
    /// ⚠️ selective — Pro avoids by default; case-by-case grant.
    AvailableSelective,
    /// ⚠️ avoid by default — Pro flags the capability but doesn't ship
    /// it ON.
    AvailableAvoidByDefault,
    /// ✅ isolated only — Research path; sandbox-within-sandbox.
    AvailableIsolatedOnly,
    /// `defer` — explicitly deferred per doctrine; revisit when
    /// stable.
    Deferred,
    /// ❌ — not available; compilation/runtime gate enforces it.
    NotAvailable,
}

/// One row of the capability lattice — three availability values
/// (one per tier) for a single capability.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
pub struct CapabilityRow {
    pub capability: Capability,
    pub mas_core: CapabilityAvailability,
    pub pro: CapabilityAvailability,
    pub research: CapabilityAvailability,
}

/// All twelve capabilities in canonical doctrine order per the
/// `mac_store_edition.md` capability table.
pub const CAPABILITY_LATTICE: [CapabilityRow; 12] = [
    CapabilityRow {
        capability: Capability::SelectedVaultRetrieval,
        mas_core: CapabilityAvailability::Available,
        pro: CapabilityAvailability::Available,
        research: CapabilityAvailability::Available,
    },
    CapabilityRow {
        capability: Capability::TouchIdGating,
        mas_core: CapabilityAvailability::Available,
        pro: CapabilityAvailability::Available,
        research: CapabilityAvailability::Available,
    },
    CapabilityRow {
        capability: Capability::AppGroupSharedSubstrate,
        mas_core: CapabilityAvailability::Available,
        pro: CapabilityAvailability::Available,
        research: CapabilityAvailability::Available,
    },
    CapabilityRow {
        capability: Capability::SandboxedXpcHelper,
        mas_core: CapabilityAvailability::Available,
        pro: CapabilityAvailability::Available,
        research: CapabilityAvailability::Available,
    },
    CapabilityRow {
        capability: Capability::CuratedLocalToolManifests,
        mas_core: CapabilityAvailability::Available,
        pro: CapabilityAvailability::Available,
        research: CapabilityAvailability::Available,
    },
    CapabilityRow {
        capability: Capability::FirstPartyCloudProviderAdapters,
        mas_core: CapabilityAvailability::AvailableBounded,
        pro: CapabilityAvailability::Available,
        research: CapabilityAvailability::Available,
    },
    CapabilityRow {
        capability: Capability::ArbitraryDownloadedSkills,
        mas_core: CapabilityAvailability::NotAvailable,
        pro: CapabilityAvailability::AvailableAvoidByDefault,
        research: CapabilityAvailability::AvailableIsolatedOnly,
    },
    CapabilityRow {
        capability: Capability::ShellOrSubprocessOrchestration,
        mas_core: CapabilityAvailability::NotAvailable,
        pro: CapabilityAvailability::AvailableIfNotarizedAndDisclosed,
        research: CapabilityAvailability::Available,
    },
    CapabilityRow {
        capability: Capability::AppleEventsAutomation,
        mas_core: CapabilityAvailability::Deferred,
        pro: CapabilityAvailability::AvailableIfJustified,
        research: CapabilityAvailability::Available,
    },
    CapabilityRow {
        capability: Capability::BrowserAutomation,
        mas_core: CapabilityAvailability::NotAvailable,
        pro: CapabilityAvailability::Available,
        research: CapabilityAvailability::Available,
    },
    CapabilityRow {
        capability: Capability::RawAneOrPrivateFrameworks,
        mas_core: CapabilityAvailability::NotAvailable,
        pro: CapabilityAvailability::NotAvailable,
        research: CapabilityAvailability::Available,
    },
    CapabilityRow {
        capability: Capability::UnrestrictedWasmOrJit,
        mas_core: CapabilityAvailability::NotAvailable,
        pro: CapabilityAvailability::AvailableSelective,
        research: CapabilityAvailability::Available,
    },
];

impl CapabilityRow {
    /// Returns the availability for a given deployment tier.
    pub fn availability(&self, tier: DeploymentTier) -> CapabilityAvailability {
        match tier {
            DeploymentTier::MasCore => self.mas_core,
            DeploymentTier::Pro => self.pro,
            DeploymentTier::Research => self.research,
        }
    }
}

impl CapabilityAvailability {
    /// Returns true when the capability ships in some form (any
    /// `Available*` variant) under the given tier. `NotAvailable`
    /// and `Deferred` return false.
    pub fn ships(self) -> bool {
        !matches!(
            self,
            CapabilityAvailability::NotAvailable | CapabilityAvailability::Deferred
        )
    }

    /// Returns true when the capability is gated on extra hardening
    /// or notarization beyond default availability.
    pub fn requires_hardening(self) -> bool {
        matches!(
            self,
            CapabilityAvailability::AvailableIfNotarizedAndDisclosed
                | CapabilityAvailability::AvailableIfJustified
                | CapabilityAvailability::AvailableSelective
                | CapabilityAvailability::AvailableAvoidByDefault
                | CapabilityAvailability::AvailableIsolatedOnly
                | CapabilityAvailability::AvailableBounded
        )
    }
}

impl Capability {
    /// Look up this capability's row in the canonical lattice.
    pub fn row(self) -> CapabilityRow {
        for row in CAPABILITY_LATTICE {
            if row.capability == self {
                return row;
            }
        }
        unreachable!("CAPABILITY_LATTICE must contain every Capability variant")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lattice_has_twelve_rows() {
        assert_eq!(CAPABILITY_LATTICE.len(), 12);
    }

    #[test]
    fn lattice_covers_every_capability_variant() {
        // Iterate the canonical capability list and verify each appears.
        let all = [
            Capability::SelectedVaultRetrieval,
            Capability::TouchIdGating,
            Capability::AppGroupSharedSubstrate,
            Capability::SandboxedXpcHelper,
            Capability::CuratedLocalToolManifests,
            Capability::FirstPartyCloudProviderAdapters,
            Capability::ArbitraryDownloadedSkills,
            Capability::ShellOrSubprocessOrchestration,
            Capability::AppleEventsAutomation,
            Capability::BrowserAutomation,
            Capability::RawAneOrPrivateFrameworks,
            Capability::UnrestrictedWasmOrJit,
        ];
        for cap in all {
            // Every capability has a lattice row.
            let row = cap.row();
            assert_eq!(row.capability, cap);
        }
    }

    #[test]
    fn mas_baseline_capabilities_ship_in_mas() {
        // The 5 baseline capabilities must always ship in MAS Core
        // per the MAS-First Focus Doctrine.
        for cap in [
            Capability::SelectedVaultRetrieval,
            Capability::TouchIdGating,
            Capability::AppGroupSharedSubstrate,
            Capability::SandboxedXpcHelper,
            Capability::CuratedLocalToolManifests,
        ] {
            let avail = cap.row().availability(DeploymentTier::MasCore);
            assert!(avail.ships(), "{:?} must ship in MAS Core", cap);
        }
    }

    #[test]
    fn risky_surfaces_never_ship_in_mas_core() {
        // The 4 explicitly-NotAvailable-in-MAS capabilities.
        for cap in [
            Capability::ArbitraryDownloadedSkills,
            Capability::ShellOrSubprocessOrchestration,
            Capability::BrowserAutomation,
            Capability::RawAneOrPrivateFrameworks,
            Capability::UnrestrictedWasmOrJit,
        ] {
            let avail = cap.row().availability(DeploymentTier::MasCore);
            assert!(!avail.ships(), "{:?} must NOT ship in MAS Core", cap);
        }
    }

    #[test]
    fn raw_ane_ships_only_in_research() {
        // ANE access is the canonical Research-only capability.
        let row = Capability::RawAneOrPrivateFrameworks.row();
        assert!(!row.mas_core.ships());
        assert!(!row.pro.ships());
        assert!(row.research.ships());
    }

    #[test]
    fn apple_events_is_deferred_in_mas() {
        // Per doctrine: Apple Events automation is "defer" in MAS,
        // not "NotAvailable" — distinct semantics.
        let row = Capability::AppleEventsAutomation.row();
        assert_eq!(row.mas_core, CapabilityAvailability::Deferred);
        assert!(!row.mas_core.ships());
    }

    #[test]
    fn research_tier_ships_every_capability() {
        // Research has the widest envelope by definition.
        for row in CAPABILITY_LATTICE {
            assert!(
                row.research.ships(),
                "{:?} must be available somehow in Research",
                row.capability
            );
        }
    }

    #[test]
    fn pro_tier_strictly_widens_or_matches_mas_core() {
        // Doctrine: "same architecture, wider capability envelopes."
        // For every row, Pro availability must AT LEAST match MAS Core.
        // Concretely: if MAS Core ships it, Pro must ship it; if MAS
        // Core doesn't, Pro may or may not.
        for row in CAPABILITY_LATTICE {
            if row.mas_core.ships() {
                assert!(
                    row.pro.ships(),
                    "{:?} ships in MAS but not Pro — doctrine violation",
                    row.capability
                );
            }
        }
    }

    #[test]
    fn requires_hardening_helper_is_correct() {
        assert!(!CapabilityAvailability::Available.requires_hardening());
        assert!(!CapabilityAvailability::NotAvailable.requires_hardening());
        assert!(!CapabilityAvailability::Deferred.requires_hardening());
        assert!(CapabilityAvailability::AvailableBounded.requires_hardening());
        assert!(CapabilityAvailability::AvailableIfNotarizedAndDisclosed
            .requires_hardening());
        assert!(CapabilityAvailability::AvailableSelective.requires_hardening());
    }

    #[test]
    fn ships_helper_is_correct() {
        // Every Available* variant ships; NotAvailable + Deferred don't.
        assert!(CapabilityAvailability::Available.ships());
        assert!(CapabilityAvailability::AvailableBounded.ships());
        assert!(CapabilityAvailability::AvailableIfNotarizedAndDisclosed.ships());
        assert!(CapabilityAvailability::AvailableIfJustified.ships());
        assert!(CapabilityAvailability::AvailableSelective.ships());
        assert!(CapabilityAvailability::AvailableAvoidByDefault.ships());
        assert!(CapabilityAvailability::AvailableIsolatedOnly.ships());
        assert!(!CapabilityAvailability::NotAvailable.ships());
        assert!(!CapabilityAvailability::Deferred.ships());
    }

    #[test]
    fn deployment_tier_serializes_in_snake_case() {
        for (tier, expected) in [
            (DeploymentTier::MasCore, "\"mas_core\""),
            (DeploymentTier::Pro, "\"pro\""),
            (DeploymentTier::Research, "\"research\""),
        ] {
            assert_eq!(serde_json::to_string(&tier).unwrap(), expected);
        }
    }

    #[test]
    fn all_three_tiers_round_trip_through_json() {
        for tier in [DeploymentTier::MasCore, DeploymentTier::Pro, DeploymentTier::Research] {
            let json = serde_json::to_string(&tier).unwrap();
            let parsed: DeploymentTier = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, tier);
        }
    }

    #[test]
    fn capability_round_trips_through_json() {
        for row in CAPABILITY_LATTICE {
            let json = serde_json::to_string(&row.capability).unwrap();
            let parsed: Capability = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, row.capability);
        }
    }

    /// Doctrine ↔ active-app capability coverage table lock.
    ///
    /// The active app's `agent_core::tools::registry::ToolTier` carries a
    /// 12-row doctrine cross-reference table mapping each HELIOS
    /// Capability variant to the active-app analog (if any) and its
    /// shipping status. If HELIOS renames a Capability variant or grows
    /// the lattice, that table goes stale silently — this test breaks
    /// to force a sync.
    ///
    /// This test ONLY locks the canonical capability *names* (the JSON
    /// snake_case wire form). Per-capability availability semantics are
    /// already locked by the surrounding tests in this module; this is
    /// the additional gate that fires on rename.
    #[test]
    fn active_app_capability_coverage_table_locked() {
        // Order matches the table in agent_core/src/tools/registry.rs.
        let canonical_names: [(Capability, &str); 12] = [
            (Capability::SelectedVaultRetrieval,         "\"selected_vault_retrieval\""),
            (Capability::TouchIdGating,                  "\"touch_id_gating\""),
            (Capability::AppGroupSharedSubstrate,        "\"app_group_shared_substrate\""),
            (Capability::SandboxedXpcHelper,             "\"sandboxed_xpc_helper\""),
            (Capability::CuratedLocalToolManifests,      "\"curated_local_tool_manifests\""),
            (Capability::FirstPartyCloudProviderAdapters,"\"first_party_cloud_provider_adapters\""),
            (Capability::ArbitraryDownloadedSkills,      "\"arbitrary_downloaded_skills\""),
            (Capability::ShellOrSubprocessOrchestration, "\"shell_or_subprocess_orchestration\""),
            (Capability::AppleEventsAutomation,          "\"apple_events_automation\""),
            (Capability::BrowserAutomation,              "\"browser_automation\""),
            (Capability::RawAneOrPrivateFrameworks,      "\"raw_ane_or_private_frameworks\""),
            (Capability::UnrestrictedWasmOrJit,          "\"unrestricted_wasm_or_jit\""),
        ];

        // Count invariant: 12 canonical capabilities. If this changes, the
        // active-app coverage table in registry.rs MUST be updated alongside.
        assert_eq!(canonical_names.len(), 12);
        assert_eq!(CAPABILITY_LATTICE.len(), canonical_names.len(),
            "lattice and coverage table size must agree — if you added a row, \
             update the table in agent_core/src/tools/registry.rs (ToolTier \
             doctrine block) too");

        // Serialized wire-form lock. A rename of any variant breaks this
        // table; that's the drift signal.
        for (cap, expected_json) in canonical_names {
            assert_eq!(serde_json::to_string(&cap).unwrap(), expected_json,
                "Capability::{:?} renamed without updating the active-app \
                 coverage table in agent_core/src/tools/registry.rs", cap);
        }

        // Cross-reference posture lock: the three "MAS baseline + shipped
        // in active app" rows must remain Available in MasCore.
        let mas_baseline_shipping = [
            Capability::SelectedVaultRetrieval,
            Capability::TouchIdGating,
            Capability::AppGroupSharedSubstrate,
            Capability::CuratedLocalToolManifests,
        ];
        for cap in mas_baseline_shipping {
            assert!(
                cap.row().mas_core.ships(),
                "{:?} is documented as shipped in agent_core's MAS build, \
                 but lattice says it doesn't ship in MasCore — coverage \
                 table is stale",
                cap
            );
        }

        // Cross-reference posture lock: the three rows the active app
        // ships only on the Pro deployment tier must NOT ship in MasCore.
        let pro_only_shipping = [
            Capability::ShellOrSubprocessOrchestration,
            Capability::AppleEventsAutomation,
            Capability::BrowserAutomation,
        ];
        for cap in pro_only_shipping {
            assert!(
                !cap.row().mas_core.ships(),
                "{:?} is documented as Pro-only in agent_core, but lattice \
                 says it DOES ship in MasCore — coverage table is stale",
                cap
            );
            assert!(
                cap.row().pro.ships(),
                "{:?} is documented as shipped on Pro in agent_core, but \
                 lattice says it doesn't ship in Pro — coverage table is stale",
                cap
            );
        }
    }
}
