# Implementation Plan: Making the Research Document Features Real

**Status:** Ready for Claude Code execution  
**Author:** Kimi Code CLI (post-audit synthesis)  
**Date:** 2026-04-09  
**Estimated effort:** 6-8 weeks (Phases 1-3), Phase 4 is architecture design, Phase 5 is long-term research

---

## Executive Summary

This plan bridges the gap between the aspirational research document and the actual codebase. Three of the four major features exist in `agent_core` (debug-only, not shipping). The plan ports them to `epistemos-core` (the shipping crate), implements missing pieces, and wires them into the live app.

**Phase 1 — GEPA (1-2 weeks):** Port `mutation_proposer.rs` to `epistemos-core`, add FFI, wire to NightBrain.  
**Phase 2 — Hyperbolic Topology (2 weeks):** Port `hyperbolic_topology.rs`, implement FEP decision engine, wire to vault search.  
**Phase 3 — Neural Cache (1-2 weeks):** Port `neural_cache.rs`, add temporal retrieval FFI, integrate with BM25 search.  
**Phase 4 — Mamba Distillation (design phase):** Architecture spec for `DistillationEngine` actor, MLX cache monitoring.  
**Phase 5 — TurboQuant (research project):** Flagged as 3-6 month research effort with clear path.

---

## Critical Pre-Reading

Before starting any phase, read these files in this order:

1. `epistemos-core/Cargo.toml` — dependencies already available
2. `epistemos-core/src/lib.rs` — module export pattern
3. `epistemos-core/src/uniffi_exports.rs` — FFI free function pattern
4. `epistemos-core/uniffi/epistemos_core.udl` — UniFFI declaration pattern
5. `build-epistemos-core.sh` — build pipeline
6. `Epistemos/State/NightBrainService.swift` — where background jobs run
7. `Epistemos/Vault/VaultLifecycleService.swift` — Swift reimplementations to replace
8. `AGENTS.md` — Swift/Rust patterns to follow

---

## FFI Pattern Reference (epistemos-core)

All new features follow this exact pattern:

**1. Add Rust module in `epistemos-core/src/`:**
```rust
pub mod my_feature;
```

**2. Export free functions in `epistemos-core/src/uniffi_exports.rs`:**
```rust
pub use my_feature::*;
```

**3. Declare in UDL `epistemos-core/uniffi/epistemos_core.udl`:**
```webidl
namespace epistemos_core {
    MyResult my_feature_func(string arg);
};

dictionary MyResult {
    string field1;
    u32 field2;
};
```

**4. Regenerate bindings:** `bash build-epistemos-core.sh`

**5. Call from Swift:**
```swift
import epistemos_coreFFI
let result = myFeatureFunc(arg: "hello")
```

---

# Phase 1: GEPA (Genetic-Pareto Prompt Evolution)

**Goal:** Make skill mutation analysis run through Rust FFI in production builds.

**Current state:**
- `agent_core/src/evolution/mutation_proposer.rs` — real implementation, debug-only
- `VaultLifecycleService.swift` — pure-Swift reimplementation, runs in NightBrain
- NightBrain calls `VaultLifecycleService.runEvolutionSweep()` which uses Swift heuristics

**Target state:**
- Rust mutation proposer runs via FFI from `VaultLifecycleService`
- Constraint gates (size ≤15KB, semantic similarity >0.80) enforced in Rust
- Pareto frontier check simplified to working heuristic gates

---

## Phase 1.1: Port `mutation_proposer.rs` to `epistemos-core`

### Step 1.1.1: Create `epistemos-core/src/evolution/` directory

```bash
mkdir -p epistemos-core/src/evolution
```

### Step 1.1.2: Create `epistemos-core/src/evolution/mod.rs`

```rust
//! GEPA: Genetic-Pareto Prompt Evolution
//! Skill mutation proposer based on trace analysis.

pub mod mutation_proposer;
pub use mutation_proposer::*;
```

### Step 1.1.3: Copy and adapt `mutation_proposer.rs`

Copy the ENTIRE content from `agent_core/src/evolution/mutation_proposer.rs` into `epistemos-core/src/evolution/mutation_proposer.rs`.

**Changes needed for epistemos-core:**

