# RAW ResearchHub research — social workflow (2026-07-03)
> RAW research archive — provenance only, DO NOT BUILD FROM THIS. Verbatim output of the ResearchHub deep-research workflow (interrupted at synthesis by a credit limit; searches+fetches completed). Distilled + corrected in RESEARCHHUB_SOURCE_DOSSIER_2026_07_03.md. Preserved so no research is lost.

**Stats:** {"angles": 5, "sources": 22, "claims": 109, "verified": 25, "confirmed": 8, "killed": 1, "unverified": 16, "afterSynthesis": 0}

## CONFIRMED claims (8)
- **The X API v2 Bookmarks surface is live and documented on docs.x.com with five endpoints, including the read endpoint GET /2/users/:id/bookmarks plus bookmark-folder reads (GET /2/users/:id/bookmarks/folders and GET /2/users/:id/bookmarks/folders/:folder_id), so an app can retrieve both a user's bookmarks and their bookmark folders via the official API.**
  - source: https://docs.x.com/x-api/posts/bookmarks/introduction
  - quote: "The Bookmarks endpoints let you view, add, and remove bookmarked Posts for the authenticated user."
  - vote: 3-0
- **Bookmarks access requires user-context authentication — user access tokens obtained via OAuth 2.0 PKCE (or 3-legged OAuth) — plus an approved developer account and a Project/App in the Developer Console; PKCE support means a public-client (no client secret) flow is officially supported, which matters for a sandboxed Mac app with no server.**
  - source: https://docs.x.com/x-api/posts/bookmarks/introduction
  - quote: "An approved developer account, A Project and App in the Developer Console, User Access Tokens via OAuth 2.0 PKCE or 3-legged OAuth"
  - vote: 3-0
- **This official Bookmarks introduction page states NO access-tier gating (Free/Basic/Pro/Enterprise), no pricing, and no rate limits — its complete prerequisites list omits any paid-tier requirement — so the crux question of which 2026 tier unlocks GET bookmarks cannot be answered from this page and must be verified against X's separate tier/pricing documentation.**
  - source: https://docs.x.com/x-api/posts/bookmarks/introduction
  - quote: "An approved developer account, A Project and App in the Developer Console, User Access Tokens via OAuth 2.0 PKCE or 3-legged OAuth"
  - vote: 3-0
- **As of mid-2026, the X API no longer uses subscription tiers (Free/Basic/Pro); it uses pay-per-usage credit pricing, so the research question's framing of 'which paid tier unlocks bookmarks' is obsolete — there are no tiers, only per-request credit costs.**
  - source: https://docs.x.com/x-api/getting-started/pricing
  - quote: "The X API uses pay-per-usage pricing. No subscriptions—pay only for what you use."
  - vote: 3-0
- **Effective Monday, April 20, 2026, X prices the bookmarks endpoint GET /2/users/{id}/bookmarks (along with followers, following, liked_tweets, tweets, mentions, lists, blocking, muting endpoints) under 'Owned Reads' at $0.001 per resource returned, i.e., $1 per 1,000 bookmarks fetched — a usage-based model rather than a flat tier gate.**
  - source: https://devcommunity.x.com/t/x-api-pricing-update-owned-reads-now-0-001-other-changes-effective-april-20-2026/263025
  - quote: "Starting Monday, April 20, 2026, these endpoints will be priced at $0.001 per resource (equivalently, 1,000 resources for $1): GET /2/users/{id}/bookmarks"
  - vote: 3-0
- **X defines 'Owned Reads' as requests made by a developer's own app for that account's own data — explicitly including bookmarks — but the announcement does not explicitly state whether end-users authenticating into a third-party client app (OAuth user context) receive this rate, nor which subscription tier is prerequisite, deferring the complete rate card to the X API Pricing page.**
  - source: https://devcommunity.x.com/t/x-api-pricing-update-owned-reads-now-0-001-other-changes-effective-april-20-2026/263025
  - quote: "Owned Reads are requests made by your own developer app for your own posts, bookmarks, followers, likes, lists & more."
  - vote: 3-0
- **twitter-web-exporter exports X/Twitter bookmarks (bypassing the 800-item cap) without using the official paid Twitter API or requiring a developer account — it works as a Tampermonkey/Violentmonkey userscript that passively captures the web app's own GraphQL responses, so a Mac app could rely on it as the export step in an import-file fallback for X bookmarks.**
  - source: https://github.com/prinsss/twitter-web-exporter
  - quote: "The script itself does not send any request to Twitter API. It installs an network interceptor to capture the response of GraphQL request"
  - vote: 3-0
- **X's official native archive export does NOT include bookmarks (and represents following/followers only as numeric IDs), meaning there is no first-party bookmarks export from X and a third-party tool like this is required for an import-based workflow.**
  - source: https://github.com/prinsss/twitter-web-exporter
  - quote: "Twitter's archive only contains the numeric user ID of your following/followers which is not human-readable. The archive also does not contain your bookmarks."
  - vote: 3-0

