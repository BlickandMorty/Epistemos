---
id: 6FF1F844-4853-4DFE-A3D2-4624FA1F9FEC
title: how to read files
---

When you open a new file, do this in order:

**1. What does this file DO?** Look at function names. `get_metadata` = gets metadata. `run_audit` = runs an audit. The names tell you.

**2. What is it bringing IN?** Look at the top: imports tell you what tools it's using. Look at function parameters: that's what data comes in.

**3. What is it spitting OUT?** Find every `return` statement. That's the output.

**4. Where does something start and end?** Find the entry point (`if __name__` or the first function called). Trace it until the last `return` or `print`.

**5. What is repeated?** Find `for` loops. They mean "this block runs multiple times." Ask: "what changes each time?" That's the variable in the loop (`col`, `count`).

**6. What could fail?** Find `try/except`. The code inside `try` is risky (reading files, API calls). If it fails, `except` catches it and handles it gracefully instead of crashing.