import type { JSONContent } from '@tiptap/core';

export function buildMermaidGraphFromDocument(doc: JSONContent): string {
  const entries = collectGraphEntries(doc).slice(0, 24);
  const lines = ['flowchart TD'];
  lines.push('  N0["Research document"]:::root');

  if (entries.length === 0) {
    lines.push('  N0 --> N1["Add headings, claims, evidence, or links"]:::gap');
    appendClassDefs(lines);
    return lines.join('\n');
  }

  let currentSection = 0;
  entries.forEach((entry, index) => {
    const id = index + 1;
    lines.push(`  N${id}${shapeForEntry(entry)}`);
    if (entry.kind === 'heading') {
      lines.push(`  N0 --> N${id}`);
      currentSection = id;
    } else {
      lines.push(`  N${currentSection} --> N${id}`);
    }
  });

  if (entries.length === 1) {
    lines.push('  N1 --> N2["Add claims, evidence, or counterpoints"]:::gap');
  }
  appendClassDefs(lines);
  return lines.join('\n');
}

type GraphEntry = {
  label: string;
  kind: 'heading' | 'claim' | 'evidence' | 'question' | 'method' | 'link' | 'code' | 'diagram' | 'image';
};

function collectGraphEntries(node: JSONContent): GraphEntry[] {
  const entries: GraphEntry[] = [];
  const seen = new Set<string>();
  walkDocument(node, (entry) => {
    if (entry.label.length < 3) return;
    const key = entry.label.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    entries.push(entry);
  });
  return entries;
}

function walkDocument(node: JSONContent, visit: (entry: GraphEntry) => void): void {
  if (node.type === 'heading') {
    const label = conciseLabel(textContent(node), 9);
    if (label) visit({ label, kind: 'heading' });
  } else if (isGraphContentNode(node)) {
    const raw = textContent(node);
    if (isMarkdownFenceMarker(raw)) return;
    const label = conciseLabel(raw);
    if (label) visit({ label, kind: classifyText(raw) });
  } else if (node.type === 'codeBlock' || node.type === 'code_block') {
    const label = conciseLabel(textContent(node), 7) ?? 'Code block';
    visit({ label, kind: 'code' });
  } else if (node.type === 'mermaid') {
    visit({ label: 'Diagram block', kind: 'diagram' });
  } else if (node.type === 'epdocImage' || node.type === 'image') {
    visit({ label: imageLabel(node), kind: 'image' });
  }

  if (node.type === 'text' && typeof node.text === 'string') {
    for (const label of wikilinkLabels(node.text)) {
      visit({ label, kind: 'link' });
    }
  }

  for (const child of node.content ?? []) {
    walkDocument(child, visit);
  }
}

function isGraphContentNode(node: JSONContent): boolean {
  return node.type === 'paragraph'
    || node.type === 'listItem'
    || node.type === 'blockquote'
    || node.type === 'tableRow';
}

function classifyText(text: string): GraphEntry['kind'] {
  const lower = text.toLowerCase();
  if (/[?]\s*$/.test(text) || lower.startsWith('why ') || lower.startsWith('how ')) return 'question';
  if (/\b(method|protocol|procedure|experiment|approach|pipeline)\b/.test(lower)) return 'method';
  if (/\b(evidence|source|citation|dataset|observed|measured|study|paper|result)\b/.test(lower)) return 'evidence';
  if (/\b(claim|thesis|argue|therefore|because|implies|conclude)\b/.test(lower)) return 'claim';
  return 'claim';
}

function imageLabel(node: JSONContent): string {
  const alt = typeof node.attrs?.alt === 'string' ? node.attrs.alt.trim() : '';
  return alt.length > 0 ? conciseLabel(alt, 7) ?? 'Image evidence' : 'Image evidence';
}

function shapeForEntry(entry: GraphEntry): string {
  const label = escapeMermaidLabel(labelForKind(entry));
  switch (entry.kind) {
    case 'heading':
      return `(["${label}"]):::section`;
    case 'question':
      return `{"${label}"}:::question`;
    case 'evidence':
      return `[/"${label}"/]:::evidence`;
    case 'method':
      return `["${label}"]:::method`;
    case 'link':
      return `[["${label}"]]:::link`;
    case 'code':
      return `["${label}"]:::code`;
    case 'diagram':
      return `["${label}"]:::diagram`;
    case 'image':
      return `["${label}"]:::image`;
    case 'claim':
      return `["${label}"]:::claim`;
  }
}

function labelForKind(entry: GraphEntry): string {
  switch (entry.kind) {
    case 'evidence': return `Evidence: ${entry.label}`;
    case 'question': return `Question: ${entry.label}`;
    case 'method': return `Method: ${entry.label}`;
    case 'link': return `[[${entry.label}]]`;
    case 'code': return `Code: ${entry.label}`;
    case 'diagram': return entry.label;
    case 'image': return entry.label;
    default: return entry.label;
  }
}

function appendClassDefs(lines: string[]): void {
  lines.push('  classDef root fill:#172033,stroke:#172033,color:#ffffff,stroke-width:2px;');
  lines.push('  classDef section fill:#eaf3ff,stroke:#5277a0,color:#172033,stroke-width:2px;');
  lines.push('  classDef claim fill:#f8fafc,stroke:#6b7f99,color:#172033;');
  lines.push('  classDef evidence fill:#fff7ed,stroke:#d69e2e,color:#422006;');
  lines.push('  classDef question fill:#f0f9ff,stroke:#38a3c7,color:#123246;');
  lines.push('  classDef method fill:#f6f1ff,stroke:#8b6bd6,color:#271a48;');
  lines.push('  classDef link fill:#eff6ff,stroke:#3a86ff,color:#17335f;');
  lines.push('  classDef code fill:#eef2f7,stroke:#56687f,color:#172033;');
  lines.push('  classDef diagram fill:#ecfdf5,stroke:#2f9e6d,color:#123524;');
  lines.push('  classDef image fill:#fff1f2,stroke:#e06c85,color:#4a1421;');
  lines.push('  classDef gap fill:#fff7ed,stroke:#d69e2e,color:#422006,stroke-dasharray: 4 3;');
}

function textContent(node: JSONContent): string {
  const ownText = typeof node.text === 'string' ? node.text : '';
  const childText = (node.content ?? []).map(textContent).join(' ');
  return `${ownText} ${childText}`.replace(/\s+/g, ' ').trim();
}

function conciseLabel(text: string, wordLimit = 8): string | null {
  const cleaned = text
    .replace(/\[\[|\]\]/g, '')
    .replace(/`+/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (cleaned.length === 0) return null;
  const sentence = cleaned.split(/[.!?]\s+/)[0] ?? cleaned;
  const words = sentence.split(/\s+/).filter(Boolean).slice(0, wordLimit);
  if (words.length === 0) return null;
  return words.join(' ');
}

function isMarkdownFenceMarker(text: string): boolean {
  return /^```[\w-]*\s*$/.test(text.trim());
}

function wikilinkLabels(text: string): string[] {
  if (!text.includes('[[')) return [];
  const labels: string[] = [];
  const pattern = /\[\[([^\]\n]{1,96})\]\]/g;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(text)) !== null) {
    const label = match[1]?.trim();
    if (label) labels.push(label);
  }
  return labels;
}

function escapeMermaidLabel(label: string): string {
  return label
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/`+/g, "'")
    .replace(/\[/g, '(')
    .replace(/\]/g, ')');
}
