//! End-to-end tests for the §7 adapter pipeline. Each test
//! seeds a companion via the §6.3 transaction, opens an
//! `.epbox` package, runs the matching applier, asserts the
//! row mutated + the audit ledger captured the diff, then
//! reverts (when reversible) and asserts the row returned to
//! its prior shape.

use std::path::Path;

use crate::adapters::applier::{
    accessory_unlock::AccessoryUnlockApplier,
    palette_unlock::PaletteUnlockApplier,
    prop_unlock::PropUnlockApplier,
    system_prompt_preset::SystemPromptPresetApplier,
    tool_affinity_bundle::ToolAffinityBundleApplier,
    Applier,
};
use crate::adapters::epbox::{
    open_epbox, AppliesTo, EpBoxContent, EpBoxManifest, EpBoxOrigin, EpBoxType,
};
use crate::companions::audit::AuditEventKind;
use crate::companions::registry::CompanionRegistry;
use crate::companions::transaction::create_companion;
use crate::companions::{
    ArmStyle, CompanionSpec, EyeStyle, HeadShape, PropKind, ProviderRole,
    ToolAffinities, ToolKind,
};

fn fixture_companion(registry: &mut CompanionRegistry, vault: &Path, name: &str) -> crate::companions::CompanionId {
    let spec = CompanionSpec {
        name: name.to_string(),
        head_shape: HeadShape::Block,
        palette_ref: "claude_warm_v1".to_string(),
        eyes: EyeStyle::NegativeSpace,
        arms: ArmStyle::None,
        prop: Some(PropKind::Wrench),
        accessory_ref: None,
        role: ProviderRole::CodeWorker,
        base_model: "claude-sonnet-4-6".to_string(),
        system_prompt_preset: "careful_reviewer_v1".to_string(),
        tool_affinities: ToolAffinities::from_prop(PropKind::Wrench),
        vault_path: vault.join("Companions").join(name),
        farm_position: (0.0, 0.0),
    };
    create_companion(registry, spec, vault).unwrap().id
}

fn fixture_manifest(ty: EpBoxType, content: EpBoxContent, applies_to: AppliesTo) -> EpBoxManifest {
    EpBoxManifest {
        epbox_version: "1.0".to_string(),
        id: format!("01J0{}", ty.as_str().to_uppercase().chars().take(20).collect::<String>()),
        r#type: ty,
        title: format!("Test {} box", ty.as_str()),
        applies_to,
        apply_duration_estimate_ms: 50,
        reversible: true,
        license: "CC0-1.0".to_string(),
        origin: "official:epistemos:test".to_string(),
        signature: "deadbeef".to_string(),
        content: Some(content),
    }
}

fn write_epbox(dir: &Path, manifest: &EpBoxManifest) {
    std::fs::create_dir_all(dir).unwrap();
    std::fs::write(
        dir.join("manifest.json"),
        serde_json::to_vec_pretty(manifest).unwrap(),
    )
    .unwrap();
}

#[test]
fn system_prompt_preset_applies_and_reverts() {
    let tmp = tempfile::tempdir().unwrap();
    let vault = tmp.path().join("vault");
    std::fs::create_dir_all(&vault).unwrap();
    let mut registry = CompanionRegistry::open_in_memory().unwrap();
    let id = fixture_companion(&mut registry, &vault, "PromptTester");

    let dir = vault.join("preset.epbox");
    let manifest = fixture_manifest(
        EpBoxType::SystemPromptPreset,
        EpBoxContent::SystemPromptPreset {
            preset_id: "careful_reviewer_v2".to_string(),
            prompt_body: None,
        },
        AppliesTo::default(),
    );
    write_epbox(&dir, &manifest);
    let opened = open_epbox(&dir, &vault).unwrap();

    let applied = SystemPromptPresetApplier::apply(
        &mut registry, id, &opened.manifest, &opened.content,
    ).unwrap();
    let companion = registry.get(id).unwrap().unwrap();
    assert_eq!(companion.system_prompt_preset, "careful_reviewer_v2");
    // Audit row written with the field change.
    let log = registry.audit_log(id).unwrap();
    assert_eq!(log.last().unwrap().event_kind, AuditEventKind::GiftBoxUnwrapped);

    SystemPromptPresetApplier::revert(&mut registry, id, &applied).unwrap();
    let after_revert = registry.get(id).unwrap().unwrap();
    assert_eq!(after_revert.system_prompt_preset, "careful_reviewer_v1");
}

