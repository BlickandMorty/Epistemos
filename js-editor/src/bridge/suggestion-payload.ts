export interface SuggestionPayload {
  id: string;
  author: string;
  turnId: string;
  kind?: string;
  from: number;
  to: number;
  mapVersion?: number;
  before: string;
  after: string;
  rationale?: string;
  sourceCitation?: string;
  claimId?: string;
}

export function suggestionPayloadFromArgs(args: unknown[]): SuggestionPayload | null {
  const first = args[0];
  if (typeof first !== 'object' || first === null) return null;
  const raw = first as Record<string, unknown>;
  const id = normalizeNonEmptyString(raw.id);
  const author = normalizeNonEmptyString(raw.author);
  const turnId = normalizeNonEmptyString(raw.turnId);
  const before = normalizeString(raw.before);
  const after = normalizeString(raw.after);
  const from = normalizeNonNegativeInteger(raw.from);
  const to = normalizeNonNegativeInteger(raw.to);
  const mapVersion = raw.mapVersion === undefined
    ? undefined
    : normalizeNonNegativeInteger(raw.mapVersion);
  if (
    !id
    || !author
    || !turnId
    || before === null
    || after === null
    || from === null
    || to === null
    || to < from
    || mapVersion === null
  ) {
    return null;
  }
  const rationale = normalizeNonEmptyString(raw.rationale);
  const sourceCitation = normalizeNonEmptyString(raw.sourceCitation);
  const claimId = normalizeNonEmptyString(raw.claimId);
  const kind = normalizeNonEmptyString(raw.kind);
  return {
    id,
    author,
    turnId,
    ...(kind ? { kind } : {}),
    from,
    to,
    ...(mapVersion !== undefined ? { mapVersion } : {}),
    before,
    after,
    ...(rationale ? { rationale } : {}),
    ...(sourceCitation ? { sourceCitation } : {}),
    ...(claimId ? { claimId } : {}),
  };
}

export function suggestionIdFromArgs(args: unknown[]): string | null {
  const first = args[0];
  if (typeof first === 'string') return normalizeNonEmptyString(first);
  if (typeof first !== 'object' || first === null) return null;
  return normalizeNonEmptyString((first as { id?: unknown }).id);
}

function normalizeNonEmptyString(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeString(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

function normalizeNonNegativeInteger(value: unknown): number | null {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
    return null;
  }
  return value;
}
