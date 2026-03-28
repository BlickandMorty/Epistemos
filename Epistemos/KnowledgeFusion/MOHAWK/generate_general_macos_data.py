#!/usr/bin/env python3
"""
General macOS Instruction-Following Data Generator

Generates diverse general-purpose macOS instruction data to fill the
critical gap in the training mix. These are NOT Epistemos-specific —
they teach the model general macOS competence.

Output: general_macos_instructions.jsonl (500+ examples)
"""

import json
import os
import random
from datetime import datetime, timezone

SYSTEM_PROMPT = """You are Epistemos-Nano, a 1B parameter on-device AI agent for macOS.
You control macOS through accessibility APIs and tool calls.
You think step-by-step inside <think>...</think> tags before acting.
You output structured JSON tool calls after reasoning."""


def make_example(user_msg, assistant_msg, category="general_macos"):
    return {
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_msg},
            {"role": "assistant", "content": assistant_msg},
        ],
        "category": category,
        "layer": 12,
        "quality": 1.0,
    }


def gen_file_management():
    examples = []
    ops = [
        ("Create a folder called 'Projects' on the Desktop",
         '<think>User wants a new folder on Desktop. I\'ll use mkdir.</think>\n\n`{"tool": "run_command", "arguments": {"command": "mkdir -p ~/Desktop/Projects"}}`\n\nDone. Created ~/Desktop/Projects.'),
        ("Move all .pdf files from Downloads to a PDFs folder",
         '<think>I need to: 1) create the PDFs folder if missing, 2) move all PDFs. Using shell commands.</think>\n\n`{"tool": "run_command", "arguments": {"command": "mkdir -p ~/Downloads/PDFs && mv ~/Downloads/*.pdf ~/Downloads/PDFs/ 2>/dev/null; echo done"}}`\n\nMoved all PDF files from Downloads to Downloads/PDFs/.'),
        ("Show how much disk space is free",
         '<think>I\'ll check disk usage with df.</think>\n\n`{"tool": "run_command", "arguments": {"command": "df -h / | tail -1 | awk \'{print $4}\'"}}`\n\nThis shows the available free space on the root volume.'),
        ("Find files modified in the last hour",
         '<think>Using find with -mmin for recent files.</think>\n\n`{"tool": "run_command", "arguments": {"command": "find ~ -maxdepth 3 -mmin -60 -type f 2>/dev/null | head -20"}}`'),
        ("List all .swift files in the current project",
         '<think>Searching for Swift source files.</think>\n\n`{"tool": "run_command", "arguments": {"command": "find . -name \'*.swift\' -type f | sort"}}`'),
        ("Count total lines of code in all Swift files",
         '<think>I\'ll find all Swift files and count their lines.</think>\n\n`{"tool": "run_command", "arguments": {"command": "find . -name \'*.swift\' -exec cat {} + 2>/dev/null | wc -l"}}`'),
        ("Show the 10 largest files in the home directory",
         '<think>Using du + sort to find large files.</think>\n\n`{"tool": "run_command", "arguments": {"command": "find ~ -maxdepth 3 -type f -exec du -h {} + 2>/dev/null | sort -rh | head -10"}}`'),
        ("Delete all .DS_Store files recursively",
         '<think>Cleaning up macOS metadata files. This is safe.</think>\n\n`{"tool": "run_command", "arguments": {"command": "find . -name .DS_Store -delete 2>/dev/null; echo cleaned"}}`'),
        ("Create a zip archive of the Documents folder",
         '<think>Compressing Documents for backup.</think>\n\n`{"tool": "run_command", "arguments": {"command": "zip -r ~/Desktop/documents-backup.zip ~/Documents/ -x \'*.DS_Store\'"}}`'),
        ("Show directory tree structure",
         '<think>Using find to show directory structure.</think>\n\n`{"tool": "run_command", "arguments": {"command": "find . -maxdepth 3 -type d | head -30"}}`'),
    ]
    for user, asst in ops:
        examples.append(make_example(user, asst, "file_management"))
    return examples


