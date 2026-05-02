use serde::{Deserialize, Serialize};

use crate::tools::registry::RiskLevel;

/// Canonical Sensitive-class grace window from doctrine §4.2.
pub const DEFAULT_SENSITIVE_GRACE_SECS: u64 = 15 * 60;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SovereignActionClass {
    Trivial,
    Reversible,
    Sensitive,
    Destructive,
    Sovereign,
}

impl SovereignActionClass {
    /// Bridge the existing tool-registry risk ladder into the Sovereign Gate
    /// matrix without changing tool execution or approval behavior.
    pub fn from_tool_risk(risk: RiskLevel) -> Self {
        match risk {
            RiskLevel::ReadOnly => Self::Trivial,
            RiskLevel::Modification => Self::Reversible,
            RiskLevel::Destructive => Self::Destructive,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case", tag = "kind")]
pub enum GateRequirement {
    #[serde(rename = "none")]
    NoPrompt,
    Biometric {
        category: String,
        grace_secs: u64,
    },
    DeviceOwnerAuthentication,
    SecureEnclaveKeyRelease {
        category: String,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case", tag = "kind")]
pub enum GateOutcome {
    Allowed,
    Denied { reason: String },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SovereignActionIntent {
    OpenNote,
    Scroll,
    Search,
    NewChat,
    DraftEdit,
    LocalCapture,
    QuickCapture,
    ExportNote,
    ShareLink,
    SoftDelete,
    OAuthScopeGrant,
    EmptyTrash,
    DropVault,
    RevokeKey,
    ChangeTier,
    UnwrapDarkNodeKey,
    SignAttestation,
    ChangePolicyProfile,
    LoadNeuralImplant,
}

impl SovereignActionIntent {
    pub fn action_class(self) -> SovereignActionClass {
        match self {
            Self::OpenNote | Self::Scroll | Self::Search => SovereignActionClass::Trivial,
            Self::NewChat | Self::DraftEdit | Self::LocalCapture | Self::QuickCapture => {
                SovereignActionClass::Reversible
            }
            Self::ExportNote | Self::ShareLink | Self::SoftDelete | Self::OAuthScopeGrant => {
                SovereignActionClass::Sensitive
            }
            Self::EmptyTrash | Self::DropVault | Self::RevokeKey | Self::ChangeTier => {
                SovereignActionClass::Destructive
            }
            Self::UnwrapDarkNodeKey
            | Self::SignAttestation
            | Self::ChangePolicyProfile
            | Self::LoadNeuralImplant => SovereignActionClass::Sovereign,
        }
    }

    pub fn gate_requirement(self) -> GateRequirement {
        match self.action_class() {
            SovereignActionClass::Trivial | SovereignActionClass::Reversible => {
                GateRequirement::NoPrompt
            }
            SovereignActionClass::Sensitive => GateRequirement::Biometric {
                category: self.gate_category().to_string(),
                grace_secs: DEFAULT_SENSITIVE_GRACE_SECS,
            },
            SovereignActionClass::Destructive => GateRequirement::DeviceOwnerAuthentication,
            SovereignActionClass::Sovereign => GateRequirement::SecureEnclaveKeyRelease {
                category: self.gate_category().to_string(),
            },
        }
    }

    pub fn gate_category(self) -> &'static str {
        match self {
            Self::OpenNote => "open_note",
            Self::Scroll => "scroll",
            Self::Search => "search",
            Self::NewChat => "new_chat",
            Self::DraftEdit => "draft_edit",
            Self::LocalCapture => "local_capture",
            Self::QuickCapture => "quick_capture",
            Self::ExportNote => "export_note",
            Self::ShareLink => "share_link",
            Self::SoftDelete => "soft_delete",
            Self::OAuthScopeGrant => "oauth_scope_grant",
            Self::EmptyTrash => "empty_trash",
            Self::DropVault => "drop_vault",
            Self::RevokeKey => "revoke_key",
            Self::ChangeTier => "change_tier",
            Self::UnwrapDarkNodeKey => "dark_node_key",
            Self::SignAttestation => "attestation",
            Self::ChangePolicyProfile => "policy_profile",
            Self::LoadNeuralImplant => "neural_implant",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tools::registry::RiskLevel;

    #[test]
    fn doctrine_examples_map_to_action_classes() {
        assert_eq!(
            SovereignActionIntent::OpenNote.action_class(),
            SovereignActionClass::Trivial
        );
        assert_eq!(
            SovereignActionIntent::QuickCapture.action_class(),
            SovereignActionClass::Reversible
        );
        assert_eq!(
            SovereignActionIntent::ExportNote.action_class(),
            SovereignActionClass::Sensitive
        );
        assert_eq!(
            SovereignActionIntent::DropVault.action_class(),
            SovereignActionClass::Destructive
        );
        assert_eq!(
            SovereignActionIntent::LoadNeuralImplant.action_class(),
            SovereignActionClass::Sovereign
        );
    }

    #[test]
    fn sensitive_requirement_uses_category_scoped_biometric_grace() {
        assert_eq!(
            SovereignActionIntent::OAuthScopeGrant.gate_requirement(),
            GateRequirement::Biometric {
                category: "oauth_scope_grant".to_string(),
                grace_secs: DEFAULT_SENSITIVE_GRACE_SECS,
            }
        );
    }

    #[test]
    fn destructive_requirement_uses_device_owner_authentication_without_grace() {
        assert_eq!(
            SovereignActionIntent::EmptyTrash.gate_requirement(),
            GateRequirement::DeviceOwnerAuthentication
        );
    }

    #[test]
    fn sovereign_requirement_is_forward_secure_enclave_key_release() {
        assert_eq!(
            SovereignActionIntent::ChangePolicyProfile.gate_requirement(),
            GateRequirement::SecureEnclaveKeyRelease {
                category: "policy_profile".to_string(),
            }
        );
    }

    #[test]
    fn existing_tool_risk_levels_bridge_conservatively() {
        assert_eq!(
            SovereignActionClass::from_tool_risk(RiskLevel::ReadOnly),
            SovereignActionClass::Trivial
        );
        assert_eq!(
            SovereignActionClass::from_tool_risk(RiskLevel::Modification),
            SovereignActionClass::Reversible
        );
        assert_eq!(
            SovereignActionClass::from_tool_risk(RiskLevel::Destructive),
            SovereignActionClass::Destructive
        );
    }

    #[test]
    fn action_class_wire_shape_is_lower_snake_case() {
        assert_eq!(
            serde_json::to_string(&SovereignActionClass::Sensitive).unwrap(),
            "\"sensitive\""
        );
        assert_eq!(
            serde_json::to_string(&GateRequirement::DeviceOwnerAuthentication).unwrap(),
            r#"{"kind":"device_owner_authentication"}"#
        );
    }
}
