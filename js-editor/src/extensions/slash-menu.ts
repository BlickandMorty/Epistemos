// W7.17.b — slash menu via @tiptap/suggestion.
//
// Listens for `/` typed in an empty paragraph context. When triggered,
// posts a requestSlashMenu message to the Swift host with the query
// string + caret anchor. The SwiftUI side renders the picker and
// dispatches insertSlashChoice(blockType) back through the inbound
// bridge — that command runs `editor.chain().focus().<commandName>().run()`
// for whichever entry the user picked.
//
// The list of available block types lives below in DEFAULT_SLASH_ITEMS;
// the SwiftUI side mirrors the catalogue for its picker UI.

import { Extension } from '@tiptap/core';
import Suggestion from '@tiptap/suggestion';
import type { SuggestionOptions } from '@tiptap/suggestion';
import type { Editor } from '@tiptap/core';
import { postBridge } from '../bridge/outbound';
import { buildMermaidGraphFromDocument } from '../graph/document-graph';

export interface SlashMenuItem {
  /** Stable id matched by the inbound `insertSlashChoice` payload. */
  id: string;
  /** Display label rendered by the SwiftUI picker. */
  label: string;
  /** Tiptap chain command applied when the entry is picked. */
  apply: (editor: Editor) => boolean;
  /** SF Symbol name the SwiftUI picker uses. */
  icon: string;
  /** Optional shortcut hint (purely cosmetic). */
  hint?: string;
}

function insertMermaid(editor: Editor, source: string): boolean {
  return editor.chain().focus().insertContent([
    {
      type: 'mermaid',
      content: [{ type: 'text', text: source }],
    },
    { type: 'paragraph' },
  ]).focus('end').run();
}

const RESEARCH_DIAGRAM_TEMPLATES = {
  flowchart: `flowchart TD
  Question["Research question"]
  Hypothesis["Working hypothesis"]
  Method["Method / protocol"]
  Evidence[/"Evidence ledger"/]
  Synthesis["Synthesis"]
  Question --> Hypothesis --> Method --> Evidence --> Synthesis`,
  sequence: `sequenceDiagram
  participant Researcher
  participant Source
  participant Ledger
  participant Synthesis
  Researcher->>Source: inspect claim
  Source-->>Ledger: cite evidence
  Ledger-->>Synthesis: update confidence
  Synthesis-->>Researcher: answer with provenance`,
  timeline: `timeline
  title Research timeline
  Question : frame the problem
  Sources : collect primary evidence
  Method : test the claim
  Synthesis : write the conclusion`,
  mindmap: `mindmap
  root((Research Topic))
    Question
      Claim
      Counterclaim
    Evidence
      Primary source
      Dataset
    Synthesis
      Implication
      Open gap`,
  state: `stateDiagram-v2
  [*] --> Question
  Question --> Evidence: collect
  Evidence --> Analysis: compare
  Analysis --> Synthesis: converge
  Analysis --> Question: gap found
  Synthesis --> [*]`,
  class: `classDiagram
  class Claim {
    +statement
    +confidence
  }
  class Source {
    +citation
    +date
  }
  class Evidence {
    +quote
    +weight
  }
  Claim --> Evidence : supported by
  Evidence --> Source : cites`,
  er: `erDiagram
  CLAIM ||--o{ EVIDENCE : supported_by
  CLAIM ||--o{ COUNTERPOINT : challenged_by
  EVIDENCE }o--|| SOURCE : cites
  SOURCE ||--o{ NOTE : summarized_in`,
  quadrant: `quadrantChart
  title Evidence matrix
  x-axis Low certainty --> High certainty
  y-axis Low impact --> High impact
  "Primary source": [0.82, 0.74]
  "Anecdote": [0.32, 0.42]
  "Replicated result": [0.91, 0.88]
  "Open gap": [0.48, 0.76]`,
  xy: `xychart-beta
  title "Evidence confidence"
  x-axis ["Source A", "Source B", "Source C"]
  y-axis "Confidence" 0 --> 100
  bar [72, 84, 61]`,
  sankey: `sankey-beta
  Source review,Evidence ledger,8
  Evidence ledger,Claim map,6
  Evidence ledger,Open gaps,2
  Claim map,Synthesis,5
  Open gaps,Next experiment,2`,
  pie: `pie showData
  title Evidence mix
  "Primary sources" : 45
  "Benchmarks" : 30
  "Open questions" : 25`,
  gantt: `gantt
  title Research plan
  dateFormat YYYY-MM-DD
  axisFormat %b %d
  section Discovery
  Source review :a1, 2026-05-07, 3d
  Evidence table :after a1, 2d
  section Synthesis
  Draft argument :2026-05-12, 2d
  Review gaps :1d`,
  journey: `journey
  title Research workflow
  section Capture
    Import sources: 4: Researcher
    Annotate evidence: 5: Researcher
  section Synthesize
    Compare claims: 4: Researcher, Agent
    Publish note: 5: Researcher`,
  requirement: `requirementDiagram
  requirement EpdocMedia {
    id: W7.11
    text: Package-local image assets
    risk: Medium
    verifymethod: Test
  }
  element AssetWriter {
    type: Swift service
    docref: EpdocPackage.assets
  }
  AssetWriter - satisfies -> EpdocMedia`,
  gitgraph: `gitGraph
  commit id: "draft"
  branch evidence
  checkout evidence
  commit id: "sources"
  checkout main
  merge evidence
  commit id: "synthesis"`,
  c4: `C4Context
  title Research context
  Person(researcher, "Researcher")
  System(epdoc, ".epdoc workspace")
  System_Ext(source, "Source corpus")
  Rel(researcher, epdoc, "writes and studies")
  Rel(epdoc, source, "cites")`,
  block: `block-beta
  columns 3
  Sources["Sources"] Evidence["Evidence"] Synthesis["Synthesis"]
  Sources --> Evidence
  Evidence --> Synthesis`,
} as const;

