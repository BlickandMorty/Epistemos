//! Integration test: F-VaultRecall-50 fixture end-to-end against a real
//! Tantivy-backed `VaultStore`.
//!
//! Seeds a temp vault with synthetic content matching each canonical
//! fixture row's contract, runs the iter-7 runner across the whole
//! fixture, and asserts that the known-passing categories
//! (`ChattyPrefix`, `SignalOnly`, `Unicode`, `Synthesis`) pass under
//! the current lexical-only retrieval, while the known-failing
//! `Paraphrase` row fails as designed — pinning the Fix-C deferred
//! semantic-recall work (per
//! `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` §4 Fix C).
//!
//! This is the WRV-floor test for T21: one execution exercises
//! - Fix-B (`strip_query_chatter` + `set_conjunction_by_default`)
//! - Fix-C (raw BM25, no clamp)
//! - `VaultStore::hybrid_search_with_trace` override (true pool size,
//!   effective_query, all-chatter detection)
//! - `RetrievalTrace` typed surface
//! - `F-VaultRecall-50` runner (`run_row`, `FVaultRecallRowOutcome`)
//!
//! Scope-locked: uses only public `agent_core::storage::*` APIs.

use agent_core::storage::f_vault_recall_50_fixture::{
    load_canonical, FVaultRecallCategory,
};
use agent_core::storage::f_vault_recall_runner::{run_all, run_row, summarize};
use agent_core::storage::vault::{VaultBackend, VaultStore};

