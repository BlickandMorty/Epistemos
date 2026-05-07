import { Extension, type Editor } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import type { EditorView } from '@tiptap/pm/view';
import { postBridge } from '../bridge/outbound';

const IMAGE_ASSET_BRIDGE_KEY = new PluginKey('epdocImageAssetBridge');
const MAX_IMAGE_BYTES = 20 * 1024 * 1024;

interface PendingImageAsset {
  pos: number;
  alt: string;
  title: string;
}

const pendingImageAssets = new Map<string, PendingImageAsset>();
let fallbackRequestCounter = 0;

export function imageAssetBridge(): Extension {
  return Extension.create({
    name: 'epdocImageAssetBridge',
    addProseMirrorPlugins(): Plugin[] {
      const editor = this.editor;
      return [
        new Plugin({
          key: IMAGE_ASSET_BRIDGE_KEY,
          props: {
            handlePaste(view: EditorView, event: ClipboardEvent): boolean {
              const file = firstImageFile(event.clipboardData?.files);
              if (!file) return false;
              event.preventDefault();
              requestPackageImageAsset(editor, file, view.state.selection.from);
              return true;
            },
            handleDOMEvents: {
              drop(view: EditorView, event: DragEvent): boolean {
                const file = firstImageFile(event.dataTransfer?.files);
                if (!file) return false;
                event.preventDefault();
                const pos = view.posAtCoords({ left: event.clientX, top: event.clientY })?.pos
                  ?? view.state.selection.from;
                requestPackageImageAsset(editor, file, pos);
                return true;
              },
            },
          },
        }),
      ];
    },
  });
}

export function completeImageAssetRequest(
  editor: Editor,
  requestID: string,
  src: string
): boolean {
  const pending = pendingImageAssets.get(requestID);
  if (!pending) return false;
  pendingImageAssets.delete(requestID);

  const safePos = Math.max(0, Math.min(pending.pos, editor.state.doc.content.size));
  return editor
    .chain()
    .focus()
    .insertContentAt(safePos, {
      type: 'epdocImage',
      attrs: {
        src,
        alt: pending.alt,
        title: pending.title,
      },
    })
    .focus('end')
    .run();
}

async function requestPackageImageAsset(editor: Editor, file: File, pos: number): Promise<void> {
  if (file.size > MAX_IMAGE_BYTES) {
    console.warn('[epdoc image] skipped image larger than 20 MB', file.name);
    return;
  }
  const requestID = nextRequestID();
  pendingImageAssets.set(requestID, {
    pos,
    alt: file.name,
    title: file.name,
  });
  try {
    const base64 = await fileToBase64(file);
    postBridge({
      type: 'storeImageAsset',
      requestID,
      filename: file.name || 'image',
      mimeType: file.type || 'image/png',
      base64,
    });
    window.epdocOutboundBridge?.flushSync();
  } catch (error) {
    pendingImageAssets.delete(requestID);
    console.warn('[epdoc image] failed to read pasted/dropped image', error);
  }
}

function firstImageFile(files: FileList | undefined | null): File | null {
  if (!files) return null;
  for (const file of Array.from(files)) {
    if (file.type.startsWith('image/')) return file;
  }
  return null;
}

async function fileToBase64(file: File): Promise<string> {
  const buffer = await file.arrayBuffer();
  return bytesToBase64(new Uint8Array(buffer));
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}

function nextRequestID(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  fallbackRequestCounter += 1;
  return `image-asset-${Date.now()}-${fallbackRequestCounter}`;
}