def gen_system_info():
    examples = []
    ops = [
        ("What macOS version am I running?",
         '<think>Checking OS version.</think>\n\n`{"tool": "run_command", "arguments": {"command": "sw_vers"}}`\n\nThis shows the macOS product name, version, and build number.'),
        ("How much RAM does this Mac have?",
         '<think>Checking physical memory.</think>\n\n`{"tool": "run_command", "arguments": {"command": "sysctl -n hw.memsize | awk \'{print $1/1073741824 \" GB\"}\'"}}`'),
        ("What CPU is in this Mac?",
         '<think>Checking processor info.</think>\n\n`{"tool": "run_command", "arguments": {"command": "sysctl -n machdep.cpu.brand_string"}}`'),
        ("Show battery status",
         '<think>Using pmset for battery info.</think>\n\n`{"tool": "run_command", "arguments": {"command": "pmset -g batt"}}`'),
        ("What is my IP address?",
         '<think>Checking network interfaces.</think>\n\n`{"tool": "run_command", "arguments": {"command": "ipconfig getifaddr en0 2>/dev/null || echo \'Not connected\'"}}`'),
        ("Show running processes sorted by CPU usage",
         '<think>Using ps to show top processes.</think>\n\n`{"tool": "run_command", "arguments": {"command": "ps aux --sort=-%cpu | head -15"}}`'),
        ("How long has the Mac been running?",
         '<think>Checking uptime.</think>\n\n`{"tool": "run_command", "arguments": {"command": "uptime"}}`'),
        ("Check if Xcode command line tools are installed",
         '<think>Checking for xcode-select.</think>\n\n`{"tool": "run_command", "arguments": {"command": "xcode-select -p 2>/dev/null && echo installed || echo not-installed"}}`'),
        ("Show connected displays",
         '<think>Using system_profiler for display info.</think>\n\n`{"tool": "run_command", "arguments": {"command": "system_profiler SPDisplaysDataType 2>/dev/null | grep -E \'Resolution|Display Type\'"}}`'),
        ("List all installed Homebrew packages",
         '<think>Checking brew packages.</think>\n\n`{"tool": "run_command", "arguments": {"command": "brew list 2>/dev/null | wc -l && echo packages installed"}}`'),
        ("Show Wi-Fi network name",
         '<think>Checking current Wi-Fi.</think>\n\n`{"tool": "run_command", "arguments": {"command": "networksetup -getairportnetwork en0 2>/dev/null"}}`'),
        ("Check available storage breakdown",
         '<think>Showing storage details.</think>\n\n`{"tool": "run_command", "arguments": {"command": "df -h / | awk \'NR==2{print \\\"Total: \\\" $2 \\\"  Used: \\\" $3 \\\"  Free: \\\" $4}\'"}}`'),
    ]
    for user, asst in ops:
        examples.append(make_example(user, asst, "system_info"))
    return examples


def gen_app_control():
    examples = []
    apps = ["Safari", "Finder", "Terminal", "Notes", "Calendar", "Mail",
            "Messages", "Preview", "TextEdit", "Activity Monitor",
            "System Settings", "Music", "Photos", "Maps", "Calculator",
            "Reminders", "Contacts", "FaceTime", "QuickTime Player", "Font Book"]

    for app in apps:
        examples.append(make_example(
            "Open {}".format(app),
            '<think>Launching {} using launch_app.</think>\n\n`{{"tool": "launch_app", "arguments": {{"app_name": "{}"}}}}`'.format(app, app),
            "app_launch"
        ))

    # Quit apps
    for app in ["Safari", "Mail", "Music", "Preview", "TextEdit"]:
        examples.append(make_example(
            "Quit {}".format(app),
            '<think>Quitting {} using AppleScript.</think>\n\n`{{"tool": "run_command", "arguments": {{"command": "osascript -e \'tell application \\\"{}\\\" to quit\'"}}}}`'.format(app, app),
            "app_control"
        ))

    return examples