/// Seed a temp `VaultStore` with content that satisfies every canonical
/// fixture row's pass contract. The synthetic vault is structured so
/// that:
/// - Each `expected_paths` doc contains all of its query's signal terms
///   (so the AND-conjunction on ≤ 3 surviving terms matches).
/// - Each `forbidden_paths` doc contains plausible chatter / decoy
///   content but NONE of the query's signal terms (so the row's
///   "must not appear" contract holds).
/// - The shared docs (`MASTER_FUSION/3_2_residency_governor.md` is
///   expected by rows 1 + 4; `notes/mamba_ssm_cache.md` is expected by
///   row 2 + intentionally fails row 5's paraphrase query) carry
///   content that simultaneously satisfies the rows that name them.
async fn seed_synthetic_vault_for_fixture(store: &VaultStore) {
    // Pairs of (path, content). Content authored so the same set of
    // docs supports every canonical row's pass/fail expectations.
    let seeds: &[(&str, &str)] = &[
        // Rows 1 (ChattyPrefix) + 4 (Synthesis) — shared expected hit.
        (
            "MASTER_FUSION/3_2_residency_governor.md",
            "residency governance tier compression governance residency tier compression",
        ),
        // Row 4 Synthesis second authoritative source.
        (
            "MASTER_FUSION/4_compression_tier_doctrine.md",
            "tier compression governance doctrine compression tier governance tier",
        ),
        // Row 1 ChattyPrefix forbidden decoys — chatter-laden but no
        // residency-governance signal terms.
        ("ui/hermes_branding.md", "ui branding hermes design feel"),
        ("ui/character_dna_specs.md", "character dna design specs visual"),
        ("user_hardware.md", "user hardware specifications M2 Pro 16 GB"),
        // Rows 2 (SignalOnly) + 5 (Paraphrase) — shared doc.
        // Content has mamba/ssm/cache (Row 2 passes via AND-conjunction)
        // but explicitly NOT "state-space-model" or "caching" (so
        // Row 5's Paraphrase query fails the AND-conjunction — the
        // doc has only "Mamba" out of the 3 query terms).
        (
            "notes/mamba_ssm_cache.md",
            "mamba ssm cache mamba ssm cache architecture notes",
        ),
        // Row 2 SignalOnly forbidden — lexically distant doc.
        (
            "notes/generic_attention_overview.md",
            "attention softmax overview generic transformer notes",
        ),
        // Row 3 Unicode expected — content with diacritics.
        (
            "notes/unicode_resume_filter.md",
            "naïve résumé filter naïve résumé filter notes",
        ),
        // Row 3 Unicode forbidden — ASCII-only variant. Tantivy's
        // default tokenizer keeps diacritics, so "naïve" ≠ "naive";
        // the AND-conjunction must reject this doc.
        (
            "notes/ascii_only_resume.md",
            "naive resume filter naive resume filter notes",
        ),
        // Row 6 (Adversarial) expected — contains all 4 query terms
        // multiple times so BM25 ranks it #1 amid the partial-overlap
        // decoys below.
        (
            "notes/design_system_hover_spec.md",
            "design system hover specification design system hover \
             specification hover specification design system",
        ),
        // Row 6 Adversarial decoys — each contains ONLY ONE of the 4
        // query terms. BM25 should rank them well below the canonical
        // doc, so `top_n = 1` cannot retain them.
        (
            "notes/old_hover_brainstorm.md",
            "hover hover hover notes brainstorm scattered thoughts",
        ),
        (
            "notes/ux_archive.md",
            "design design archive notes old miscellaneous thoughts",
        ),
        (
            "notes/system_overview.md",
            "system system system overview general notes summary",
        ),
        // Row 7 (PureChatter) forbidden decoys — unrelated docs that
        // share NO terms with the chatter-laden query "show me my notes
        // please" (after the chatter strip + fallback, the raw query
        // would OR-match any doc containing "show", "me", "my", "notes",
        // or "please"; these decoys deliberately avoid those tokens so
        // the runner's forbidden contract holds even on the noise path).
        (
            "notes/totally_unrelated_a.md",
            "alpha beta gamma delta epsilon",
        ),
        (
            "notes/totally_unrelated_b.md",
            "lambda calculus combinator reduction",
        ),
        // Row 8 (exact-quote PhraseQuery) forbidden — contains both
        // "residency" and "governance" but with three tokens between
        // them, so PhraseQuery for `"residency governance"` must NOT
        // match. The expected doc
        // (MASTER_FUSION/3_2_residency_governor.md, already seeded
        // above) carries the bigram at adjacent positions.
        (
            "notes/residency_scattered.md",
            "residency tier compression governance notes scattered",
        ),
        // Row 9 (multilingual mixed-script) expected — Latin "Mamba"
        // + CJK "缓存" with whitespace between so Tantivy's default
        // tokenizer keeps them as distinct tokens.
        (
            "notes/mamba_chinese.md",
            "Mamba 缓存 ssm 架构 notes Mamba 缓存",
        ),
        // Row 9 forbidden — same Latin token but no CJK token, so
        // the AND-conjunction must reject this doc. Doubles as the
        // iter-28 Cyrillic row's forbidden (no Cyrillic either).
        (
            "notes/mamba_english_only.md",
            "Mamba ssm cache architecture notes English only",
        ),
        // Row 13 (Cyrillic multilingual) expected — Latin "Mamba"
        // + Cyrillic "кэш" with whitespace between tokens.
        (
            "notes/mamba_cyrillic.md",
            "Mamba кэш Mamba кэш architecture notes",
        ),
        // Row 16 (Arabic multilingual) expected — Latin "Mamba" +
        // Arabic "كاش" (kash) with whitespace between tokens.
        (
            "notes/mamba_arabic.md",
            "Mamba كاش Mamba كاش architecture notes",
        ),
        // Row 23 (pure-CJK) expected — two CJK tokens with whitespace
        // between so they tokenize distinctly. 缓存 = cache, 架构 =
        // architecture.
        (
            "notes/pure_chinese.md",
            "缓存 架构 缓存 架构 笔记 notes",
        ),
        // Row 23 forbidden — Latin equivalent only; AND on CJK
        // tokens cannot match.
        (
            "notes/latin_only_ssm.md",
            "Mamba SSM cache architecture notes English equivalent",
        ),
        // Row 17 (single-term SignalOnly) expected — contains
        // "Hamiltonian" multiple times so AND-on-one-token matches
        // and BM25 ranks it high.
        (
            "notes/hamiltonian_dynamics.md",
            "Hamiltonian mechanics dynamics Hamiltonian operator \
             notes classical Hamiltonian",
        ),
        // Row 17 forbidden — mentions general physics but NOT
        // "Hamiltonian" specifically; AND-on-one-token rejects it.
        (
            "notes/general_physics.md",
            "physics general overview classical mechanics notes \
             quantum thermodynamics",
        ),
        // Row 18 (3rd Adversarial — agent-runtime domain) canonical:
        // contains all 4 of {agent, runtime, substrate, trace} multiple
        // times so BM25 ranks it #1. Decoys each contain ONE.
        (
            "notes/agent_runtime_v2_substrate.md",
            "agent runtime substrate trace agent runtime substrate \
             trace System G Invader Agent canon agent runtime",
        ),
        // Iter-75 4th Synthesis pair-partner: a second canonical doc
        // carrying all 3 of {agent, runtime, substrate} so the
        // Synthesis pair-retention contract holds against the 3-term
        // AND-conjunction. No "trace" — distinguishes it from the
        // iter-43 Adversarial canonical above, but the Synthesis row's
        // 3-term query is satisfied by both.
        (
            "notes/agent_runtime_substrate_v3.md",
            "agent runtime substrate agent runtime substrate runtime \
             substrate System G canon agent runtime substrate",
        ),
        (
            "notes/agent_brainstorm.md",
            "agent agent agent brainstorm scattered thoughts canon",
        ),
        (
            "notes/runtime_old_design.md",
            "runtime runtime runtime old design draft archived",
        ),
        (
            "notes/substrate_concepts.md",
            "substrate substrate substrate concepts overview general",
        ),
        // Row 19 (3rd Synthesis — hardware-falsifier domain): two
        // canonical docs each carry all 3 of {hardware, floor,
        // falsifier} so the AND-conjunction matches both for the
        // pair-retention contract.
        (
            "notes/m2_pro_hardware_floor.md",
            "hardware floor falsifier M2 Pro hardware floor M2 Pro \
             16 GB UMA hardware floor falsifier handbook",
        ),
        (
            "notes/falsifier_handbook.md",
            "hardware floor falsifier handbook collection falsifier \
             rules hardware floor falsifier methodology",
        ),
        // Row 11 (near-duplicate Synthesis): pair of near-identical
        // docs. Both carry all 3 of {specific, design, pattern} with
        // equal frequency so BM25 ranks them similarly; AND-conjunction
        // returns both. Pass requires top-2 to retain both — pre-MMR
        // baseline contract.
        (
            "notes/design_pattern_v1.md",
            "specific design pattern with notes implementation specific \
             design pattern details",
        ),
        (
            "notes/design_pattern_v1_copy.md",
            "specific design pattern with notes implementation revision \
             specific design pattern details",
        ),
        // Row 13 (2nd Adversarial — graph/event domain): canonical doc
        // carries all four query terms multiple times so BM25 ranks it
        // #1; partial-overlap decoys each carry ONE term repeated.
        (
            "notes/canonical_graph_event_v3.md",
            "graph node update event graph node update event session \
             graph node update event log",
        ),
        (
            "notes/graph_brainstorm.md",
            "graph graph graph brainstorm thoughts scattered general",
        ),
        (
            "notes/old_node_design.md",
            "node node node old design draft archived",
        ),
        (
            "notes/event_archive.md",
            "event event event archive historical records summary",
        ),
        // Row 24 (4th Adversarial — storage/vault canon domain, iter-66):
        // canonical doc carries all four of {vault, index, reload,
        // tantivy} multiple times so BM25 ranks it #1; partial-overlap
        // decoys each carry ONE term repeated. Pins the failure mode
        // against substrate-canon vocabulary itself.
        (
            "notes/vault_index_reload_canon.md",
            "vault index reload tantivy vault index reload tantivy \
             VaultStore::reload_index Tantivy reader visibility vault \
             index reload tantivy",
        ),
        (
            "notes/vault_brainstorm.md",
            "vault vault vault brainstorm scattered storage notes general",
        ),
        (
            "notes/old_index_design.md",
            "index index index old design draft archived structure",
        ),
        (
            "notes/tantivy_misc_notes.md",
            "tantivy tantivy tantivy miscellaneous notes overview general",
        ),
        // Iter-84 (5th Adversarial — BM25 saturation + length-norm axis):
        // Canonical doc carries all 4 of {bm25, saturation, length,
        // penalty} 2-3× each in a moderate-length body. With Tantivy's
        // default BM25 (k1=1.2, b=0.75) the four saturated per-term
        // contributions accumulate to outrank both the single-term
        // partial-overlap decoys AND the long-stuffed decoy below.
        (
            "notes/bm25_saturation_length_penalty.md",
            "bm25 saturation length penalty bm25 saturation length \
             penalty bm25 saturation length penalty ranking ir search \
             relevance scoring notes",
        ),
        // Load-bearing iter-84 decoy: a long doc that stuffs ONLY the
        // term "saturation" 80× amid unrelated junk content. Under raw
        // TF this would win (80 ≫ 3); under BM25's TF-saturation cap
        // PLUS length-normalization (the doc is ~6-8× avgdl for this
        // corpus) the contribution drops below the canonical's 4-term
        // accumulated saturated score. This is the row's whole point.
        (
            "notes/saturation_stuffed_decoy.md",
            "saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             saturation saturation saturation saturation saturation \
             alpha beta gamma delta epsilon zeta eta theta iota kappa \
             lambda mu nu xi omicron pi rho sigma tau upsilon phi chi \
             psi omega lorem ipsum dolor sit amet consectetur adipiscing \
             elit sed do eiusmod tempor incididunt ut labore et dolore \
             magna aliqua enim ad minim veniam quis nostrud exercitation \
             ullamco laboris nisi aliquip ex ea commodo consequat duis \
             aute irure reprehenderit voluptate velit esse cillum fugiat \
             nulla pariatur excepteur sint occaecat cupidatat non proident \
             sunt culpa qui officia deserunt mollit anim id est laborum",
        ),
        // Iter-84 single-term partial-overlap decoys — same shape as
        // every prior Adversarial row's decoys. Each carries exactly
        // ONE of the four query terms.
        (
            "notes/bm25_overview.md",
            "bm25 bm25 bm25 overview general notes summary",
        ),
        (
            "notes/length_archive.md",
            "length length length archive historical notes records",
        ),
        (
            "notes/penalty_misc_notes.md",
            "penalty penalty penalty miscellaneous notes overview general",
        ),
        // Iter-85 (5th Synthesis — storage/tokenizer pair-retention):
        // Both pair-partner docs carry all 3 of {tokenizer, indexing,
        // tantivy} 2-3× each. AND-conjunction on the 3 terms returns
        // exactly these two docs (every other seed in this vault has
        // ≤ 1 of the three query tokens). Pre-MMR baseline: both copies
        // retained in top-3.
        (
            "notes/tokenizer_indexing_tantivy_overview.md",
            "tokenizer indexing tantivy tokenizer indexing tantivy \
             SimpleTokenizer indexing pipeline overview tantivy",
        ),
        (
            "notes/tokenizer_indexing_tantivy_internals.md",
            "tokenizer indexing tantivy SimpleTokenizer NGramTokenizer \
             indexing tantivy internals tokenizer term dictionary",
        ),
        // Iter-86 (5th Paraphrase — abbreviation/acronym axis):
        // Canonical doc spells out "machine learning" in full; the
        // iter-86 query uses the acronym "ml" instead. Lexical
        // retrieval has no acronym dictionary so AND on
        // {ml, inference, cache} blocks this doc — row FAILS by
        // design, pinning Fix-C deferred acronym-expansion work.
        (
            "notes/machine_learning_inference_cache.md",
            "machine learning inference cache machine learning \
             inference cache architecture notes",
        ),
        // Iter-88 (2nd exact-quote PhraseQuery — design-system domain):
        // forbidden decoy carries BOTH "design" and "system" but with
        // intervening tokens so the PhraseQuery `"design system"`
        // (adjacent bigram required) does NOT match. The expected doc
        // (notes/design_system_hover_spec.md, already seeded for iter-15)
        // carries the bigram adjacent.
        (
            "notes/design_general_system.md",
            "design general overview system notes architecture",
        ),
        // Iter-89 (2nd near-duplicate Synthesis — compression-doctrine-
        // canon domain): pair of near-identical docs each carry all 3
        // of {compression, doctrine, canon} with equal frequency. AND-
        // conjunction returns both; BM25 ranks them similarly. Pass
        // requires top-2 to retain both — pre-MMR baseline contract,
        // same shape as iter-24 in a 2nd domain. The 3 query tokens
        // appear together in NO other seeded doc (compression +
        // doctrine appear in MASTER_FUSION/4_compression_tier_doctrine
        // but without "canon"; canon appears in agent-runtime seeds
        // but without "compression" or "doctrine").
        (
            "notes/compression_doctrine_canon_v1.md",
            "compression doctrine canon compression doctrine canon \
             notes architecture details",
        ),
        (
            "notes/compression_doctrine_canon_v2.md",
            "compression doctrine canon compression doctrine canon \
             notes architecture revised details",
        ),
        // Iter-91 (6th Adversarial — Apple Metal compute domain):
        // Canonical doc carries all 4 of {metal, compute, shader,
        // kernel} 2-3× each so BM25 ranks it #1 amid the 3 partial-
        // overlap decoys below. Same shape as the 5 prior Adversarial
        // rows.
        (
            "notes/metal_compute_shader_kernel.md",
            "metal compute shader kernel metal compute shader kernel \
             shader kernel metal compute pipeline notes",
        ),
        (
            "notes/metal_archive.md",
            "metal metal metal archive notes historical apple",
        ),
        (
            "notes/compute_brainstorm.md",
            "compute compute compute brainstorm scattered thoughts \
             general",
        ),
        (
            "notes/shader_misc_notes.md",
            "shader shader shader miscellaneous notes overview general",
        ),
        // Iter-93 (6th Unicode — Greek-script extension): Latin
        // "Mamba" + Greek "λ" (U+03BB lambda) + Latin "cache". Greek
        // single-letter token is a distinct Unicode Letter so Tantivy's
        // SimpleTokenizer keeps it. AND on {Mamba, λ, cache} matches
        // this doc; the iter-9 forbidden seed (mamba_english_only.md)
        // is blocked because it lacks the Greek codepoint.
        (
            "notes/mamba_greek_lambda.md",
            "Mamba λ cache Mamba λ cache architecture notes greek",
        ),
        // Iter-95 (7th Synthesis — Metal pipeline pair-retention):
        // Second pair-partner doc. iter-91's
        // metal_compute_shader_kernel.md is the first pair-partner
        // (it includes "pipeline" by design) — both contain all 3 of
        // {metal, compute, pipeline}.
        (
            "notes/metal_compute_pipeline_v2.md",
            "metal compute pipeline metal compute pipeline architecture \
             variant notes",
        ),
        // Iter-100 (7th Adversarial — MLX-Swift inference domain):
        // canonical carries all 4 of {mlx, swift, inference, backend}
        // 2-3× each; 3 partial-overlap decoys each carry ONE term.
        // Same shape as the 6 prior Adversarial rows.
        (
            "notes/mlx_swift_inference_backend.md",
            "mlx swift inference backend mlx swift inference backend \
             local model pipeline notes",
        ),
        (
            "notes/mlx_archive.md",
            "mlx mlx mlx archive notes historical apple silicon",
        ),
        (
            "notes/swift_brainstorm.md",
            "swift swift swift brainstorm thoughts scattered general",
        ),
        (
            "notes/inference_misc_notes.md",
            "inference inference inference miscellaneous notes overview",
        ),
        // Iter-101 (7th Unicode — Japanese-katakana extension):
        // Latin "Mamba" + katakana "メモリ" (U+30E1 U+30E2 U+30EA,
        // memory) + Latin "cache". Tantivy's SimpleTokenizer
        // tokenizes whitespace-separated; the katakana sequence
        // becomes one token distinct from Han ideographs (U+4E00–
        // U+9FFF) and every other script.
        (
            "notes/mamba_japanese_katakana.md",
            "Mamba メモリ cache Mamba メモリ cache architecture notes",
        ),
        // Iter-102 (3rd exact-quote PhraseQuery — storage/vault canon
        // domain): forbidden decoy carries BOTH "vault" and "index"
        // but with an intervening "general overview" so the
        // PhraseQuery `"vault index"` (adjacent bigram required)
        // does NOT match. The expected doc
        // (notes/vault_index_reload_canon.md, seeded for iter-66)
        // carries the bigram adjacent.
        (
            "notes/vault_general_index.md",
            "vault general overview index notes archive",
        ),
        // Iter-108 (3rd near-duplicate Synthesis — neural-cache-layer
        // domain): pair of near-identical docs each carry all 3 of
        // {neural, cache, layer} with equal frequency. AND-
        // conjunction matches both; BM25 ranks them similarly. The
        // 3 query tokens appear together in NO other seeded doc
        // (mamba_ssm_cache has "cache" but no neural/layer; every
        // other seed lacks 2+ of the 3 terms). Pre-MMR baseline:
        // top-2 retains both copies.
        (
            "notes/neural_cache_layer_v1.md",
            "neural cache layer neural cache layer architecture \
             notes details",
        ),
        (
            "notes/neural_cache_layer_v2.md",
            "neural cache layer neural cache layer architecture \
             notes revised details",
        ),
        // Iter-109 (8th Unicode — Hebrew-script extension): Latin
        // "Mamba" + Hebrew "ש" (shin, U+05E9) + Latin "cache". Six
        // non-Latin scripts now: CJK + Cyrillic + Arabic + Greek +
        // Japanese-katakana + Hebrew.
        (
            "notes/mamba_hebrew.md",
            "Mamba ש cache Mamba ש cache architecture notes hebrew",
        ),
        // Iter-117 (9th Unicode — Devanagari-script extension): Latin
        // "Mamba" + Devanagari "कैश" (kaish, "cache" in Hindi; U+0915
        // U+0948 U+0936) + Latin "cache". The Devanagari token uses
        // a vowel-mark cluster (matras); SimpleTokenizer keeps it
        // as a single whitespace-separated token. Seven non-Latin
        // scripts pinned (+ Devanagari).
        (
            "notes/mamba_devanagari.md",
            "Mamba कैश cache Mamba कैश cache architecture notes hindi",
        ),
        // Iter-123 (10th Unicode — Thai-script extension): Latin
        // "Mamba" + Thai "แคช" (kæch, "cache"; U+0E41 U+0E04 U+0E0A)
        // + Latin "cache". Thai grapheme cluster with above-base
        // and pre-base vowel marks; SimpleTokenizer keeps cluster
        // as single token. Eight non-Latin scripts pinned (+ Thai).
        (
            "notes/mamba_thai.md",
            "Mamba แคช cache Mamba แคช cache architecture notes thai",
        ),
        // Iter-129 (11th Unicode — Korean Hangul extension): Latin
        // "Mamba" + Hangul "캐시" (kaesi, "cache"; U+CE90 U+C2DC)
        // + Latin "cache". Hangul syllabic blocks are precomposed
        // — SimpleTokenizer keeps them as single tokens. Nine
        // non-Latin scripts pinned (+ Korean-Hangul).
        (
            "notes/mamba_korean.md",
            "Mamba 캐시 cache Mamba 캐시 cache architecture notes korean",
        ),
    ];
    for (path, content) in seeds {
        store
            .write(path, content, None, false)
            .await
            .expect("write seed note");
    }
    store.reload_index().expect("reload index");
}

