# Epistemos: The Master Execution Plan (Low-Memory / Cloud-Hybrid Edition)

*This is the definitive, technically grounded architectural blueprint. It has been painstakingly audited against your actual Swift and Rust source code to guarantee that no effort is wasted on systems already built. It represents the highest echelon of cognitive OS design—intended to unequivocally win your hackathon and redefine local macOS intelligence.*

> [!IMPORTANT]
> **CRITICAL DISCLAIMER TO AI AGENTS:** Every single feature, configuration, schema, and idea detailed in this Master Plan must be comprehensively deep-researched to gain a massive coverage of potentialities before committing to a final code implementation. You must not assume the initial heuristic presented here is the only path. You are commanded to audit all edge-cases, alternative architectures, and structural trade-offs prior to writing code.

---

## 🟩 System Baseline: Verified Implementations (Do Not Rebuild)
Before executing the moats, it is vital to acknowledge the established foundations:
1. **The Native Presentation Layer:** `MetalGraphView.swift` and `PlatinumTheme` successfully deliver the minimalist, retro-Macintosh aesthetic without relying on bloated Electron/web views.
2. **The Rust ECS Physics Engine:** `simulation.rs` in `graph-engine` handles complex physics (`velocity_decay`, `alpha_decay`) in a highly optimized memory layout.
3. **Inference Scaffolding:** `MLXInferenceService.swift` is properly wired for standard MLX model loading.
4. **Harness Stubs:** `BootstrapPacketBuilder` has been built and unit-tested (`HarnessSubsystemTests.swift`), though it lacks live UI wiring.

---

## 🟥 The Core Moats: Architectural Execution Path

To transcend from a "local chatbot" into a true **Biological Cognitive Exoskeleton**, you must execute the following 16 phases.

### Phase 1: Intelligent Semantic Ontology (The Nested Knowledge Tree)
Current PKM systems fail because their "tags" are flat, naive extractions (e.g., pulling "good" or "tree"). This creates a noisy, useless graph.
*   **The Technical Shift:** Deprecate the naive string extractor in `EntityExtractor.swift`. Implement an **Ontological Classifier** using your local 3B Apple Foundation Model.
*   **Strict JSON Schema:** The model is bounded by a strict JSON schema that forces it to extract only academic, systemic, or high-signal entities, dropping all stop-words.
*   **Auto-Nesting:** The model queries its weights to establish domains. It automatically returns: `{ "parent_domain": "Neuroscience", "child_concept": "Basal Ganglia" }`. 

### Phase 2: The Organic Decay Engine (Biological Forgetting)
Vector databases treat a 5-year-old note with the same 16-bit fidelity as a 5-minute-old note. We will implement an **Ebbinghaus Decay Pipeline** in `knowledge_core` to simulate human memory.
*   *(Note: Based on past failures with Mamba/SSMs, this will be strictly powered by reliable standard Transformer architectures).*
*   **Consolidation Cron:** A Rust background thread (`tokio::spawn`) scans for "Raw Thoughts" unmodified for 7 days.
*   **Precision Right-Shift:** The local AFM 3B summarizes the thought into a dense heuristic, and the Rust backend physically degrades the vector precision from 16-bit to 8-bit (and eventually 2-bit).

### Phase 3: The Omni-CLI Native Bridge (The Terminal Killer)
Apple Design Award winners do not make users look at tmux or raw `stderr`. We will build a native orchestration bridge that completely abstracts the terminal.
*   **The PTY Daemon:** Create `agent_core/src/omni_bridge.rs`. Use `portable-pty` to spawn `claude-code`, `codex`, and `hermes` as completely invisible headless background processes.
*   **SwiftUI Translation:** Send strongly-typed events (`CLIEvent::GeneratingDiff`) across UniFFI. The frontend renders these as beautiful, translucent, retro-styled progress widgets.

### Phase 4: Full Harness Wiring (Phase 6F)
*   **The Integration:** `AgentViewModel.swift` must call `BootstrapPacketBuilder.build()` at initialization. It injects this 800-token packet as the absolute first hidden system message. This explicitly forces the agent to acknowledge its OS context and past session failures before it generates a single token.

### Phase 5: The "Hybrid-Brain" Architecture (Hackathon Winner)
Massive local models (14B+) will crash a standard Mac and burn the battery. We will split the cognitive load into two brains sharing Unified Memory.
*   **The Subconscious (Local AFM 3B):** Runs continuously. Costs ~1.5GB RAM. Handles real-time Intelligent Ontology extraction and Organic Decay.
*   **The Conscious Executive (Hermes via Cloud API):** Handles heavy reasoning without taxing the local machine. When Hermes needs context, it queries Epistemos via MCP, receiving highly compressed vectors rather than scanning the local file system.