## UNVERIFIED claims (quote-backed; verification cut off by credits) (16)
- As of mid-2026, Reddit's free-access Data API rate limit is 100 queries per minute per OAuth client ID, averaged over a 10-minute window to permit bursting — ample for a personal research/PKM client's feed polling.
  - source: https://support.reddithelp.com/hc/en-us/articles/16160319875092-Reddit-Data-API-Wiki
- OAuth authentication is mandatory for the Reddit Data API: clients must use a registered OAuth token, and unauthenticated traffic is blocked outright rather than given a default rate limit — so a MAS client app must implement Reddit OAuth (or fall back to RSS) rather than hitting .json endpoints anonymously.
  - source: https://support.reddithelp.com/hc/en-us/articles/16160319875092-Reddit-Data-API-Wiki
- Free Data API access exists in 2026 but is framed as conditional eligibility governed by Reddit's Responsible Builder Policy, Developer Terms, and Data API Terms, with a 'contact us to request' step — there is no self-serve paid tier or pricing schedule published on this official wiki page.
  - source: https://support.reddithelp.com/hc/en-us/articles/16160319875092-Reddit-Data-API-Wiki
- Any app that persists Reddit content locally (e.g., Epistemos save-to-vault) has a ToS obligation to delete content and author-identifying data once it is deleted on Reddit — Reddit recommends purging stored user data within 48 hours and states that retaining deleted content even in anonymized form violates its terms.
  - source: https://support.reddithelp.com/hc/en-us/articles/16160319875092-Reddit-Data-API-Wiki
- Mastodon provides an official, documented API endpoint for reading a user's bookmarks: GET /api/v1/bookmarks, which returns the statuses the authenticated user has bookmarked as an array of Status entities.
  - source: https://docs.joinmastodon.org/methods/bookmarks/
- The Mastodon bookmarks endpoint requires OAuth user-context authentication: a user token passed as a Bearer Authorization header, with the read:bookmarks OAuth scope — there is no additional cost or paid tier, just standard Mastodon OAuth.
  - source: https://docs.joinmastodon.org/methods/bookmarks/
- The Semantic Scholar API is free to use, and most endpoints are publicly accessible without any authentication; an API key is optional and only certain endpoints require it, meaning a sandboxed macOS client can call it directly with no server-side secret and no OAuth flow.
  - source: https://www.semanticscholar.org/product/api
- Unauthenticated (keyless) access to the Semantic Scholar API is rate-limited to a shared pool of 1,000 requests per second across ALL unauthenticated users worldwide, so a client app without a key may be throttled during heavy global use.
  - source: https://www.semanticscholar.org/product/api
- An authenticated Semantic Scholar API key starts at a dedicated rate limit of 1 request per second on all endpoints; keys are private, distributed via email (simple API-key auth, not OAuth), and must not be shared — compatible with per-user Keychain storage in a client app.
  - source: https://www.semanticscholar.org/product/api
- Semantic Scholar allows unauthenticated (no API key) access to its public API, with all unauthenticated users sharing a pooled rate limit of 5,000 requests per 5 minutes (since March 28, 2023) — meaning a sandboxed Mac client can call the API with no key and no server, but throughput is unpredictable because the pool is shared globally across all unauthenticated users.
  - source: https://github.com/allenai/s2-folks/blob/main/API_RELEASE_NOTES.md
- As of August 2024, Semantic Scholar stopped approving API key requests for third-party apps and for requests from free email domains — so Epistemos cannot ship or obtain an app-level S2 key, and individual users on gmail-type addresses cannot get personal keys either; the unauthenticated pool is effectively the only client-side path.
  - source: https://github.com/allenai/s2-folks/blob/main/API_RELEASE_NOTES.md
- The Readwise Reader API uses simple static-token authentication (an 'Authorization: Token XXX' header) with each user obtaining their own token from readwise.io/access_token — there is no OAuth flow or app-registration program documented, and the docs explicitly anticipate third-party integrations directing 'your users' to fetch their own tokens, which means a sandboxed client-side-only Mac app can integrate with no server middleman and no embedded secret (user pastes token, app stores it in Keychain).
  - source: https://readwise.io/reader_api
- Readwise Reader API rate limits are per access token — 50 requests/minute for document CREATE (POST /save/) and UPDATE, and 20 requests/minute for LIST, DELETE, bulk update, and tag endpoints — and exceeding a limit returns HTTP 429 with a Retry-After header giving the seconds to wait, so a per-user feed poller stays comfortably inside limits.
  - source: https://readwise.io/reader_api
