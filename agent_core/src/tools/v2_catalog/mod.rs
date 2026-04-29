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

pub mod action_bash;
pub mod action_terminal;
pub mod chunk_reduce;
pub mod file_patch;
pub mod file_read;
pub mod file_search;
pub mod file_write;
pub mod graph_neighbors;
pub mod knowledge_contradiction;
pub mod knowledge_neural_recall;
pub mod knowledge_recall;
pub mod system_cron;
pub mod system_todo;
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
            super::graph_neighbors::SPEC,
            super::chunk_reduce::SPEC,
            super::action_bash::SPEC,
            super::file_read::SPEC,
            super::file_write::SPEC,
            super::file_search::SPEC,
            super::file_patch::SPEC,
            super::knowledge_recall::SPEC,
            super::knowledge_contradiction::SPEC,
            super::knowledge_neural_recall::SPEC,
            super::system_todo::SPEC,
            super::system_cron::SPEC,
            super::action_terminal::SPEC,
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
            (
                super::graph_neighbors::SPEC.name,
                (super::graph_neighbors::SPEC.input_schema)(),
            ),
            (
                super::chunk_reduce::SPEC.name,
                (super::chunk_reduce::SPEC.input_schema)(),
            ),
            (
                super::action_bash::SPEC.name,
                (super::action_bash::SPEC.input_schema)(),
            ),
            (
                super::file_read::SPEC.name,
                (super::file_read::SPEC.input_schema)(),
            ),
            (
                super::file_write::SPEC.name,
                (super::file_write::SPEC.input_schema)(),
            ),
            (
                super::file_search::SPEC.name,
                (super::file_search::SPEC.input_schema)(),
            ),
            (
                super::file_patch::SPEC.name,
                (super::file_patch::SPEC.input_schema)(),
            ),
            (
                super::knowledge_recall::SPEC.name,
                (super::knowledge_recall::SPEC.input_schema)(),
            ),
            (
                super::knowledge_contradiction::SPEC.name,
                (super::knowledge_contradiction::SPEC.input_schema)(),
            ),
            (
                super::knowledge_neural_recall::SPEC.name,
                (super::knowledge_neural_recall::SPEC.input_schema)(),
            ),
            (
                super::system_todo::SPEC.name,
                (super::system_todo::SPEC.input_schema)(),
            ),
            (
                super::system_cron::SPEC.name,
                (super::system_cron::SPEC.input_schema)(),
            ),
            (
                super::action_terminal::SPEC.name,
                (super::action_terminal::SPEC.input_schema)(),
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
            super::graph_neighbors::SPEC,
            super::chunk_reduce::SPEC,
            super::action_bash::SPEC,
            super::file_read::SPEC,
            super::file_write::SPEC,
            super::file_search::SPEC,
            super::file_patch::SPEC,
            super::knowledge_recall::SPEC,
            super::knowledge_contradiction::SPEC,
            super::knowledge_neural_recall::SPEC,
            super::system_todo::SPEC,
            super::system_cron::SPEC,
            super::action_terminal::SPEC,
        ] {
            assert!(
                spec.name.contains('.'),
                "v2 catalog tool {} must use plan-canonical dotted naming",
                spec.name
            );
        }
    }

    #[test]
    fn pro_only_tools_are_marked_pro_only() {
        // Plan §1.6: action.* tools are Pro-only and never ship in the
        // App Store dispatch grammar. This invariant lives at the SPEC
        // level — Phase 3+ dispatch construction filters by profile.
        use crate::tools::Profile;
        assert_eq!(
            super::action_bash::SPEC.profile,
            Profile::ProOnly,
            "action.bash must be Pro-only per §1.6 / §17"
        );
        assert_eq!(
            super::action_terminal::SPEC.profile,
            Profile::ProOnly,
            "action.terminal must be Pro-only per §1.6 / §17"
        );
        // small_model_safe = false for Pro-only destructive tools so the
        // 1.5B router never reaches for the shell.
        assert!(!super::action_bash::SPEC.small_model_safe);
        assert!(!super::action_terminal::SPEC.small_model_safe);
    }
}