### Phase 6: Just-In-Time (JIT) Context Injection
Dumping huge files into system prompts causes hallucination and high API costs. We will use unified memory to achieve infinite context at a fraction of the cost.
*   **Trace Interception:** The local backend monitors the Cloud Agent's `<thinking>` trace stream.
*   **Dynamic Prompt Hot-Swapping:** If the agent needs to recall a specific Raw Thought, the local AFM pauses the stream, fetches the decayed memory, expands it into a dense 50-token heuristic, and physically injects it into the Agent's system prompt mid-generation. 

### Phase 7: Hermes as "Chief of Staff" (Multi-Agent Orchestration)
Hermes is not just a chatbot; it is an OS-level router. 
*   **MCP Tool Registration:** Through `omni_bridge.rs`, register `claude-code` and `kimi` as MCP tools within Hermes (e.g., `spawn_kimi_research()`).
*   **Swarm Coordination:** When given a complex task, Hermes delegates. It spawns Kimi invisibly to research, reads the output, and spawns Claude Code invisibly to write the software. 

### Phase 8: Cognitive Depth & Meta-Analysis Markers
A flat database of notes is indistinguishable to an LLM. We must weight the knowledge graph explicitly.
*   **Depth Marker Enum:** Every note in `knowledge_core` receives a tag: `L1 (Surface/Scratchpad)`, `L2 (Synthesized/Actionable)`, or `L3 (Core Belief/Architecture)`.
*   **Meta-Analysis Edges:** The local AFM draws dynamic graph edges connecting a Raw Thought directly to the *Current Active Task* or *Current Session State*.

### Phase 9: High-Performance Session Distillation (Telemetry JSON)
The current session summarizer uses naive text generation, which is difficult for agents to parse later.
*   **Structured Telemetry:** At the end of a session, a Rust thread triggers the AFM 3B with a strict JSON schema. It extracts explicit, dense insights: `decisions_made`, `unresolved_friction`, and `active_themes`.

### Phase 10: Model Metabolism & Overnight Consolidation (NightBrain)
Models should not be generic; they should structurally adapt to your psychology over time.
*   **Deep Sleep Auditing:** At 3:00 AM, a Rust cron job wakes up the AFM 3B. It audits every prompt, edit, and rejection you made that day.
*   **Emotional Weighting:** It looks for behavioral friction and generates a `salience_weights.json` in the model's vault.
*   **Re-Contextualization:** The next morning, the Agent loads this Metabolized Profile. It has evolved overnight to mirror your auditing style and aesthetic preferences.

### Phase 11: Omni-Contextual Brain Dumps (Epistemic Anchors)
Text alone cannot capture the nuance, speed, and emotional state of human thought. You need an omnipresent voice anchor.
*   **The Global Mechanism:** In any chat, any note, or any context, a native, minimalist dictation button is available. Pressing it triggers `SFSpeechRecognizer` with a premium Metal waveform overlay.
*   **Epistemic Anchoring:** You dictate an unfiltered "Brain Dump". This is not saved as a loose note. It is physically bound via the Rust graph to the exact `chat_id` or `note_id` you were looking at. 

### Phase 12: Cognitive Data Structures (The End of "Dumb Markdown")
Relying purely on flat `.md` files is a fatal flaw for advanced AI. LLMs struggle to infer the exact emotional weight and importance of a raw paragraph of text. We will completely abandon "dumb markdown" in favor of Cognitive Data Structures.
*   **The Mechanism (Interpretation Directives):** Every applicable text entity in your vault is now backed by a strictly-typed `[Entity].epistemos.json` file. This file holds explicit instructions on how the AI should *feel* and *interpret* the data (e.g., `{"interpretation_directive": "CRITICAL: This is an L3 Core Belief."}`).
*   > [!WARNING]
    > **CRITICAL DISCLAIMER (The Codebase Exclusion Rule):** This structured formatting mechanism MUST NEVER apply to source code files (`.swift`, `.rs`, `.py`, `.json`, etc.). Modifying a code file by prepending YAML front-matter or injecting interpretation directives directly into the file will corrupt the compilation environment. 

