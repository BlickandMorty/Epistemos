//! B.1 self-evolution boundary.
//!
//! This module consumes repeated successful procedure outcomes and turns them
//! into reviewable skill proposals. Promotion remains a separate Sovereign
//! Gate/UI step.

use std::collections::{HashMap, HashSet};

use super::procedural_memory::ProcedureOutcomeRecord;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SkillProposalDraft {
    pub name: String,
    pub rationale: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SkillEvolutionCandidate {
    pub proposal: SkillProposalDraft,
    pub steps_taken: Vec<String>,
    pub repetitions: usize,
    pub source_skill_names: Vec<String>,
}

pub fn propose_repeated_success_skill(
    records: &[ProcedureOutcomeRecord],
    min_repetitions: usize,
) -> Option<SkillEvolutionCandidate> {
    if min_repetitions == 0 {
        return None;
    }

    let mut grouped: HashMap<Vec<String>, RepetitionStats> = HashMap::new();
    for record in records.iter().filter(|record| record.succeeded) {
        if record.steps_taken.is_empty() {
            continue;
        }
        let entry = grouped.entry(record.steps_taken.clone()).or_default();
        entry.repetitions += 1;
        entry.last_seen = entry.last_seen.max(record.occurred_at_unix_seconds);
        entry.source_skill_names.insert(record.skill_name.clone());
    }

    grouped
        .into_iter()
        .filter(|(_, stats)| stats.repetitions >= min_repetitions)
        .max_by(|(_, a), (_, b)| {
            a.repetitions
                .cmp(&b.repetitions)
                .then_with(|| a.last_seen.cmp(&b.last_seen))
        })
        .map(|(steps_taken, stats)| {
            let mut source_skill_names: Vec<String> =
                stats.source_skill_names.into_iter().collect();
            source_skill_names.sort();
            let name = learned_skill_name(&steps_taken);
            SkillEvolutionCandidate {
                proposal: SkillProposalDraft {
                    name,
                    rationale: format!(
                        "Detected {} successful repetitions of the same {}-step tool sequence.",
                        stats.repetitions,
                        steps_taken.len()
                    ),
                },
                steps_taken,
                repetitions: stats.repetitions,
                source_skill_names,
            }
        })
}

#[derive(Default)]
struct RepetitionStats {
    repetitions: usize,
    last_seen: i64,
    source_skill_names: HashSet<String>,
}

fn learned_skill_name(steps: &[String]) -> String {
    let slug = steps
        .join("-")
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() {
                character.to_ascii_lowercase()
            } else {
                '-'
            }
        })
        .collect::<String>()
        .split('-')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join("-");

    if slug.is_empty() {
        "learned-skill".to_string()
    } else {
        format!("learned-{slug}")
    }
}