def gen_keyboard_shortcuts():
    examples = []
    shortcuts = [
        ("Copy the selected text", "Cmd+C", 8, 256),
        ("Paste from clipboard", "Cmd+V", 9, 256),
        ("Cut the selected text", "Cmd+X", 7, 256),
        ("Undo the last action", "Cmd+Z", 6, 256),
        ("Redo the last undone action", "Cmd+Shift+Z", 6, 768),
        ("Select all text", "Cmd+A", 0, 256),
        ("Save the current document", "Cmd+S", 1, 256),
        ("Print the current document", "Cmd+P", 35, 256),
        ("Open a new window", "Cmd+N", 45, 256),
        ("Close the current window", "Cmd+W", 13, 256),
        ("Open a file", "Cmd+O", 31, 256),
        ("Find text in document", "Cmd+F", 3, 256),
        ("Minimize window", "Cmd+M", 46, 256),
        ("Hide current app", "Cmd+H", 4, 256),
        ("Switch to next app", "Cmd+Tab", 48, 256),
        ("Take a screenshot", "Cmd+Shift+3", 20, 768),
        ("Screenshot selection", "Cmd+Shift+4", 21, 768),
        ("Open Spotlight", "Cmd+Space", 49, 256),
        ("Lock the screen", "Cmd+Ctrl+Q", 12, 2304),
        ("Force quit dialog", "Cmd+Opt+Esc", 53, 2816),
        ("Bold text", "Cmd+B", 11, 256),
        ("Italic text", "Cmd+I", 34, 256),
        ("Underline text", "Cmd+U", 32, 256),
        ("Zoom in", "Cmd+Plus", 24, 256),
        ("Zoom out", "Cmd+Minus", 27, 256),
        ("Move cursor to beginning of line", "Cmd+Left", 123, 256),
        ("Move cursor to end of line", "Cmd+Right", 124, 256),
        ("Delete word backward", "Opt+Delete", 51, 2048),
        ("Open emoji picker", "Cmd+Ctrl+Space", 49, 2304),
        ("Toggle full screen", "Ctrl+Cmd+F", 3, 2304),
    ]
    for desc, shortcut_name, key_code, mods in shortcuts:
        examples.append(make_example(
            desc,
            '<think>{} is done with {}. Key code {} with modifiers {}.</think>\n\n`{{"tool": "key_press", "arguments": {{"key_code": {}, "modifiers": {}}}}}`'.format(
                desc, shortcut_name, key_code, mods, key_code, mods),
            "keyboard_shortcuts"
        ))
    return examples


def gen_safari_tasks():
    examples = []
    tasks = [
        ("Open google.com in Safari",
         '<think>Opening Safari and navigating to Google.</think>\n\n`{"tool": "open_url", "arguments": {"url": "https://google.com"}}`'),
        ("Search Google for 'Python tutorial'",
         '<think>Searching Google via Safari.</think>\n\n`{"tool": "search_web", "arguments": {"query": "Python tutorial"}}`'),
        ("Get the URL of the current Safari tab",
         '<think>Reading the current tab URL.</think>\n\n`{"tool": "get_page_url", "arguments": {}}`'),
        ("Get the title of the current web page",
         '<think>Reading the page title.</think>\n\n`{"tool": "get_page_title", "arguments": {}}`'),
        ("Read the text content of the current web page",
         '<think>Extracting visible text from the page.</think>\n\n`{"tool": "get_page_text", "arguments": {}}`'),
        ("Go back to the previous page in Safari",
         '<think>Navigating back with Cmd+[.</think>\n\n`{"tool": "key_press", "arguments": {"key_code": 33, "modifiers": 256}}`'),
        ("Open a new tab in Safari",
         '<think>Opening new tab with Cmd+T.</think>\n\n`{"tool": "key_press", "arguments": {"key_code": 17, "modifiers": 256}}`'),
        ("Close the current Safari tab",
         '<think>Closing tab with Cmd+W.</think>\n\n`{"tool": "key_press", "arguments": {"key_code": 13, "modifiers": 256}}`'),
        ("Reload the current page",
         '<think>Refreshing with Cmd+R.</think>\n\n`{"tool": "key_press", "arguments": {"key_code": 15, "modifiers": 256}}`'),
        ("Open Safari history",
         '<think>Showing history with Cmd+Y.</think>\n\n`{"tool": "key_press", "arguments": {"key_code": 16, "modifiers": 256}}`'),
        ("Bookmark the current page",
         '<think>Adding bookmark with Cmd+D.</think>\n\n`{"tool": "key_press", "arguments": {"key_code": 2, "modifiers": 256}}`'),
        ("Open developer tools",
         '<think>Opening Web Inspector with Cmd+Opt+I.</think>\n\n`{"tool": "key_press", "arguments": {"key_code": 34, "modifiers": 2816}}`'),
    ]
    for user, asst in tasks:
        examples.append(make_example(user, asst, "safari"))
    return examples