/// End-to-end: every fixture row evaluated against a synthetic vault
/// that satisfies its pass contract. Known-passing categories must
/// pass; the Paraphrase row must fail (pins Fix-C deferred work).
#[tokio::test]
async fn f_vault_recall_50_canonical_rows_against_seeded_vault() {
    let vault_root = tempfile::tempdir().expect("temp vault");
    let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
        .expect("open vault");
    seed_synthetic_vault_for_fixture(&store).await;

    let fixture = load_canonical();
    let mut passed_rows = Vec::new();
    let mut failed_rows = Vec::new();
    for row in fixture {
        let (outcome, _trace) = run_row(&store, row).await.expect("run_row");
        if outcome.passed {
            passed_rows.push((row.category, row.query, outcome));
        } else {
            failed_rows.push((row.category, row.query, outcome));
        }
    }

    // Categorize expected results.
    // Currently-passing (lexical-only retrieval, Fix-B + Fix-C in place):
    //   ChattyPrefix, SignalOnly, Unicode, Synthesis.
    // Currently-failing (pins V1.x Fix-C semantic recall):
    //   Paraphrase.
    let expected_pass_count = fixture
        .iter()
        .filter(|r| r.category != FVaultRecallCategory::Paraphrase)
        .count();
    let expected_fail_count = fixture.len() - expected_pass_count;

    assert_eq!(
        passed_rows.len(),
        expected_pass_count,
        "expected {} rows passing; got {}. Failed rows: {:#?}",
        expected_pass_count,
        passed_rows.len(),
        failed_rows
            .iter()
            .map(|(c, q, o)| (*c, *q, o.expected_missed.clone(), o.forbidden_present.clone()))
            .collect::<Vec<_>>()
    );
    assert_eq!(
        failed_rows.len(),
        expected_fail_count,
        "expected {} rows failing (Paraphrase pinned to Fix-C deferred); \
         got {}. Currently-failing categories: {:?}",
        expected_fail_count,
        failed_rows.len(),
        failed_rows.iter().map(|(c, _, _)| *c).collect::<Vec<_>>()
    );

    // The single failing row MUST be Paraphrase. If a different category
    // fails, something regressed.
    assert!(
        failed_rows
            .iter()
            .all(|(c, _, _)| *c == FVaultRecallCategory::Paraphrase),
        "only Paraphrase rows may fail under lexical-only retrieval; \
         got failures in: {:?}",
        failed_rows.iter().map(|(c, _, _)| *c).collect::<Vec<_>>()
    );

    // The Paraphrase row MUST report its missed expected path
    // (notes/mamba_ssm_cache.md) — the row exists to document exactly
    // this miss.
    let paraphrase_outcome = failed_rows
        .first()
        .map(|(_, _, o)| o.clone())
        .expect("at least one failing row must be Paraphrase");
    assert!(
        paraphrase_outcome
            .expected_missed
            .iter()
            .any(|p| p == "notes/mamba_ssm_cache.md"),
        "Paraphrase row must report mamba_ssm_cache.md as expected_missed; \
         got expected_missed = {:?}",
        paraphrase_outcome.expected_missed
    );
}

