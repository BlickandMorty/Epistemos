---
id: DDB791F0-D111-4621-B72D-3BF27D19115C
title: "Intuit SWE I Interview — Jordan's Personalized Study Guide"
---

lov 

# Intuit SWE I Interview — Jordan's Personalized Study Guide

## What You're Walking Into

Intuit's 2026 interview process has 5 gates. Each one tests something different, and your unique profile (AI-assisted builder + red-teamer + military ops) gives you genuine advantages — but only if you can speak the fundamentals fluently.

---

## Your Honest Gap Analysis

Based on scanning your resume and the full Brainiac v2 codebase (100+ files, 14 Zustand slices, 10-stage pipeline, Drizzle ORM, async generators, D3.js visualizations), here's where you stand:

### What You Already Know (But Need to Articulate)
- **Async generators & SSE streaming** — Your `runPipeline()` function IS the async generator pattern. You need to explain `yield`, how the consumer pulls events, and why SSE over WebSocket.
- **State management architecture** — 14 Zustand slices is a serious design. You need to explain the slice pattern, why Zustand over Redux, and how persist middleware works.
- **Discriminated unions** — Your `PipelineEvent` type is a textbook discriminated union. Know what that term means and how TypeScript narrows on the `type` field.
- **Database schema design** — Your Drizzle ORM schema with 9 tables, foreign keys, and JSON columns demonstrates relational design. Explain your normalization decisions.
- **Design patterns** — Observer (Zustand subscriptions), Strategy (3-layer steering), Factory (LLM providers), Pipeline (10-stage engine), State Machine (safety allostasis). You USE these — now NAME them.

### What You Need to Learn from Scratch
- **DSA problem-solving under pressure** — You can build systems but can you solve Two Sum in 5 minutes on a whiteboard? This is muscle memory, not intelligence. You need to drill.
- **Big-O analysis** — For every solution, you must state time and space complexity instantly.
- **SQL query writing** — SELECT, JOINs, GROUP BY, window functions, CTEs. Tested on the OA.
- **OOP vocabulary** — Polymorphism types, SOLID principles, the four pillars. Intuit asks these directly.
- **OS fundamentals** — Deadlock conditions, processes vs threads, GIL. Quick-fire questions.

### What You Know Conceptually But Should Code from Scratch
- **Sorting algorithms** — Can you write merge sort without looking? Binary search?
- **Tree traversals** — Inorder, preorder, postorder, BFS. Code them cold.
- **Graph algorithms** — BFS, DFS, topological sort (you use DAGs in your causal inference work!).
- **Python stdlib** — heapq, bisect, collections.Counter, functools.lru_cache. These are interview power tools.

---

## The Question Types You'll Face

### Round 1: Online Assessment (90 min)
**What:** 1-2 SQL queries, 1 Bash question, 1-2 LeetCode problems (easy + medium)
**Question types:** String manipulation, array operations, hash map problems, basic SQL joins and aggregations
**Your prep:** SQL fundamentals + LeetCode easy/medium grind

### Round 2: Recruiter Screen (25-35 min)
**What:** Background, motivation, AI tooling questions
**Question types:** "Tell me about yourself", "Why Intuit?", "Do you use AI tools? How?"
**Your prep:** Practice your 2-minute pitch. Practice AI workflow explanation.

### Round 3: Live Technical (60-75 min)
**What:** 1-2 coding problems solved live + theory questions
**Question types:**
- DSA coding (medium difficulty): Decode String, Search in Sorted Matrix, Longest Substring
- OOP theory rapid-fire: Polymorphism types, deadlock conditions, ACID properties
- AI discussion: How do you validate AI-generated code?
**Your prep:** LeetCode medium problems daily + flashcards for theory

### Round 4: Craft Demo (90 min build + 60 min presentation)
**What:** Build an app solo (90 min), then present to 4 interviewers and defend every decision
**Question types:**
- Architecture probes: "Why this database? Why this framework?"
- Scaling probes: "What breaks at 10x users?"
- AI probes: "Explain this function line by line"
- D4D probes: "Who is the user? What's their pain point?"
**Your prep:** Practice your 30-second elevator pitch. Do prompt audits on your key files.

### Round 5: Virtual Onsite Loop (4-6 hours)
**What:** Multiple interviews covering DSA, system design, behavioral, culture
**Question types:** Mix of all above categories
**Your prep:** Full mock interviews under time pressure

