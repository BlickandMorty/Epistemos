# Intuit SWE 1 Interview — Corrected Study Guide (v3)

> **What changed from v2:** Round structure corrected to match the actual Uptime Crew pipeline (verified via Glassdoor Dec 2025, LeetCode Discuss, Blind, Roundz Substack). OS/DBMS sections expanded. Behavioral prep added. Project defense methodology added. Take-home assessment round added. AI workflow section expanded.

---

## The Actual Interview Pipeline (Uptime Crew → Intuit, 2025-2026)

There are **5 gates**. The first 4 are managed by Uptime Crew (a staffing agency). Gate 5 is the hand-off to Intuit proper.

### Gate 1: Online Assessment (OA)
- **Platform:** HackerRank or Glider
- **Duration:** 90 minutes
- **Format:** 1 Bash question + 1-2 SQL queries + 1-2 LeetCode problems
- **Difficulty:** Easy to Medium (occasionally one Hard)
- **Reported questions:** Text calculator in Bash, basic JOINs and aggregations in SQL, array/string manipulation in code
- **What they're testing:** Can you write working code under time pressure? Do you know basic SQL?

### Gate 2: Recruiter Screen
- **Duration:** 25-35 minutes
- **Format:** Behavioral + AI usage deep-dive
- **What they ask:**
  - "Tell me about yourself" (have a 2-minute pitch ready)
  - "Why Intuit?"
  - "Do you use AI tools? How?" (this is a MAJOR focus in 2026)
  - "How do you validate AI-generated code?"
  - "Walk me through your AI workflow"
  - General behavioral questions about teamwork, conflict, ownership
- **What they're testing:** Are you the Pilot or the Passenger? Can you articulate your process?

### Gate 3: Take-Home Assessment
- **Duration:** 2-4 hours (self-paced, deadline given)
- **Format:** Build a small application from scratch
- **Reported assignments:** "Design a Bank and Gradebook System", REST API with CRUD operations, microservice with CSV data processing
- **What they're testing:** Can you build a complete, working system? Is your code clean? Do you handle edge cases? Do you write tests?
- **Critical:** This is what you'll be grilled on in Gate 4. Every line matters.

### Gate 4: Tech Screen (Take-Home Defense)
- **Duration:** 30 minutes
- **Format:** Live review of your Gate 3 submission
- **What they ask:**
  - "Walk me through your architecture"
  - "Why did you choose this data structure here?"
  - "What happens if [edge case]?"
  - "How would you scale this?"
  - "Explain this function line by line"
- **What they're testing:** Did you actually write this? Do you understand every decision?

### Gate 5: Intuit Hand-Off — Project Presentation
- **Duration:** 60 minutes
- **Format:** Present a previous project to Intuit engineers (not Uptime Crew)
- **What they ask:**
  - Architecture walkthrough
  - Technology choice justifications
  - Scaling questions ("What breaks at 10x?")
  - AI integration questions
  - Design for Delight (D4D) questions ("Who is the user? What's their pain point?")
- **What they're testing:** Engineering judgment, system thinking, product awareness, communication

### Possible Additional Rounds (Virtual Onsite Loop)
Some candidates report a full onsite loop (4-6 hours) after the Uptime Crew pipeline, with:
- DSA coding (medium-hard)
- System design
- OOP/OS/DBMS rapid-fire theory
- Behavioral interviews on Intuit values
- Craft demo presentation

**Not every candidate gets this.** It depends on the team and headcount. Prepare for it anyway.

---

## What You Need to Know (Priority Order)

### Tier 1: MUST KNOW (tested in almost every SDE1 interview)

**OOP Fundamentals (rapid-fire format)**
- The 4 pillars: Encapsulation, Abstraction, Inheritance, Polymorphism
- Polymorphism types: Compile-time (method overloading) vs Runtime (method overriding)
- When function overloading occurs vs overriding
- Virtual keyword and why it exists
- Difference between abstract class and interface
- SOLID principles (at minimum: Single Responsibility, Open/Closed)