const RESEARCH_CHART_TEMPLATES = {
  scatter: `{
  "type": "scatter",
  "title": "Confidence vs impact",
  "x": { "label": "Confidence", "min": 0, "max": 1 },
  "y": { "label": "Impact", "min": 0, "max": 1 },
  "points": [
    { "x": 0.82, "y": 0.74, "label": "Primary source", "category": "source" },
    { "x": 0.32, "y": 0.42, "label": "Anecdote", "category": "weak" },
    { "x": 0.91, "y": 0.88, "label": "Replicated result", "category": "strong" },
    { "x": 0.48, "y": 0.76, "label": "Open gap", "category": "gap" }
  ]
}`,
  bar: `{
  "type": "bar",
  "title": "Evidence by type",
  "x": { "label": "Evidence type" },
  "y": { "label": "Items", "min": 0 },
  "bars": [
    { "label": "Primary", "value": 8 },
    { "label": "Dataset", "value": 5 },
    { "label": "Benchmark", "value": 4 },
    { "label": "Gap", "value": 3 }
  ]
}`,
  line: `{
  "type": "line",
  "title": "Confidence over drafts",
  "x": { "label": "Draft", "min": 1, "max": 5 },
  "y": { "label": "Confidence", "min": 0, "max": 1 },
  "points": [
    { "x": 1, "y": 0.42, "label": "Capture" },
    { "x": 2, "y": 0.58, "label": "Source pass" },
    { "x": 3, "y": 0.71, "label": "Counterpoints" },
    { "x": 4, "y": 0.83, "label": "Synthesis" },
    { "x": 5, "y": 0.89, "label": "Review" }
  ]
}`,
} as const;