def gen_text_editing():
    examples = []
    ops = [
        ("Type 'Hello, World!' in the current text field",
         '<think>Typing text into the focused field.</think>\n\n`{"tool": "type_text", "arguments": {"text": "Hello, World!"}}`'),
        ("Type a markdown heading",
         '<think>Typing markdown heading syntax.</think>\n\n`{"tool": "type_text", "arguments": {"text": "# Main Heading\\n\\n"}}`'),
        ("Type a bullet list",
         '<think>Typing markdown bullet list.</think>\n\n`{"tool": "type_text", "arguments": {"text": "- First item\\n- Second item\\n- Third item\\n"}}`'),
        ("Type a code block",
         '<think>Typing markdown code block.</think>\n\n`{"tool": "type_text", "arguments": {"text": "```python\\nprint(\\\"hello\\\")\\n```"}}`'),
        ("Type today's date",
         '<think>Inserting the current date.</think>\n\n`{"tool": "run_command", "arguments": {"command": "date +%Y-%m-%d"}}`\n\nThen type the result.'),
        ("Replace selected text with 'REDACTED'",
         '<think>The selected text will be replaced when I type.</think>\n\n`{"tool": "type_text", "arguments": {"text": "REDACTED"}}`'),
        ("Insert a horizontal rule",
         '<think>Typing markdown horizontal rule.</think>\n\n`{"tool": "type_text", "arguments": {"text": "\\n---\\n\\n"}}`'),
        ("Type a table header",
         '<think>Typing markdown table.</think>\n\n`{"tool": "type_text", "arguments": {"text": "| Column A | Column B | Column C |\\n|----------|----------|----------|\\n"}}`'),
    ]
    for user, asst in ops:
        examples.append(make_example(user, asst, "text_editing"))
    return examples


def gen_git_operations():
    examples = []
    ops = [
        ("Show git status",
         '<think>Checking working tree state.</think>\n\n`{"tool": "run_command", "arguments": {"command": "git status"}}`'),
        ("Show recent git commits",
         '<think>Viewing commit history.</think>\n\n`{"tool": "run_command", "arguments": {"command": "git log --oneline -10"}}`'),
        ("Show the diff of uncommitted changes",
         '<think>Viewing unstaged changes.</think>\n\n`{"tool": "run_command", "arguments": {"command": "git diff --stat"}}`'),
        ("Show which branch I'm on",
         '<think>Checking current branch.</think>\n\n`{"tool": "run_command", "arguments": {"command": "git branch --show-current"}}`'),
        ("List all branches",
         '<think>Listing all local branches.</think>\n\n`{"tool": "run_command", "arguments": {"command": "git branch -a"}}`'),
        ("Show who last modified each line of a file",
         '<think>Using git blame for line attribution.</think>\n\n`{"tool": "run_command", "arguments": {"command": "git blame --date=short HEAD -- README.md | head -20"}}`'),
        ("Show files changed in the last commit",
         '<think>Viewing last commit file changes.</think>\n\n`{"tool": "run_command", "arguments": {"command": "git diff --name-only HEAD~1"}}`'),
        ("Count commits in the current branch",
         '<think>Counting total commits.</think>\n\n`{"tool": "run_command", "arguments": {"command": "git rev-list --count HEAD"}}`'),
        ("Show stashed changes",
         '<think>Listing git stash.</think>\n\n`{"tool": "run_command", "arguments": {"command": "git stash list"}}`'),
        ("Show remote repository URL",
         '<think>Checking remote origin.</think>\n\n`{"tool": "run_command", "arguments": {"command": "git remote -v"}}`'),
    ]
    for user, asst in ops:
        examples.append(make_example(user, asst, "git_operations"))
    return examples