- The Reader API v3 (base URL https://readwise.io/api/v3/) exposes a full two-way surface — save/create document, list documents, update, bulk update, delete, and list tags — with cursor-based pagination (nextPageCursor) on the list endpoint, which is sufficient for both a 'save from Epistemos to Reader' action and a 'sync my Reader library/queue into the ResearchHub' adapter.
  - source: https://readwise.io/reader_api
- Raindrop.io provides an official, publicly documented API covering its service, hosted at developer.raindrop.io.
  - source: https://developer.raindrop.io/
- Third-party access to the Raindrop.io API requires registering an application and authenticating via OAuth 2.0 authorization-code flow, and the token exchange (POST https://raindrop.io/oauth/access_token) requires a client_secret in the request body (parameters: grant_type, code, client_id, client_secret, redirect_uri), with no PKCE option documented — meaning a pure client-side distributed app cannot complete the flow without embedding a secret or using a server middleman.
  - source: https://developer.raindrop.io/

## SOURCES fetched (22)
- https://docs.x.com/x-api/posts/bookmarks/introduction (primary, 5 claims)
- https://docs.x.com/x-api/getting-started/pricing (primary, 5 claims)
- https://devcommunity.x.com/t/x-api-pricing-update-owned-reads-now-0-001-other-changes-effective-april-20-2026/263025 (primary, 5 claims)
- https://github.com/prinsss/twitter-web-exporter (primary, 5 claims)
- https://keep.md/blog/export-x-bookmarks (blog, 5 claims)
- https://postproxy.dev/blog/x-api-pricing-2026/ (blog, 5 claims)
- https://support.reddithelp.com/hc/en-us/articles/16160319875092-Reddit-Data-API-Wiki (primary, 5 claims)
- https://techcrunch.com/2025/09/08/bluesky-adds-private-bookmarks/ (secondary, 5 claims)
- https://techcrunch.com/2025/05/22/mozilla-is-shutting-down-read-it-later-app-pocket/ (secondary, 4 claims)
- https://docs.joinmastodon.org/methods/bookmarks/ (primary, 5 claims)
- https://intuitionlabs.ai/articles/research-paper-apis-scientific-literature (blog, 5 claims)
- https://www.semanticscholar.org/product/api (primary, 5 claims)
- https://github.com/allenai/s2-folks/blob/main/API_RELEASE_NOTES.md (primary, 5 claims)
- https://readwise.io/reader_api (primary, 5 claims)
- https://developer.raindrop.io/ (primary, 5 claims)
- https://www.zotero.org/support/dev/web_api/v3/basics (primary, 5 claims)
- https://www.instapaper.com/developers/v1/full-api (primary, 5 claims)
- https://dev.are.na/documentation (primary, 5 claims)
- https://beemind.app/blog/pocket-alternatives (blog, 5 claims)
- https://datatracker.ietf.org/doc/html/rfc8252 (primary, 5 claims)
- https://www.macrumors.com/2016/04/11/third-party-reddit-apps-pulled/ (secondary, 5 claims)
- https://developer.apple.com/app-store/review/guidelines/ (primary, 5 claims)

## RAW agent findings (resultPreviews — the pre-verification search/fetch signal)
```
{"question":"For a sandboxed Mac App Store PKM app (Swift, URLSession-only, no server except an optional small proxy, keys in Keychain), which research-content sources — X bookmarks, Reddit, Hacker News, GitHub, Hugging Face, scholarly APIs (Semantic Scholar/OpenAlex/PubMed/Crossref/OpenReview), read-later services (Raindrop/Instapaper/Readwise/Zotero/Pocket), Bluesky/Mastodon/Lobsters, and RSS/Yo…
```
```
{"results":[{"url":"https://docs.x.com/x-api/posts/bookmarks/introduction","title":"Bookmarks — X API v2 official documentation","relevance":"high","snippet":"Official docs for GET /2/users/:id/bookmarks. Confirms the endpoint requires User Access Tokens via OAuth 2.0 PKCE (user context) — app-only auth cannot read bookmarks; scopes are tweet.read, users.read, bookmark.read (+offline.access for re…
```
```
{"results":[{"url":"https://support.reddithelp.com/hc/en-us/articles/16160319875092-Reddit-Data-API-Wiki","title":"Reddit Data API Wiki (official Reddit Help)","relevance":"high","snippet":"Official post-2023 terms governing a free client app: free tier = 100 queries/minute per OAuth client ID (10 QPM without OAuth), averaged over a 10-minute window, non-commercial use only, app registration requi…
```
```
{"results":[{"url":"https://intuitionlabs.ai/articles/research-paper-apis-scientific-literature","title":"Research Paper APIs for Scientific Literature in 2026 | IntuitionLabs","relevance":"high","snippet":"2026-dated survey of exactly the beyond-arXiv scholarly lane (Semantic Scholar, OpenAlex, Crossref, PubMed E-utilities, etc.) with per-API auth and rate-limit notes: OpenAlex ~100k calls/day fr…
```
```
{"results":[{"url":"https://readwise.io/reader_api","title":"Readwise Reader API — official documentation","relevance":"high","snippet":"Official Reader (v3) API docs: auth is a user-pasted access token from readwise.io/access_token sent as 'Authorization: Token XXX' — no OAuth app, no client secret, so it's trivially MAS-viable pure-client-side. Documents save/list/update/delete document endpoint…
```
```
{"results":[{"url":"https://datatracker.ietf.org/doc/html/rfc8252","title":"RFC 8252 — OAuth 2.0 for Native Apps (IETF)","relevance":"high","snippet":"The canonical spec answering the 'server secret vs pure client-side' question: native apps are public clients that must NOT be issued/required to hold a shared client secret; PKCE is mandatory and servers should reject native-app auth requests witho…
```
```
{"claims":[{"claim":"The X API v2 Bookmarks surface is live and documented on docs.x.com with five endpoints, including the read endpoint GET /2/users/:id/bookmarks plus bookmark-folder reads (GET /2/users/:id/bookmarks/folders and GET /2/users/:id/bookmarks/folders/:folder_id), so an app can retrieve both a user's bookmarks and their bookmark folders via the official API.","quote":"The Bookmarks …
```
```
{"claims":[{"claim":"As of mid-2026, the X API no longer uses subscription tiers (Free/Basic/Pro); it uses pay-per-usage credit pricing, so the research question's framing of 'which paid tier unlocks bookmarks' is obsolete — there are no tiers, only per-request credit costs.","quote":"The X API uses pay-per-usage pricing. No subscriptions—pay only for what you use.","importance":"central"},{"claim…
```
```
{"claims":[{"claim":"Effective Monday, April 20, 2026, X prices the bookmarks endpoint GET /2/users/{id}/bookmarks (along with followers, following, liked_tweets, tweets, mentions, lists, blocking, muting endpoints) under 'Owned Reads' at $0.001 per resource returned, i.e., $1 per 1,000 bookmarks fetched — a usage-based model rather than a flat tier gate.","quote":"Starting Monday, April 20, 2026,…
```
```
{"claims":[{"claim":"twitter-web-exporter exports X/Twitter bookmarks (bypassing the 800-item cap) without using the official paid Twitter API or requiring a developer account — it works as a Tampermonkey/Violentmonkey userscript that passively captures the web app's own GraphQL responses, so a Mac app could rely on it as the export step in an import-file fallback for X bookmarks.","quote":"The sc…
```
```
{"claims":[{"claim":"As of 2026, X provides no native bookmarks export feature, and the official X data archive ZIP does not include bookmarks.","quote":"There is no official CSV button, the data archive ZIP does not include bookmarks.","importance":"central"},{"claim":"The X API bookmarks endpoint (GET /2/users/:id/bookmarks) is only available behind X's paid developer tiers in 2026 (the article …
```
```
{"claims":[{"claim":"As of February 2026, X made pay-per-use (credit-based) pricing the default API model and discontinued the free tier; new developers can no longer sign up for the Basic or Pro subscription tiers — only pay-per-use or Enterprise remain available, with free access limited to case-by-case-approved 'for-good public utility apps'.","quote":"New developers cannot sign up for Basic or…
```
```
{"claims":[{"claim":"The Readwise Reader API uses simple static-token authentication (an 'Authorization: Token XXX' header) with each user obtaining their own token from readwise.io/access_token — there is no OAuth flow or app-registration program documented, and the docs explicitly anticipate third-party integrations directing 'your users' to fetch their own tokens, which means a sandboxed client…
```
```
{"claims":[{"claim":"Raindrop.io provides an official, publicly documented API covering its service, hosted at developer.raindrop.io.","quote":"This is the official documentation for Raindrop.io API. A reference to the functionality our public API provides with detailed description of each API endpoint, parameters, and examples.","importance":"central"},{"claim":"Third-party access to the Raindrop…
```
```
{"claims":[{"claim":"Zotero Web API v3 supports pure client-side integration without any server middleman: third-party apps can either use OAuth or simply instruct users to create a dedicated API key in their Zotero account settings, which is then sent as a plain HTTP header (Zotero-API-Key or Authorization: Bearer) — an auth model fully compatible with a sandboxed Mac App Store app using URLSessi…
```
```
{"claims":[{"claim":"The Instapaper Full API authenticates via OAuth 1.0a with HMAC-SHA1 request signing, and xAuth (direct username/password exchange for a token) is the ONLY way to obtain an access token — there is no OAuth 2.0 PKCE flow. This means a sandboxed MAS client can integrate purely client-side (a simple signed POST to https://www.instapaper.com/api/1/oauth/access_token, no redirect UR…
```
```
{"claims":[{"claim":"Are.na's legacy developer portal (dev.are.na) and its V2 API are officially deprecated as of mid-2026, with documentation and OAuth application management relocated to the new Are.na Developers site at https://www.are.na/developers — so any integration plan citing the old V2 docs is stale.","quote":"This developer portal is deprecated. The V2 API documentation and OAuth applic…
```
```
{"claims":[{"claim":"Mozilla shut down Pocket on July 8, 2025, after announcing the shutdown on May 22, 2025 (app-store removal and new sign-ups disabled at announcement).","quote":"Mozilla officially shut down Pocket on July 8, 2025","importance":"central"},{"claim":"The Pocket data-export window closed on November 12, 2025, after which all user data was permanently deleted — meaning as of mid-20…
```
```
{"claims":[{"claim":"As of mid-2026, Reddit's free-access Data API rate limit is 100 queries per minute per OAuth client ID, averaged over a 10-minute window to permit bursting — ample for a personal research/PKM client's feed polling.","quote":"We enforce rate limits for those eligible for free access usage of our Data API. The limit is: 100 queries per minute (QPM) per OAuth client id. QPM limit…
```
```
{"claims":[{"claim":"Bluesky shipped a native bookmarking feature, announced Monday September 8, 2025, branded 'Saved Posts' — directly answering the research question of whether Bluesky shipped native bookmarks.","quote":"The company on Monday announced the new addition, which it calls Saved Posts.","importance":"central"},{"claim":"At launch, Bluesky bookmarks are stored off-protocol — outside t…
```
```
{"claims":[{"claim":"Mozilla shut down Pocket on July 8, 2025 (announced May 22, 2025), confirming Pocket is not an integrable source for any 2026 app; the app was acquired by Mozilla in 2017.","quote":"shutting down Pocket, a read-it-later app it acquired in 2017, on July 8","importance":"central"},{"claim":"Pocket user data export (list, archive, favorites, notes, highlights) was only available …
```
```
{"claims":[{"claim":"Mastodon provides an official, documented API endpoint for reading a user's bookmarks: GET /api/v1/bookmarks, which returns the statuses the authenticated user has bookmarked as an array of Status entities.","quote":"GET /api/v1/bookmarks ... Statuses the user has bookmarked. ... Returns: Array of Status","importance":"central"},{"claim":"The Mastodon bookmarks endpoint requir…
```
```
{"claims":[{"claim":"Secrets statically embedded in a distributed native app cannot be treated as confidential, which classifies native apps as OAuth public clients — meaning any research-source API that requires a confidential client secret (rather than supporting PKCE public clients) structurally requires a server middleman, while PKCE-supporting APIs can be integrated purely client-side in a sa…
```
```
{"claims":[{"claim":"In April 2016, Apple removed multiple popular third-party Reddit clients (Narwhal, iAlien, BaconReader, Eggplant, Antenna) from the App Store over NSFW content concerns — a documented precedent that third-party Reddit clients are an App Store review risk area.","quote":"Popular third-party Reddit apps like Narwhal, iAlien, Baconreader, Eggplant and Antenna have been pulled fro…
```
```
{"claims":[{"claim":"Guideline 5.2.2 requires that an app displaying content from a third-party service (e.g. Reddit, X, Hacker News, Hugging Face) be specifically permitted to do so under that service's terms of use, and Apple can demand proof of authorization — making each source's API ToS the controlling legal document for a ResearchHub feature, not just a technical detail.","quote":"If your ap…
```
```
{"claims":[{"claim":"Google Scholar has no official API in 2026; third-party tools scrape it but Google actively blocks automated access, so it cannot be a sanctioned feed source for a client app.","quote":"No official API exists. Third-party tools (Publish or Perish, various scrapers) simulate API access, but Google often blocks automated access. ... Thus, Google Scholar is not considered a stand…
```
```
{"claims":[{"claim":"The Semantic Scholar API is free to use, and most endpoints are publicly accessible without any authentication; an API key is optional and only certain endpoints require it, meaning a sandboxed macOS client can call it directly with no server-side secret and no OAuth flow.","quote":"Certain endpoints require authentication via an API key, and authenticated users have access to…
```
```
{"claims":[{"claim":"Semantic Scholar allows unauthenticated (no API key) access to its public API, with all unauthenticated users sharing a pooled rate limit of 5,000 requests per 5 minutes (since March 28, 2023) — meaning a sandboxed Mac client can call the API with no key and no server, but throughput is unpredictable because the pool is shared globally across all unauthenticated users.","quote…
```
```
{"refuted":false,"evidence":"Live fetch of the primary source (docs.x.com/x-api/posts/bookmarks/introduction, 2026-07-03) confirms the endpoints table lists exactly 5 endpoints: GET /2/users/:id/bookmarks, POST /2/users/:id/bookmarks, DELETE /2/users/:id/bookmarks/:tweet_id, GET /2/users/:id/bookmarks/folders (\"Get bookmark folders\"), and GET /2/users/:id/bookmarks/folders/:folder_id (\"Get Post…
```
```
{"refuted":false,"evidence":"Direct WebFetch of the cited primary source https://docs.x.com/x-api/posts/bookmarks/introduction on 2026-07-03 confirms the page documents exactly 5 endpoints in a table: GET /2/users/:id/bookmarks (get user's bookmarks), POST /2/users/:id/bookmarks, DELETE /2/users/:id/bookmarks/:tweet_id, GET /2/users/:id/bookmarks/folders (get bookmark folders), and GET /2/users/:i…
```
```
{"refuted":false,"evidence":"Independently fetched the primary source https://docs.x.com/x-api/posts/bookmarks/introduction on 2026-07-03: the page lists exactly 5 endpoints — GET /2/users/:id/bookmarks, POST /2/users/:id/bookmarks, DELETE /2/users/:id/bookmarks/:tweet_id, GET /2/users/:id/bookmarks/folders, and GET /2/users/:id/bookmarks/folders/:folder_id — matching the claim's count and exact p…
```
```
{"refuted":false,"evidence":"Live fetch (2026-07-03) of the cited primary source https://docs.x.com/x-api/posts/bookmarks/introduction confirms the prerequisite list verbatim: \"An approved developer account\", \"A Project and App in the Developer Console\", \"User Access Tokens via OAuth 2.0 PKCE or 3-legged OAuth\" — and confirms App-only/Bearer tokens are NOT listed for Bookmarks, so the user-c…
```
```
{"refuted":false,"evidence":"Refutation attempted on all axes; claim survives. (1) Quote verified verbatim on the cited primary source (docs.x.com/x-api/posts/bookmarks/introduction): prerequisites are \"An approved developer account,\" \"A Project and App in the Developer Console,\" and \"User Access Tokens via OAuth 2.0 PKCE or 3-legged OAuth\" — the claim's requirements list is a faithful read,…
```
```
{"refuted":false,"evidence":"Verified against the live primary source: https://docs.x.com/x-api/posts/bookmarks/introduction contains the quoted requirements verbatim — \"An approved developer account, A Project and App in the Developer Console, User Access Tokens via OAuth 2.0 PKCE or 3-legged OAuth\" — so the first half of the claim is directly supported. The public-client inference goes beyond …
```
```
{"refuted":false,"evidence":"Verbatim fetch of https://docs.x.com/x-api/posts/bookmarks/introduction on 2026-07-03 confirms every assertion: the page body contains only a bookmarks overview, a 5-endpoint table (GET/POST/DELETE /2/users/:id/bookmarks + 2 folder endpoints), and a Requirements section listing exactly the three quoted prerequisites (approved developer account, Project+App in Developer…
```
```
{"refuted":false,"evidence":"Live fetch of https://docs.x.com/x-api/posts/bookmarks/introduction on 2026-07-03 confirms the claim: the page's complete prerequisites list is verbatim \"An approved developer account / A Project and App in the Developer Console / User Access Tokens via OAuth 2.0 PKCE or 3-legged OAuth\" (matches supporting quote exactly), and the page contains no pricing, no rate-lim…
```
```
{"refuted":false,"evidence":"Two independent live fetches of https://docs.x.com/x-api/posts/bookmarks/introduction (2026-07-03) confirm the claim. A verbatim transcription with explicit string checks found \"Basic\", \"Pro\", \"Enterprise\", \"Free\", \"$\", \"per month\", \"rate limit\", \"requests per\", and \"15 minutes\" appear NOWHERE on the page. The complete Prerequisites callout is exactly…
```
```
{"refuted":false,"evidence":"Primary source verified live: docs.x.com/x-api/getting-started/pricing states verbatim \"The X API uses pay-per-usage pricing. No subscriptions—pay only for what you use\" and \"No contracts, subscriptions, or minimum spend,\" listing per-endpoint credit costs (bookmark write $0.005/request; post reads $0.005/resource) with no Free/Basic/Pro tiers anywhere on the page.…
```
```
{"refuted":false,"evidence":"Verified the primary source live on 2026-07-03: https://docs.x.com/x-api/getting-started/pricing contains the exact quote \"The X API uses pay-per-usage pricing. No subscriptions—pay only for what you use,\" lists no Free/Basic/Pro tiers anywhere, and documents upfront credit purchase in the Developer Console with per-endpoint costs (post reads $0.005, post create $0.0…
```
```
{"refuted":false,"evidence":"Claim verified against the live primary source and 4+ independent secondary sources. (1) Direct fetch of https://docs.x.com/x-api/getting-started/pricing confirms the quote verbatim (\"The X API uses pay-per-usage pricing. No subscriptions—pay only for what you use.\" / \"No contracts, subscriptions, or minimum spend\") and shows the mechanics: credits purchased in the…
```
```
{"refuted":true,"evidence":"The quote is real but ellipsized past the decisive qualifier. Live fetch of https://docs.x.com/x-api/getting-started/pricing (2026-07-03) confirms the endpoint is listed under Owned Reads at $0.001/resource (effective 2026-04-20), BUT the page states verbatim: \"The following endpoints qualify for Owned Read pricing when {id} matches the authenticated user AND that user…
```
```
{"refuted":true,"evidence":"The $0.001 Owned Reads rate and the bookmarks endpoint listing are real and current on the primary source (docs.x.com/x-api/getting-started/pricing, effective 2026-04-20), but the claim overreaches the quote in a way that breaks its conclusion. (1) Condition misstated: the claim says the rate applies \"when an app fetches the authenticated user's own data,\" but the off…
```
```
{"refuted":true,"evidence":"The claim overreaches its own source in a way that flips the answer for the stated use case, and its cost arithmetic is contradicted by post-rollout billing evidence. (1) Condition misstated: the claim says the $0.001 Owned Read rate applies \"when an app fetches the authenticated user's own data,\" but the cited page (docs.x.com/x-api/getting-started/pricing, fetched 2…
```
```
{"refuted":false,"evidence":"Claim confirmed by X's official pricing docs (docs.x.com/x-api/getting-started/pricing), which currently state \"Owned Reads are requests made by your own developer app for your own data (posts, bookmarks, followers, likes, lists, and more). These endpoints are priced at $0.001 per resource\" and explicitly list GET /2/users/{id}/bookmarks plus followers, following, li…
```
```
{"refuted":false,"evidence":"Claim survives adversarial verification. (1) The cited primary source exists: direct WebFetch of the devcommunity.x.com URL returned 403 (Discourse anti-bot), but the search index confirms the exact thread title \"X API Pricing Update: Owned Reads Now $0.001 + Other Changes Effective April 20, 2026\" in X Developers' Announcements category at the exact cited URL (post …
```
```
{"refuted":false,"evidence":"Claim verified against two independent official sources. (1) The cited devcommunity.x.com thread 263025 exists with the exact title \"X API Pricing Update: Owned Reads Now $0.001 + Other Changes Effective April 20, 2026\" in the official Announcements category (direct fetch returns 403 from Discourse anti-bot, but title/content verified via search index and multiple co…
```
```
{"refuted":false,"evidence":"Claim survives adversarial checks. (1) Definition quote verified verbatim via multiple independent mirrors: \"Owned Reads are requests made by your own developer app for your own posts, bookmarks, followers, likes, lists & more\" appears in the devcommunity thread 263025 snippet, and docs.x.com/x-api/getting-started/pricing carries the matching definition explicitly in…
```
```
{"refuted":false,"evidence":"Verified against the primary announcement's full text (retrieved via rendering proxy; devcommunity.x.com 403s direct fetches). All four claim components hold: (1) The definition is verbatim-accurate — \"Owned Reads are requests made by your own developer app for your own posts, bookmarks, followers, likes, lists & more\" — with GET /2/users/{id}/bookmarks explicitly li…
```
```
{"refuted":false,"evidence":"Verified against the FULL primary text of devcommunity.x.com thread 263025, retrieved via the Discourse JSON API (HTML fetch 403s; .json endpoint returned 200). The OP is by X staff member taycaldwell (staff: true), posted 2026-04-16, changes effective 2026-04-20, posts_count=1 (no substantive replies). Clause-by-clause: (1) Definition verbatim: \"Owned Reads are reque…
```
```
{"refuted":false,"evidence":"Every load-bearing element of the claim checks out against the primary source, fetched directly (github.com/prinsss/twitter-web-exporter, July 2026). (1) Bookmarks + 800-cap bypass: the README states verbatim \"the official API has a 800 limit when accessing the bookmarks. The script can export all bookmarks without that limit until it's restricted by the Twitter web a…
```
```
{"refuted":false,"evidence":"Attempted refutation failed on all checklist axes. (1) Quote-support: I fetched the primary source (github.com/prinsss/twitter-web-exporter) directly; the README states verbatim \"Export your bookmarks (without the max 800 limit!)\", explains \"the official API has a 800 limit when accessing the bookmarks. The script can export all bookmarks without that limit\", state…
```
```
{"refuted":false,"evidence":"Primary source verified 2026-07-03: the prinsss/twitter-web-exporter README states verbatim \"Export your bookmarks (without the max 800 limit!)\", \"No developer account or API key required\", and the FAQ text quoted in the claim (\"The script itself does not send any request to Twitter API. It installs an network interceptor to capture the response of GraphQL request…
```
```
{"refuted":false,"evidence":"Quote verified verbatim in prinsss/twitter-web-exporter README (repo current: v1.4.0, Feb 25 2026). Underlying facts independently corroborated by multiple mid-2026 sources: keep.md guide dated April 22, 2026 explicitly reports checking X's official help page and confirms \"The official archive will not export your bookmarks\" and that X Premium's only bookmark feature…
```
```
{"refuted":false,"evidence":"Claim survives adversarial checks. (1) Quote verified verbatim in prinsss/twitter-web-exporter README FAQ (\"Q: Why do you build this?\"): \"Twitter's archive only contains the numeric user ID of your following/followers which is not human-readable. The archive also does not contain your bookmarks.\" (2) X's own help pages (help.x.com \"How to download your X archive a…
```
```
{"refuted":false,"evidence":"Claim survives all five adversarial checks. (1) Quote verified verbatim: WebFetch of github.com/prinsss/twitter-web-exporter confirms the README FAQ states exactly \"Twitter's archive only contains the numeric user ID of your following/followers which is not human-readable. The archive also does not contain your bookmarks.\" — and the repo is actively maintained (v1.4.…
```

## Verification vote log
- Q: Research question: For a native macOS research/PKM app (Epistemos — sandboxed Ma…
- Decomposed into 5 angles: X bookmarks crux (primary decision), 2024–2026 platform-policy shifts (recent news), Scholarly API lane (academic/technical), Read-later & personal-library APIs, Client-only architecture & App Store review (practitioner)
- X bookmarks crux (primary decision): 6 results
- Read-later & personal-library APIs: 6 results
- 2024–2026 platform-policy shifts (recent news): 6 results
- 2024–2026 platform-policy shifts (recent news): 4 novel (2 filtered)
- Client-only architecture & App Store review (practitioner): 6 results
- Client-only architecture & App Store review (practitioner): 3 novel (3 filtered)
- Scholarly API lane (academic/technical): 6 results
- Scholarly API lane (academic/technical): 3 novel (3 filtered)
- Fetched 22 sources → 109 claims → verifying top 25
- "The X API v2 Bookmarks surface is live and documen…": 3-0 ✓
- "Bookmarks access requires user-context authenticat…": 3-0 ✓
- "This official Bookmarks introduction page states N…": 3-0 ✓
- "As of mid-2026, the X API no longer uses subscript…": 3-0 ✓
- "The Bookmarks read endpoint (GET /2/users/{id}/boo…": 0-3 ✗
- "twitter-web-exporter exports X/Twitter bookmarks (…": 3-0 ✓
- [v0:As of mid-2026, Reddit's free-access Dat] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:OAuth authentication is mandatory for th] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:Free Data API access exists in 2026 but] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:Free Data API access exists in 2026 but] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Free Data API access exists in 2026 but] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Free Data API access exists in 2026 but is framed …": 0-0 (3 errored) ?
- [v0:Any app that persists Reddit content loc] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:Any app that persists Reddit content loc] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Any app that persists Reddit content loc] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Any app that persists Reddit content locally (e.g.…": 0-0 (3 errored) ?
- [v0:Mastodon provides an official, documente] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:Mastodon provides an official, documente] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Mastodon provides an official, documente] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Mastodon provides an official, documented API endp…": 0-0 (3 errored) ?
- [v0:The Mastodon bookmarks endpoint requires] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:The Mastodon bookmarks endpoint requires] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:The Mastodon bookmarks endpoint requires] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "The Mastodon bookmarks endpoint requires OAuth use…": 0-0 (3 errored) ?
- [v0:The Semantic Scholar API is free to use,] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:The Semantic Scholar API is free to use,] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:The Semantic Scholar API is free to use,] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "The Semantic Scholar API is free to use, and most …": 0-0 (3 errored) ?
- [v2:As of mid-2026, Reddit's free-access Dat] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:Unauthenticated (keyless) access to the] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:Unauthenticated (keyless) access to the] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Unauthenticated (keyless) access to the] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Unauthenticated (keyless) access to the Semantic S…": 0-0 (3 errored) ?
- [v1:An authenticated Semantic Scholar API ke] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:An authenticated Semantic Scholar API ke] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:Semantic Scholar allows unauthenticated] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:An authenticated Semantic Scholar API ke] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "An authenticated Semantic Scholar API key starts a…": 0-0 (3 errored) ?
- [v2:Semantic Scholar allows unauthenticated] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:Semantic Scholar allows unauthenticated] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Semantic Scholar allows unauthenticated (no API ke…": 0-0 (3 errored) ?
- [v0:As of August 2024, Semantic Scholar stop] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:The Readwise Reader API uses simple stat] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:As of August 2024, Semantic Scholar stop] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:As of August 2024, Semantic Scholar stop] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "As of August 2024, Semantic Scholar stopped approv…": 0-0 (3 errored) ?
- [v1:The Readwise Reader API uses simple stat] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:As of mid-2026, Reddit's free-access Dat] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "As of mid-2026, Reddit's free-access Data API rate…": 0-0 (3 errored) ?
- [v2:The Readwise Reader API uses simple stat] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "The Readwise Reader API uses simple static-token a…": 0-0 (3 errored) ?
- [v0:Readwise Reader API rate limits are per] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Readwise Reader API rate limits are per] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:The Reader API v3 (base URL https://read] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:Readwise Reader API rate limits are per] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Readwise Reader API rate limits are per access tok…": 0-0 (3 errored) ?
- [v2:The Reader API v3 (base URL https://read] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:Raindrop.io provides an official, public] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:Raindrop.io provides an official, public] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:The Reader API v3 (base URL https://read] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "The Reader API v3 (base URL https://readwise.io/ap…": 0-0 (3 errored) ?
- [v1:Third-party access to the Raindrop.io AP] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:Third-party access to the Raindrop.io AP] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Raindrop.io provides an official, public] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Raindrop.io provides an official, publicly documen…": 0-0 (3 errored) ?
- [v2:Third-party access to the Raindrop.io AP] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Third-party access to the Raindrop.io API requires…": 0-0 (3 errored) ?
- [v0:OAuth authentication is mandatory for th] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "X defines 'Owned Reads' as requests made by a deve…": 3-0 ✓
- "X's official native archive export does NOT includ…": 3-0 ✓
- [v1:OAuth authentication is mandatory for th] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "OAuth authentication is mandatory for the Reddit D…": 0-0 (3 errored) ?
- "Effective Monday, April 20, 2026, X prices the boo…": 3-0 ✓
- Verify done: 25 claims → 8 confirmed, 1 refuted, 16 unverified
- [synthesize] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
