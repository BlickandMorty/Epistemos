# MAS C Build Prompt - Release Pruning

ID: `MAS-C-F11-RELEASE-PRUNING-BUILD-2026-07-08`

```text
Build Release Pruning for MAS C.

Read:
- docs/mas-c/MAS_C_CONTROL.md
- docs/mas-c/features/11-release-pruning/PLAN.md
- docs/mas-c/MAS_C_RELEASE_EVIDENCE_GATE.md
- project.yml

Task:
Make the MAS target and archive clean. Start with a read-only classification of
target membership, compile flags, resources, scripts, and built archive
contents. Edit only after classifying each suspicious item.

Classification labels:
- active MAS behavior
- legacy name for active in-process MAS bridge
- parked provenance
- forbidden MAS runtime/resource
- unknown needs investigation

Required proof:
- classification table
- surgical project/source diff
- xcodegen if project.yml changed
- MAS build/test checkpoint or precise blocker
- strings/find archive scan
- no accidental deletion of unrelated docs or in-flight feature work
```