---

## The AI-Pilot Framework (Critical for 2026)

Intuit knows you use AI. They're testing if you're the **Pilot** (architects and directs) or a **Passenger** (copies and hopes). Your Mercor red-teaming experience is your secret weapon.

### During the Live AI Assessment:
1. **Understand first** — Think about the approach before touching AI
2. **Prompt specifically** — "Implement a sliding window for longest substring, using a hash map for positions"
3. **Evaluate critically** — "The logic is correct but it misses the empty string edge case"
4. **Modify visibly** — Add error handling, rename variables, optimize
5. **Explain everything** — "I changed this because..."

### Your Framing:
> "I evaluate AI output the same way I evaluate model responses at Mercor — I look for logic gaps, edge case failures, and assumptions that might not hold. My value is system design judgment and knowing when AI-generated code has subtle bugs."

---

## Priority Study Order (4-Week Plan)

### Week 1: Python + Core DSA
Day 1: Python data structures (lists, dicts, sets, Counter, deque)
Day 2: Python OOP (classes, inheritance, dunder methods)
Day 3: Strings & arrays (two pointer, sliding window)
Day 4: Hash maps (Two Sum, Group Anagrams, Max Product of Three)
Day 5: Linked lists (reverse, cycle detect, merge)
Day 6: Stacks & queues (Decode String!)
Day 7: Review + SQL basics (SELECT, JOINs)

### Week 2: Trees, Graphs, SQL, OOP
Day 8: Binary trees (traversals, max depth, validate BST)
Day 9: BST operations + Tries
Day 10: Graphs (BFS, DFS, topological sort)
Day 11: SQL advanced (window functions, CTEs, ACID, indexing)
Day 12: OOP deep dive (4 pillars, SOLID, polymorphism types)
Day 13: Sorting & binary search (merge sort, search in matrix)
Day 14: Review + mock interview

### Week 3: DP, System Design, Behavioral
Day 15-16: Dynamic programming (Fibonacci, Coin Change, LCS)
Day 17: System design (leaderboard, chatbot pipeline)
Day 18: OS & networking (deadlock, HTTP, SSE vs WebSocket)
Day 19: TypeScript deep dive (generics, async generators, Zod)
Day 20: Project deep-dive prep (elevator pitch, architecture walkthrough)
Day 21: Behavioral + full mock

### Week 4: Polish
Day 22-23: Drill weakest topics
Day 24-25: LeetCode sprint (3 mediums/day)
Day 26: AI workflow practice (prompt iteration, code explanation)
Day 27: Final mock (full simulation)
Day 28: Rest + light review

---

## Must-Solve LeetCode Problems (Intuit Reported)

- [ ] #1 Two Sum (Easy)
- [ ] #3 Longest Substring Without Repeating Characters (Medium)
- [ ] #56 Merge Intervals (Medium)
- [ ] #206 Reverse Linked List (Easy)
- [ ] #394 Decode String (Medium)
- [ ] #240 Search a 2D Matrix II (Medium)
- [ ] #380 Insert Delete GetRandom O(1) (Medium)
- [ ] #146 LRU Cache (Hard)
- [ ] #42 Trapping Rain Water (Hard)

---

## Things You Must Explain from Your Own Codebase

From your Brainiac v2 project — these are the things interviewers will drill on:

- [ ] What an async generator is and how `yield` pauses/resumes execution
- [ ] Why SSE over WebSocket for your pipeline streaming
- [ ] How Zustand's slice pattern composes 14 independent domains
- [ ] What discriminated unions are and how TypeScript narrows on them
- [ ] Your SQLite schema design and why local-first architecture
- [ ] How Drizzle ORM maps TypeScript types to SQL
- [ ] What the Observer pattern is (your store subscriptions)
- [ ] What the Strategy pattern is (your 3-layer steering engine)
- [ ] What the Factory pattern is (your LLM provider selection)
- [ ] What Cohen's d, Bradford Hill criteria, and Bayes' theorem are
- [ ] How your token-bucket rate limiter works
- [ ] What contrastive learning, Bayesian priors, and k-NN mean

---

## Your Skill is Installed

The full interview prep skill is saved at:
`.skills/skills/intuit-interview-prep/`

It contains 11 reference files covering every topic. When you want to study a specific area, just ask me and I'll pull up the relevant material with code examples, practice problems, and connections to your projects.

Let's get you hired.