**DBMS Theory**
- ACID properties (Atomicity, Consistency, Isolation, Durability) — define each
- Normalization: 1NF, 2NF, 3NF — define each with examples
- Indexing: what it is, why it speeds up queries, trade-offs
- DDL vs DML vs DCL — what each stands for, examples of commands in each
- File system vs DBMS — why use a database?
- Transactions: what they are, how they maintain consistency

**SQL (practical)**
- SELECT, WHERE, ORDER BY, GROUP BY, HAVING
- JOINs: INNER, LEFT, RIGHT, FULL — know the difference
- Aggregations: COUNT, SUM, AVG, MAX, MIN
- Subqueries and CTEs (WITH clause)
- Window functions: ROW_NUMBER, RANK, PARTITION BY

**DSA Core (LeetCode)**
- Arrays & Strings: Two pointers, sliding window, prefix sums
- Hash maps: Frequency counting, two-sum pattern, grouping
- Linked lists: Reverse, detect cycle, merge two sorted
- Stacks & Queues: Decode String (#394), valid parentheses, monotonic stack
- Trees: All traversals (inorder, preorder, postorder, BFS/level-order), max depth, validate BST
- Graphs: BFS, DFS, topological sort
- Sorting: Merge sort (know how to write it), binary search (and its variants)

**Bash Basics**
- File operations: cat, grep, sed, awk
- Piping and redirection: |, >, >>, 2>&1
- Variables, conditionals, loops
- Simple text processing (the OA reportedly asked for a "simple text calculator")

### Tier 2: LIKELY TESTED (comes up in 60-70% of interviews)

**OS Fundamentals**
- Process vs Thread — what's the difference?
- Deadlock: 4 necessary conditions (Mutual Exclusion, Hold and Wait, No Preemption, Circular Wait)
- Mutex vs Semaphore — when to use which
- Virtual Memory — what is it, why does it exist
- Thrashing — what causes it
- Context switching — what happens during one
- GIL (Python's Global Interpreter Lock) — what it is and why it matters

**Dynamic Programming**
- Fibonacci (memoization vs tabulation)
- Coin Change
- Longest Common Subsequence
- Climbing Stairs
- Know how to identify: "Can I break this into overlapping subproblems?"

**System Design (lightweight for SWE-1)**
- REST API design (endpoints, HTTP methods, status codes)
- Database schema design (tables, relationships, foreign keys)
- Caching basics (why, where, invalidation)
- "What breaks at 10x users?" — know how to reason about bottlenecks

### Tier 3: GOOD TO KNOW (comes up occasionally, differentiates strong candidates)

- Design patterns: Observer, Strategy, Factory, Singleton
- Networking: HTTP vs HTTPS, TCP vs UDP, OSI model layers
- Python internals: how the interpreter runs code, C vs Python speed difference
- Testing: unit tests, integration tests, TDD basics
- CI/CD: what it is, why it matters
- Agile/Scrum vocabulary

---

## Must-Solve LeetCode Problems (Intuit Reported)

These are confirmed by multiple candidate reports:

- [ ] #1 Two Sum (Easy) — hash map pattern
- [ ] #3 Longest Substring Without Repeating Characters (Medium) — sliding window
- [ ] #56 Merge Intervals (Medium) — sorting + merge
- [ ] #206 Reverse Linked List (Easy) — pointer manipulation
- [ ] #238 Product of Array Except Self (Medium) — prefix/suffix pattern
- [ ] #240 Search a 2D Matrix II (Medium) — start from top-right corner
- [ ] #394 Decode String (Medium) — stack or recursion
- [ ] #380 Insert Delete GetRandom O(1) (Medium) — hashmap + array
- [ ] #146 LRU Cache (Hard) — hashmap + doubly linked list
- [ ] #42 Trapping Rain Water (Hard) — two pointer or stack
- [ ] #200 Number of Islands (Medium) — BFS/DFS on grid
- [ ] #994 Rotting Oranges (Medium) — BFS on grid
- [ ] Unique Email Addresses (Easy) — string parsing
- [ ] Path in matrix with obstacles (Medium) — BFS with blocked cells

---

## Behavioral Prep (Don't Skip This)

Intuit evaluates against their core values. Have a story ready for each:

**Customer Obsession**
- "Tell me about a time you designed something with the end user in mind"
- Your angle: How Brainiac v2's UI decisions serve researchers, not just engineers

**Ownership / Bias for Action**
- "Tell me about a time you took initiative without being asked"
- Your angle: Building Brainiac v2 end-to-end as a solo project, military initiative

**Craftsmanship**
- "Tell me about a time you went above and beyond on code quality"
- Your angle: 14 Zustand slices, 10-stage pipeline architecture, type safety

**Boundaryless Collaboration**
- "Tell me about a time you worked across teams or disciplines"
- Your angle: Military comms coordination, Mercor cross-functional AI evaluation

**Integrity Without Compromise**
- "Tell me about a time you pushed back on something you disagreed with"
- Your angle: Red-teaming AI systems at Mercor — your literal job is finding where things are wrong

---

## The AI Workflow Explanation (Prepare This Cold)

You will be asked about AI usage. Have this ready:

**Your 60-second version:**
> "I use AI as a force multiplier, not a replacement for understanding. My workflow has three phases: First, I architect the solution myself — I decide the data structures, the component hierarchy, the state management approach. Second, I use AI to accelerate implementation — I give it specific, scoped prompts like 'implement a sliding window for this constraint set.' Third, I evaluate the output the same way I evaluate model responses at Mercor — I look for logic gaps, missed edge cases, assumptions that don't hold, and type safety issues. I never ship AI-generated code I can't explain line by line."

**Follow-up questions they'll ask:**
- "Give me an example of when AI gave you wrong code" → Have a specific story ready
- "How do you know when to trust it vs not?" → Talk about your red-teaming heuristics
- "What's the most complex thing you've built with AI assistance?" → Brainiac v2

---

## 4-Week Study Plan (Revised)

### Week 1: Foundations
- Day 1-2: Python data structures + OOP vocabulary (4 pillars, polymorphism types, SOLID)
- Day 3-4: Arrays, strings, hash maps (Two Sum, sliding window, frequency counting)
- Day 5: Linked lists + stacks (Reverse LL, Decode String)
- Day 6: SQL fundamentals (SELECT, JOINs, GROUP BY, aggregations)
- Day 7: DBMS theory (ACID, normalization, indexing) + Bash basics

### Week 2: Core DSA + Theory
- Day 8-9: Trees (all traversals, validate BST, max depth)
- Day 10: Graphs (BFS, DFS, topological sort, Number of Islands)
- Day 11: Sorting + Binary Search (merge sort from scratch, Search 2D Matrix)
- Day 12: OS fundamentals (deadlock, processes vs threads, virtual memory)
- Day 13: SQL advanced (window functions, CTEs) + more DBMS theory
- Day 14: Review + first mock interview

### Week 3: Advanced + Project Prep
- Day 15-16: Dynamic programming (Coin Change, LCS, Climbing Stairs)
- Day 17: System design basics (REST API design, caching, scaling reasoning)
- Day 18: **Project deep-dive** — read through your own codebase, annotate every file
- Day 19: **Project presentation practice** — 2-min pitch, architecture walkthrough, line-by-line defense
- Day 20: Behavioral prep (write out STAR stories for each Intuit value)
- Day 21: Full mock interview (DSA + theory rapid-fire + behavioral)

### Week 4: Polish + Drill
- Day 22-23: Weakest topics drill
- Day 24-25: LeetCode sprint (3 mediums/day from the reported list)
- Day 26: AI workflow practice + take-home simulation (build a REST API in 2 hours)
- Day 27: Final full mock
- Day 28: Rest + light review

---

## Warning: Process Can Stall

Multiple Glassdoor reviews (Dec 2025) report that Uptime Crew will leave you in "In-Review" indefinitely if headcount fills. They reportedly don't notify you of rejection. Move fast through the pipeline, follow up proactively, and don't put all your eggs in this basket — keep applying elsewhere simultaneously.
