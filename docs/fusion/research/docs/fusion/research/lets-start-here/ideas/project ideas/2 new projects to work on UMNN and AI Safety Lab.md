
### **Vault Notes — Clean, Stable Summaries (Save These)**

  

What follows is **not marketing**, not resume copy, and not code.

This is a **conceptual map** you can come back to months from now and instantly remember _what you were building and why_.

  

Read it slowly once.

Then save it.

---

# **🧪 PROJECT 1: AI Decision-Safety Laboratory**

  

_(System-level, applied, safety research platform)_

  

## **What this project is**

  

The **AI Decision-Safety Lab** is a **research platform** for studying how AI systems affect _human decision-making in safety-critical contexts_.

  

It does **not** try to make models smarter.

It tries to answer a deeper question:

  

> _When AI systems give advice, refuse, or express uncertainty — do they make human decisions safer or more dangerous over time?_

  

This project treats AI models as **black boxes** and focuses on **outcomes**, not internal mechanics.

---

## **The core problem it addresses**

  

Most AI safety work asks:

- “Did the model follow policy?”
    
- “Was the answer allowed?”
    

  

This lab asks:

- “What happened _after_ the model responded?”
    
- “Did trust increase or decrease?”
    
- “Did the decision improve or degrade?”
    
- “Did safety regress over time?”
    

  

This shift — from **output correctness** to **decision impact** — is the project’s core insight.

---

## **Mental model**

  

Think of this like a **physics lab**:

- The lab itself is not the experiment
    
- It **runs experiments**
    
- It uses **instruments** to measure behavior
    

  

The AI Decision-Safety Lab is the **environment**.

The safety modules are **measurement instruments**.

---

## **Core instruments (modules inside the lab)**

  

### **1️⃣ Safety Regression Detection**

  

**Purpose:**

Detect when a model becomes _less safe over time_, even if raw accuracy improves.

  

**What it tracks:**

- Unsafe compliance rate
    
- Over-refusal vs under-refusal
    
- Decision outcome degradation
    
- Confidence miscalibration drift
    
- Behavioral changes across model versions or prompt changes
    

  

**Why this matters:**

Most evaluations are one-off. Real safety requires **longitudinal monitoring**.

  

This module runs **automatically** whenever:

- a model changes
    
- prompts change
    
- policies change
    

---

### **2️⃣ Human–Model Disagreement Analyzer**

  

**Purpose:**

Understand _where and why_ humans disagree with AI outputs — and whether that disagreement is healthy or dangerous.

  

**Key questions it answers:**

- When does disagreement improve outcomes?
    
- When does it signal alignment failure?
    
- When should a model defer?
    
- When does trust become harmful?
    

  

This module reframes disagreement as **signal**, not noise.

---

### **3️⃣ Refusal Quality Evaluator**

  

**Purpose:**

Evaluate refusals _as decision interventions_, not binary policy outcomes.

  

**It asks:**

- Was the refusal appropriate?
    
- Did it de-escalate harm?
    
- Did it preserve human autonomy?
    
- Did it offer safe alternatives?
    

  

Here, refusal quality becomes an **outcome variable**, not a checkbox.

---

## **Why combining these matters**

  

Individually, these look like strong engineering tools.

  

Together, they form a **closed-loop safety system**:

1. Human asks for guidance
    
2. Model responds or refuses
    
3. Human agrees or disagrees
    
4. Decision outcome occurs
    
5. Metrics update
    
6. Safety regression is detected
    
7. System flags or adapts
    

  

This loop is rare — and research-grade.

---

## **What this project is** 

## **not**

- Not a benchmark leaderboard
    
- Not a single evaluation script
    
- Not model-architecture-dependent
    

  

It is a **measurement infrastructure** for safety.

---

## **Long-term value**

- Supports multiple models (black-box friendly)
    
- Enables publishable safety insights
    
- Forms a foundation for applied research, PhD work, or safety engineering roles
    

---

# **🧠 PROJECT 2: Uncertainty-Modulated Neural Networks (UMNN)**

  

_(Mechanism-level, architectural, learning-dynamics research)_

  

## **What this project is**

  

**UMNN** explores a different question:

  

> _How should neural networks behave — and learn — when they are uncertain?_

  

This project **does not evaluate behavior**.

It **changes how behavior is generated**.

  

UMNN treats models as **white boxes** and studies internal learning dynamics.

---

## **The core problem it addresses**

  

Standard neural networks assume:

- all errors are equal
    
- learning signal is global
    
- confidence is implicit or ignored
    

  

This creates:

- overconfidence
    
- brittle behavior
    
- unsafe action instead of refusal
    
- poor calibration in high-stakes contexts
    

  

UMNN challenges those assumptions.

---

## **Core idea (one sentence)**

  

> **Uncertainty should actively control computation and learning — not just be reported.**

---

## **The key mechanism**

  

Instead of:

```
loss → backprop → update all weights
```

UMNN uses:

```
outcome → uncertainty gate → structured feedback → localized updates
```

This changes _how learning happens_.

---

## **What “uncertainty-modulated” means**

  

The model explicitly represents:

- how confident it is
    
- how wrong it was
    
- how costly the mistake was
    

  

Uncertainty then:

- gates depth of computation
    
- influences refusal vs action
    
- modulates learning strength
    

  

Examples:

- High confidence + wrong → strong corrective update
    
- Low confidence + wrong → mild update
    
- Low confidence + correct refusal → reinforce refusal mechanism
    
- High confidence + unnecessary refusal → penalize over-refusal
    

---

## **Learning signal rework (credit assignment)**

  

UMNN replaces scalar loss with **structured feedback**.

  

Instead of one number, learning signal is decomposed into **buckets**, such as:

- correct / incorrect
    
- confident / uncertain
    
- harmful / harmless
    
- refusal appropriate / inappropriate
    

  

Different components of the network receive **different feedback**.

  

This is a fundamental change to credit assignment.

---

## **Why this is legitimate “rethinking how AI works”**

  

UMNN does **not**:

- replace backprop entirely
    
- invent a new paradigm
    
- claim biological realism
    

  

It **does**:

- change learning dynamics
    
- break the “all errors are equal” assumption
    
- align learning with safety outcomes
    
- integrate uncertainty into decision logic
    

  

That is real, defensible research.

---

## **Relationship to the Decision-Safety Lab**

  

These projects are **separate but connected**.

- The **lab** evaluates _behavioral outcomes_
    
- **UMNN** generates behavior differently
    

  

UMNN can be plugged into the lab like any other model.

  

This allows:

- direct comparison with standard architectures
    
- safety regression testing
    
- empirical grounding of architectural choices
    

---

## **Long-term value**

- Bridges theory and applied safety
    
- Supports research-grade experimentation
    
- Creates a mechanistic story behind safety metrics
    
- Signals deep understanding of learning systems
    

---

## **Final mental anchor (remember this)**

- **Decision-Safety Lab** = _measurement of impact_
    
- **UMNN** = _mechanism of behavior_
    
- **Learning signal rework** = _internal research axis_
    

  

Two projects.

One coherent research identity.

---

### **TL;DR (vault version)**

  

You are building **one lab that measures safety outcomes** and **one model that reasons under uncertainty differently**. Everything else is a module, experiment, or chapter — not a new project.

  

If you ever feel lost, return to this sentence:

  

> _“I study how AI systems influence human decisions — and how uncertainty-aware learning can make that influence safer.”_

  

If you want, next time we can turn these notes into:

- a README
    
- a research proposal
    
- or a 2-week execution plan