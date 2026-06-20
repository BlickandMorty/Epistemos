//! ModelCapabilityProfile — the single, data-driven per-model profile (SS-AB).
//!
//! SS-Z found per-model config "badly scattered + partly outdated" across two
//! disconnected universes (the MLX `LocalTextModelID` ladders + the GGUF
//! `GemmaQATRuntimeCandidate` struct which carries ZERO inference config), with
//! "no single per-model profile anywhere" — the SS-W chat-template crash and the
//! hardcoded GGUF 4096 context window both fall straight out of that gap.
//!
//! This module is the MAS-safe (non-`pro-build`) floor: one resolver every lane
//! can read — GGUF (Pro subprocess) resolves its `--ctx-size` / stop tokens /
//! chat template from here instead of hardcoding them; the Swift picker reads the
//! `picker_use_case` copy. Pure data + resolution, no subprocess, no network →
//! `cargo test --lib` covers it. Per-model VALUES are sourced from SS-AB's
//! definitive table (ctx caps honor the 16 GB KV-cache budget).

/// The chat/prompt format a model speaks. Carries the per-model stop tokens
/// (SS-AB: "[Ollama] per-model stop tokens — MISSING today on GGUF") and the
/// llama.cpp builtin `--chat-template` name used to make the SS-W
/// `common_chat_templates_apply` crash structurally unreachable for the GGUF lane.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PromptDialect {
    /// `<|im_end|>`-terminated ChatML (Qwen, Hermes, LFM2, most OSS instruct).
    Chatml,
    /// Meta Llama 3 (`<|eot_id|>`).
    Llama3,
    /// Google Gemma (`<end_of_turn>`).
    Gemma,
    /// Mistral / Devstral (`</s>`).
    Mistral,
    /// Microsoft Phi (`<|end|>`).
    Phi,
    /// IBM Granite.
    Granite,
    /// Reasoning-only models with no chat/tool framing (VibeThinker, R1-Distill).
    None,
}

impl PromptDialect {
    /// The per-model stop strings llama-cli should halt on (beyond the model's
    /// own EOG token). Empty for reasoning-only models.
    pub fn stop_tokens(self) -> &'static [&'static str] {
        match self {
            PromptDialect::Chatml => &["<|im_end|>", "<|endoftext|>"],
            PromptDialect::Llama3 => &["<|eot_id|>", "<|end_of_text|>"],
            PromptDialect::Gemma => &["<end_of_turn>", "<eos>"],
            PromptDialect::Mistral => &["</s>"],
            PromptDialect::Phi => &["<|end|>", "<|endoftext|>"],
            PromptDialect::Granite => &["<|end_of_text|>"],
            PromptDialect::None => &[],
        }
    }

    /// The llama.cpp builtin `--chat-template` name for this dialect, or `None`
    /// for reasoning-only models (which use the embedded/plain template). Used by
    /// the GGUF lane to OVERRIDE a broken embedded template (SS-W).
    pub fn llama_cpp_template_name(self) -> Option<&'static str> {
        match self {
            PromptDialect::Chatml => Some("chatml"),
            PromptDialect::Llama3 => Some("llama3"),
            PromptDialect::Gemma => Some("gemma"),
            PromptDialect::Mistral => Some("mistral"),
            PromptDialect::Phi => Some("phi3"),
            PromptDialect::Granite => Some("granite"),
            PromptDialect::None => None,
        }
    }
}

/// Which runtime lane serves the model (SS-AB).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ModelLane {
    /// MAS-safe in-process MLX (Apple Silicon).
    Mlx,
    /// Pro-only GGUF llama.cpp subprocess.
    Gguf,
    /// Experimental / research lane (honest, not advertised as production).
    Research,
}

/// The capability tier the foundation lineup advertises (Fast / Think / Code).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CapabilityTier {
    Fast,
    Think,
    Code,
}

/// The single per-model capability profile (SS-AB). `'static` so the canonical
/// table is zero-allocation const data; the resolver returns owned copies.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ModelCapabilityProfile {
    pub id: &'static str,
    pub display_name: &'static str,
    /// Effective context window (SS-AB caps the 16 GB KV-cache budget — e.g.
    /// Qwen3's 256K is capped to ~32K). Replaces the GGUF hardcoded 4096.
    pub context_window: u32,
    pub max_output_tokens: u32,
    pub prompt_dialect: PromptDialect,
    pub lane: ModelLane,
    pub tier: CapabilityTier,
    /// SHORT use-case line shown on the model picker (≤ ~60 chars, SS-AB).
    pub picker_use_case: &'static str,
    /// Whether this is one of the advertised "best" models (all remain
    /// installable; advertised ones are surfaced prominently).
    pub advertised: bool,
}

