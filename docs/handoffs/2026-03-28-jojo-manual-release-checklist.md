# Jojo Manual Release Checklist

**Date:** 2026-03-28  
**Audience:** Jojo  
**Purpose:** Everything you still need to do outside normal coding, including fresh-user simulation and actual public-release prep.

---

## 1. What You Can Keep Doing

### Daily development

Keep building in Xcode for day-to-day work.

- Use the `Epistemos` scheme
- Use `Debug` for local runs
- Do not rely on stale DerivedData app bundles

### Repeatable release-preservation check

Before you trust the branch as “still healthy,” run:

```bash
./scripts/audit/release_preflight.sh
```

That is the new repeatable check for keeping the app release-ready on disk.

---

## 2. Important Signing Nuance

The earlier Xcode launch error was misleading. It did **not** mean the project fundamentally requires a provisioning profile just to run locally. It meant the specific app bundle being launched was not in a valid signed state.

If you want a real distributable app, then yes, you need real signing:

- `Apple Development` for locally signed development builds if you want full normal development signing
- `Developer ID Application` for direct distribution outside the Mac App Store
- App Store signing only if you are actually shipping through the Mac App Store

Current product direction:

- **Direct distribution first**
- **Not Mac App Store for the full Omega/MLX app**

---

## 3. Before Public Release

You still need these non-code items:

1. Apple Developer Program enrollment must be active.
2. A `Developer ID Application` certificate must be configured on the shipping machine.
3. Privacy policy URL must exist.
4. Support URL must exist.
5. A real notarization workflow must be configured.
6. A DMG packaging flow must exist.
7. GitHub Release or other download hosting must be ready.

---

## 4. Manual Verification You Still Need To Do

### A. Fresh local artifact check

After a fresh build, verify:

- the app launches from the built `.app`
- the app has the Rust dylibs in `Contents/Frameworks`
- the app has the Knowledge Fusion runtime assets in `Contents/Resources/KnowledgeFusion/...`
- there is no unexpected `Contents/PlugIns`

### B. New-user simulation on your current Mac

Do this before involving another machine:

1. Create a clean macOS user account or use a separate clean test account.
2. Download or copy the final DMG as if you were a real user.
3. Install the app from the DMG into `/Applications`.
4. Launch it without opening Xcode first.
5. Confirm:
   - first launch succeeds
   - no missing-dylib errors
   - no missing-asset errors
   - app does not depend on repo-relative paths
   - note runtime and Knowledge Fusion surfaces do not immediately break

### C. Fresh-machine simulation on another MacBook

This is still required before public release.

Use a Mac that does **not** have your dev environment assumptions.

Check:

1. DMG download works from the actual host you will use.
2. Gatekeeper / notarization behavior is clean.
3. Install to `/Applications` works.
4. First launch succeeds.
5. Permissions prompts are understandable.
6. Model/runtime assets resolve correctly.
7. Core note workflows and Omega workflows still function.

### D. Manual app behavior pass

Manually verify:

- note AI stream / accept / discard
- close and reopen note after AI use
- research entry points
- Omega panel visibility
- browser / automation permission flow
- Terminal tool flow
- UTF-16 / Unicode note open if that remains a concern

---

## 5. Direct Distribution Packaging Tasks

When you are ready to make a real public artifact:

1. Build the app cleanly.
2. Sign with `Developer ID Application`.
3. Create the DMG.
4. Submit for notarization.
5. Staple the notarization ticket.
6. Re-test the stapled DMG on a clean machine.
7. Upload the DMG to GitHub Releases or your chosen host.
8. Publish checksums and release notes.

---

## 6. GitHub Sync Checklist

When you want everything on disk and GitHub aligned:

1. Run `./scripts/audit/release_preflight.sh`
2. Commit only after the preflight is green
3. Push the branch
4. Open or update the PR
5. If it is the release commit:
   - create a Git tag
   - create a GitHub Release
   - upload the DMG
   - upload checksums
   - paste release notes

---

## 7. My Honest Personal Take

The app is much closer than it was. The repo-side release blockers that were hurting you most are mostly build-graph and bundle-correctness issues, and those were real fixes.

What still keeps me from casually saying “ship it” is not code panic, it is the last-mile reality:

- direct-distribution signing
- notarization
- DMG packaging
- fresh-user install behavior
- fresh-machine verification

If those go well, the branch is in a credible place for a direct-distribution release.

