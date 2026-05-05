---
id: EA698099-A1F4-41FE-9841-89FE617D0570
title: future udate for PFC
---

ok so a future update for this app is the Phase B Deviations — Should You Add Them?

1. Shared Learning Protocol Extraction (B.5)

- What's missing: Plan said create lib/notes/learning-runner.ts as a shared module, then refactor both the SSE route (app/api/notes-learn/route.ts) and the daemon task to call it. Instead, the daemon has its own self-contained copy.
    
- Impact: ~200 lines of duplicated logic. If you change a learning step, you'd need to update both files.
    
- Should you add it? Not now. The two consumers have fundamentally different I/O — the SSE route streams to browser, daemon writes SQLite. Extracting a shared core means adding an abstraction layer (callback/event emitter) that adds complexity for minimal gain. Both share learning-prompts.ts already, so prompt changes propagate automatically. Revisit if you ever add a 3rd consumer. i want to save this in my notes as a future feature i can implement.

another feature that u can drag and drop pdfs images and entire wbesites like links and stuff and it will just instantly get on the notes. so the note system of this app isvery robust and deeply integrated with websites like you can get lots of meta data insights from websites or jus paste a link and u can be prompted to have it write the entire article or the paper and poplate it to your note.