impl ModelCapabilityProfile {
    /// The per-model stop tokens (delegated to the dialect).
    pub fn stop_tokens(&self) -> &'static [&'static str] {
        self.prompt_dialect.stop_tokens()
    }

    /// The llama.cpp builtin chat-template name for the GGUF lane (None for
    /// reasoning-only models).
    pub fn llama_cpp_template_name(&self) -> Option<&'static str> {
        self.prompt_dialect.llama_cpp_template_name()
    }
}

/// The canonical profile set (SS-AB's definitive table). Honest + real — no fake
/// descriptions. `profile_for` family-matches an id against these.
pub const CANON: &[ModelCapabilityProfile] = &[
    ModelCapabilityProfile {
        id: "gemma-4-e2b",
        display_name: "Gemma 4 E2B",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Gemma,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Fastest on-device · everyday chat",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "gemma-4-e4b",
        display_name: "Gemma 4 E4B",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Gemma,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Fast on-device · 128K context",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "gemma-4-12b-qat",
        display_name: "Gemma 4 12B QAT",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Gemma,
        lane: ModelLane::Gguf,
        tier: CapabilityTier::Code,
        picker_use_case: "Strongest local coder (Pro)",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "qwen3-4b",
        display_name: "Qwen3 4B",
        context_window: 32_768,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Chatml,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Best all-round · strong tools + reasoning",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "qwen3-1.7b",
        display_name: "Qwen3 1.7B",
        context_window: 32_768,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Chatml,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Quick all-round · low RAM",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "vibethinker-1.5b",
        display_name: "VibeThinker-1.5B",
        context_window: 32_768,
        max_output_tokens: 8192,
        prompt_dialect: PromptDialect::None,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Think,
        picker_use_case: "Tiny math/logic reasoning",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "deepseek-r1-distill-1.5b",
        display_name: "DeepSeek-R1-Distill-1.5B",
        context_window: 32_768,
        max_output_tokens: 8192,
        prompt_dialect: PromptDialect::None,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Think,
        picker_use_case: "General step-by-step reasoning",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "smollm3-3b",
        display_name: "SmolLM3-3B",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Chatml,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Think,
        picker_use_case: "Open reasoning + tools, 128K",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "lfm2.5-1.2b",
        display_name: "LFM2.5-1.2B",
        context_window: 32_768,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Chatml,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Ultra-fast on-device tool-caller",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "phi-4-mini",
        display_name: "Phi-4-mini 3.8B",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Phi,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Think,
        picker_use_case: "128K reasoning + function-calling",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "granite-4-nano-1b",
        display_name: "Granite 4 Nano 1B",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Granite,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Enterprise-clean tool/RAG model",
        advertised: false,
    },
];

/// A conservative default for an id that matches no canonical family — honest
/// "unknown local model" config (a safe small context, ChatML, not advertised).
pub const DEFAULT_PROFILE: ModelCapabilityProfile = ModelCapabilityProfile {
    id: "unknown",
    display_name: "Local model",
    context_window: 8192,
    max_output_tokens: 4096,
    prompt_dialect: PromptDialect::Chatml,
    lane: ModelLane::Mlx,
    tier: CapabilityTier::Fast,
    picker_use_case: "Local model",
    advertised: false,
};

/// Resolve a model id/path/slug to its capability profile by family (best-effort
/// substring match, order-sensitive so e.g. a DeepSeek-R1-Distill-Qwen id maps to
/// the reasoning profile, not Qwen). Returns [`DEFAULT_PROFILE`] for unknowns —
/// NEVER a panic, NEVER an empty/fake profile (no-fake).
pub fn profile_for(model_id: &str) -> ModelCapabilityProfile {
    let id = model_id.to_lowercase();
    // Reasoning-only families first (their ids often also contain a base-model
    // name like "qwen" — match the reasoning identity, not the base).
    if id.contains("vibethinker") {
        return *find("vibethinker-1.5b");
    }
    if id.contains("deepseek") && (id.contains("distill") || id.contains("r1")) {
        return *find("deepseek-r1-distill-1.5b");
    }
    if id.contains("gemma") {
        // 12B (the GGUF coder) vs the small E2B/E4B MLX models.
        if id.contains("12b") || id.contains("27b") {
            return *find("gemma-4-12b-qat");
        }
        if id.contains("e4b") || id.contains("4b") {
            return *find("gemma-4-e4b");
        }
        return *find("gemma-4-e2b");
    }
    if id.contains("qwen") || id.contains("qwopus") {
        if id.contains("1.7b") || id.contains("1_7b") || id.contains("1.5b") {
            return *find("qwen3-1.7b");
        }
        return *find("qwen3-4b");
    }
    if id.contains("smollm3") || id.contains("smollm-3") {
        return *find("smollm3-3b");
    }
    if id.contains("lfm") || id.contains("liquid") {
        return *find("lfm2.5-1.2b");
    }
    if id.contains("phi") {
        return *find("phi-4-mini");
    }
    if id.contains("granite") {
        return *find("granite-4-nano-1b");
    }
    DEFAULT_PROFILE
}