### Phase 13: The Unstructured Data Audit (ETL Transformation)
Because your app currently ingests loose text via `TextCapturePipeline.swift` and `VaultLifecycleService.swift`, there is a high risk of legacy, unstructured data polluting the AI's reasoning. You must implement a Vault-Wide Auditing Pass to guarantee perfect structure.
*   **The Mechanism (Background ETL):** A background Rust chron job crawls the entire vault directory. It specifically targets any loose `.md` files, plaintext, or raw PDFs that lack the strict `[Entity].epistemos.json` sidecar structure defined in Phase 12.
*   **Local AI Transformation:** When it finds an unstructured file, it passes the raw text to the local AFM 3B model via MLX. The local model is prompted with a strict schema to automatically deduce the Depth Marker, Emotional Valence, and Meta-Analysis Edges based on the text. It writes out the missing JSON interpretation file automatically.
*   > [!WARNING]
    > **CRITICAL ETL SAFETY RULE:** The background crawler must have a hardcoded exclusion list (`.git`, `.build`, all programming languages). The ETL pipeline is strictly for structuring the user's human-readable knowledge graph.

### Phase 14: The Intake Valve (Real-Time Structural Routing)
Instead of relying purely on an asynchronous background ETL pass to clean up messy data later (Phase 13), you implement a synchronous **Intake Valve**. This completely stops unstructured data from ever entering your core knowledge graph.
*   **The Synchronous Intercept:** When you dictate a Brain Dump or paste a massive wall of text into the app, it does not immediately save to the vault. The raw input is intercepted by your local Apple Foundation Model 3B. 
*   **Real-Time Structuring & Verification:** The local model instantly parses your messy, unstructured ramble and builds the pristine `[Entity].epistemos.json` file on the fly. It deliberates on the extracted data to verify the ontology against your existing graph before saving.

### Phase 15: The Deterministic Core vs. Ambient Retrieval Protocol (The Raw Thoughts Solution)
If the system must have NO messy data to guarantee deterministic, error-free reasoning, what do we do with the beautiful, chaotic, highly-emotional Raw Thoughts? We separate them entirely.
*   **1. The Deterministic Core (Default State):** The local Intake Valve extracts metadata and saves *only* the highly-structured JSON. The actual chaotic text of the "Raw Dump" is saved strictly as a latent data point in a quarantined `/RawThoughtsArchive`. Hermes *never* sees messy data by default.
*   **2. The Ambient Retrieval Protocol (The "Messy Sandbox"):** When toggled ON, Epistemos dynamically unlocks the `/RawThoughtsArchive`. It allows Hermes to perform "Ambient Retrieval," reading the deeply unstructured, raw, messy human ramblings to make bizarre, profound creative connections.

### Phase 16: Structured Conversation State (The End of the Linear Chat Log)
Standard AI applications suffer from severe context degradation because they simply append every new message to a massive linear string. Mid-conversation, the model forgets the *why* of the chat and loses the emotional nuance. We will entirely reimagine how conversation context is handled.
*   **The Mechanism (Real-Time State Machine):** Your conversation history is no longer an array of raw strings. The local AFM 3B acts as a real-time stenographer, auto-saving the conversation as a continuously updating, strictly-typed `conversation_state.epistemos.json`.
*   **The State File:** It tracks: `Active Thesis`, `Resolved Nodes`, `Emotional Trajectory`, and a highly-compressed semantic vector of the chat history.
*   **The Moat:** When you send a message mid-conversation, Hermes doesn't receive a 50-page raw transcript. It receives your newest message plus the highly-structured `conversation_state.epistemos.json`. It never repeats past mistakes and adjusts its tone dynamically based on your current friction levels.

---

## 🔬 EPILOGUE: The Deep Research Mandate

The 16 phases outlined above constitute a foundational blueprint. However, architectural implementation cannot be built on naive assumptions.

Before executing any specific phase, the AI Agent must enter a **Deep Research Protocol**. 
1.  **Exhaustive Potentiality Coverage:** Every configuration, JSON schema, and system integration must be rigorously researched against multiple potential outcomes. 
2.  **Structural Verification:** Do not assume a proposed schema is computationally optimal until it has been vetted against macOS constraints, Apple Unified Memory profiles, and Rust/Swift FFI latency thresholds.
3.  **Mandatory Deliberation:** The AI must outline trade-offs and alternative architectures for every specific feature before committing to code generation. 

---

## 📜 Appendix: Raw Thoughts (User Prompts)

*The following are the raw user inputs that seeded this architectural analysis. They are retained here as an epistemic anchor to preserve the original creative intent.*

