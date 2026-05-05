### Core changes to make on all my products:
1. **the thing:** If your config.py is empty, you likely have HARDCODED values (URLs, Port numbers, file paths) scattered inside your logic.
2. **The Fix:** Find any variable that might change depending on where the app runs (e.g., PORT = 5000 or DB_PATH = "data/db.sqlite") and move them to config.py.
3. **The Benefit:** It makes your code "Environment Agnostic"—meaning it can run on any machine without rewriting the internal logic.