#[test]
fn tool_affinity_bundle_applies_and_reverts() {
    let tmp = tempfile::tempdir().unwrap();
    let vault = tmp.path().join("vault");
    std::fs::create_dir_all(&vault).unwrap();
    let mut registry = CompanionRegistry::open_in_memory().unwrap();
    let id = fixture_companion(&mut registry, &vault, "ToolTester");

    let dir = vault.join("tools.epbox");
    let manifest = fixture_manifest(
        EpBoxType::ToolAffinityBundle,
        EpBoxContent::ToolAffinityBundle {
            enable: vec!["web_search".to_string(), "graph_search".to_string()],
            disable: vec!["test_run".to_string()],
        },
        AppliesTo::default(),
    );
    write_epbox(&dir, &manifest);
    let opened = open_epbox(&dir, &vault).unwrap();

    let prior_companion = registry.get(id).unwrap().unwrap();
    let prior_bits = prior_companion.tool_affinities.bits();
    assert!(prior_companion.tool_affinities.has(ToolKind::TestRun));

    let applied = ToolAffinityBundleApplier::apply(
        &mut registry, id, &opened.manifest, &opened.content,
    ).unwrap();
    let after = registry.get(id).unwrap().unwrap();
    assert!(after.tool_affinities.has(ToolKind::WebSearch));
    assert!(after.tool_affinities.has(ToolKind::GraphSearch));
    assert!(!after.tool_affinities.has(ToolKind::TestRun));

    ToolAffinityBundleApplier::revert(&mut registry, id, &applied).unwrap();
    let after_revert = registry.get(id).unwrap().unwrap();
    assert_eq!(after_revert.tool_affinities.bits(), prior_bits);
}

#[test]
fn prop_unlock_applies_and_reverts() {
    let tmp = tempfile::tempdir().unwrap();
    let vault = tmp.path().join("vault");
    std::fs::create_dir_all(&vault).unwrap();
    let mut registry = CompanionRegistry::open_in_memory().unwrap();
    let id = fixture_companion(&mut registry, &vault, "PropTester");

    let dir = vault.join("prop.epbox");
    let manifest = fixture_manifest(
        EpBoxType::PropUnlock,
        EpBoxContent::PropUnlock {
            prop: "Lantern".to_string(),
            auto_apply: true,
        },
        AppliesTo::default(),
    );
    write_epbox(&dir, &manifest);
    let opened = open_epbox(&dir, &vault).unwrap();

    let applied = PropUnlockApplier::apply(
        &mut registry, id, &opened.manifest, &opened.content,
    ).unwrap();
    let after = registry.get(id).unwrap().unwrap();
    assert_eq!(after.prop, Some(PropKind::Lantern));

    PropUnlockApplier::revert(&mut registry, id, &applied).unwrap();
    let after_revert = registry.get(id).unwrap().unwrap();
    assert_eq!(after_revert.prop, Some(PropKind::Wrench));
}

#[test]
fn accessory_unlock_applies_and_reverts() {
    let tmp = tempfile::tempdir().unwrap();
    let vault = tmp.path().join("vault");
    std::fs::create_dir_all(&vault).unwrap();
    let mut registry = CompanionRegistry::open_in_memory().unwrap();
    let id = fixture_companion(&mut registry, &vault, "AccTester");

    let dir = vault.join("acc.epbox");
    let manifest = fixture_manifest(
        EpBoxType::AccessoryUnlock,
        EpBoxContent::AccessoryUnlock { accessory: "scarf_red_v1".to_string() },
        AppliesTo::default(),
    );
    write_epbox(&dir, &manifest);
    let opened = open_epbox(&dir, &vault).unwrap();

    let applied = AccessoryUnlockApplier::apply(
        &mut registry, id, &opened.manifest, &opened.content,
    ).unwrap();
    let after = registry.get(id).unwrap().unwrap();
    assert_eq!(after.accessory_ref.as_deref(), Some("scarf_red_v1"));

    AccessoryUnlockApplier::revert(&mut registry, id, &applied).unwrap();
    let after_revert = registry.get(id).unwrap().unwrap();
    assert_eq!(after_revert.accessory_ref, None);
}

