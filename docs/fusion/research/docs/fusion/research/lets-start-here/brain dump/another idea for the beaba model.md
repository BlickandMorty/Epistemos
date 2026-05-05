deep-seed-reasoner/
  /core
  /modules
    deep_seed_loop.py
    complexity_transfer.py
  /eval
  /benchmarks

# Recommendation

**Build them as one project with two toggleable modules.**  
Keep them independent inside the repo, but designed to compose.

---

# Detailed Implementation Plan

## 1. Deep‑Seeded Question Loop (Module A)

### Pipeline

1. Draft initial answer
2. Extract key concepts from the answer
3. Generate **3–5 deeper questions** (bounded)
4. Rank those questions
5. Answer top 2–3
6. Merge into final response

### Controls to avoid output bloat

- **Cap** number of generated questions (e.g., max 5)
- **Cap** number answered (e.g., top 2–3)
- Use a **length budget** (total tokens for sub‑answers)
- Use **importance scoring**:
    - causal impact
    - uncertainty reduction
    - relevance to user goal

### Pseudocode

`answer = model(prompt) concepts = extract_concepts(answer) questions = generate_deep_questions(concepts) ranked = rank_questions(questions) selected = ranked[:3] sub_answers = [model(q) for q in selected] final = merge(answer, sub_answers, budget=token_limit)`