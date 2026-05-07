// Tracks whether the native host has loaded package content into the
// editor. Tiptap extensions can mutate the boot placeholder document
// before Swift pushes the real .epdoc payload; those updates must never
// autosave over the package.

let hostDocumentLoaded = false;

export function markHostDocumentLoaded(): void {
  hostDocumentLoaded = true;
}

export function hasHostDocumentLoaded(): boolean {
  return hostDocumentLoaded;
}