1. **Remove agent_core-specific imports** (anything from `crate::storage::memory_classifier`)
2. **Replace `memory_classifier::embed_text_public`** with a simple cosine-similarity stub or remove semantic gate
3. **Keep all core logic:** `ImprovementSignal`, `SkillMutation`, `ConstraintCheck`, `propose_mutation()`
4. **Add `#[derive(uniffi::Record)]`** to public structs (instead of agent_core's proc-macro style)

The agent_core version uses:
```rust
use crate::storage::memory_classifier;
```

In epistemos-core, replace the semantic gate with a simpler heuristic:
```rust
// Semantic preservation gate — simplified for epistemos-core
// Full embedding-based similarity requires sentence-transformers,
// which adds ~50MB to the binary. Use Jaccard similarity as proxy.
fn semantic_similarity(a: &str, b: &str) -> f64 {
    let tokens_a: std::collections::HashSet<_> = a.split_whitespace().collect();
    let tokens_b: std::collections::HashSet<_> = b.split_whitespace().collect();
    let intersection = tokens_a.intersection(&tokens_b).count();
    let union = tokens_a.union(&tokens_b).count();
    if union == 0 { return 1.0; }
    intersection as f64 / union as f64
}
```

### Step 1.1.4: Update `epistemos-core/src/lib.rs`

Add to the module list and re-exports:

```rust
pub mod evolution;

// In the re-export section, add:
pub use evolution::{ImprovementSignal, SkillMutation, ConstraintCheck, propose_mutation};
```

### Step 1.1.5: Add FFI exports in `uniffi_exports.rs`

Add to `epistemos-core/src/uniffi_exports.rs`:

```rust
pub use crate::evolution::mutation_proposer::{
    propose_mutation,
    ImprovementSignal,
    SkillMutation,
    ConstraintCheck,
};
```

### Step 1.1.6: Add UDL declarations

Edit `epistemos-core/uniffi/epistemos_core.udl`:

In the `namespace` block, add:
```webidl
/// Analyze skill content + trace pattern and propose a mutation.
/// Returns JSON string with mutation proposal, or empty string if gates fail.
string propose_skill_mutation(string skill_content, string trace_pattern_json);
```

Add type dictionaries:
```webidl
dictionary SkillMutation {
    string mutation_type;
    string reasoning;
    string proposed_appendix;
    u32 version_increment;
    boolean gates_passed;
};

dictionary ConstraintCheck {
    boolean size_ok;
    boolean semantic_preserved;
    u32 proposed_size_bytes;
    double semantic_similarity;
};

enum ImprovementSignal {
    "FrequentRetries",
    "SlowExecution",
    "ConsistentFailure",
    "UnusedCapability"
};
```

### Step 1.1.7: Build and test

```bash
cd epistemos-core && cargo test
bash build-epistemos-core.sh
```

---

## Phase 1.2: Wire FFI into Swift

### Step 1.2.1: Read current `VaultLifecycleService.swift`

The file already has `proposeSkillMutation()` as a pure-Swift function (lines ~430-450). We need to:
1. Keep the Swift function as fallback
2. Add FFI call as primary path
3. Fall back to Swift if FFI returns empty

### Step 1.2.2: Modify `VaultLifecycleService.analyzeAndProposeEvolution()`

Current code (simplified):
```swift
func analyzeAndProposeEvolution(skillName: String) -> SkillEvolutionResult? {
    guard let patternJSON = try? analyzeSkillTraces(...) else { return nil }
    // ... load skill content ...
    guard let mutationJSON = try? proposeSkillMutation(...) else { return nil }
    return SkillEvolutionResult(...)
}
```

New code:
```swift
func analyzeAndProposeEvolution(skillName: String) -> SkillEvolutionResult? {
    // Step 1: Analyze traces (still in Swift — reads filesystem)
    guard let patternJSON = try? analyzeSkillTraces(
        vaultPath: vaultPath,
        skillName: skillName
    ), !patternJSON.isEmpty, patternJSON != "{}" else {
        return nil
    }
    
    // Step 2: Load current skill content
    let skillPath = URL(fileURLWithPath: vaultPath)
        .appendingPathComponent("skills")
        .appendingPathComponent(skillName)
        .appendingPathComponent("SKILL.md")
    guard let skillContent = try? String(contentsOf: skillPath, encoding: .utf8) else {
        Self.log.warning("Skill file not found: \(skillName)")
        return nil
    }
    
    // Step 3: Try Rust FFI first, fall back to Swift heuristic
    #if canImport(epistemos_coreFFI)
    let mutationJSON = proposeSkillMutation(skillContent: skillContent, tracePatternJson: patternJSON)
    #else
    let mutationJSON: String? = nil
    #endif
    
    let effectiveMutation: String
    if let mutationJSON, !mutationJSON.isEmpty {
        effectiveMutation = mutationJSON
        Self.log.info("GEPA: Used Rust mutation proposer for \(skillName)")
    } else {
        // Fallback to Swift heuristic
        guard let swiftMutation = try? proposeSkillMutation(
            skillContent: skillContent,
            tracePatternJson: patternJSON
        ), !swiftMutation.isEmpty else {
            return nil
        }
        effectiveMutation = swiftMutation
        Self.log.info("GEPA: Used Swift fallback for \(skillName)")
    }
    
    return SkillEvolutionResult(
        skillName: skillName,
        patternJSON: patternJSON,
        mutationJSON: effectiveMutation
    )
}
```

### Step 1.2.3: Build test

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
```

### Step 1.2.4: Add Rust unit tests

In `epistemos-core/src/evolution/mutation_proposer.rs`, add tests that mirror the agent_core tests:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_frequent_retries_signal() {
        let content = "# Test Skill\n\nDo thing.";
        let pattern = r#"{"skill_name":"test","trace_count":5,"success_count":1,"failure_count":4,"average_duration_ms":1000.0,"top_failure_outputs":["error"]}"#;
        let result = propose_mutation(content.to_string(), pattern.to_string());
        assert!(!result.is_empty());
    }

    #[test]
    fn test_size_gate_rejects_large_skill() {
        let content = "x".repeat(20_000);
        let pattern = r#"{"skill_name":"test","trace_count":10,"success_count":0,"failure_count":10}"#;
        let result = propose_mutation(content, pattern.to_string());
        assert!(result.is_empty()); // Gates should fail
    }
}
```

Run: `cd epistemos-core && cargo test evolution`

---

## Phase 1.3: Add GEPA Settings UI

### Step 1.3.1: Add config keys

In `Epistemos/Config/EpistemosConfig.swift`, add:

```swift
@AppStorage("gepaAutoPropose")
var gepaAutoPropose: Bool = true

@AppStorage("gepaMinTraces")
var gepaMinTraces: Int = 5

@AppStorage("gepaSizeLimitKB")
var gepaSizeLimitKB: Int = 15
```

### Step 1.3.2: Add Settings panel section

In `Epistemos/Views/Settings/AISettingsView.swift` (or wherever AI settings live), add:

```swift
Section("Skill Evolution (GEPA)") {
    Toggle("Auto-propose skill mutations", isOn: $config.gepaAutoPropose)
    
    Stepper("Minimum traces before analysis: \(config.gepaMinTraces)",
            value: $config.gepaMinTraces, in: 3...20)
    
    Stepper("Max skill size (KB): \(config.gepaSizeLimitKB)",
            value: $config.gepaSizeLimitKB, in: 5...50)
}
```

### Step 1.3.3: Wire config to NightBrain

In `NightBrainService.executeJob(.skillEvolutionAnalysis)`, add config checks:

```swift
case .skillEvolutionAnalysis:
    let (autoPropose, minTraces) = await MainActor.run {
        (config.gepaAutoPropose, config.gepaMinTraces)
    }
    guard autoPropose else {
        Self.log.info("GEPA: auto-propose disabled in settings")
        return
    }
    if let vaultPath = vaultPathProvider?() {
        let lifecycle = VaultLifecycleService(vaultPath: vaultPath)
        let proposals = await lifecycle.runEvolutionSweep(minTraces: minTraces)
        // ...
    }
```

Update `VaultLifecycleService.runEvolutionSweep()` to accept `minTraces` parameter.

---

## Phase 1 Completion Checklist

- [ ] `epistemos-core/src/evolution/mutation_proposer.rs` exists and compiles
- [ ] FFI functions declared in UDL and bindings generated
- [ ] `VaultLifecycleService` calls Rust FFI with Swift fallback
- [ ] Settings UI has GEPA toggles
- [ ] `cargo test` passes for mutation_proposer
- [ ] `xcodebuild build` succeeds
- [ ] NightBrain GEPA job uses new config

---

# Phase 2: Hyperbolic Topo-Spatial Memory

**Goal:** Port hyperbolic topology from agent_core, implement FEP decision engine, wire to live vault graph.

**Current state:**
- `agent_core/src/storage/hyperbolic_topology.rs` — 613 LOC, Poincaré math is real
- FEP decision engine (`should_pierce_blanket`) is NOT implemented
- Module is debug-only, not shipping
- Works on filesystem, not SwiftData note graph

**Target state:**
- Module in `epistemos-core` with FFI exports
- FEP engine with actual Variational Free Energy calculation
- Integration with vault search and graph context

---

## Phase 2.1: Port `hyperbolic_topology.rs` to `epistemos-core`

### Step 2.1.1: Create directory and mod

```bash
mkdir -p epistemos-core/src/topology
```

`epistemos-core/src/topology/mod.rs`:
```rust
pub mod hyperbolic;
pub use hyperbolic::*;
```

### Step 2.1.2: Copy and adapt the topology module

Copy from `agent_core/src/storage/hyperbolic_topology.rs` to `epistemos-core/src/topology/hyperbolic.rs`.

**Required changes:**

1. **Replace agent_core imports** with epistemos-core equivalents
2. **Add `#[derive(uniffi::Record)]`** to public structs
3. **Add the missing FEP implementation**

### Step 2.1.3: Implement `should_pierce_blanket()` with FEP

Add this to the `MarkovBlanket` impl:

```rust
impl MarkovBlanket {
    /// Free Energy Principle decision: should the AI read inside this folder?
    /// 
    /// F = E_q[log q(s|π) - log p(o,s|π)] = Complexity - Accuracy
    /// 
    /// We approximate:
    /// - Complexity = entropy of blanket summary (higher = more complex = more uncertain)
    /// - Accuracy = negative log-likelihood of observations given the blanket
    /// 
    /// Pierce when F > threshold (high uncertainty warrants deeper look)
    pub fn should_pierce_blanket(
        &self,
        query_embedding: &[f32],  // Query vector (simplified: keyword presence vector)
        blanket_embedding: &[f32], // Blanket summary vector
        threshold: f64,
    ) -> bool {
        // Accuracy: cosine similarity between query and blanket
        let accuracy = cosine_similarity(query_embedding, blanket_embedding);
        
        // Complexity: normalized entropy of child distribution
        let complexity = self.complexity_weight();
        
        // Variational Free Energy = Complexity - Accuracy
        // (negative free energy in active inference literature)
        let free_energy = complexity - accuracy;
        
        free_energy > threshold
    }
    
    /// Compute complexity weight from child distribution entropy
    fn complexity_weight(&self) -> f64 {
        if self.child_metrics.is_empty() {
            return 0.0;
        }
        
        let total_cw: f64 = self.child_metrics.iter().map(|m| m.complexity_weight).sum();
        if total_cw == 0.0 {
            return 0.0;
        }
        
        // Entropy of complexity-weight distribution
        let entropy: f64 = self.child_metrics.iter().map(|m| {
            let p = m.complexity_weight / total_cw;
            if p > 0.0 { -p * p.ln() } else { 0.0 }
        }).sum();
        
        // Normalize: max entropy = ln(n)
        let max_entropy = (self.child_metrics.len() as f64).ln();
        if max_entropy > 0.0 {
            entropy / max_entropy
        } else {
            0.0
        }
    }
}

fn cosine_similarity(a: &[f32], b: &[f32]) -> f64 {
    let len = a.len().min(b.len());
    if len == 0 { return 0.0; }
    
    let dot: f64 = (0..len).map(|i| (a[i] as f64) * (b[i] as f64)).sum();
    let norm_a: f64 = (0..len).map(|i| (a[i] as f64).powi(2)).sum().sqrt();
    let norm_b: f64 = (0..len).map(|i| (b[i] as f64).powi(2)).sum().sqrt();
    
    if norm_a > 0.0 && norm_b > 0.0 {
        dot / (norm_a * norm_b)
    } else {
        0.0
    }
}
```

### Step 2.1.4: Add FFI exports

In `epistemos-core/src/lib.rs`:
```rust
pub mod topology;
pub use topology::{HyperbolicPoint, VaultNodeMetrics, VaultHyperbolicMap, build_topology};
```

In `epistemos-core/src/uniffi_exports.rs`:
```rust
pub use crate::topology::hyperbolic::{
    build_topology,
    topology_to_agent_context,
    HyperbolicPoint,
    VaultNodeMetrics,
    VaultHyperbolicMap,
};
```

In `epistemos-core/uniffi/epistemos_core.udl`:
```webidl
dictionary HyperbolicPoint {
    double r;
    double theta;
};

dictionary VaultNodeMetrics {
    string name;
    string node_type;
    double complexity_weight;
    double gravity;
    double volatility;
    HyperbolicPoint position;
};

dictionary VaultHyperbolicMap {
    string root_path;
    sequence<VaultNodeMetrics> nodes;
    sequence<string> blanket_summaries;
};

/// Build hyperbolic topology map of vault directory tree.
VaultHyperbolicMap build_vault_topology(string vault_root);

/// Convert topology to compact LLM-readable context string.
string topology_to_context(VaultHyperbolicMap topology);
```

### Step 2.1.5: Build and test

```bash
cd epistemos-core && cargo test topology
bash build-epistemos-core.sh
```

---

## Phase 2.2: Swift Integration

### Step 2.2.1: Create `HyperbolicTopologyService.swift`

New file: `Epistemos/Vault/HyperbolicTopologyService.swift`

```swift
import Foundation
import epistemos_coreFFI

/// Service for building and querying hyperbolic vault topology.
/// Uses Rust FFI for Poincaré disk embedding and FEP-based traversal decisions.
actor HyperbolicTopologyService {
    static let shared = HyperbolicTopologyService()
    
    private var cachedTopology: VaultHyperbolicMap?
    private var lastBuildTime: Date?
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    
    /// Build or retrieve cached topology for a vault root.
    func topology(for vaultRoot: String) -> VaultHyperbolicMap {
        if let cached = cachedTopology,
           let lastBuild = lastBuildTime,
           Date().timeIntervalSince(lastBuild) < cacheTTL {
            return cached
        }
        
        let topology = buildVaultTopology(vaultRoot: vaultRoot)
        cachedTopology = topology
        lastBuildTime = Date()
        return topology
    }
    
    /// Invalidate cache when vault changes.
    func invalidateCache() {
        cachedTopology = nil
        lastBuildTime = nil
    }
    
    /// Get topology as agent context string for prompt injection.
    func contextString(for vaultRoot: String) -> String {
        let topo = topology(for: vaultRoot)
        return topologyToContext(topology: topo)
    }
    
    /// FEP-based folder relevance check.
    /// Returns true if the AI should read inside this folder given the query.
    func shouldExploreFolder(
        vaultRoot: String,
        folderPath: String,
        query: String,
        threshold: Double = 0.3
    ) -> Bool {
        // Simplified: check if query keywords appear in blanket summary
        let topo = topology(for: vaultRoot)
        
        // Find the folder in topology
        guard let node = topo.nodes.first(where: { 
            folderPath.hasSuffix($0.name) || $0.name == folderPath 
        }) else {
            return true // Default to exploring if not found
        }
        
        // Simple keyword overlap as embedding proxy
        let queryTokens = Set(query.lowercased().split(separator: " "))
        let nodeTokens = Set(node.name.lowercased().split(separator: " "))
        let overlap = Double(queryTokens.intersection(nodeTokens).count)
        let accuracy = overlap / Double(queryTokens.count)
        
        // Complexity = normalized volatility
        let complexity = node.volatility
        
        let freeEnergy = complexity - accuracy
        return freeEnergy > threshold
    }
}
```

### Step 2.2.2: Wire to vault search

In `Epistemos/Vault/VaultSearchService.swift` (or wherever search happens), add topology-aware ranking:

```swift
/// Boost search results using hyperbolic topology relevance.
func rankedSearch(query: String, vaultRoot: String) -> [SearchResult] {
    let baseResults = performBM25Search(query: query)
    
    // Get topology for relevance boosting
    let topology = await HyperbolicTopologyService.shared.topology(for: vaultRoot)
    
    return baseResults.map { result in
        var scored = result
        // Boost files in high-gravity folders
        if let node = topology.nodes.first(where: { result.path.contains($0.name) }) {
            let gravityBoost = node.gravity * 0.1 // Small boost
            scored.score += gravityBoost
        }
        return scored
    }.sorted { $0.score > $1.score }
}
```

### Step 2.2.3: Add to TriageService context

In `TriageService`, when building context for local model queries, inject topology:

```swift
private func buildContextWithTopology(prompt: String) -> String {
    guard let vaultRoot = VaultRegistry.shared.primaryVault?.path else {
        return prompt
    }
    
    let topoContext = await HyperbolicTopologyService.shared.contextString(for: vaultRoot)
    
    return """
    [Vault Topology Context]
    \(topoContext)
    
    [User Query]
    \(prompt)
    """
}
```

---

## Phase 2.3: NightBrain Integration

Add a new NightBrain job:

```swift
case .hyperbolicTopologyRefresh:
    if let vaultPath = vaultPathProvider?() {
        await HyperbolicTopologyService.shared.invalidateCache()
        let _ = await HyperbolicTopologyService.shared.topology(for: vaultPath)
        Self.log.info("Hyperbolic topology refreshed")
    }
```

Add to `Job.allCases` and set interval to run every 24h (alongside other jobs).

---

## Phase 2 Completion Checklist

- [ ] `epistemos-core/src/topology/hyperbolic.rs` compiles with FEP engine
- [ ] FFI exports declared in UDL
- [ ] `HyperbolicTopologyService.swift` created and integrated
- [ ] Search ranking uses topology gravity
- [ ] TriageService injects topology context
- [ ] NightBrain has topology refresh job
- [ ] `cargo test` passes for topology

---

# Phase 3: Neural Cache

**Goal:** Port neural cache to epistemos-core, wire to retrieval system for temporal-aware search.

**Current state:**
- `agent_core/src/storage/neural_cache.rs` — 373 LOC, hot/warm/cold tiers
- epistemos-core has BM25 retrieval (`epistemos-core/src/retrieval/`)
- No temporal search in the live app

**Target state:**
- Neural cache in epistemos-core with FFI
- Temporal retrieval API for "what did I work on last Tuesday?"
- Integration with existing BM25 index

---

## Phase 3.1: Port `neural_cache.rs`

### Step 3.1.1: Create module

```bash
mkdir -p epistemos-core/src/cache
```

`epistemos-core/src/cache/mod.rs`:
```rust
pub mod neural;
pub use neural::*;
```

### Step 3.1.2: Copy and adapt

Copy from `agent_core/src/storage/neural_cache.rs` to `epistemos-core/src/cache/neural.rs`.

**Key changes:**
1. Replace `agent_core::storage::memory_classifier` with simple keyword matching
2. Add `#[derive(uniffi::Record)]` to structs
3. Make `NeuralCache` methods callable from FFI

Simplified keyword matching (replacing embeddings):
```rust
fn keyword_similarity(query: &str, fact: &str) -> f64 {
    let q_tokens: std::collections::HashSet<_> = query.to_lowercase()
        .split_whitespace()
        .collect();
    let f_tokens: std::collections::HashSet<_> = fact.to_lowercase()
        .split_whitespace()
        .collect();
    
    let intersection = q_tokens.intersection(&f_tokens).count();
    let union = q_tokens.union(&f_tokens).count();
    
    if union == 0 { 0.0 } else { intersection as f64 / union as f64 }
}
```

### Step 3.1.3: FFI exports

In UDL:
```webidl
dictionary CachedFact {
    string id;
    string content;
    string source;
    double created_at_epoch;
    double complexity;
    double gravity;
    u32 access_count;
};

dictionary TemporalQueryResult {
    sequence<CachedFact> facts;
    double query_latency_ms;
    string layer_hit; // "hot", "warm", "cold"
};

/// Retrieve facts matching query with temporal awareness.
TemporalQueryResult neural_retrieve(string vault_root, string query, u32 limit);

/// Retrieve facts from a specific time window.
TemporalQueryResult neural_retrieve_temporal(
    string vault_root,
    string query,
    u64 minutes_ago,
    u64 window_minutes,
    u32 limit
);
```

### Step 3.1.4: Build and test

```bash
cd epistemos-core && cargo test cache
bash build-epistemos-core.sh
```

---

## Phase 3.2: Swift Integration

### Step 3.2.1: Create `NeuralCacheService.swift`

```swift
import Foundation
import epistemos_coreFFI

/// Temporal-aware retrieval service.
/// Answers questions like "what did I work on yesterday?" or
/// "find my notes about X from last week."
actor NeuralCacheService {
    static let shared = NeuralCacheService()
    
    /// General retrieval with automatic tier selection.
    func retrieve(query: String, limit: UInt32 = 10) -> [CachedFact] {
        guard let vaultRoot = VaultRegistry.shared.primaryVault?.path else {
            return []
        }
        let result = neuralRetrieve(vaultRoot: vaultRoot, query: query, limit: limit)
        return result.facts
    }
    
    /// Temporal window retrieval.
    func retrieveTemporal(
        query: String,
        minutesAgo: UInt64,
        windowMinutes: UInt64,
        limit: UInt32 = 10
    ) -> [CachedFact] {
        guard let vaultRoot = VaultRegistry.shared.primaryVault?.path else {
            return []
        }
        let result = neuralRetrieveTemporal(
            vaultRoot: vaultRoot,
            query: query,
            minutesAgo: minutesAgo,
            windowMinutes: windowMinutes,
            limit: limit
        )
        return result.facts
    }
    
    /// Convenience: retrieve from today.
    func retrieveToday(query: String) -> [CachedFact] {
        retrieveTemporal(query: query, minutesAgo: 0, windowMinutes: 24 * 60, limit: 20)
    }
    
    /// Convenience: retrieve from last N days.
    func retrieveLastDays(query: String, days: Int) -> [CachedFact] {
        let minutes = UInt64(days * 24 * 60)
        retrieveTemporal(query: query, minutesAgo: minutes, windowMinutes: minutes, limit: 20)
    }
}
```

### Step 3.2.2: Add chat command

In the chat UI, add a `/temporal` or `/recent` command:

```swift
// In chat input handler
if message.hasPrefix("/recent ") {
    let query = String(message.dropFirst(8))
    let facts = await NeuralCacheService.shared.retrieveLastDays(query: query, days: 7)
    let context = facts.map { "- [\($0.source)]: \($0.content)" }.joined(separator: "\n")
    // Inject context into the prompt
}
```

### Step 3.2.3: Populate cache from vault

In `NightBrainService`, add a job that scans vault notes and populates the neural cache:

```swift
case .neuralCacheRefresh:
    if let vaultPath = vaultPathProvider?() {
        // Scan all markdown files, extract facts, populate cache
        let noteFiles = try? FileManager.default.enumerator(
            at: URL(fileURLWithPath: vaultPath),
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        // ... populate neural cache via FFI
        Self.log.info("Neural cache refreshed")
    }
```

---

## Phase 3 Completion Checklist

- [ ] `epistemos-core/src/cache/neural.rs` compiles
- [ ] FFI temporal retrieval functions work
- [ ] `NeuralCacheService.swift` provides Swift API
- [ ] Chat has `/recent` command
- [ ] NightBrain populates cache
- [ ] `cargo test` passes for neural cache

---

# Phase 4: Mamba Distillation Engine — Architecture Design

**Goal:** Design the continuous distillation loop that feeds overflow KV-cache tokens into SSM state.

**Current state:**
- SSM state save/load works via MLX (`.safetensors` prompt cache)
- Custom Metal kernels compiled but not invoked
- No `DistillationEngine` actor

**Blockers identified:**

### Blocker 1: MLX Cache Access
MLX-Swift's `KVCache` protocol does not expose token-level eviction. The cache is opaque. To implement distillation, we need:

```swift
// Hypothetical API — does NOT exist in current MLX-Swift
protocol KVCache {
    var tokenCount: Int { get }
    func evictOldestTokens(count: Int) -> [Float] // Returns evicted token embeddings
}
```

**Resolution path:** Fork `mlx-swift-lm` to add:
1. `tokenCount` property on `MambaCache`
2. `extractOverflowTokens(count:)` method
3. Return format: `[layer: [head: [token: [embedding]]]]`

### Blocker 2: Token-to-SSM Format Conversion
Evicted tokens from KV cache are attention key/value pairs (shape depends on model). SSM state expects hidden state tensors (shape: `[layers, state_dim, head_dim]`). We need:

```rust
/// Convert KV overflow to SSM state update
fn kv_to_ssm_update(kv_tokens: &[f16], ssm_state: &mut SSMState) -> Result<()>
```

This requires understanding the exact tensor shapes and implementing a projection layer. This is model-specific.

### Blocker 3: Custom Metal Forward Pass
The 14 helper kernels need a `Mamba2ForwardPass.swift` that orchestrates them. This is 1000+ lines of Metal dispatch code. The document `MAMBA2_CODEX_IMPLEMENTATION_GUIDE.md` lists this as the core remaining work.

### Recommended Approach (Pragmatic)

Instead of full custom Metal distillation, implement a **simpler version** using MLX:

```swift
actor DistillationEngine {
    /// When cache is near full, save current state + summary of oldest tokens
    func checkpointAndDistill(session: ChatSession) async {
        let cache = session.kvCache
        guard cache.approximateTokenCount > cache.capacity * 0.9 else { return }
        
        // Save current state
        await ssmService.saveMLXCache(cache, modelId: session.modelId, sessionId: session.id)
        
        // Generate summary of conversation so far using local model
        let summary = await generateSummary(from: session.messageHistory)
        
        // Inject summary as system context for continuation
        session.injectContext(summary)
        
        // Clear cache (model continues with distilled context)
        session.clearCache()
    }
}
```

This is **not** the research-document vision (no selective scan of individual tokens), but it achieves the same goal: preventing context overflow by distilling old conversation into SSM-compatible state + summary.

---

## Phase 4 Deliverable

A design document at `docs/DISTILLATION_ENGINE_DESIGN.md` containing:
1. MLX cache extension requirements (fork spec)
2. Token-to-SSM projection math
3. `DistillationEngine` actor interface
4. Integration points with `NoteChatState` and `TriageService`
5. Decision: implement summary-based distillation first, token-level later

---

# Phase 5: TurboQuant — Research Project Assessment

**Goal:** Evaluate feasibility and define implementation path.

**Current state:** Zero implementation. Referenced in 5+ planning docs as future work.

**What TurboQuant requires:**

### 1. FWHT (Fast Walsh-Hadamard Transform) Kernel
```metal
kernel void fwht(device float* data, uint gid [[thread_position_in_grid]]) {
    // Bit-reversal permutation + butterfly operations
    // Required for random rotation before quantization
}
```

### 2. Lloyd-Max Codebook Training
```rust
fn train_codebook(vectors: &[f32], bits: u8) -> Vec<f32> {
    // K-means clustering to find optimal quantization centroids
    // For 4-bit: 16 centroids, for 3-bit: 8 centroids
}
```

### 3. Asymmetric Quantization Path
```rust
fn quantize_keys(keys: &[f32]) -> QuantizedKeys { /* TQ3: q8_0-K */ }
fn quantize_values(values: &[f32]) -> QuantizedValues { /* TurboQuant-4S: V */ }
```

### 4. MLX Integration
Patch MLX's `KVCache` to use quantized storage instead of full f16 tensors.

### Assessment

| Component | Effort | Blockers |
|-----------|--------|----------|
| FWHT kernel | 1 week | Need to verify numerical accuracy vs CPU reference |
| Codebook training | 2 weeks | Requires calibration dataset from user's actual conversations |
| Quantization ops | 3 weeks | Must match llama.cpp's TurboQuant reference implementation |
| MLX integration | 4+ weeks | Deep changes to MLX tensor storage; may conflict with upstream |
| **Total** | **10+ weeks** | Requires ongoing upstream coordination |

### Recommendation

**Defer TurboQuant to Phase 6+** (post-V1 release). The research is sound but the engineering cost is high relative to user-facing benefit. Implement the other features first.

---

# Execution Order for Claude Code

**Week 1-2: Phase 1 (GEPA)**
1. Port `mutation_proposer.rs` → `epistemos-core/src/evolution/`
2. Add FFI exports
3. Wire to `VaultLifecycleService`
4. Add settings UI
5. Test end-to-end

**Week 3-4: Phase 2 (Hyperbolic Topology)**
1. Port `hyperbolic_topology.rs` → `epistemos-core/src/topology/`
2. Implement FEP engine
3. Create `HyperbolicTopologyService.swift`
4. Wire to search and TriageService
5. Test

**Week 5-6: Phase 3 (Neural Cache)**
1. Port `neural_cache.rs` → `epistemos-core/src/cache/`
2. Create `NeuralCacheService.swift`
3. Add chat `/recent` command
4. Wire to NightBrain
5. Test

**Week 7-8: Phase 4 (Distillation Design)**
1. Write design document
2. Identify exact MLX extension points
3. Prototype summary-based distillation
4. Decision gate: proceed to implementation or defer

---

# Testing Strategy

For each phase:

1. **Rust unit tests:** `cd epistemos-core && cargo test <module>`
2. **FFI contract tests:** Verify Swift can call all new functions
3. **Integration tests:** Feature works through the full stack
4. **Manual verification:** Run the app, trigger the feature, verify output

Run full suite before declaring phase complete:
```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
cd graph-engine && cargo test
cd epistemos-core && cargo test
```

---

# Success Criteria

**Phase 1 complete when:**
- NightBrain GEPA job uses Rust FFI
- Skill mutations are proposed with constraint gates enforced
- Settings UI shows GEPA options

**Phase 2 complete when:**
- Vault search ranks results using hyperbolic topology
- TriageService injects topology context into prompts
- FEP engine decides folder exploration at runtime

**Phase 3 complete when:**
- `/recent <query>` in chat returns temporally-relevant results
- Neural cache is populated by NightBrain
- Temporal queries work end-to-end

**Phase 4 complete when:**
- Design document approved
- MLX extension requirements documented
- Decision made on implementation timeline

---

*End of plan. Start with Phase 1.1.1.*