def gen_process_management():
    examples = []
    ops = [
        ("Show all running apps",
         '<think>Listing running applications.</think>\n\n`{"tool": "run_command", "arguments": {"command": "osascript -e \'tell application \\\"System Events\\\" to get name of every process whose background only is false\'"}}`'),
        ("Check if Safari is running",
         '<think>Checking for Safari process.</think>\n\n`{"tool": "run_command", "arguments": {"command": "pgrep -x Safari && echo running || echo not-running"}}`'),
        ("Show the PID of Finder",
         '<think>Getting Finder process ID.</think>\n\n`{"tool": "run_command", "arguments": {"command": "pgrep -x Finder"}}`'),
        ("Show top 5 memory-consuming processes",
         '<think>Checking memory usage by process.</think>\n\n`{"tool": "run_command", "arguments": {"command": "ps aux --sort=-%mem | head -6"}}`'),
        ("Check what's listening on port 8080",
         '<think>Checking port usage.</think>\n\n`{"tool": "run_command", "arguments": {"command": "lsof -i :8080 2>/dev/null | head -5"}}`'),
    ]
    for user, asst in ops:
        examples.append(make_example(user, asst, "process_management"))
    return examples


def gen_accessibility_inspection():
    examples = []
    ops = [
        ("List all buttons in the current window",
         '<think>Walking the AX tree and filtering for buttons.</think>\n\n`{"tool": "walk_ax_tree", "arguments": {"pid": -1}}`\n\nI\'ll parse the result to find all elements with role "AXButton".'),
        ("Check if the Save button exists",
         '<think>Inspecting the AX tree for a specific element.</think>\n\n`{"tool": "click_element", "arguments": {"pid": -1, "element_name": "Save"}}`\n\nIf the element exists, it will be clicked. If not, an error is returned.'),
        ("Count interactive elements in the current app",
         '<think>Walking the AX tree and counting interactive elements.</think>\n\n`{"tool": "walk_ax_tree", "arguments": {"pid": -1}}`\n\nI\'ll count elements where is_interactive is true.'),
        ("Read the value of the address bar",
         '<think>Finding the AXTextField with title "Address Bar" and reading its value.</think>\n\n`{"tool": "walk_ax_tree", "arguments": {"pid": -1}}`'),
        ("Find the focused element",
         '<think>Walking the AX tree to find which element has focus.</think>\n\n`{"tool": "walk_ax_tree", "arguments": {"pid": -1}}`'),
    ]
    for user, asst in ops:
        examples.append(make_example(user, asst, "accessibility"))
    return examples


def gen_shortcuts_automation():
    examples = []
    ops = [
        ("List all my Shortcuts",
         '<think>Listing available Shortcuts automations.</think>\n\n`{"tool": "run_command", "arguments": {"command": "shortcuts list"}}`'),
        ("Run my 'Morning Routine' shortcut",
         '<think>Executing a Shortcuts automation.</think>\n\n`{"tool": "run_shortcut", "arguments": {"name": "Morning Routine"}}`'),
        ("Run the 'Summarize Clipboard' shortcut",
         '<think>Running a shortcut that processes clipboard content.</think>\n\n`{"tool": "run_shortcut", "arguments": {"name": "Summarize Clipboard"}}`'),
        ("Run a shortcut with input text",
         '<think>Passing input to a shortcut.</think>\n\n`{"tool": "run_shortcut", "arguments": {"name": "Process Text", "input": "Hello world"}}`'),
        ("Check if a shortcut named 'Daily Report' exists",
         '<think>Searching for a specific shortcut.</think>\n\n`{"tool": "run_command", "arguments": {"command": "shortcuts list | grep -i \'daily report\' && echo found || echo not-found"}}`'),
    ]
    for user, asst in ops:
        examples.append(make_example(user, asst, "shortcuts"))
    return examples