#[test]
fn palette_unlock_records_audit_only_no_row_mutation() {
    let tmp = tempfile::tempdir().unwrap();
    let vault = tmp.path().join("vault");
    std::fs::create_dir_all(&vault).unwrap();
    let mut registry = CompanionRegistry::open_in_memory().unwrap();
    let id = fixture_companion(&mut registry, &vault, "PaletteTester");

    let dir = vault.join("palette.epbox");
    let manifest = fixture_manifest(
        EpBoxType::PaletteUnlock,
        EpBoxContent::PaletteUnlock { palette_ref: "kimi_indigo_v1".to_string() },
        AppliesTo::default(),
    );
    write_epbox(&dir, &manifest);
    let opened = open_epbox(&dir, &vault).unwrap();

    let prior = registry.get(id).unwrap().unwrap();
    let applied = PaletteUnlockApplier::apply(
        &mut registry, id, &opened.manifest, &opened.content,
    ).unwrap();
    let after = registry.get(id).unwrap().unwrap();
    // Row palette_ref UNCHANGED — unlocks surface in customisation.
    assert_eq!(after.palette_ref, prior.palette_ref);
    // But the audit ledger gained a row.
    let log = registry.audit_log(id).unwrap();
    assert!(log.iter().any(|e| {
        e.event_kind == AuditEventKind::GiftBoxUnwrapped
            && e.payload["epbox_type"] == "palette_unlock"
    }));

    PaletteUnlockApplier::revert(&mut registry, id, &applied).unwrap();
    // Revert adds another audit row but doesn't mutate the column.
}

#[test]
fn applies_to_mismatch_rejects_apply() {
    let tmp = tempfile::tempdir().unwrap();
    let vault = tmp.path().join("vault");
    std::fs::create_dir_all(&vault).unwrap();
    let mut registry = CompanionRegistry::open_in_memory().unwrap();
    let id = fixture_companion(&mut registry, &vault, "MismatchTester");
    // Companion is CodeWorker / claude-sonnet-4-6; manifest restricts to Helper.
    let dir = vault.join("mismatch.epbox");
    let manifest = fixture_manifest(
        EpBoxType::AccessoryUnlock,
        EpBoxContent::AccessoryUnlock { accessory: "x".to_string() },
        AppliesTo {
            role: vec!["Helper".to_string()],
            models: vec![],
        },
    );
    write_epbox(&dir, &manifest);
    let opened = open_epbox(&dir, &vault).unwrap();
    let err = AccessoryUnlockApplier::apply(
        &mut registry, id, &opened.manifest, &opened.content,
    ).unwrap_err();
    assert!(matches!(
        err,
        crate::adapters::ApplierError::AppliesToMismatch { .. }
    ));
    // The row wasn't touched.
    let after = registry.get(id).unwrap().unwrap();
    assert_eq!(after.accessory_ref, None);
}

#[test]
fn type_mismatch_between_applier_and_manifest_rejects() {
    let tmp = tempfile::tempdir().unwrap();
    let vault = tmp.path().join("vault");
    std::fs::create_dir_all(&vault).unwrap();
    let mut registry = CompanionRegistry::open_in_memory().unwrap();
    let id = fixture_companion(&mut registry, &vault, "TypeMismatchTester");
    let dir = vault.join("typemismatch.epbox");
    let manifest = fixture_manifest(
        EpBoxType::PaletteUnlock,
        EpBoxContent::PaletteUnlock { palette_ref: "claude_warm_v1".to_string() },
        AppliesTo::default(),
    );
    write_epbox(&dir, &manifest);
    let opened = open_epbox(&dir, &vault).unwrap();
    // Run the wrong applier — must reject.
    let err = AccessoryUnlockApplier::apply(
        &mut registry, id, &opened.manifest, &opened.content,
    ).unwrap_err();
    assert!(matches!(
        err,
        crate::adapters::ApplierError::TypeMismatch { .. }
    ));
}

#[test]
fn epbox_origin_classification_round_trip() {
    // Sanity belt-and-braces — exercise the parser from this
    // crate's tests too (epbox.rs has its own coverage but
    // crossing the module boundary catches re-export drift).
    for raw in [
        "official:epistemos:starter-pack-v1",
        "community:hf:user/cool-skill",
        "user:local:my-finetune-2026",
    ] {
        let parsed = EpBoxOrigin::parse(raw).expect(raw);
        assert_eq!(parsed.raw(), raw);
    }
    assert!(EpBoxOrigin::parse("rando:bad").is_none());
}
