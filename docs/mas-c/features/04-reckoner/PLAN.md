# MAS C Feature Plan - Reckoner

ID: `MAS-C-F04-RECKONER-2026-07-08`
Codename: `RECKONER`
Status: active after LumenLens storage/editor seams

## Intent

Make datasets feel native to the note workspace: vault artifacts, spreadsheet
views, formulas, charts, citations, and June-driven data tools without a
separate data product.

## Scope

- Vault-backed CSV/XLSX/dataset artifacts.
- IronCalc as calculation authority where applicable.
- Univer or similar renderer only as a render/edit surface, not truth.
- Dataset tabs embedded in Epdoc notebook context.
- MAS June data capabilities with dry-run, confirm, undo, and provenance.

## Fabric Mapping

- F1 vault bus: datasets are vault artifacts with stable manifests.
- F2 agent capability registry: June exposes import, clean, calculate, chart,
  summarize, and embed tools.
- F3 MAS status/provenance: shows import/clean/calc/chart states.
- F4 graph: links datasets to notes, sources, columns, and claims.
- F5 provenance: records transform formula, source, and approval.
- F6 event bus: streams dataset operation state and errors.

## Phases

1. Inventory current data/table plan, renderer, calc, and vault seams.
2. Lock artifact manifest and rebuild path.
3. Prove one import, one formula/calc, one chart/embed, and one undo.
4. Integrate dataset tabs into Epdoc notebook.
5. Add source/legal and privacy notes for imported datasets.

## Parked Or Forbidden

- No Kindred presence dependency.
- No private DB table as sole truth.
- No opaque agent mutation without preview and undo.
- No unlicensed commercial data import.

## Acceptance Evidence

- Dataset fixture in vault.
- Calc/transform provenance.
- Undo or rollback proof.
- Epdoc embed/tab manual evidence.
- MAS June tool proof with dry-run and confirm.

