//! Phase 2F-N — per-tool static catalog modules.
//!
//! Each submodule here ships an `AdapterSpec` constant + an
//! `input_schema()` function returning a `&'static Value`. The
//! `ToolRegistry::build_v2_catalog()` factory in `registry.rs`
//! pairs each spec with a freshly-constructed handler instance
//! to produce `Box<dyn Tool>` values that drive the new §3.1
//! Tool-trait surface.
//!
//! Naming uses plan-canonical dotted form (`vault.search`,
//! `vault.read`, etc.) per §3.5 / §6.7. The legacy underscored
//! names (`vault_search`) remain addressable via
//! `ToolRegistry::execute()` until Phase 2G.

pub mod vault_read;
pub mod vault_search;
pub mod vault_write;
pub mod workspace_search;

#[cfg(test)]
mod tests {
    use crate::grammar::{build_dispatch_grammar, schema_to_llg};
    use serde_json::Value;

    #[test]
    fn every_catalog_spec_compiles_via_grammar_compiler() {
        // Plan §17.3 sampler-bound dispatch invariant: every tool's
        // input schema must compile via the grammar compiler so the
        // sampler can mask invalid tokens at decode time.
        let specs = [
            super::vault_search::SPEC,
            super::vault_read::SPEC,
            super::vault_write::SPEC,
            super::workspace_search::SPEC,
        ];
        for spec in specs {
            let s = (spec.input_schema)();
            schema_to_llg(s).unwrap_or_else(|e| {
                panic!(
                    "tool {} input schema failed grammar compile: {:?}",
                    spec.name, e
                )
            });
        }
    }

    #[test]
    fn dispatch_grammar_over_full_v2_catalog_compiles() {
        // §17.3: a single dispatch grammar over the entire v2 catalog
        // must compile. Phase 3 router will use exactly this shape.
        let pairs: Vec<(&str, &Value)> = vec![
            (
                super::vault_search::SPEC.name,
                (super::vault_search::SPEC.input_schema)(),
            ),
            (
                super::vault_read::SPEC.name,
                (super::vault_read::SPEC.input_schema)(),
            ),
            (
                super::vault_write::SPEC.name,
                (super::vault_write::SPEC.input_schema)(),
            ),
            (
                super::workspace_search::SPEC.name,
                (super::workspace_search::SPEC.input_schema)(),
            ),
        ];
        build_dispatch_grammar(&pairs).expect("v2 dispatch grammar must compile");
    }

    #[test]
    fn catalog_uses_dotted_names_per_plan_canon() {
        // Plan §3.5 / §6.7 use dotted tool names. Confirm v2_catalog
        // adopts this everywhere (legacy underscored names remain
        // addressable via the legacy ToolRegistry::execute path).
        for spec in [
            super::vault_search::SPEC,
            super::vault_read::SPEC,
            super::vault_write::SPEC,
            super::workspace_search::SPEC,
        ] {
            assert!(
                spec.name.contains('.'),
                "v2 catalog tool {} must use plan-canonical dotted naming",
                spec.name
            );
        }
    }
}
