# Epistemos Privacy Policy

**Effective Date:** March 31, 2026  
**Last Updated:** March 31, 2026

## Overview

Epistemos is a macOS-native personal knowledge management application with on-device AI capabilities. Your privacy is fundamental to our design: **your notes, conversations, and personal data stay on your device by default.**

## Data We Collect

### On-Device Only (Default)
- **Notes and vault content** — stored locally on your Mac in your chosen vault directory. Never uploaded to any server.
- **Local AI model data** — inference happens entirely on-device using Apple Silicon (Metal/ANE). No data leaves your machine for local model inference.
- **Knowledge graph** — built and stored locally. Not transmitted anywhere.
- **Application preferences** — stored in macOS UserDefaults and Keychain on your device.

### Cloud API Usage (Opt-In Only)
When you explicitly choose to use cloud AI models (Claude, Perplexity), the following data is sent to the respective API provider:
- **Your prompt/query** — the text you send to the cloud model.
- **Conversation context** — recent messages in the current conversation thread.

**We do not operate any intermediate servers.** API calls go directly from your Mac to the provider's endpoint. We never see, store, or process your API traffic.

### API Keys
- Stored in macOS Keychain (encrypted, hardware-backed on Apple Silicon).
- Never stored in UserDefaults, config files, or transmitted to us.

## Data We Do NOT Collect
- No analytics or telemetry
- No crash reports (unless you explicitly share them)
- No usage tracking
- No advertising identifiers
- No location data
- No contact information

## Third-Party Services
When you opt in to cloud AI features, your data is subject to the respective provider's privacy policy:
- **Anthropic (Claude):** https://www.anthropic.com/privacy
- **Perplexity:** https://www.perplexity.ai/privacy

## macOS Permissions
Epistemos may request the following system permissions:
- **Accessibility** — required for Computer Use (agent desktop automation). Only active when you explicitly start an agent session.
- **Screen Recording** — required for ScreenCaptureKit-based agent perception. Only active during agent sessions.
- **File Access** — to read/write your vault directory.

## Data Deletion
All your data is stored locally. To delete it:
1. Delete the Epistemos app.
2. Delete your vault directory.
3. Remove API keys from Keychain Access.app.

## Contact
For privacy questions: jordan@epistemos.app

## Changes
We will update this policy as needed. Changes will be noted by the "Last Updated" date above.
