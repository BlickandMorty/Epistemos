# NoteInsightService — Design Document

## Problem

Epistemos has 1014+ notes but no pre-computed intelligence about them. Every AI interaction (dialogue, note chat, search) starts cold — re-analyzing content on the fly. Cross-note connections exist only as explicit graph edges. Semantic relationships are invisible.

**Goal:** Make the app feel like it already knows everything. Search, dialogue, and chat should draw from pre-computed insights so the user never sees a loading state for intelligence. The boundary between "my notes" and "AI understanding" should be invisible.

## Anti-Blurriness Contract

**If everything is connected, nothing is.** This system MUST enforce:

1. **Hard threshold: 0.70 minimum relatedness.** Below this, the connection doesn't exist.
2. **Gap detection.** If scores drop sharply (>0.15 gap between consecutive ranks), cut there — even if under 5 results.
3. **Signal transparency.** Every connection carries a `reason` enum: `.sharedEntities`, `.semanticSimilarity`, `.sharedKeywords`, `.structuralProximity`. Consumers MUST display the reason.
4. **Cap: 5 related notes max per note.** Hubs (notes relating to 50+ others) get their top 5, period.
5. **Staleness decay.** Relatedness scores for notes not updated in 30+ days get a 10% penalty per month. Active notes stay prominent.

## Data Model

### SDNoteInsight (new SwiftData model)

```swift
@Model
final class SDNoteInsight {
    @Attribute(.unique) var pageId: String   // matches SDPage.id
    var contentHash: String                  // SHA256 of body, skip if unchanged
    var lastAnalyzedAt: Date

    // ML signals (from ContentPersonalitySignals)
    var sentiment: Double                    // -1.0 to +1.0
    var formality: Double                    // 0.0 to 1.0
    var vocabDiversity: Double               // 0.0 to 1.0
    var questionDensity: Double              // 0.0 to 1.0

    // Extracted content
    var entityKeywordsJSON: String           // JSON-encoded [String]
    var topicNounsJSON: String               // JSON-encoded [String]

    // Cross-note relatedness (top 5)
    var relatedNoteIdsJSON: String           // JSON-encoded [String]
    var relatednessScoresJSON: String        // JSON-encoded [Double]
    var relatednessReasonsJSON: String       // JSON-encoded [String] (reason per connection)
}
```

### RelatednessReason (enum)

```swift
enum RelatednessReason: String, Codable {
    case sharedEntities       // NER overlap
    case semanticSimilarity   // embedding cosine > threshold
    case sharedKeywords       // topic noun overlap
    case structuralProximity  // within 2 hops in graph
}
```

## Processing Pipeline

### Phase 1: Per-Note Analysis (~5s for 1014 notes)

Runs on `Task.detached(priority: .utility)` — zero main thread impact.

```
For each SDPage:
  1. Compute contentHash(body)
  2. Skip if SDNoteInsight.contentHash matches (unchanged)
  3. Run ContentPersonalitySignals.analyze(body)
     - NLTagger sentimentScore → sentiment
     - NLTagger lexicalClass → formality, vocabDiversity, questionDensity
     - NLTagger nameType → entityKeywords
     - Noun frequency → topicNouns
  4. Persist SDNoteInsight
```

Parallelized: process in chunks of 50 notes using TaskGroup.

### Phase 2: Cross-Note Relatedness (~1-2s)

After all notes are analyzed:

