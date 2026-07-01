import Foundation

nonisolated public enum HTMLWorkspaceVaultSearchDashboardTemplate {
    public static func package(
        query: String,
        limit: Int = HTMLWorkspaceDataFeed.defaultLimit,
        title: String? = nil
    ) -> HTMLWorkspacePackage {
        var package = HTMLWorkspacePackage.defaultPackage(title: title ?? "Vault Search Dashboard")
        apply(to: &package, query: query, limit: limit)
        if let title {
            package.manifest.title = title
        }
        return package
    }

    public static func apply(
        to package: inout HTMLWorkspacePackage,
        query: String,
        limit: Int = HTMLWorkspaceDataFeed.defaultLimit
    ) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let clampedLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)
        package.manifest.title = normalizedQuery.isEmpty
            ? "Vault Search Dashboard"
            : "Vault Search: \(normalizedQuery)"
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: normalizedQuery, limit: clampedLimit)
        package.manifest.dataFeed = feed
        package.indexHTML = html
        package.styleCSS = css
        package.scriptJS = js
        package.dataJSON = HTMLWorkspaceDataFeedJSONEnvelope.staleDataJSON(
            feed: feed,
            error: "Feed pending"
        )
        package.manifest.updatedAt = Int64(Date().timeIntervalSince1970 * 1_000)
        package.manifest.contentHash = package.currentContentHash
    }

    private static let html = """
    <main class="workspace vault-search-dashboard">
      <section class="hero" data-dom-root>
        <p class="eyebrow">Vault Search Feed</p>
        <h1 class="workspace-title" data-display-title>Live vault results</h1>
        <p class="lede">A local data surface backed by data.json and the active vault search index.</p>
      </section>
      <section class="feed-summary" aria-label="Feed status">
        <article>
          <span>Query</span>
          <strong data-query>Waiting</strong>
        </article>
        <article>
          <span>Results</span>
          <strong data-count data-metric-value>0</strong>
        </article>
        <article>
          <span>Status</span>
          <strong data-feed-status data-metric-value>Pending</strong>
        </article>
      </section>
      <section class="feed-meta" aria-label="Feed provenance">
        <span data-refresh>Waiting for refresh</span>
        <span data-provenance>VaultSyncService.searchFullAsync</span>
        <span data-context-requirement></span>
        <span data-context-drop-status></span>
      </section>
      <nav class="workspace-nav" aria-label="Workspace sections">
        <a href="#context-feed">Context</a>
        <a href="#pinned-context">Pinned</a>
        <a href="#rank-signal">Ranks</a>
        <a href="#selected-source">Detail</a>
        <a href="#vault-results">Results</a>
      </nav>
      <section class="feed-controls" aria-label="Result controls">
        <label>
          <span>Filter</span>
          <input data-result-filter type="search" placeholder="Search visible results">
        </label>
        <label>
          <span>Pick source</span>
          <select data-context-picker aria-label="Pick context source"></select>
        </label>
        <label>
          <span>Sort</span>
          <select data-result-sort aria-label="Sort visible results">
            <option value="rank-desc">Rank high first</option>
            <option value="rank-asc">Rank low first</option>
            <option value="title-asc">Title A-Z</option>
            <option value="source-asc">Source A-Z</option>
            <option value="context-asc">Context kind A-Z</option>
          </select>
        </label>
        <button type="button" data-pin-context>Pin source</button>
        <span data-filter-count>0 visible</span>
      </section>
      <section id="pinned-context" class="pinned-context" data-pinned-context data-context-dropzone data-context-section="Pinned" aria-label="Pinned context sources">
        <p class="empty">No pinned sources yet.</p>
      </section>
      <section id="context-feed" class="context-tabs" data-context-tabs aria-label="Context kind tabs"></section>
      <section id="rank-signal" class="feed-chart" data-result-chart data-context-dropzone data-context-section="Rank chart" aria-label="Result rank chart">
        <p class="empty">Waiting for ranked results.</p>
      </section>
      <section id="selected-source" class="result-detail" data-result-detail data-context-dropzone data-context-section="Detail" aria-label="Selected result detail">
        <p class="empty">Select a result to inspect its source.</p>
      </section>
      <section id="vault-results" class="results" data-vault-results data-context-dropzone data-context-section="Results" aria-live="polite"></section>
    </main>
    """

    private static let css = """
    :root {
      color-scheme: light dark;
      font-family: var(--epistemos-workspace-body-font);
    }

    html {
      scroll-behavior: smooth;
    }

    body {
      margin: 0;
      min-height: 100vh;
      background: var(--epistemos-workspace-bg);
      color: var(--epistemos-workspace-fg);
    }

    .workspace {
      width: min(1040px, 100%);
      margin: 0 auto;
      padding: 42px;
      box-sizing: border-box;
    }

    .hero {
      display: grid;
      gap: 10px;
    }

    .eyebrow {
      margin: 0;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      font-size: 12px;
      color: var(--epistemos-workspace-muted);
    }

    h1 {
      margin: 0;
      font-family: var(--epistemos-workspace-title-font);
      font-weight: 400;
      font-synthesis: none;
      font-size: 44px;
      line-height: 1;
      letter-spacing: 0;
    }

    .lede {
      max-width: 62ch;
      margin: 0;
      line-height: 1.55;
      color: var(--epistemos-workspace-muted);
    }

    .feed-summary {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 10px;
      margin-top: 26px;
    }

    .feed-summary article,
    .feed-chart,
    .result-detail,
    .result-card {
      border-radius: 8px;
      background: var(--epistemos-workspace-card);
      box-shadow: 0 10px 28px color-mix(in srgb, var(--epistemos-workspace-fg) 9%, transparent);
    }

    .feed-summary article {
      padding: 14px;
    }

    .feed-summary span,
    .source-label,
    .detail-label,
    .result-card small,
    .feed-meta,
    .empty {
      color: var(--epistemos-workspace-muted);
    }

    .feed-summary strong {
      display: block;
      margin-top: 6px;
      font-family: var(--epistemos-workspace-heading-font);
      font-weight: 400;
      font-synthesis: none;
      font-variant-numeric: tabular-nums;
      line-height: 1;
    }

    .feed-meta {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin-top: 14px;
      font-size: 12px;
    }

    .workspace-nav {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 16px;
      font-size: 12px;
    }

    .workspace-nav a {
      padding: 6px 9px;
      border-radius: 6px;
      background: color-mix(in srgb, var(--epistemos-workspace-card) 78%, transparent);
      color: var(--epistemos-workspace-fg);
      text-decoration: none;
      box-shadow: 0 8px 18px color-mix(in srgb, var(--epistemos-workspace-fg) 7%, transparent);
    }

    .workspace-nav a:focus {
      outline: 2px solid color-mix(in srgb, var(--epistemos-workspace-accent) 62%, transparent);
      outline-offset: 2px;
    }

    .feed-controls {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 10px;
      margin-top: 18px;
    }

    .feed-controls label {
      flex: 1 1 240px;
      display: grid;
      gap: 6px;
      color: var(--epistemos-workspace-muted);
      font-size: 12px;
    }

    .feed-controls input,
    .feed-controls select,
    .feed-controls button {
      appearance: none;
      box-sizing: border-box;
      border: 0;
      border-radius: 8px;
      background: var(--epistemos-workspace-card);
      color: var(--epistemos-workspace-fg);
      font: inherit;
      padding: 10px 12px;
      box-shadow: 0 10px 28px color-mix(in srgb, var(--epistemos-workspace-fg) 8%, transparent);
    }

    .feed-controls input,
    .feed-controls select {
      width: 100%;
    }

    .feed-controls button {
      align-self: end;
      cursor: pointer;
      font-size: 12px;
    }

    .feed-controls button:disabled {
      cursor: default;
      opacity: 0.58;
    }

    .feed-controls input:focus,
    .feed-controls select:focus,
    .feed-controls button:focus {
      outline: 2px solid color-mix(in srgb, var(--epistemos-workspace-accent) 62%, transparent);
      outline-offset: 2px;
    }

    [data-filter-count] {
      color: var(--epistemos-workspace-muted);
      font-size: 12px;
    }

    .context-tabs {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 12px;
    }

    .context-tabs,
    .feed-chart,
    .pinned-context,
    .result-detail,
    .results {
      scroll-margin-top: 18px;
    }

    .context-tab {
      appearance: none;
      border: 0;
      border-radius: 6px;
      background: color-mix(in srgb, var(--epistemos-workspace-card) 88%, var(--epistemos-workspace-fg) 12%);
      color: var(--epistemos-workspace-muted);
      cursor: pointer;
      font: inherit;
      font-size: 12px;
      padding: 7px 10px;
    }

    .context-tab.is-active {
      background: var(--epistemos-workspace-accent);
      color: var(--epistemos-workspace-bg);
    }

    .context-tab:focus {
      outline: 2px solid color-mix(in srgb, var(--epistemos-workspace-accent) 62%, transparent);
      outline-offset: 2px;
    }

    .detail-tabs {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin: 4px 0 8px;
    }

    .detail-tab {
      appearance: none;
      border: 0;
      border-radius: 6px;
      background: color-mix(in srgb, var(--epistemos-workspace-card) 88%, var(--epistemos-workspace-fg) 12%);
      color: var(--epistemos-workspace-muted);
      cursor: pointer;
      font: inherit;
      font-size: 12px;
      padding: 7px 10px;
    }

    .detail-tab.is-active {
      background: var(--epistemos-workspace-accent);
      color: var(--epistemos-workspace-bg);
    }

    .detail-tab:focus {
      outline: 2px solid color-mix(in srgb, var(--epistemos-workspace-accent) 62%, transparent);
      outline-offset: 2px;
    }

    .feed-chart {
      display: grid;
      gap: 10px;
      margin-top: 18px;
      padding: 16px;
      transition: box-shadow 120ms ease, background 120ms ease;
    }

    .pinned-context {
      display: grid;
      gap: 10px;
      margin-top: 18px;
      padding: 16px;
      transition: box-shadow 120ms ease, background 120ms ease;
    }

    [data-context-dropzone].is-drop-target {
      background: color-mix(in srgb, var(--epistemos-workspace-accent) 14%, transparent);
      box-shadow: 0 12px 30px color-mix(in srgb, var(--epistemos-workspace-accent) 18%, transparent);
    }

    .section-context-badge {
      margin: 0;
      color: var(--epistemos-workspace-muted);
      font-size: 12px;
      line-height: 1.35;
      overflow-wrap: anywhere;
    }

    .pinned-card {
      display: grid;
      gap: 6px;
      padding: 12px;
      cursor: pointer;
    }

    .pinned-card button {
      justify-self: start;
      appearance: none;
      border: 0;
      border-radius: 6px;
      background: color-mix(in srgb, var(--epistemos-workspace-card) 88%, var(--epistemos-workspace-fg) 12%);
      color: var(--epistemos-workspace-muted);
      cursor: pointer;
      font: inherit;
      font-size: 12px;
      padding: 6px 9px;
    }

    .chart-heading {
      margin: 0;
      color: var(--epistemos-workspace-muted);
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }

    .chart-row {
      display: grid;
      grid-template-columns: minmax(120px, 1fr) minmax(120px, 2fr) minmax(44px, auto);
      gap: 10px;
      align-items: center;
      min-width: 0;
    }

    .chart-label {
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .chart-track {
      height: 12px;
      border-radius: 999px;
      overflow: hidden;
      background: color-mix(in srgb, var(--epistemos-workspace-fg) 10%, transparent);
    }

    .chart-bar {
      display: block;
      width: var(--chart-value);
      height: 100%;
      background: var(--epistemos-workspace-accent);
    }

    .chart-value {
      color: var(--epistemos-workspace-muted);
      font-size: 12px;
      font-variant-numeric: tabular-nums;
      text-align: right;
    }

    .result-detail {
      display: grid;
      gap: 10px;
      margin-top: 18px;
      padding: 16px;
      transition: box-shadow 120ms ease, background 120ms ease;
    }

    .result-detail h2 {
      margin: 0;
      font-family: var(--epistemos-workspace-heading-font);
      font-weight: 400;
      font-synthesis: none;
      letter-spacing: 0;
    }

    .detail-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      gap: 10px;
      margin: 0;
    }

    .detail-grid div {
      min-width: 0;
    }

    .detail-label {
      display: block;
      font-size: 12px;
    }

    .detail-value {
      display: block;
      margin-top: 4px;
      overflow-wrap: anywhere;
      font-variant-numeric: tabular-nums;
    }

    .results {
      display: grid;
      gap: 10px;
      margin-top: 24px;
      transition: box-shadow 120ms ease, background 120ms ease;
    }

    .result-card {
      padding: 16px;
      cursor: pointer;
    }

    .result-card.is-selected {
      box-shadow:
        0 0 0 2px color-mix(in srgb, var(--epistemos-workspace-accent) 64%, transparent),
        0 10px 28px color-mix(in srgb, var(--epistemos-workspace-fg) 9%, transparent);
    }

    .result-card.is-section-bound {
      box-shadow:
        0 0 0 1px color-mix(in srgb, var(--epistemos-workspace-accent) 46%, transparent),
        0 10px 28px color-mix(in srgb, var(--epistemos-workspace-fg) 7%, transparent);
    }

    .result-card.is-selected.is-section-bound {
      box-shadow:
        0 0 0 2px color-mix(in srgb, var(--epistemos-workspace-accent) 68%, transparent),
        0 10px 28px color-mix(in srgb, var(--epistemos-workspace-fg) 10%, transparent);
    }

    .result-card:focus {
      outline: 2px solid color-mix(in srgb, var(--epistemos-workspace-accent) 62%, transparent);
      outline-offset: 2px;
    }

    .result-card h2 {
      margin: 0 0 8px;
      font-family: var(--epistemos-workspace-heading-font);
      font-weight: 400;
      font-synthesis: none;
      letter-spacing: 0;
    }

    .result-card p {
      margin: 0;
      line-height: 1.5;
    }

    @media (max-width: 640px) {
      .workspace {
        padding: 28px;
      }

      h1 {
        font-size: 32px;
      }
    }
    """

    private static let js = """
    function text(selector, value) {
      const node = HTMLWorkspace.q(selector);
      if (node) {
        node.textContent = String(value);
      }
    }

    function normalized(value) {
      return String(value || '').toLowerCase();
    }

    let selectedContextKind = 'all';
    let selectedResultKey = null;
    let pinnedContextKeys = [];
    let sectionContextKeys = {};
    let sectionContextLabels = {};
    let contextDropStatus = '';
    let contextDropKey = null;
    const pinnedContextLimit = 16;
    const contextDragType = 'application/x-epistemos-context-key';
    const nativeContextDragType = 'com.epistemos.workspace-context';
    const selectedDetailViews = ['summary', 'metadata'];
    const selectedDetailLabels = { summary: 'Summary', metadata: 'Metadata' };
    let selectedDetailView = 'summary';

    function resultContextKind(result) {
      return String(result.context_kind || 'vault_record').trim() || 'vault_record';
    }

    function feedProvenance(meta = null) {
      const data = HTMLWorkspace.data || {};
      const envelope = meta || data._epistemos || {};
      return String(envelope.provenance || 'No provenance recorded').trim() || 'No provenance recorded';
    }

    function resultProvenance(result, meta = null) {
      return String((result && result.provenance) || '').trim() || feedProvenance(meta);
    }

    function resultKey(result) {
      return [
        result.page_id,
        result.title,
        result.source_label,
        result.context_kind,
        result.provenance
      ].map((part) => String(part || '').trim()).join('|') || 'vault-result';
    }

    function resultSearchText(result) {
      return [
        result.title,
        result.snippet,
        result.page_id,
        result.source_label,
        result.context_kind,
        result.provenance
      ].map(normalized).join(' ');
    }

    function availableContextKinds(results, meta) {
      const metadataKinds = Array.isArray(meta.context_kinds) ? meta.context_kinds : [];
      return Array.from(new Set(
        metadataKinds
          .concat(results.map(resultContextKind))
          .map((kind) => String(kind || '').trim())
          .filter(Boolean)
      )).sort();
    }

    function resultsForSelectedKind(results) {
      if (selectedContextKind === 'all') { return results; }
      return results.filter((result) => resultContextKind(result) === selectedContextKind);
    }

    function visibleResults(results) {
      const filter = normalized(HTMLWorkspace.q('[data-result-filter]')?.value).trim();
      const scopedResults = resultsForSelectedKind(results);
      if (!filter) { return scopedResults; }
      return scopedResults.filter((result) => resultSearchText(result).includes(filter));
    }

    function sortedResults(results) {
      const sortMode = HTMLWorkspace.q('[data-result-sort]')?.value || 'rank-desc';
      const sorted = results.slice();
      const textValue = (result, field) => normalized(result[field]).trim();
      const rankValue = (result) => Number.isFinite(Number(result.rank)) ? Number(result.rank) : -Infinity;
      if (sortMode === 'rank-asc') {
        return sorted.sort((a, b) => rankValue(a) - rankValue(b));
      }
      if (sortMode === 'title-asc') {
        return sorted.sort((a, b) => textValue(a, 'title').localeCompare(textValue(b, 'title')));
      }
      if (sortMode === 'source-asc') {
        return sorted.sort((a, b) => textValue(a, 'source_label').localeCompare(textValue(b, 'source_label')));
      }
      if (sortMode === 'context-asc') {
        return sorted.sort((a, b) => resultContextKind(a).localeCompare(resultContextKind(b)));
      }
      return sorted.sort((a, b) => rankValue(b) - rankValue(a));
    }

    function resultCountLabel(results, allResults, filter) {
      if (selectedContextKind !== 'all' || filter) {
        return `${results.length} visible / ${allResults.length} total`;
      }
      return `${allResults.length} visible`;
    }

    function requiredContextLabel(meta) {
      const kind = String(meta.required_context_kind || '').trim();
      if (!kind) { return ''; }
      return meta.required_context_available
        ? `Required ${kind}: available`
        : `Required ${kind}: unavailable`;
    }

    function renderContextTabs(allResults, meta) {
      const host = HTMLWorkspace.q('[data-context-tabs]');
      if (!host) { return; }

      const kinds = availableContextKinds(allResults, meta);
      if (selectedContextKind !== 'all' && !kinds.includes(selectedContextKind)) {
        selectedContextKind = 'all';
      }

      host.replaceChildren();
      ['all'].concat(kinds).forEach((kind) => {
        const active = kind === selectedContextKind;
        const count = kind === 'all'
          ? allResults.length
          : allResults.filter((result) => resultContextKind(result) === kind).length;
        const label = kind === 'all' ? 'All' : kind.replace(/_/g, ' ');
        const button = HTMLWorkspace.el('button', {
          type: 'button',
          class: active ? 'context-tab is-active' : 'context-tab',
          'aria-pressed': active ? 'true' : 'false',
          'data-context-kind': kind
        }, `${label} ${count}`);
        button.addEventListener('click', () => {
          selectedContextKind = kind;
          renderVaultResults();
        });
        host.append(button);
      });
    }

    function activeResult(results) {
      if (results.length === 0) {
        selectedResultKey = null;
        return null;
      }
      const selected = selectedResultKey
        ? results.find((result) => resultKey(result) === selectedResultKey)
        : null;
      if (selected) { return selected; }
      selectedResultKey = resultKey(results[0]);
      return results[0];
    }

    function sectionBoundResult(sectionID, allResults) {
      const key = sectionContextKeys[sectionID];
      if (!key) { return null; }
      return allResults.find((result) => resultKey(result) === key) || null;
    }

    function sectionAugmentedResults(sectionID, results, allResults) {
      const boundResult = sectionBoundResult(sectionID, allResults);
      if (!boundResult) { return results; }
      const boundKey = resultKey(boundResult);
      return [boundResult].concat(results.filter((result) => resultKey(result) !== boundKey));
    }

    function detailRow(label, value) {
      return HTMLWorkspace.el('div', {}, [
        HTMLWorkspace.el('span', { class: 'detail-label' }, label),
        HTMLWorkspace.el('strong', { class: 'detail-value' }, value || 'Unavailable')
      ]);
    }

    function renderDetailTabs() {
      return HTMLWorkspace.el('div', { class: 'detail-tabs', 'aria-label': 'Selected source views' },
        selectedDetailViews.map((view) => {
          const active = view === selectedDetailView;
          const button = HTMLWorkspace.el('button', {
            type: 'button',
            class: active ? 'detail-tab is-active' : 'detail-tab',
            'aria-pressed': active ? 'true' : 'false',
            'data-detail-view': view
          }, selectedDetailLabels[view] || view);
          button.addEventListener('click', () => {
            selectedDetailView = view;
            renderVaultResults();
          });
          return button;
        })
      );
    }

    function renderResultDetail(results, allResults, meta = null) {
      const host = HTMLWorkspace.q('[data-result-detail]');
      if (!host) { return; }
      host.replaceChildren();

      const boundResult = sectionBoundResult('selected-source', allResults);
      const selected = boundResult || activeResult(results);
      if (!selected) {
        host.append(HTMLWorkspace.el('p', { class: 'empty' }, 'No visible result selected.'));
        return;
      }

      host.append(HTMLWorkspace.el('p', { class: 'chart-heading' }, boundResult ? 'Dropped section source' : 'Selected source'));
      host.append(renderDetailTabs());
      if (selectedDetailView === 'metadata') {
        host.append(HTMLWorkspace.el('div', { class: 'detail-grid' }, [
          detailRow('Page', selected.page_id || 'vault'),
          detailRow('Rank', Number.isFinite(Number(selected.rank)) ? Number(selected.rank).toFixed(2) : 'Unavailable'),
          detailRow('Context', resultContextKind(selected)),
          detailRow('Source', selected.source_label || 'Vault search result'),
          detailRow('Provenance', resultProvenance(selected, meta))
        ]));
        return;
      }

      host.append(HTMLWorkspace.el('h2', {}, selected.title || 'Untitled'));
      host.append(HTMLWorkspace.el('p', {}, selected.snippet || 'No snippet available.'));
      host.append(HTMLWorkspace.el('div', { class: 'detail-grid' }, [
        detailRow('Context', resultContextKind(selected)),
        detailRow('Source', selected.source_label || 'Vault search result')
      ]));
    }

    function renderContextPicker(results, selected) {
      const picker = HTMLWorkspace.q('[data-context-picker]');
      if (!picker) { return; }
      picker.replaceChildren();
      picker.disabled = results.length === 0;
      if (results.length === 0) {
        picker.append(HTMLWorkspace.el('option', { value: '' }, 'No visible sources'));
        return;
      }
      results.forEach((result, index) => {
        const key = resultKey(result);
        const title = result.title || result.page_id || `Source ${index + 1}`;
        const source = result.source_label || 'Vault search result';
        const kind = resultContextKind(result);
        picker.append(HTMLWorkspace.el('option', {
          value: key,
          'data-context-kind': kind,
          'data-source-label': source
        }, `${title} / ${source} / ${kind}`));
      });
      picker.value = selected ? resultKey(selected) : resultKey(results[0]);
    }

    function updatePinButton(selected) {
      const button = HTMLWorkspace.q('[data-pin-context]');
      if (!button) { return; }
      const key = selected ? resultKey(selected) : '';
      const alreadyPinned = key && pinnedContextKeys.includes(key);
      button.disabled = !selected || alreadyPinned;
      button.textContent = alreadyPinned ? 'Pinned' : 'Pin source';
    }

    function contextRecordAttributes(result, extra = {}) {
      const attributes = {
        page_id: result.page_id || '',
        title: result.title || '',
        context_kind: resultContextKind(result),
        source_label: result.source_label || 'Vault search result'
      };
      Object.keys(extra).forEach((key) => {
        if (extra[key]) { attributes[key] = extra[key]; }
      });
      return attributes;
    }

    function recordContextEvent(eventName, result, extra = {}) {
      const app = window.HTMLWorkspaceApp || (window.HTMLWorkspace && window.HTMLWorkspace.app);
      if (!result || !app || typeof app.record !== 'function') { return; }
      app.record(eventName, contextRecordAttributes(result, extra));
    }

    function renderPinnedContext(allResults) {
      const host = HTMLWorkspace.q('[data-pinned-context]');
      if (!host) { return; }
      host.replaceChildren();

      const byKey = new Map(allResults.map((result) => [resultKey(result), result]));
      for (let index = pinnedContextKeys.length - 1; index >= 0; index -= 1) {
        if (!byKey.has(pinnedContextKeys[index])) {
          pinnedContextKeys.splice(index, 1);
        }
      }

      if (pinnedContextKeys.length === 0) {
        host.append(HTMLWorkspace.el('p', { class: 'empty' }, 'No pinned sources yet.'));
        return;
      }

      host.append(HTMLWorkspace.el('p', { class: 'chart-heading' }, 'Pinned context'));
      pinnedContextKeys.forEach((key) => {
        const result = byKey.get(key);
        if (!result) { return; }
        const card = HTMLWorkspace.el('article', {
          class: 'pinned-card',
          role: 'button',
          tabindex: '0',
          'data-pinned-context-key': key
        }, [
          HTMLWorkspace.el('strong', {}, result.title || result.page_id || 'Pinned source'),
          HTMLWorkspace.el('span', { class: 'source-label' }, `${result.source_label || 'Vault search result'} / ${resultContextKind(result)}`),
          HTMLWorkspace.el('p', {}, result.snippet || 'No snippet available.'),
          HTMLWorkspace.el('button', { type: 'button', 'data-unpin-context': key }, 'Remove')
        ]);
        card.addEventListener('click', () => {
          selectPinnedContext(key);
        });
        card.addEventListener('keydown', (event) => {
          if (event.target && event.target.closest && event.target.closest('[data-unpin-context]')) { return; }
          if (event.key !== 'Enter' && event.key !== ' ') { return; }
          event.preventDefault();
          selectPinnedContext(key);
        });
        card.querySelector('[data-unpin-context]')?.addEventListener('click', (event) => {
          event.stopPropagation();
          const removeIndex = pinnedContextKeys.indexOf(key);
          if (removeIndex >= 0) {
            pinnedContextKeys.splice(removeIndex, 1);
          }
          renderVaultResults();
        });
        host.append(card);
      });
    }

    function selectPinnedContext(key) {
      const filterInput = HTMLWorkspace.q('[data-result-filter]');
      if (filterInput) { filterInput.value = ''; }
      selectedContextKind = 'all';
      selectedResultKey = key;
      renderVaultResults();
    }

    function pinContextKey(key) {
      if (key && !pinnedContextKeys.includes(key)) {
        pinnedContextKeys.push(key);
        if (pinnedContextKeys.length > pinnedContextLimit) {
          pinnedContextKeys.splice(0, pinnedContextKeys.length - pinnedContextLimit);
        }
      }
    }

    function pinSelectedContext() {
      const data = HTMLWorkspace.data || {};
      const allResults = Array.isArray(data.results) ? data.results : [];
      const selected = activeResult(visibleResults(allResults));
      if (!selected) { return; }
      const key = resultKey(selected);
      pinContextKey(key);
      recordContextEvent('workspace.context.pin', selected, { action: 'button' });
      renderVaultResults();
    }

    function dropzoneContextID(dropzone) {
      return String(dropzone?.id || dropzone?.getAttribute('data-context-section') || 'workspace-section').trim();
    }

    function dropzoneContextLabel(dropzone) {
      return String(dropzone?.getAttribute('data-context-section') || dropzone?.getAttribute('aria-label') || dropzoneContextID(dropzone)).trim();
    }

    function bindDropzoneContext(dropzone, key) {
      if (!dropzone || !key) { return; }
      const sectionID = dropzoneContextID(dropzone);
      sectionContextKeys[sectionID] = key;
      sectionContextLabels[sectionID] = dropzoneContextLabel(dropzone);
      dropzone.dataset.contextKey = key;
    }

    function refreshContextDropStatus(allResults) {
      const byKey = new Map(allResults.map((result) => [resultKey(result), result]));
      if (contextDropKey && !byKey.has(contextDropKey)) {
        contextDropKey = null;
        contextDropStatus = 'Dropped context is no longer in the current data.json feed.';
      }
      Object.keys(sectionContextKeys).forEach((sectionID) => {
        if (byKey.has(sectionContextKeys[sectionID])) { return; }
        const sectionLabel = sectionContextLabels[sectionID] || sectionID;
        delete sectionContextKeys[sectionID];
        delete sectionContextLabels[sectionID];
        contextDropStatus = `Dropped context for ${sectionLabel} is no longer in the current data.json feed.`;
      });
    }

    function hasContextDrag(event) {
      const types = Array.from(event.dataTransfer?.types || []);
      return types.includes(contextDragType) || types.includes(nativeContextDragType) || types.includes('text/plain');
    }

    function droppedContextPayload(event) {
      return String(
        event.dataTransfer?.getData(contextDragType) ||
        event.dataTransfer?.getData(nativeContextDragType) ||
        event.dataTransfer?.getData('text/plain') ||
        ''
      ).trim();
    }

    function droppedPayloadField(payload, fieldName) {
      const prefix = `${fieldName}:`;
      const line = String(payload || '')
        .split(/\\r?\\n/)
        .map((part) => part.trim())
        .find((part) => part.toLowerCase().startsWith(prefix.toLowerCase()));
      return line ? line.slice(prefix.length).trim() : '';
    }

    function contextKeyFromDroppedPayload(payload, allResults) {
      const raw = String(payload || '').trim();
      if (!raw) { return ''; }
      const exact = allResults.find((result) => resultKey(result) === raw);
      if (exact) { return resultKey(exact); }

      const pageID = droppedPayloadField(raw, 'page_id');
      const title = droppedPayloadField(raw, 'title');
      const contextKind = droppedPayloadField(raw, 'context_kind');
      const sourceLabel = droppedPayloadField(raw, 'source_label');
      const provenance = droppedPayloadField(raw, 'Provenance');
      const matches = (actual, expected) => {
        if (!expected) { return true; }
        const actualText = String(actual || '').trim();
        if (actualText === expected) { return true; }
        return expected.endsWith('...') && actualText.startsWith(expected.slice(0, -3));
      };
      const matched = allResults.find((result) => {
        return matches(result.page_id, pageID)
          && matches(result.title, title)
          && matches(resultContextKind(result), contextKind)
          && matches(result.source_label || 'Vault search result', sourceLabel)
          && matches(resultProvenance(result), provenance);
      });
      return matched ? resultKey(matched) : '';
    }

    function pinDroppedContextKey(key, dropzone = null) {
      const data = HTMLWorkspace.data || {};
      const allResults = Array.isArray(data.results) ? data.results : [];
      const exists = key && allResults.some((result) => resultKey(result) === key);
      if (!exists) {
        contextDropKey = null;
        contextDropStatus = 'Dropped context is not in the current data.json feed.';
        text('[data-context-drop-status]', contextDropStatus);
        return;
      }
      const result = allResults.find((candidate) => resultKey(candidate) === key);
      contextDropKey = key;
      contextDropStatus = dropzone
        ? `Context selected for ${dropzoneContextLabel(dropzone)} from current data.json feed.`
        : 'Context selected from current data.json feed.';
      selectedContextKind = 'all';
      selectedResultKey = key;
      pinContextKey(key);
      bindDropzoneContext(dropzone, key);
      recordContextEvent('workspace.context.drop', result, {
        section: dropzone ? dropzoneContextLabel(dropzone) : 'workspace'
      });
      renderVaultResults();
    }

    function pinDroppedContextPayload(payload, dropzone = null) {
      const data = HTMLWorkspace.data || {};
      const allResults = Array.isArray(data.results) ? data.results : [];
      const key = contextKeyFromDroppedPayload(payload, allResults);
      pinDroppedContextKey(key, dropzone);
    }

    function clearContextDropTargets() {
      document.querySelectorAll('[data-context-dropzone].is-drop-target').forEach((node) => {
        node.classList.remove('is-drop-target');
      });
    }

    function installContextDropzone(dropzone) {
      if (!dropzone) { return; }
      dropzone.addEventListener('dragover', (event) => {
        if (!hasContextDrag(event)) { return; }
        event.preventDefault();
        if (event.dataTransfer) { event.dataTransfer.dropEffect = 'copy'; }
        dropzone.classList.add('is-drop-target');
      });
      dropzone.addEventListener('dragleave', (event) => {
        if (event.relatedTarget && dropzone.contains(event.relatedTarget)) { return; }
        clearContextDropTargets();
      });
      dropzone.addEventListener('drop', (event) => {
        if (!hasContextDrag(event)) { return; }
        event.preventDefault();
        const payload = droppedContextPayload(event);
        clearContextDropTargets();
        pinDroppedContextPayload(payload, dropzone);
      });
    }

    function renderDropzoneContextBadges(allResults) {
      const byKey = new Map(allResults.map((result) => [resultKey(result), result]));
      document.querySelectorAll('[data-context-dropzone]').forEach((dropzone) => {
        dropzone.querySelectorAll('[data-section-context-badge]').forEach((node) => node.remove());
        const sectionID = dropzoneContextID(dropzone);
        const key = sectionContextKeys[sectionID];
        const result = key ? byKey.get(key) : null;
        dropzone.toggleAttribute('data-context-bound', !!result);
        if (!result) {
          delete dropzone.dataset.contextKey;
          delete sectionContextLabels[sectionID];
          return;
        }
        const badge = HTMLWorkspace.el('p', {
          class: 'section-context-badge',
          'data-section-context-badge': ''
        }, `Section context: ${result.title || result.page_id || 'Untitled'} / ${result.source_label || 'Vault search result'} / ${resultContextKind(result)}`);
        dropzone.prepend(badge);
      });
    }

    function rankDatum(result, index) {
      const value = Number(result.rank);
      if (!Number.isFinite(value) || value <= 0) { return null; }
      return {
        label: result.title || result.page_id || `Result ${index + 1}`,
        source: result.source_label || result.context_kind || 'Vault search result',
        value
      };
    }

    function renderResultChart(results, allResults) {
      const host = HTMLWorkspace.q('[data-result-chart]');
      if (!host) { return; }
      host.replaceChildren();

      const boundResult = sectionBoundResult('rank-signal', allResults);
      const chartResults = sectionAugmentedResults('rank-signal', results, allResults);

      const ranked = chartResults
        .map(rankDatum)
        .filter(Boolean)
        .sort((a, b) => b.value - a.value)
        .slice(0, 8);

      if (ranked.length === 0) {
        const message = boundResult
          ? 'Dropped section source has no numeric rank available for charting.'
          : (results.length > 0 ? 'No numeric ranks available for charting.' : 'No visible results to chart.');
        host.append(HTMLWorkspace.el('p', { class: 'empty' }, message));
        return;
      }

      const max = Math.max(...ranked.map((datum) => datum.value));
      host.append(HTMLWorkspace.el('p', { class: 'chart-heading' }, boundResult ? 'Dropped section rank signal' : 'Rank signal'));
      ranked.forEach((datum) => {
        const percent = Math.max(4, Math.round((datum.value / max) * 100));
        host.append(HTMLWorkspace.el('div', { class: 'chart-row', title: datum.source }, [
          HTMLWorkspace.el('span', { class: 'chart-label' }, datum.label),
          HTMLWorkspace.el('span', { class: 'chart-track' }, [
            HTMLWorkspace.el('span', { class: 'chart-bar', style: `--chart-value: ${percent}%` }, '')
          ]),
          HTMLWorkspace.el('span', { class: 'chart-value' }, datum.value.toFixed(2))
        ]));
      });
    }

    function renderVaultResults() {
      const data = HTMLWorkspace.data || {};
      const meta = data._epistemos || {};
      const allResults = Array.isArray(data.results) ? data.results : [];
      refreshContextDropStatus(allResults);
      renderContextTabs(allResults, meta);
      const results = sortedResults(visibleResults(allResults));
      const displayedResults = sectionAugmentedResults('vault-results', results, allResults);
      const resultsSectionBoundKey = sectionContextKeys['vault-results'] || null;
      const filter = normalized(HTMLWorkspace.q('[data-result-filter]')?.value).trim();
      const status = meta.stale ? 'Stale' : (meta.status || 'Fresh');
      const refreshed = meta.refreshed_at_ms
        ? new Date(meta.refreshed_at_ms).toLocaleString()
        : 'Waiting for refresh';

      text('[data-query]', meta.query || 'No query');
      text('[data-count]', meta.result_count ?? allResults.length);
      text('[data-feed-status]', status);
      text('[data-refresh]', refreshed);
      text('[data-provenance]', feedProvenance(meta));
      text('[data-context-requirement]', requiredContextLabel(meta));
      text('[data-context-drop-status]', contextDropStatus);
      text('[data-filter-count]', resultCountLabel(results, allResults, filter));
      const selectedResult = activeResult(displayedResults);
      renderContextPicker(displayedResults, selectedResult);
      updatePinButton(selectedResult);
      renderPinnedContext(allResults);
      renderResultChart(results, allResults);
      renderResultDetail(displayedResults, allResults, meta);

      const host = HTMLWorkspace.q('[data-vault-results]');
      if (!host) {
        renderDropzoneContextBadges(allResults);
        return;
      }
      host.replaceChildren();
      if (displayedResults.length === 0) {
        host.append(HTMLWorkspace.el('p', { class: 'empty' }, filter ? 'No results match this filter.' : (meta.error || 'No matching context records yet.')));
        renderDropzoneContextBadges(allResults);
        return;
      }

      displayedResults.forEach((result, index) => {
        const key = resultKey(result);
        const isSectionBound = resultsSectionBoundKey && key === resultsSectionBoundKey;
        const cardClass = [
          'result-card',
          selectedResult && key === resultKey(selectedResult) ? 'is-selected' : '',
          isSectionBound ? 'is-section-bound' : ''
        ].filter(Boolean).join(' ');
        const resultOrdinal = isSectionBound ? 'Dropped section source' : `#${index + 1}`;
        const card = HTMLWorkspace.el('article', {
          class: cardClass,
          'data-result-key': key,
          'data-section-bound-result': isSectionBound ? 'true' : 'false',
          'data-rank': result.rank ?? index,
          draggable: 'true',
          role: 'button',
          tabindex: '0'
        }, [
          HTMLWorkspace.el('small', {}, `${resultOrdinal} / ${result.page_id || 'vault'}`),
          HTMLWorkspace.el('h2', {}, result.title || 'Untitled'),
          HTMLWorkspace.el('p', {}, result.snippet || ''),
          HTMLWorkspace.el('small', { class: 'source-label' }, `${result.source_label || 'Vault search result'} / ${result.context_kind || 'vault_record'}`)
        ]);
        card.addEventListener('click', () => {
          selectedResultKey = key;
          renderVaultResults();
        });
        card.addEventListener('dragstart', (event) => {
          if (!event.dataTransfer) { return; }
          event.dataTransfer.effectAllowed = 'copy';
          event.dataTransfer.setData(contextDragType, key);
          event.dataTransfer.setData('text/plain', key);
        });
        card.addEventListener('keydown', (event) => {
          if (event.key !== 'Enter' && event.key !== ' ') { return; }
          event.preventDefault();
          selectedResultKey = key;
          renderVaultResults();
        });
        host.append(card);
      });
      renderDropzoneContextBadges(allResults);
    }

    renderVaultResults();
    HTMLWorkspace.q('[data-result-filter]')?.addEventListener('input', renderVaultResults);
    HTMLWorkspace.q('[data-result-sort]')?.addEventListener('change', renderVaultResults);
    HTMLWorkspace.q('[data-context-picker]')?.addEventListener('change', (event) => {
      selectedResultKey = event.currentTarget.value || null;
      pinContextKey(selectedResultKey);
      const data = HTMLWorkspace.data || {};
      const allResults = Array.isArray(data.results) ? data.results : [];
      const selected = allResults.find((result) => resultKey(result) === selectedResultKey);
      recordContextEvent('workspace.context.pick', selected, { action: 'picker' });
      renderVaultResults();
    });
    HTMLWorkspace.q('[data-pin-context]')?.addEventListener('click', pinSelectedContext);
    document.querySelectorAll('[data-context-dropzone]').forEach(installContextDropzone);
    window.addEventListener('htmlworkspace:datachange', renderVaultResults);
    document.documentElement.dataset.htmlWorkspace = 'ready';
    """
}

extension HTMLWorkspacePackage {
    public static func vaultSearchDashboardPackage(
        query: String,
        limit: Int = HTMLWorkspaceDataFeed.defaultLimit,
        title: String? = nil
    ) -> HTMLWorkspacePackage {
        HTMLWorkspaceVaultSearchDashboardTemplate.package(query: query, limit: limit, title: title)
    }

    public mutating func applyVaultSearchDashboardTemplate(
        query: String,
        limit: Int = HTMLWorkspaceDataFeed.defaultLimit
    ) {
        HTMLWorkspaceVaultSearchDashboardTemplate.apply(to: &self, query: query, limit: limit)
    }
}