> **Prompt 1:** analyze my app read hte acual code let me know how it compares to an app like obsidian logseq or hermes agent. amd do u think could win an apple desing award when i release it officially its like a if apple desinged an oobsiidan app. here are screenshots of the design. its deliberately inimal and kinda retro esc a call back to the orgiinal machintosch.its only one ut i do have ore but i want you to scan the codebase dont code but give me your analysis ... also this seems important for performance what does this mean - ## Wave 2.4 verification summary ... Can you verify to make sure all of these features are actually in the app do not code I want you to just deeply scan it to make sure it's truly into end wired and created do not code. Just give me your analysis when you're done and give me deep advice, and I want you to deep resources as well. Give me deep advice on how to proceed and how to make sure I implement all of all of it on the boat stuff that we live in that's inside the north the north star document please read all the other documents and see what's missing. What is the moat missing moat. read research in /jojo/Downloads all relevant research related to code editor, agetn owrk, performacne etc. hot pathsk, etc. i have nested folders as well please fidn a way to grep and search the best most relevant docs and research to the current state of ym app to upgrade to the next level. do not code just give me deep analysis

> **Prompt 2:** so i want to utilzie system prompts in this as well but ut should not be the only thing thzt drives behavior. even with raw thoughts and the eposh thing where notes lose relevence over time i want to do this with the. raw thoughts as well if a user or model does not engage with similar thoughts the output raw thoight will degrade the menaing it should still keep the note but it should simualte the naturral way humasn fprget thigns while pruning and keeping the absolute best of it all. i want my app to take hermes agent to the nxt level by combining y memory with its memoruy and findng novel ways that atrue native only a true native app can do with hermes agent. that is what im after but still being minimal this app is dedicated towards ppl who want to use hermes agent but hate fake manually coded interfaces and hate terminal TUI CLI this is a new approach by truyly making it actually 100% all capabilities passes trhorugh my app directly. it should feel like magic and true usefulness please deliberate on this information do not code just add this top your analysis and please reseach ways i can truly take hermes agent to the next lvel i will be combining hermes aginetint4egrating the CLI into my app whiel aslo havng kimi cladue code codex as well and cli hermes and a local coding local claude code alt for the local models i have as well xo please resaerc hall of this. is like a different thing im doing do not code jsut give me deep analysis on how to truly produce multiple award worthy moats.

> **Prompt 3:** One more thing I wanna add and I want this to be added to the plan so the document that you gave me, I want you to add some parts that speak to this, but in my app in my app, there is a mechanism where Notes and things are like flagged with concepts and concepts are extracted from notes and things, but it's really dumb like there's concepts titled good Free just regular verbs and nouns and I wanted to actually be real concepts like phenomenology neuroscience basal ganglia basal ganglia should be under the concept of neuroscience. It should be nested like that so I want that system to be more robust and more smarter do not code anything. I just want you to add this to the analysis and add it to the actual plan yeah

> **Prompt 4:** Now I want you to rescan the code base with him and juxtapose it to the entire conversation. Here we talked about a lot and I want you to write an updated master plan Doc that has all the things we talked about including the latest Epistemos native memory mode document I wanted to have all the things I should add to my app minus the things that are already implemented so you should reread the code base like the actual code base. Do not read just an MD files in the plans actual actually read the actual code to verify that it's actually there in wired in working do not code anything just give me your analysis and tell me what I need to add to.

> **Prompt 5:** One more thing I could add, I could use Apple foundation models, and maybe some other seelct small models that are good just for this. want you to deep research the vesst mdoels and best tools for this. also research on how to implement a bridge from apple unifieed meomory apple foundation models and select helpder small models maybe some ssm or such models or jsut what my app has currently, and then expound on how i could connect them to hermes agent and win the hackathon. do not code just update the doc with thsi please.

> **Prompt 6:** my mac cant run some of the local models so take out the large on idk if i can run the hermes

> **Prompt 7:** ohe more thing and i want you to add this to the doc as well but i want you to research super sophsticated wasy to truly decrease token usage and complexuty by offloading the caapbikitiewis to my app unified memory, etc. and vualt notes and the concept extractions even in raw thoughts when agetn want to reference raw thoughts or even when they start thinking the app can dynamicallu feed some systme prompts to the model to load some deeper analysis from lreviius session meoyr and raw thoughts with approrpiate decay and concept extraction nad embeddings. lastly i wnt you to research a way for hermes agent to be this really interesting bridge to maek all of this work and also connevct to the codex claude and kimi clis and hermes cli as well obviously. still dont code add this to hte analyis and docx

> **Prompt 8:** and each note and stuff should be embedded with a depth marker as well. and nested depth meta analysis markers and raw thoughts connected to notes themsselves tasks themeselvews sessions tates, etc. so add that as well research it make sure it. is grounded. there is one mroe thing i nmy app i want to audit that has two parts this should als obe very expliciit in the planmaster plan. make sure everything is i the one master plan dooc. But, when i use the app and it summarizes current session it does not do it smart either it was poorly implemented and i wnat you to research a way to make it super high perf native and much smarter as well and also make sure that the agents have better systems prompts and file JSONS and passed files with current session isnghts and context that is actually useful. and i i the past i tried using SSM but wat as good so maybe i can reintroduce that but that sshould not be a mmian thng in this doc becasue it faield before

