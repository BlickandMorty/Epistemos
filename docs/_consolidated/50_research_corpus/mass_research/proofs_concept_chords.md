# Formal Properties: Leibnizian Concept Chords

## Statement 1 — Dissonance on Missing Requirements
Given a rule `requires[A] = {B1, B2, ...}`, if concept A is present and any Bi is missing,
then `dissonance_score > 0`.

**Proof:**
The evaluator appends a dissonance event when A is present and any required concept is absent.
The dissonance score includes a positive base proportional to the count of events.
Therefore score > 0.

---

## Statement 2 — Dissonance on Forbidden Pairs
Given a forbidden pair `(X, Y)`, if both are present then `dissonance_score > 0`.

**Proof:**
The evaluator appends a dissonance event for forbidden pairs.
Thus the event count is positive and score > 0.

---

## Statement 3 — Zero Dissonance for Empty Concept Set
If `concepts = []`, then `dissonance_score = 0`.

**Proof:**
The evaluator checks for an empty list and returns 0.0 directly.

---

## Statement 4 — Chord Product Multiplicativity
The chord product is the multiplicative product of primes assigned to the detected concepts.

**Proof:**
The function initializes product = 1 and multiplies each concept’s prime exactly once.
By definition this equals the product of primes for the concepts in the set.
