//! Deterministic prompt-suite manifest for F-KV-Direct-Gate.
//!
//! The live MLX runner materializes these prompts with the model tokenizer and
//! emits paired logits/metrics. This file keeps the 100-prompt / 128K / 256-token
//! target canonical without committing a huge prompt corpus to the repo.

use std::path::PathBuf;

use serde::Serialize;

const DEFAULT_OUTPUT: &str = "artifacts/falsifiers/kv_direct_gate/prompt_suite.json";
const SUITE_ID: &str = "qwen3_8b_128k_kv_direct_prompt_suite_v1";
const TARGET_CONTEXT_TOKENS: u64 = 128_000;
const DECODE_TOKENS_PER_PROMPT: u64 = 256;

fn main() {
    let output = std::env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(DEFAULT_OUTPUT));
    let suite = build_suite();

    if let Some(parent) = output.parent() {
        std::fs::create_dir_all(parent).expect("create prompt suite directory");
    }
    let bytes = serde_json::to_vec_pretty(&suite).expect("serialize prompt suite");
    std::fs::write(&output, bytes).expect("write prompt suite");

    println!(
        "KV-Direct prompt suite: prompts={} target_context_tokens={} decode_tokens_per_prompt={} output={}",
        suite.prompts.len(),
        TARGET_CONTEXT_TOKENS,
        DECODE_TOKENS_PER_PROMPT,
        output.display()
    );
}

#[derive(Debug, Serialize)]
struct PromptSuite {
    suite_id: &'static str,
    model_family: &'static str,
    target_context_tokens: u64,
    decode_tokens_per_prompt: u64,
    prompt_count: usize,
    routes: Routes,
    materialization_contract: MaterializationContract,
    prompts: Vec<PromptSpec>,
}

#[derive(Debug, Serialize)]
struct Routes {
    reference: &'static str,
    test: &'static str,
}

#[derive(Debug, Serialize)]
struct MaterializationContract {
    tokenizer: &'static str,
    context_rule: &'static str,
    runner_obligation: &'static str,
}

#[derive(Debug, Serialize)]
struct PromptSpec {
    id: String,
    family: &'static str,
    seed: u64,
    target_context_tokens: u64,
    decode_tokens: u64,
    anchor: String,
    query: String,
    evidence_need: &'static str,
}

fn build_suite() -> PromptSuite {
    let families = [
        ("long_prefix_recall", 0xA1C3_u64),
        ("multi_turn", 0xB2D5_u64),
        ("code_completion", 0xC3E7_u64),
        ("reasoning", 0xD4F9_u64),
    ];
    let mut prompts = Vec::with_capacity(100);
    for (family, base_seed) in families {
        for index in 0..25 {
            let seed = base_seed + index as u64;
            prompts.push(prompt_for(family, index, seed));
        }
    }

    PromptSuite {
        suite_id: SUITE_ID,
        model_family: "Qwen3-8B-MLX-4bit",
        target_context_tokens: TARGET_CONTEXT_TOKENS,
        decode_tokens_per_prompt: DECODE_TOKENS_PER_PROMPT,
        prompt_count: prompts.len(),
        routes: Routes {
            reference: "full_hot_kv_reference",
            test: "kv_direct_ssd_oracle_candidate",
        },
        materialization_contract: MaterializationContract {
            tokenizer: "the resolved Qwen3-8B MLX tokenizer",
            context_rule: "repeat anchor blocks deterministically until the tokenizer reports at least target_context_tokens, then trim on a token boundary",
            runner_obligation: "emit one next-token logit row per prompt for both routes plus RSS, throughput, wall-clock, context, decode, and spill labels",
        },
        prompts,
    }
}

fn prompt_for(family: &'static str, index: usize, seed: u64) -> PromptSpec {
    let id = format!("{family}_{index:03}");
    let anchor = match family {
        "long_prefix_recall" => format!(
            "Ledger shard {index:02} seed {seed}: retain the final checksum, owner, and exception clause across a very long prefix."
        ),
        "multi_turn" => format!(
            "Conversation block {index:02} seed {seed}: alternate project updates, user corrections, and late-binding constraints."
        ),
        "code_completion" => format!(
            "Source bundle {index:02} seed {seed}: a Swift/Rust bridge sketch with hidden invariants, test names, and failure notes."
        ),
        "reasoning" => format!(
            "Reasoning dossier {index:02} seed {seed}: compare two construction paths, retain rejected assumptions, and select the witnessed path."
        ),
        _ => unreachable!("unknown prompt family"),
    };
    let query = match family {
        "long_prefix_recall" => {
            "Return the retained checksum and exception clause only if the witness is internally consistent."
        }
        "multi_turn" => {
            "Resolve the last user correction against the earlier constraint and state the next action."
        }
        "code_completion" => {
            "Complete the bridge function signature and name the invariant that must be tested."
        }
        "reasoning" => {
            "Choose the construction path with the smallest unpaid WBO term and cite the discarded assumption."
        }
        _ => unreachable!("unknown prompt family"),
    };

    PromptSpec {
        id,
        family,
        seed,
        target_context_tokens: TARGET_CONTEXT_TOKENS,
        decode_tokens: DECODE_TOKENS_PER_PROMPT,
        anchor,
        query: query.to_string(),
        evidence_need:
            "next-token logits must match the full-hot-KV reference under the D_KL threshold",
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeMap;

    #[test]
    fn suite_has_required_shape() {
        let suite = build_suite();
        assert_eq!(suite.prompts.len(), 100);
        assert!(suite
            .prompts
            .iter()
            .all(|prompt| prompt.target_context_tokens >= TARGET_CONTEXT_TOKENS));
        assert!(suite
            .prompts
            .iter()
            .all(|prompt| prompt.decode_tokens >= DECODE_TOKENS_PER_PROMPT));

        let mut counts = BTreeMap::<&str, usize>::new();
        for prompt in &suite.prompts {
            *counts.entry(prompt.family).or_default() += 1;
        }
        assert_eq!(counts.get("long_prefix_recall"), Some(&25));
        assert_eq!(counts.get("multi_turn"), Some(&25));
        assert_eq!(counts.get("code_completion"), Some(&25));
        assert_eq!(counts.get("reasoning"), Some(&25));
    }
}
