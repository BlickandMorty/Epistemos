# BUILDER SESSION PROMPT — Quick Capture

Copy everything between the `=====` lines below into a fresh Claude Code terminal session. The prompt is self-contained: it points the agent at the canonical plan, names the non-negotiable invariants inline so the agent cannot freelance them, and tells the agent exactly which phase to start with.

The agent **must not guess**. Anything not specified here is in `docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md`. The agent reads the plan in full before writing any code.

---

```
====================================================================
You are the building agent for Epistemos Quick Capture. Your job is to
implement the plan at docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md exactly,
phase by phase, without freelancing.

This prompt names the load-bearing constraints so you cannot lose them
to a context-window compaction. The full normative reference is the plan
file; this prompt is the launchpad.

──────────────────────────────────────────────────────────────────────
PHASE 0 — DO THIS BEFORE WRITING ANY CODE
──────────────────────────────────────────────────────────────────────

1. Read the plan in full:
     docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md
   It is ~32k words across 26 sections (§0–§25). Read every section.
   Do not skim. The plan absorbs five rounds of research; if anything
   you remember from training disagrees with the plan, the plan wins.

2. Read the project rules:
     CLAUDE.md  (in repo root)

3. Read the auto-memory:
     ~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/MEMORY.md
   Plus every linked memory file (user profile, hardware, feedback).

4. Read these supporting docs, in order:
     docs/AGENT_PROGRESS.md           — current state of the agent system
     docs/agent-system/AGENT_ARCHITECTURE.md
     docs/EPISTEMOS_FUSED_v3.md       — master spec
     docs/HERMES_INTEGRATION_RESEARCH.md
     docs/INSTANT_RECALL_ARCHITECTURE.md
     docs/APP_ISSUES_AUTO_FIX.md      — fix opportunistically while you work

5. Run a web search before every phase. The plan §0.1 lists exact
   queries per phase. Use them verbatim. Do not skip.

6. After Phase 0 completes, message back with:
   - One paragraph confirming you've read the plan (cite the section
     count and the four-action enum to prove you read §4).
   - Your understanding of which phase you're about to enter.
   - Any contradictions you found between research and the plan
     (do not silently diverge).

──────────────────────────────────────────────────────────────────────
NON-NEGOTIABLE INVARIANTS — DO NOT VIOLATE
──────────────────────────────────────────────────────────────────────

A. LOCAL-FIRST IS THE HARD DEFAULT (§1.3, §1.4)
   - Cloud is reachable ONLY via /cloud command, ⌥-submit, or the
     narrow auto-escalation in §6.7.
   - "Cloud allowed" Setting is tri-state: Off | Generator only |
     Inference + Generator. Default is "Generator only".
   - No external services. No Vercel, no SaaS telemetry, no localhost
     web servers, no auto-MCP-bridges.
   - No subprocess inference. MLX-Swift is in-process. The Hermes
     Python subprocess (Pro profile) is for orchestration ONLY,
     never for inference.

B. NO-LLM-FIRST WITHIN LOCAL (§1.4)
   - Every variant ladder MUST start with a deterministic non-LLM
     variant. LLMs are the LAST local resort, not the first. Code
     review rejects tools that have an LLM as variant A unless the
     author proves no deterministic predecessor exists.

C. THE FOUR-ACTION ROUTING ENUM (§4.1)
   place | merge_into_existing_note | create_folder | defer
   - merge requires confidence ≥ 0.90 AND target note's last-edited
     time > 24h.
   - create_folder requires (a) genuinely new concept (no existing
     concept node within cosine 0.92), (b) ≥3 neighbour notes
     clustered tightly (cosine ≥0.8), (c) no existing parent fits.
   - defer is the highest-trust path, not failure.

D. ROUTING THRESHOLDS (§4.3, §4.4, §4.5)
   - Variant A (centroid embedding):  ≥ 0.85
   - Variant B (GBNF classification):  ≥ 0.75
   - Variant C (concept-anchored):     ≥ 0.70
   - Below all three → DEFER.
   These are FLOORS, not guides.

E. THREE LOAD-BEARING DECODE MECHANISMS (§22.1)
   All three ship in Phase 6, all three are active by default on every
   reasoning-bearing tool:
   - Grammar-Aligned Decoding (§22.1.1): mask-and-rescore preserves
     probability distribution shape over the valid subset.
   - CRANE (§22.1.2): unconstrained reasoning region + constrained
     committal region, separated by sentinel tokens (<think>...</think>).
     Reasoning quality preserved while output stays structurally bound.
   - IterGen (§22.1.3): on schema violation, BACKTRACK to the most
     recent grammar-symbol boundary, RESTORE the KV-cache snapshot,
     INJECT a small repair hint, RESUME generation. Edit only the
     failing span — do NOT regenerate the whole output. The prior
     tokens are not re-read; they live in the restored KV-cache.

F. COMPILE-VERIFY-MINT FOR EVERY GENERATED SKILL (§17.2)
   No skill ships without passing all four gates:
   G1: cargo check + cargo clippy + slot-spec must_not_call static check
   G2: LLM semantic intent classification (description vs implementation)
   G3: sandbox dyn-link execution against test fixture in subprocess
   G4: permission manifest validation (must_not_call enforced at runtime)
   Maximum 3 revisions before tombstone. No exceptions.

G. SAMPLER-BOUND TOOL DISPATCH (§17)
   The grammar IS the dispatch table. The model literally cannot emit a
   syntactically invalid call because MLX-Structured zeros out invalid
   tokens at decode time. There is no "tool selection prompt", no
   "JSON parse and pray", no string regex post-hoc.

H. VERBATIM RETENTION INVARIANT (§24.2, §25.3)
   The user's captured words are NEVER rewritten in place. Summaries,
   extractions, abstractions are DERIVED ARTIFACTS stored alongside
   with provenance pointers back to the verbatim drawer (sha256-keyed).
   "The model summarized over my words" is structurally impossible.

I. COMMIT CADENCE (§0.4 + memory rule)
   Commit after EVERY phase passes verification. NEVER batch.
   The user has lost work to git checkout. This rule is load-bearing.

J. ZERO TEST REGRESSIONS
   The 2,679-test suite must stay green. Run swift test + cargo test
   after every phase before committing.

K. NEVER edit .xcodeproj directly — use xcodegen.
   NEVER commit model files (.gguf, .safetensors, .mlx).
   NEVER use try!, force-unwraps, or print() in production paths.
   NEVER strip thinking blocks from message history when stop_reason
   is "tool_use" — pass the entire content array back including
   thinking blocks + signatures.

──────────────────────────────────────────────────────────────────────
THE EXISTING CODEBASE — LEVERAGE, DO NOT REBUILD
──────────────────────────────────────────────────────────────────────

§25 of the plan inventories what already exists. Most of the substrate
is built. You are EXTENDING, not rewriting:

  agent_core/src/storage/vault.rs            — VaultStore (rusqlite + Tantivy)
  agent_core/src/storage/memory_classifier.rs — VaultFact + MemoryOperation
  agent_core/src/storage/session_graph.rs    — typed nodes/edges (Mem0-shaped)
  agent_core/src/vault_registry.rs           — multi-vault identity
  agent_core/src/skill_router.rs             — TF-IDF skill matching
  agent_core/src/context_loader.rs           — 5-tier injection (Letta-shaped)
  agent_core/src/tools/registry.rs           — 33 tools, ToolTier + RiskLevel
  agent_core/src/agent_loop.rs               — AgentSession + run_scaffold_turn
  Epistemos/LocalAgent/HermesPromptBuilder.swift  — Hermes XML format
  Epistemos/LocalAgent/LocalToolGrammar.swift     — Swift tool grammar
  Epistemos/Engine/MLXInferenceService.swift      — MLX integration
  epistemos-core/uniffi/epistemos_core.udl        — UDL surface
  epistemos-core/src/uniffi_exports.rs            — Rust→Swift glue

Cargo deps already present: uniffi 0.28, tantivy 0.22, rusqlite 0.32,
tracing 0.1, tokio 1.43 (full features), serde, uuid, chrono, regex,
sha2, rayon.

Cargo deps missing (you must add per phase): llguidance, schemars,
jsonschema, proptest, zeroize.

──────────────────────────────────────────────────────────────────────
LOAD-BEARING CODE SNIPPETS (REFERENCE — do not invent your own)
──────────────────────────────────────────────────────────────────────

The Tool trait (§3.1):

  pub trait Tool: Send + Sync {
      fn name(&self) -> &'static str;
      fn input_schema(&self) -> &'static serde_json::Value;
      fn output_schema(&self) -> &'static serde_json::Value;
      fn variants(&self) -> &[VariantId];
      fn profile(&self) -> Profile;
      fn small_model_safe(&self) -> bool;
      async fn invoke(&self, ctx: &ToolCtx, variant: VariantId, input: Value)
          -> ToolResult;
  }

  pub struct ToolMeta {
      pub status: Status,           // Ok | Empty | Partial | Error
      pub variant_used: VariantId,
      pub latency_ms: u32,
      pub confidence: Option<f32>,
      pub schema_version: u32,
      pub power_state: Option<PowerState>,
  }

  pub struct ToolResult {
      pub meta: ToolMeta,
      pub result: serde_json::Value,    // schema-validated; field name is `result`
  }

The variant runner with HealthCheck + cache (§3.2):

  pub async fn run_with_variants(tool: &dyn Tool, ctx: &ToolCtx, input: Value)
      -> ToolResult
  {
      if let Some(cached) = ctx.cache.get(tool.name(), &input).await {
          return cached;
      }
      let mut last_err = None;
      for &variant in tool.variants() {
          if !ctx.health.is_available(tool.name(), variant).await {
              ctx.tracer.record_skip(tool.name(), variant, "unavailable");
              continue;
          }
          let attempt_ctx = ctx.with_variant(variant);
          let result = match tokio::time::timeout(
              ctx.latency_budget_per_variant(),
              tool.invoke(&attempt_ctx, variant, input.clone()),
          ).await {
              Ok(r) => r,
              Err(_) => ToolResult::error(variant, "timeout"),
          };
          if let Err(e) = ctx.validator.validate(tool.output_schema(), &result.result) {
              ctx.tracer.record_schema_violation(tool.name(), variant, &e);
              last_err = Some(e.to_string());
              continue;
          }
          match result.meta.status {
              Status::Ok => {
                  ctx.cache.put(tool.name(), &input, &result).await;
                  return result;
              }
              Status::Partial if result.meta.confidence.unwrap_or(0.0) > 0.7 => {
                  ctx.cache.put(tool.name(), &input, &result).await;
                  return result;
              }
              _ => continue,
          }
      }
      ToolResult::error_with_context(VariantId::Last, last_err.unwrap_or_default())
  }

The MemType enum (§24.3 + §25.4):

  #[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug)]
  #[repr(u8)]
  pub enum MemType {
      Identity, Preference, Goal, Project, Habit,
      Decision, Constraint, Relationship, Episode, Reflection,
      Capture, Semantic, Procedural,
  }

The four-variant route_capture decision (§4.5):

  enum RouteVariant { Centroid, LLMClassify, ConceptSearch, Defer }

  async fn route_capture(input: RouteInput) -> RouteDecision {
      if let Some(d) = try_centroid(&input).await? {
          if d.confidence >= 0.85 { return d; }
      }
      if let Some(d) = try_llm_classify(&input).await? {
          if d.confidence >= 0.75 { return d; }
      }
      if let Some(d) = try_concept_then_neighbour(&input).await? {
          if d.confidence >= 0.70 { return d; }
      }
      RouteDecision::defer("low_confidence_after_three_variants")
  }

The IterGen backtrack (§22.1.3):

  impl HealLoop {
      pub async fn backtrack_and_retry(
          &self, state: &mut GenerationState, error: ValidationError,
      ) -> Result<GenerationState> {
          let failing_idx = state.field_index.get(&error.field_path)
              .ok_or(BacktrackError::FieldNotFound)?;
          let (&boundary_idx, _) = state.grammar_boundaries
              .range(..*failing_idx).next_back()
              .ok_or(BacktrackError::NoBoundary)?;
          state.tokens.truncate(boundary_idx);
          let kv_handle = state.kv_snapshots.get(&boundary_idx)
              .ok_or(BacktrackError::NoSnapshot)?;
          self.engine.restore_kv(kv_handle).await?;
          self.grammar.restore_parser_state(boundary_idx)?;
          let hint = self.compose_repair_hint(&error);
          self.engine.inject_context_tokens(&hint).await?;
          let new_tokens = self.engine.continue_generation(state.tokens.len()).await?;
          state.tokens.extend(new_tokens);
          Ok(state.clone())
      }
  }

──────────────────────────────────────────────────────────────────────
WORKFLOW PER PHASE
──────────────────────────────────────────────────────────────────────

For every phase 0.5 → 13:

  1. Re-read the plan section for THIS phase. (Don't rely on memory of
     phases you've already done; the plan is authoritative.)
  2. Run the web searches in §0.1 for THIS phase. They are mandatory.
     Do not skip. If a search returns information that contradicts the
     plan, STOP and surface the contradiction to the user before
     proceeding.
  3. Read the on-disk research docs flagged for this phase per §0.2.
  4. Plan the work. Use TodoWrite. One in_progress task at a time.
  5. Implement. Reference the load-bearing snippets above; the field
     name is `result`, not `payload`. The naming convention is
     non-negotiable.
  6. Run the phase verification command from §12. It MUST pass.
  7. Run swift test + cargo test --manifest-path agent_core/Cargo.toml
     to confirm zero regression.
  8. Update the §14 implementation note for this phase: list what you
     read, what changed your mind, the verification command, the
     result, the commit sha.
  9. Commit. Use a HEREDOC for the message; co-authored-by Claude.
     Never batch. Never skip the commit.
 10. Update docs/AGENT_PROGRESS.md with ✅ + today's date for this phase.
 11. Move to the next phase.

──────────────────────────────────────────────────────────────────────
START HERE
──────────────────────────────────────────────────────────────────────

After completing the Phase 0 reads above, your first implementation
phase is Phase 0.5 (First-run bootstrap) per §11. Work the phases in
order. Do not reorder. Do not parallelize phases.

If you encounter ambiguity, ASK before assuming. The plan is large
enough that something is in there; if you can't find it, ask.

If a verification gate fails, STOP. Do not commit. Investigate the
root cause. Do not bypass with --no-verify or any equivalent.

When all phases pass and §16's Definition of Done (25+ criteria) is
green, message back with the final SHA and the eval results.

You have everything you need. Begin.
====================================================================
```

---

## Notes on usage

- **Where to paste**: a fresh Claude Code session in the repo root (or any working directory inside the worktree). The prompt assumes `pwd` is the Epistemos repo root.
- **Model recommendation**: Opus or the most capable Sonnet you have access to. The plan is large; the agent should use TodoWrite and re-read sections per phase rather than try to hold all 32k words in active context.
- **Length**: the prompt is ~1,400 words. Long, but inline-load-bearing. The agent cannot lose the four-action enum or the 0.85/0.75/0.70 thresholds even if its context-window compacts older messages — those constants are in the prompt itself.
- **Why so prescriptive**: the user's risk profile (lost work to git checkout) means commit-after-every-phase + zero-regression must be enforced, not encouraged. The prompt makes both unviolable.
- **What's NOT in the prompt and is in the plan**: the JSON Schemas, the per-model engineering catalog (12 models), the Fortress catalog of 30 built-in skills, the Compile-Verify-Mint pipeline details, the Templater spec, the §24/§25 architectural ports. The agent reads those; the prompt names them by section so the agent knows where to look.