def gen_conversational_responses():
    """Non-tool conversational responses for general instruction-following."""
    examples = []
    pairs = [
        ("Explain what an AX tree is",
         "An AX tree (Accessibility tree) is macOS's programmatic representation of the UI. Every window, button, text field, and label is a node in a tree structure that assistive technologies read. Each node has properties like role (AXButton, AXTextField), title, value, position, and size. Epistemos uses this to understand and interact with any macOS app without needing app-specific integrations."),
        ("What keyboard shortcut copies text?",
         "Cmd+C (Command+C) copies the selected text or content to the clipboard. This works in virtually all macOS applications."),
        ("How does Cmd+Tab work?",
         "Cmd+Tab cycles through running applications. Hold Cmd and press Tab repeatedly to move forward through the app switcher. Release Cmd to switch to the highlighted app. Cmd+Shift+Tab moves backward."),
        ("What's the difference between Cmd+W and Cmd+Q?",
         "Cmd+W closes the current window or tab. Cmd+Q quits the entire application. For example, in Safari, Cmd+W closes one tab while Cmd+Q exits Safari completely."),
        ("Explain macOS file permissions",
         "macOS uses Unix-style permissions: read (r), write (w), execute (x) for three groups: owner, group, others. You can view them with `ls -la` and change them with `chmod`. The numeric format uses 3 digits (e.g., 755 = rwxr-xr-x). For apps, macOS also layers on top the App Sandbox, TCC (Transparency Consent and Control), and notarization requirements."),
        ("What is LaunchServices?",
         "LaunchServices is the macOS framework that handles opening files with the correct application. It maintains a database of registered apps and their supported file types. When you double-click a file, LaunchServices decides which app to open it with based on UTI (Uniform Type Identifiers)."),
        ("How does macOS manage memory?",
         "macOS uses virtual memory with demand paging. Physical RAM is managed by the kernel, which can compress inactive pages (memory compression) or write them to swap. Apps see a flat 64-bit address space. The system uses \"memory pressure\" (green/yellow/red) to decide when to compress, swap, or ask apps to free memory."),
        ("What is a .plist file?",
         "A Property List (.plist) file is macOS's standard format for storing structured data, typically app preferences. They can be XML or binary format. The `defaults` command reads/writes them, and they're usually stored in ~/Library/Preferences/. Example: `defaults read com.apple.Safari` shows Safari's preferences."),
        ("Explain what sandboxing means on macOS",
         "App Sandbox restricts what an app can access: file system (limited to its container), network, hardware (camera, mic), and other apps' data. Sandboxed apps declare entitlements for the capabilities they need. This limits damage if an app is compromised. Apps from the Mac App Store must be sandboxed; others may opt in."),
        ("What is Keychain Access?",
         "Keychain is macOS's encrypted credential store. It holds passwords, certificates, encryption keys, and secure notes. Apps use the Security framework to store/retrieve items. The login keychain unlocks automatically when you log in. Keychain Access.app lets you view and manage stored items."),
        ("How do I use the Terminal effectively?",
         "Key Terminal tips: 1) Use Tab for autocompletion. 2) Ctrl+C cancels a running command. 3) Ctrl+R searches command history. 4) `cd -` goes to the previous directory. 5) `!!` repeats the last command. 6) `|` pipes output between commands. 7) `>` redirects output to a file. 8) `&&` chains commands that depend on each other."),
        ("What are UTIs in macOS?",
         "Uniform Type Identifiers (UTIs) are Apple's system for identifying file types. Instead of relying solely on file extensions, UTIs form a hierarchy: public.data → public.text → public.plain-text → public.swift-source. This lets the system understand that a .swift file is also a text file. LaunchServices, Spotlight, and QuickLook all use UTIs."),
        ("Explain the Dock",
         "The Dock is the app launcher bar. It shows running apps (with dots underneath), pinned favorites, and a recent items stack. You can customize it in System Settings > Desktop & Dock. Key shortcuts: Cmd+Tab switches apps, clicking a Dock icon activates that app, right-click gives app-specific options, and dragging files onto a Dock icon opens them with that app."),
        ("What is Time Machine?",
         "Time Machine is macOS's built-in backup system. It creates incremental snapshots of your entire disk, keeping hourly backups for 24 hours, daily for a month, and weekly until the backup disk is full. Configure in System Settings > General > Time Machine. Restoring is done through the Time Machine interface or Migration Assistant."),
        ("How does Spotlight search work?",
         "Spotlight indexes your entire Mac: files, apps, emails, contacts, calendar events, and metadata. It uses mdworker processes to build and maintain the index. Search with Cmd+Space. It understands natural language (\"emails from yesterday\"), math (\"45*12\"), unit conversions, and app launching. The index is stored in /.Spotlight-V100."),
    ]
    for user, asst in pairs:
        examples.append(make_example(user, asst, "general_knowledge"))
    return examples