export const DEFAULT_SLASH_ITEMS: SlashMenuItem[] = [
  { id: 'heading-1', label: 'Heading 1', icon: 'h.square', hint: '⌘1',
    apply: (e) => e.chain().focus().toggleHeading({ level: 1 }).run() },
  { id: 'heading-2', label: 'Heading 2', icon: 'h.square', hint: '⌘2',
    apply: (e) => e.chain().focus().toggleHeading({ level: 2 }).run() },
  { id: 'heading-3', label: 'Heading 3', icon: 'h.square', hint: '⌘3',
    apply: (e) => e.chain().focus().toggleHeading({ level: 3 }).run() },
  { id: 'bullet-list', label: 'Bulleted list', icon: 'list.bullet', hint: '⌘⇧8',
    apply: (e) => e.chain().focus().toggleBulletList().run() },
  { id: 'numbered-list', label: 'Numbered list', icon: 'list.number', hint: '⌘⇧7',
    apply: (e) => e.chain().focus().toggleOrderedList().run() },
  { id: 'task-list', label: 'Task list', icon: 'checklist', hint: '⌘⇧9',
    apply: (e) => e.chain().focus().toggleTaskList().run() },
  { id: 'blockquote', label: 'Quote', icon: 'text.quote', hint: '⌘⇧.',
    apply: (e) => e.chain().focus().toggleBlockquote().run() },
  { id: 'code-block', label: 'Code block', icon: 'curlybraces', hint: '⌘⇧C',
    apply: (e) => e.chain().focus().toggleCodeBlock().run() },
  { id: 'math-display', label: 'Math (block)', icon: 'function',
    apply: (e) => e.chain().focus().insertContent([
      { type: 'blockMath', attrs: { latex: 'E = mc^2' } },
      { type: 'paragraph' },
    ]).run(),
  },
  { id: 'mermaid', label: 'Document diagram', icon: 'flowchart',
    apply: (e) => insertMermaid(e, buildMermaidGraphFromDocument(e.getJSON())) },
  { id: 'mermaid-flowchart', label: 'Research flowchart', icon: 'flowchart',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.flowchart) },
  { id: 'mermaid-sequence', label: 'Sequence diagram', icon: 'arrow.left.arrow.right',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.sequence) },
  { id: 'mermaid-timeline', label: 'Timeline diagram', icon: 'timeline.selection',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.timeline) },
  { id: 'mermaid-mindmap', label: 'Mind map', icon: 'brain',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.mindmap) },
  { id: 'mermaid-state', label: 'State diagram', icon: 'arrow.triangle.branch',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.state) },
  { id: 'mermaid-class', label: 'Class diagram', icon: 'square.stack.3d.up',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.class) },
  { id: 'mermaid-er', label: 'Entity relationship', icon: 'tablecells',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.er) },
  { id: 'mermaid-quadrant', label: 'Evidence quadrant', icon: 'circle.grid.cross',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.quadrant) },
  { id: 'mermaid-xy', label: 'Evidence chart', icon: 'chart.bar',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.xy) },
  { id: 'mermaid-sankey', label: 'Evidence flow', icon: 'arrow.down.right.and.arrow.up.left',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.sankey) },
  { id: 'mermaid-pie', label: 'Evidence pie chart', icon: 'chart.pie',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.pie) },
  { id: 'mermaid-gantt', label: 'Research Gantt', icon: 'calendar',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.gantt) },
  { id: 'mermaid-journey', label: 'User journey', icon: 'point.topleft.down.curvedto.point.bottomright.up',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.journey) },
  { id: 'mermaid-requirement', label: 'Requirement trace', icon: 'checkmark.seal',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.requirement) },
  { id: 'mermaid-gitgraph', label: 'Version graph', icon: 'point.3.connected.trianglepath.dotted',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.gitgraph) },
  { id: 'mermaid-c4', label: 'C4 context', icon: 'network',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.c4) },
  { id: 'mermaid-block', label: 'Block architecture', icon: 'square.stack.3d.down.right',
    apply: (e) => insertMermaid(e, RESEARCH_DIAGRAM_TEMPLATES.block) },
  { id: 'chart-scatter', label: 'Scatterplot', icon: 'chart.xyaxis.line',
    apply: (e) => e.chain().focus().insertEpdocChart({ source: RESEARCH_CHART_TEMPLATES.scatter }).focus('end').run() },
  { id: 'chart-bar', label: 'Bar chart', icon: 'chart.bar',
    apply: (e) => e.chain().focus().insertEpdocChart({ source: RESEARCH_CHART_TEMPLATES.bar }).focus('end').run() },
  { id: 'chart-line', label: 'Line chart', icon: 'chart.line.uptrend.xyaxis',
    apply: (e) => e.chain().focus().insertEpdocChart({ source: RESEARCH_CHART_TEMPLATES.line }).focus('end').run() },
  { id: 'callout-tip', label: 'Callout — Tip', icon: 'lightbulb',
    apply: (e) => e.chain().focus().insertContent({ type: 'callout', attrs: { kind: 'tip' }, content: [{ type: 'paragraph' }] }).run() },
  { id: 'callout-warning', label: 'Callout — Warning', icon: 'exclamationmark.triangle',
    apply: (e) => e.chain().focus().insertContent({ type: 'callout', attrs: { kind: 'warning' }, content: [{ type: 'paragraph' }] }).run() },
  { id: 'callout-danger', label: 'Callout — Danger', icon: 'octagon',
    apply: (e) => e.chain().focus().insertContent({ type: 'callout', attrs: { kind: 'danger' }, content: [{ type: 'paragraph' }] }).run() },
  { id: 'table-3x3', label: 'Table 3×3', icon: 'tablecells',
    apply: (e) => e.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run() },
  { id: 'image', label: 'Image', icon: 'photo',
    apply: (e) => {
      const src = window.prompt('Image URL');
      if (!src) return false;
      return e.chain().focus().insertEpdocImage({ src, alt: '' }).run();
    } },
  { id: 'divider', label: 'Divider', icon: 'minus', hint: '⌘⇧R',
    apply: (e) => e.chain().focus().setHorizontalRule().run() },
];