/// Look up a canonical profile by exact id (used internally by [`profile_for`]).
/// Returns a reference into [`CANON`]; falls back to [`DEFAULT_PROFILE`].
fn find(id: &str) -> &'static ModelCapabilityProfile {
    CANON.iter().find(|p| p.id == id).unwrap_or(&DEFAULT_PROFILE)
}

/// The advertised "best" models, in canonical order (for the picker's
/// advertise-stack).
pub fn advertised() -> impl Iterator<Item = &'static ModelCapabilityProfile> {
    CANON.iter().filter(|p| p.advertised)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_canon_profile_is_honest_and_complete() {
        for p in CANON {
            assert!(!p.id.is_empty());
            assert!(!p.display_name.is_empty());
            // No fake/empty picker copy; honest + within the ~60-char picker budget.
            assert!(!p.picker_use_case.is_empty(), "empty picker copy for {}", p.id);
            assert!(
                p.picker_use_case.chars().count() <= 60,
                "picker copy too long for {}: {:?}",
                p.id,
                p.picker_use_case
            );
            // A real context window — NEVER the hardcoded-4096 GGUF bug.
            assert!(p.context_window >= 8192, "ctx too small for {}", p.id);
            assert!(p.max_output_tokens > 0);
        }
    }

    #[test]
    fn gguf_models_resolve_a_chat_template_so_ss_w_is_unreachable() {
        // Every dialect-bearing model exposes a llama.cpp builtin template name,
        // so the GGUF lane can always override a broken embedded template (SS-W).
        let gemma = profile_for("gemma-4-12b-qat-gguf");
        assert_eq!(gemma.llama_cpp_template_name(), Some("gemma"));
        assert!(gemma.stop_tokens().contains(&"<end_of_turn>"));

        let qwen = profile_for("Qwen3-4B-MLX");
        assert_eq!(qwen.llama_cpp_template_name(), Some("chatml"));
        assert!(qwen.stop_tokens().contains(&"<|im_end|>"));
    }

    #[test]
    fn deepseek_r1_distill_qwen_resolves_to_reasoning_not_qwen() {
        // The id contains "qwen" but it is a DeepSeek-R1 reasoning model — the
        // reasoning identity must win (mirrors the SS-W/logo deepseek-before-qwen
        // ordering bug class).
        let p = profile_for("DeepSeek-R1-Distill-Qwen-1.5B");
        assert_eq!(p.tier, CapabilityTier::Think);
        assert_eq!(p.prompt_dialect, PromptDialect::None);
        assert!(p.stop_tokens().is_empty());
    }

    #[test]
    fn context_windows_honor_the_16gb_budget() {
        // Qwen capped to ~32K (not its native 256K) for the KV-cache budget;
        // Gemma keeps its 128K.
        assert_eq!(profile_for("qwen3-4b").context_window, 32_768);
        assert_eq!(profile_for("gemma-4-e2b-it").context_window, 128_000);
    }

    #[test]
    fn unknown_model_gets_an_honest_default_never_a_panic() {
        let p = profile_for("some-brand-new-model-v9");
        assert_eq!(p.id, "unknown");
        assert!(!p.advertised);
        assert!(p.context_window >= 8192);
    }

    #[test]
    fn advertised_set_is_the_best_models() {
        let names: Vec<_> = advertised().map(|p| p.display_name).collect();
        assert!(names.contains(&"Gemma 4 E2B"));
        assert!(names.contains(&"Qwen3 4B"));
        assert!(names.contains(&"VibeThinker-1.5B"));
        // A non-advertised one is excluded.
        assert!(!names.contains(&"Granite 4 Nano 1B"));
    }
}