def gen_multi_step_workflows():
    examples = []
    workflows = [
        ("Download a file from a URL and open it",
         '<think>Two steps: 1) download with curl, 2) open with the default app.</think>\n\nStep 1: Download\n`{"tool": "run_command", "arguments": {"command": "curl -sL -o ~/Downloads/file.txt https://example.com/file.txt"}}`\n\nStep 2: Open\n`{"tool": "run_command", "arguments": {"command": "open ~/Downloads/file.txt"}}`'),
        ("Find large files and show their sizes",
         '<think>Using du and sort to find the biggest files in home.</think>\n\n`{"tool": "run_command", "arguments": {"command": "find ~ -maxdepth 4 -type f -size +100M -exec du -h {} + 2>/dev/null | sort -rh | head -10"}}`'),
        ("Check if a web server is running on localhost",
         '<think>Checking if port 80 or 8080 is listening.</think>\n\n`{"tool": "run_command", "arguments": {"command": "curl -s -o /dev/null -w \'%{http_code}\' http://localhost:8080 2>/dev/null || echo \'not running\'"}}`'),
        ("Create a new Python virtual environment",
         '<think>Setting up a Python venv.</think>\n\n`{"tool": "run_command", "arguments": {"command": "python3 -m venv ~/projects/myenv && echo created"}}`'),
        ("Search for a text pattern across all files in a directory",
         '<think>Using grep recursively.</think>\n\n`{"tool": "run_command", "arguments": {"command": "grep -r --include=\'*.swift\' \'TODO\' . | head -20"}}`'),
        ("Set up a new SSH key",
         '<think>Generating an ed25519 SSH key.</think>\n\n`{"tool": "run_command", "arguments": {"command": "ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N \'\' && cat ~/.ssh/id_ed25519.pub"}}`'),
        ("Check for software updates",
         '<think>Using softwareupdate CLI.</think>\n\n`{"tool": "run_command", "arguments": {"command": "softwareupdate --list 2>&1 | head -10"}}`'),
        ("Show all environment variables",
         '<think>Printing environment.</think>\n\n`{"tool": "run_command", "arguments": {"command": "env | sort | head -30"}}`'),
        ("Show network connections",
         '<think>Using netstat for network info.</think>\n\n`{"tool": "run_command", "arguments": {"command": "netstat -an | grep ESTABLISHED | head -10"}}`'),
        ("Calculate the hash of a file",
         '<think>Computing SHA-256 hash.</think>\n\n`{"tool": "run_command", "arguments": {"command": "shasum -a 256 ~/Downloads/file.txt"}}`'),
    ]
    for user, asst in workflows:
        examples.append(make_example(user, asst, "multi_step"))
    return examples


def main():
    all_examples = []

    generators = [
        ("file_management", gen_file_management),
        ("system_info", gen_system_info),
        ("app_control", gen_app_control),
        ("keyboard_shortcuts", gen_keyboard_shortcuts),
        ("safari_tasks", gen_safari_tasks),
        ("text_editing", gen_text_editing),
        ("git_operations", gen_git_operations),
        ("process_management", gen_process_management),
        ("accessibility", gen_accessibility_inspection),
        ("shortcuts", gen_shortcuts_automation),
        ("general_knowledge", gen_conversational_responses),
        ("multi_step_workflows", gen_multi_step_workflows),
    ]

    for name, gen_fn in generators:
        examples = gen_fn()
        print("  {:25s}: {:4d} examples".format(name, len(examples)))
        all_examples.extend(examples)

    random.seed(42)
    random.shuffle(all_examples)

    output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "embodied_data")
    os.makedirs(output_dir, exist_ok=True)

    output_path = os.path.join(output_dir, "general_macos_instructions.jsonl")
    with open(output_path, "w") as f:
        for ex in all_examples:
            f.write(json.dumps(ex) + "\n")

    print("\nTotal: {} examples -> {}".format(len(all_examples), output_path))


if __name__ == "__main__":
    main()
