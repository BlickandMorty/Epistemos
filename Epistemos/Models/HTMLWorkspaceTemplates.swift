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
      </section>
      <section class="results" data-vault-results aria-live="polite"></section>
    </main>
    """

    private static let css = """
    :root {
      color-scheme: light dark;
      font-family: var(--epistemos-workspace-body-font);
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

    .results {
      display: grid;
      gap: 10px;
      margin-top: 24px;
    }

    .result-card {
      padding: 16px;
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

    function renderVaultResults() {
      const data = HTMLWorkspace.data || {};
      const meta = data._epistemos || {};
      const results = Array.isArray(data.results) ? data.results : [];
      const status = meta.stale ? 'Stale' : (meta.status || 'Fresh');
      const refreshed = meta.refreshed_at_ms
        ? new Date(meta.refreshed_at_ms).toLocaleString()
        : 'Waiting for refresh';

      text('[data-query]', meta.query || 'No query');
      text('[data-count]', meta.result_count ?? results.length);
      text('[data-feed-status]', status);
      text('[data-refresh]', refreshed);
      text('[data-provenance]', meta.provenance || 'No provenance recorded');

      const host = HTMLWorkspace.q('[data-vault-results]');
      if (!host) { return; }
      host.replaceChildren();
      if (results.length === 0) {
        host.append(HTMLWorkspace.el('p', { class: 'empty' }, meta.error || 'No matching notes yet.'));
        return;
      }

      results.forEach((result, index) => {
        host.append(HTMLWorkspace.el('article', { class: 'result-card', 'data-rank': result.rank ?? index }, [
          HTMLWorkspace.el('small', {}, `#${index + 1} / ${result.page_id || 'vault'}`),
          HTMLWorkspace.el('h2', {}, result.title || 'Untitled'),
          HTMLWorkspace.el('p', {}, result.snippet || ''),
          HTMLWorkspace.el('small', { class: 'source-label' }, `${result.source_label || 'Vault search result'} / ${result.context_kind || 'vault_record'}`)
        ]));
      });
    }

    renderVaultResults();
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