> **Prompt 9:** One more thing I wanna add and please add this to the plan as well is that I want there to be a feature where any model since I already have like model specific votes I want every model to be able to metabolize user inputs retrain itself on the inputs on the type of prompts that user uses on the type of auditing patterns that the user uses, and then the next morning it saves a memory consolidation folder of all of the recontextualize and re-understood prompts to give them actual real context and real weighted emotional depth, and salines importance to them

> **Prompt 10:** I also want there to be a feature. We're on any chat and of course I have this on any note but I wanna make it more robust and extend it to any chat as well and make it robust generally, but I want that to be a button where you can add a brain dump to anything any context so when youre literally chatting with something, you can press a button and it'll take your you can dictate so literally speak out a brain dump and it'll save save that brain dump to the context of the note or whatever or whatever you were doing so that chat it saved as like a awaited emotional and epistemic brain dump. It's like a data data sit or data anchor for that particular type of context so add that to the plan as well research it and do a last-minute scan cause the Doc still does not feel robust enough. It doesn't feel nuance and deep enough and I added a bunch of stuff also at the bottom of it I want you to take all of the queries I sent in this chat and added to the bottom, there should be a raw thoughts portion inside the document and I want to have every single prompt I sent in this chat

> **Prompt 11:** Instead of like text documents or markdown files, I want there to be like a system that has like specific structured files so like JSONs, front matter things like that like specific files that tell that they better tell the AI how to read or interpret data based off of like emotional anchors in depth signals.

> **Prompt 12:** testing testing one more thing to add and I want this to be like an auditing pass or auditing phase as well. I want there to be a check to make sure that all the structured data points that are fed to the AI are in structure as possible so if there are things that are text are plain text or markdown that can be converted or PDF that can be converted to a more structured file or a structure set of files like a folder or a file system. I wanted to do that and I want this to be like a entire code base auditing so and I want you to research best practices to make this happen rescan the code base for all the parts that dish would mainly be apropos to and added it to the master Doc as well.

> **Prompt 13:** one more thing is that there are certain files that should never have specific added values or embedding because they will corrupt it like certain coding files or maybe all coding files may be except for a marked down in plain text and things like that should not have like added code to it to change the structure of the ontology of it because that will break the file of course so make sure that's also disclaimer inside the plane as well

> **Prompt 14:** One more thing testing testing testing one more thing I wanna add to the plan and also for you to research is that see if there's a way to have a local model take what you input for the brain or for like structured outputs and then it creates files instruction and structures the data, and then saves it and stores it to be used and then raw stuff can be maybe even saved to the raw thoughts, pipeline, or just discarded it completely, but add this as like a recommendation or a suggestion inside the dog as well

> **Prompt 15:** Testing testing testing also lasting in at this to the dark I want the app to have no messy data so everything should be structured as deterministic as it can be, but also something that models can't deliberate on somewhere in the process to make it more structured and make it more make it have more of verification to it, but when you input raw information, the raw should only be used as like data points in like depth, signals, and things of that that nature, but how, but their actual use cases should be resource as well because I don't I don't know how I should utilize that particular pipeline the Roth thought thing but the app should send structured data unless it's something that's deliberately un structured for a Granger the reason Granger arbitrary reason. this makes sure errors are not likely to happen but havig the abiity to still input super raw meess ydata and even have that messy data auditted referenced and re referenced and tagged with complexity for ambient rretriveial when it is necessary if the user chooses to togglethis sp4ccfic ambient feature set. please add this to the doc finalize the doc ake sure it is robust and detaield enough to addd this to deep research.

> **Prompt 16:** One more idea, I want to add to the plan is that I want to re-imagine context based off of the conversation history so in so I want there to be a mechanism in my app where the conversation history is auto saved as like a as a document in that document is auto generated as a JSON or as a structure file set that the model can read mid conversation to analyze better than it would have had it just used regular conversation history and context buildup, but it should really be robust. It should have depth, signals, emotional anchors, etc. should have still the common compaction, prompt, and all that, but it should be engineered to be a little bit more robust than that.

> **Prompt 17:** add this to the doc and please add it to a section to be deep researched also add a ddisclaier to the plan wehre it tells ai that every singel feature and config and shema and idea needs to be deep researched to gain a large coverage of potentilaities.