```
For each note A:
  candidates = []
  For each note B (B != A):
    score = 0.0
    reasons = []

    // Signal 1: Embedding cosine similarity (0.40 weight)
    cos = cosineSimilarity(embedding[A], embedding[B])
    if cos > 0.60:
      score += cos * 0.40
      reasons.append(.semanticSimilarity)

    // Signal 2: Entity overlap — Jaccard (0.25 weight)
    jaccard = |entities[A] ∩ entities[B]| / |entities[A] ∪ entities[B]|
    if jaccard > 0.15:
      score += jaccard * 0.25
      reasons.append(.sharedEntities)

    // Signal 3: Keyword overlap — Jaccard (0.20 weight)
    kwJaccard = |topics[A] ∩ topics[B]| / |topics[A] ∪ topics[B]|
    if kwJaccard > 0.20:
      score += kwJaccard * 0.20
      reasons.append(.sharedKeywords)

    // Signal 4: Graph proximity (0.15 weight)
    hops = shortestPath(A, B)  // from GraphStore
    if hops <= 2:
      proximityScore = hops == 1 ? 0.15 : 0.08
      score += proximityScore
      reasons.append(.structuralProximity)

    if score >= 0.70 && !reasons.isEmpty:
      candidates.append((B, score, reasons))

  // Gap detection: sort by score desc, cut at first >0.15 gap
  candidates.sort(by: score desc)
  cutoff = applyGapDetection(candidates, maxGap: 0.15)
  store top min(5, cutoff) for note A
```

### Performance Budget

| Step | Per-note | Total (1014) | Thread |
|------|----------|-------------|--------|
| ContentHash check | 0.1ms | 100ms | Background |
| NLTagger analysis | 5ms | 5s | Background |
| Embedding lookup | 0ms | 0ms | Already computed |
| Pairwise relatedness | — | 1-2s | Background (Rust SIMD for cosine) |
| SwiftData persist | 0.5ms | 500ms | Background |
| **Total** | — | **~7-8s** | **Zero main thread** |

### Incremental Updates

On vault sync (file changed/created/deleted):
- Re-analyze only changed notes (contentHash mismatch)
- Re-compute relatedness only for changed notes + their existing related notes
- ~50ms per changed note

## Integration Points

### 1. Search (SearchIndexService)

```
User types query →
  1. Text search (existing FTS) → ranked results
  2. Semantic search (embedding similarity to query) → ranked results
  3. Faceted filter from SDNoteInsight:
     - "Questioning notes" (questionDensity > 0.3)
     - "Academic/formal" (formality > 0.6)
     - "Positive/negative" (sentiment thresholds)
  4. Merge & deduplicate, boost notes with high relatedness to top results
```

### 2. Dialogue (DialogueChatState)

Already partially wired. Enhancements:
- `DialogueNodeProfile.derive()` reads from SDNoteInsight (instant, no NLTagger at open time)
- System prompt includes related notes: "Your closest connections are [X, Y, Z] because you share concepts [A, B]"
- Cross-note intelligence: "Note X contradicts your stance on [topic]"

### 3. Note Chat (NoteChatState)

- System prompt enriched with related note summaries
- AI can reference connections: "This relates to your note on [X] which discusses [Y]"
- Pre-computed signals mean zero additional latency

### 4. Graph (GraphState)

- Suggested edges: notes with relatedness > 0.80 but no explicit edge → dashed/ghost edge in graph
- Edge type: `.suggested` — user can accept (creates real edge) or dismiss
- Visual: thin dashed line, lower alpha than real edges

### 5. Sidebar

- "Related Notes" section below note content
- Each entry shows: note title + reason chip ("Shared: JavaScript, React")
- Tap to navigate

## File Layout

| File | Purpose |
|------|---------|
| `Epistemos/Models/SDNoteInsight.swift` | SwiftData model |
| `Epistemos/Engine/NoteInsightService.swift` | Background analysis + relatedness |
| `Epistemos/Engine/NoteInsightService+Relatedness.swift` | Cross-note scoring (if large) |

## Risks

1. **NLTagger quality** — sentiment for short notes may be noisy. Mitigation: require minimum 50 words for sentiment signal.
2. **Stale insights** — notes edited but not re-analyzed. Mitigation: contentHash check on every vault sync.
3. **Hub pollution** — "JavaScript" entity appears in 200 notes, connecting everything. Mitigation: IDF weighting — common entities get lower Jaccard contribution.
4. **Cold start** — first launch takes 7-8s. Mitigation: show "Indexing insights..." in sidebar, non-blocking.