/// Smaller-scope sanity check: the canonical 1:15 PM ChattyPrefix row
/// passes against the seeded vault AND the trace records the Fix-B
/// chatter strip transformation (the load-bearing T21 evidence that
/// the original bug is structurally fixed).
#[tokio::test]
async fn canonical_chatty_prefix_row_passes_with_fix_b_trace() {
    let vault_root = tempfile::tempdir().expect("temp vault");
    let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
        .expect("open vault");
    seed_synthetic_vault_for_fixture(&store).await;

    let row = load_canonical()
        .iter()
        .find(|r| r.category == FVaultRecallCategory::ChattyPrefix)
        .expect("fixture must contain a ChattyPrefix row");
    let (outcome, trace) = run_row(&store, row).await.expect("run_row");

    assert!(
        outcome.passed,
        "the canonical 1:15 PM scene row MUST pass — this is the row \
         that the entire T21 mission exists to make pass. Outcome: {:?}",
        outcome
    );
    assert_eq!(outcome.expected_seen, vec!["MASTER_FUSION/3_2_residency_governor.md"]);
    assert!(outcome.forbidden_present.is_empty());

    // Fix-B is observable in the trace.
    assert_eq!(
        trace.effective_query, "residency governance",
        "Fix-B chatter strip must reduce the chatty input to its signal-bearing terms"
    );
    assert!(
        trace.notes.iter().any(|n| n.contains("Fix-B chatter strip")),
        "trace must carry the Fix-B note: {:?}",
        trace.notes
    );
    assert!(
        trace.notes.iter().any(|n| n.contains("AND conjunction applied")),
        "trace must carry the AND-conjunction note (2 surviving terms ≤ 3): {:?}",
        trace.notes
    );
}

