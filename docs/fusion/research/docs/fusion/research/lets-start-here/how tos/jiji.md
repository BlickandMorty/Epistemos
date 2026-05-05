---
id: AF5EB0DD-2F12-4543-B221-6EC3B40040D7
title: jiji
---

 [[outdated - notes for future projects]]
### Core changes to make on all my products:
1. **the thing:** If your config.py is empty, you likely have HARDCODED values (URLs, Port numbers, file paths) scattered inside your logic.
2. **The Fix:** Find any variable that might change depending on where the app runs (e.g., PORT = 5000 or DB_PATH = "data/db.sqlite") and move them to config.py.
3. **The Benefit:** It makes your code "Environment Agnostic"—meaning it can run on any machine without rewriting the internal logic.
## Preliminary brain dump before more structured notes...
I think most of my files I have config.py files but there’s not much in those files on my projects I’m afraid I built the apps without using config in mind am I okay also what would I need to do to make them better by using config also that’s an edit I can make to my project. But using GitHub when I want to document an update what’s the process I know I code it but I guess I should have an old and new project version then write what I changed or what exactly is the process including commit comments and updates read mes. Also branching I need to know everything about this concept: Branching: Never work directly on the main branch. Use feature/login-ui and then use Pull Requests to merge them. This mimics a real engineering workflow.

Also this: GitHub Actions: Add a simple .yml file in .github/workflows to run your tests automatically when you push code. This is a massive "hire me" signal.

This seems very important yet not common very novel so thi as well: Containerization: Include a Dockerfile. This ensures your project runs on their machine exactly like it does on yours.

TL;DR: Focus on Readability (README), Environment Isolation (Docker/venv), and Version Control History (Clean commits). Quality over quantity—pick your best 3 projects and "polish them to death."

But yea this entire answer seems like all the main things I need to make sure I have down pack.

## more structured notes to come back too but still unfinished...
Refining Engineering Workflow
TL;DR: Transitioning from a "coder" to an "engineer" involves moving logic into configurations, using Git as a historical log rather than a backup, and automating your quality checks.
🧠 Refactoring with config.py
If your config.py is empty, you likely have HARDCODED values (URLs, Port numbers, file paths) scattered inside your logic.
 * The Fix: Find any variable that might change depending on where the app runs (e.g., PORT = 5000 or DB_PATH = "data/db.sqlite") and move them to config.py.
 * The Benefit: It makes your code "Environment Agnostic"—meaning it can run on any machine without rewriting the internal logic.
🌿 Master the Branching Workflow
You do not keep "old and new" versions of project folders. Git handles the history for you. Use the Feature Branch Workflow:
 * START: Ensure you are on main and it's up to date.
 * BRANCH: Run git checkout -b feature/add-logging. You are now in a "parallel universe."
 * CODE: Make your changes.
 * COMMIT: Use the Conventional Commits style: feat: add logging to api calls.
 * PUSH: git push origin feature/add-logging.
 * PULL REQUEST (PR): On GitHub, click "Compare & pull request." Write a summary of what changed.
 * MERGE: Once you're happy, merge the PR into main.
🤖 Automation & Portability
 * GitHub Actions (.yml): Think of this as a robot that wakes up every time you push code. It installs your dependencies and runs your tests. If the robot fails, it puts a RED X on your commit. If it passes, a GREEN CHECK. Employers love seeing those green checks; it proves your code isn't broken.
 * Docker (Dockerfile): This is a blueprint for a "virtual computer." Instead of telling an employer "Install Python 3.10 and these 50 libraries," you give them a Dockerfile. They run one command, and your app launches in a container exactly as it does on your screen.
🛠️ The "Polishing" Checklist
To "polish to death" your top 3 projects, ensure they have:
 * Clean main branch (only working code).
 * A tests/ folder with at least basic logic checks.
 * A .github/workflows/main.yml to run those tests.
 * A Dockerfile to make it portable.
 * A README that looks like a professional product manual.
TL;DR: Stop thinking about "folders" and start thinking about "branches." Use config.py to remove hardcoded values and GitHub Actions to prove your code works.
Check for Understanding: Would you like me to provide a specific Dockerfile template or a GitHub Action .yml script for one of your Python projects?