export function applySlashChoice(editor: Editor, blockType: string): boolean {
  const item = DEFAULT_SLASH_ITEMS.find((candidate) => candidate.id === blockType);
  if (!item) {
    console.warn(`[epdoc slash] unknown block type '${blockType}'`);
    return false;
  }
  try {
    return item.apply(editor);
  } catch (error) {
    console.warn(`[epdoc slash] '${blockType}' failed`, error);
    return false;
  }
}

export function buildSlashMenu(opts: { onActivate: (query: string, anchor: DOMRect) => void } = { onActivate: () => {} }) {
  return Extension.create({
    name: 'epdocSlashMenu',
    addProseMirrorPlugins() {
      const editor = this.editor;
      const suggestionOptions: SuggestionOptions = {
        editor,
        char: '/',
        startOfLine: false,
        items: ({ query }) => filterSlashItems(query),
        render: () => ({
          onStart: ({ clientRect, query }) => {
            const rect = clientRect?.() ?? new DOMRect(0, 0, 0, 0);
            postBridge({
              type: 'requestSlashMenu',
              query,
              anchor: { x: rect.x, y: rect.y, w: rect.width, h: rect.height },
            });
            opts.onActivate(query, rect);
          },
          onUpdate: ({ clientRect, query }) => {
            const rect = clientRect?.() ?? new DOMRect(0, 0, 0, 0);
            postBridge({
              type: 'requestSlashMenu',
              query,
              anchor: { x: rect.x, y: rect.y, w: rect.width, h: rect.height },
            });
          },
          onKeyDown: ({ event }) => {
            // Escape collapses the SwiftUI picker; the plugin re-emits
            // requestSlashMenu with empty query so the host can hide.
            if (event.key === 'Escape') {
              postBridge({ type: 'requestSlashMenu', query: '', anchor: { x: 0, y: 0, w: 0, h: 0 } });
              return false;
            }
            return false;
          },
          onExit: () => {
            postBridge({ type: 'requestSlashMenu', query: '', anchor: { x: 0, y: 0, w: 0, h: 0 } });
          },
        }),
        command: ({ editor: ed, range, props }) => {
          const item = props as SlashMenuItem;
          // Drop the `/query` text the suggestion captured, then run the apply().
          ed.chain().focus().deleteRange(range).run();
          applySlashChoice(ed, item.id);
        },
      };
      return [Suggestion(suggestionOptions)];
    },
  });
}

function filterSlashItems(query: string): SlashMenuItem[] {
  if (!query) return DEFAULT_SLASH_ITEMS;
  const needle = query.toLowerCase();
  return DEFAULT_SLASH_ITEMS.filter((item) =>
    item.label.toLowerCase().includes(needle) || item.id.includes(needle)
  );
}