/// T21 iter-23 (2026-05-18): end-to-end `run_all` → `summarize` against
/// the canonical fixture. Pins the W-21 Settings → Diagnostics → "Vault
/// recall health" surface contract: a single call chain produces an
/// aggregate pass-rate breakdown the Swift surface can render directly.
///
/// Asserts:
/// - `summary.total` == fixture row count (10 today).
/// - `summary.passed` + `summary.failed` == total.
/// - Both Paraphrase rows (state-space-model + SSL typo) are in the
///   failing set; every other row passes.
/// - `summary.pass_rate` matches `passed / total`.
/// - `by_category` is non-empty AND sorted alphabetically (deterministic
///   JSON output for the W-21 row).
#[tokio::test]
async fn summary_aggregates_run_all_outcomes_for_w21_diagnostics() {
    let vault_root = tempfile::tempdir().expect("temp vault");
    let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
        .expect("open vault");
    seed_synthetic_vault_for_fixture(&store).await;

    let pairs = run_all(&store, load_canonical())
        .await
        .expect("run_all");
    let outcomes: Vec<_> = pairs.iter().map(|(o, _t)| o.clone()).collect();
    let summary = summarize(&outcomes);

    let fixture_len = load_canonical().len();
    assert_eq!(
        summary.total, fixture_len,
        "summary.total must equal fixture row count"
    );
    assert_eq!(
        summary.passed + summary.failed,
        summary.total,
        "pass + fail must equal total"
    );

    // Both Paraphrase rows are expected to fail today (Fix-C deferred);
    // everything else passes.
    let expected_failing = load_canonical()
        .iter()
        .filter(|r| r.category == FVaultRecallCategory::Paraphrase)
        .count();
    assert_eq!(
        summary.failed, expected_failing,
        "expected exactly {} Paraphrase failures (Fix-C deferred), got {}",
        expected_failing, summary.failed
    );

    // Pass-rate sanity: matches the integer division.
    let expected_rate = (summary.passed as f64) / (summary.total as f64);
    assert!(
        (summary.pass_rate - expected_rate).abs() < 1e-9,
        "pass_rate {} does not match passed/total = {}",
        summary.pass_rate,
        expected_rate
    );

    // Per-category breakdown is non-empty AND alphabetically sorted
    // (the W-21 surface relies on deterministic order for stable
    // diff-friendly JSON output).
    assert!(
        !summary.by_category.is_empty(),
        "by_category breakdown must be populated"
    );
    let mut category_names: Vec<&str> = summary
        .by_category
        .iter()
        .map(|c| c.category.as_str())
        .collect();
    let original = category_names.clone();
    category_names.sort();
    assert_eq!(
        original, category_names,
        "by_category must be sorted alphabetically; got {:?}",
        original
    );

    // Paraphrase category breakdown — load-bearing for the W-21 row's
    // "Paraphrase: 0/N" rendering. The count derives from the fixture
    // so adding more Paraphrase rows doesn't break the test; what's
    // load-bearing is that EVERY Paraphrase row fails (the category
    // pins Fix-C deferred work).
    let paraphrase_stats = summary
        .by_category
        .iter()
        .find(|c| c.category == "Paraphrase")
        .expect("Paraphrase category must be present in by_category");
    let expected_paraphrase_count = load_canonical()
        .iter()
        .filter(|r| r.category == FVaultRecallCategory::Paraphrase)
        .count();
    assert_eq!(paraphrase_stats.total, expected_paraphrase_count);
    assert_eq!(
        paraphrase_stats.passed, 0,
        "every Paraphrase row must fail under lexical-only retrieval (pins Fix-C deferred)"
    );
}
