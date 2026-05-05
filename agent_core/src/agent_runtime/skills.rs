//! B.1 skills consolidation boundary.
//!
//! The legacy skill router, registry store, and tool facade still live in their
//! original files while the migration stays behavior-preserving. New runtime
//! call sites route through this module so `agent_core::hermes::skills` becomes
//! the canonical ownership point before the larger file move.

use std::path::PathBuf;

pub use crate::skill_router::{SkillEntry, SkillMatch, SkillRouter};
pub use crate::storage::skills_registry::{SkillRegistryEntry, SkillsRegistryStore};
pub use crate::tools::skills::{
    skill_manage_schema, skill_view_schema, skills_list_schema, skills_tool_schema,
    SkillManageHandler, SkillViewHandler, SkillsListHandler, SkillsStore, SkillsTool,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SkillInvocationDraft {
    pub name: String,
    pub expected_outcome: String,
}

pub fn default_skills_dir() -> PathBuf {
    crate::tools::skills::default_skills_dir()
}
