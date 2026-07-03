# RAW ResearchHub research — academic workflow (2026-07-03)
> RAW research archive — provenance only, DO NOT BUILD FROM THIS. Verbatim output of the ResearchHub deep-research workflow (interrupted at synthesis by a credit limit; searches+fetches completed). Distilled + corrected in RESEARCHHUB_SOURCE_DOSSIER_2026_07_03.md. Preserved so no research is lost.

**Stats:** {"angles": 5, "sources": 26, "claims": 130, "verified": 25, "confirmed": 7, "killed": 0, "unverified": 18, "afterSynthesis": 0}

## CONFIRMED claims (7)
- **The Unpaywall REST API is free and requires no API key — authentication is just an email query parameter appended to each request, and the live API enforces this by rejecting placeholder emails (a call with an example.com address returns HTTP 422 'Please use your own email address in API calls'). This makes it fully MAS-viable client-side from Swift/URLSession with nothing to store in Keychain.**
  - source: https://unpaywall.org/products/api
  - quote: "The REST API gives anyone free, programmatic access to the Unpaywall database. [...] Requests must include your email as a parameter at the end of the URL, like this: api.unpaywall.org/my/request?email=YOUR_EMAIL"
  - vote: 3-0
- **The stated rate limit is 100,000 calls per day (an honor-system 'please limit' request, not a hard enforced quota per the docs), with bulk users directed to snapshot downloads instead — far more than a personal PKM app needs for one-click OA resolution.**
  - source: https://unpaywall.org/products/api
  - quote: "Please limit use to 100,000 calls per day. If you need faster access, you'll be better served by downloading the entire database snapshot for local access."
  - vote: 3-0
- **The GET /v2/:doi endpoint implements the core 'OA resolution chain' step directly: given a DOI it returns OA status plus bibliographic info, and (live-verified 2026-07-03 against 10.1038/nature12373) the JSON includes is_oa, oa_status ('green'), an oa_locations array, and best_oa_location with url_for_pdf (e.g. https://arxiv.org/pdf/1304.1068), url_for_landing_page, license, version, and host_type — i.e., DOI → Unpaywall → legal OA PDF link in one call.**
  - source: https://unpaywall.org/products/api
  - quote: "Gets OA status and bibliographic info for an given DOI-assigned resource. [...] https://api.unpaywall.org/v2/10.1038/nature12373?email=YOUR_EMAIL"
  - vote: 3-0
- **Elsevier's free API use cases require the client application itself to be free of charge, non-commercial, and advertising-free — meaning a paid Mac App Store app would not qualify for the free-tier Scopus/SciVal display use cases without a separate commercial agreement.**
  - source: https://dev.elsevier.com/policy.html
  - quote: "The client application needs to be free of use and non-commercial. This also means that it should be free of advertising."
  - vote: 3-0
- **Abstract display rights differ by Elsevier product and use case: ScienceDirect abstracts may be displayed (federated search use case), while Scopus abstracts are explicitly prohibited from public display in the institutional-repository use case and are only permitted for the Academic Research use case.**
  - source: https://dev.elsevier.com/policy.html
  - quote: "For results from ScienceDirect, the display of abstracts is allowed. ... The following Scopus items may not be displayed publicly: abstracts"
  - vote: 3-0
- **Elsevier's policy forbids persistently storing or indexing API-retrieved data — only temporary performance caching is allowed — which blocks ingesting Elsevier-sourced metadata/citation edges into a local knowledge graph in perpetuity (with a narrow exception for institutional repositories' own-institution metadata).**
  - source: https://dev.elsevier.com/policy.html
  - quote: "Data retrieved through the APIs cannot be indexed or stored in a data repository, other than temporarily for performance reasons"
  - vote: 2-0
- **The IEEE Xplore API license scope is restricted to non-commercial educational, research, or scientific use inside the licensee's own educational institution, so embedding it in a commercially distributed macOS app (like Epistemos on MAS) without a separately negotiated commercial license would violate the terms.**
  - source: https://developer.ieee.org/API_Terms_of_Use2
  - quote: "non-commercial educational, research, or scientific activities within the Licensee's educational institution"
  - vote: 3-0

## UNVERIFIED claims (quote-backed; verification cut off by credits) (18)
- IEEE's terms forbid bulk retention or bulk presentation of API content — content may only be displayed in response to an individual query — which blocks persisting IEEE metadata/abstracts into a local vault or knowledge graph and blocks feeding IEEE records in as citation edges for offline storage.
  - source: https://developer.ieee.org/API_Terms_of_Use2
- IEEE explicitly prohibits using any API content for AI/ML/LLM training, enhancement, or development, a restriction directly relevant to an AI-native PKM app that processes paper metadata with on-device models.
  - source: https://developer.ieee.org/API_Terms_of_Use2
- API access is gated to existing IEEE customers (with registration and an API key) unless a specific license is agreed, meaning a general consumer app cannot assume its end users are eligible to obtain keys.
  - source: https://developer.ieee.org/API_Terms_of_Use2
- Springer Nature offers a 'Meta API' that exposes metadata and abstracts for millions of its documents — this is the publisher-sanctioned route for a third-party client app (like Epistemos) to display abstracts and metadata for Springer/Nature papers, including paywalled ones, without touching full text.
  - source: https://dev.springernature.com/
- Springer Nature offers a dedicated 'Open Access API' that returns full-text content of its open-access publications, meaning a DOI→OA-copy resolution chain can terminate at a publisher-direct full-text fetch for SN OA papers rather than relying solely on Unpaywall/OpenAlex.
  - source: https://dev.springernature.com/
- Full text of Springer Nature's paywalled corpus is only available via the Full Text (TDM) API, which is explicitly scoped to subscription-based content (over 3 million articles across 20+ subject areas) — so client-side full-text access to paywalled SN papers requires a subscription/TDM entitlement and is not viable as a free baseline for a consumer MAS app.
  - source: https://dev.springernature.com/
- The OpenAIRE Graph API enforces a rate limit of 60 requests per hour for unauthenticated requests and 7,200 requests per hour for authenticated requests, with no payment tier mentioned — making it a free API whose practical ceiling depends only on whether the client registers.
  - source: https://graph.openaire.eu/docs/apis/graph-api/
- OpenAIRE Graph records are licensed CC-BY and may be re-used commercially in a client app (e.g., displayed in a native macOS PKM) as long as OpenAIRE is credited as the data source — resolving the content-licensing/ToS-for-display question in the app's favor.
  - source: https://graph.openaire.eu/docs/apis/graph-api/
- The CORE API is free to use without registration at a baseline tier, but organisations that register for faster rates typically pay; Supporting/Sustaining Members get the faster rate free as a member benefit.
  - source: https://core.ac.uk/services/api
- CORE's advertised baseline rate limit is one batch request or five single requests per 10 seconds, with faster/VIP rates available only by contacting CORE.
  - source: https://core.ac.uk/services/api
- Commercial use of the CORE API is explicitly permitted under CORE's Terms & Conditions, with a 30-day free trial for Institution and Enterprise tiers and an eligibility assessment for free licences during registration — relevant because a Mac App Store app is a commercial integration.
  - source: https://core.ac.uk/services/api
- The CORE API provides real-time machine access to full texts of open-access research papers, not just metadata, making it usable as a full-text retrieval node in a DOI-to-PDF OA resolution chain.
  - source: https://core.ac.uk/services/api
- OSF APIv2 permits anonymous (unauthenticated) read access but caps it at 100 requests/hour, while authenticated requests get 10,000/day; 429 responses carry a Retry-After header. This makes a Keychain-stored personal token effectively required for any serious client-side preprint polling in Epistemos.
  - source: https://developer.osf.io/
- Authentication is a user-created Personal Access Token sent as a Bearer header (created at osf.io/settings/tokens, with limitable scopes) or an OAuth 2.0 web-application flow — plain HTTPS REST with no SDK requirement, so it is MAS-viable via URLSession with the token in Keychain.
  - source: https://developer.osf.io/
- One API serves all OSF-hosted preprint servers: the /v2/preprints/ endpoint filters by provider (the spec names OSF, socarxiv, and psyarxiv as example providers), and provider-scoped endpoints exist at /providers/preprints/{provider_id}/preprints/ plus per-provider taxonomies, licenses, and subjects — confirming PsyArXiv-family servers share the single OSF API. Filtering on date_created/date_modified enables client-side new-preprint alert polling.
  - source: https://developer.osf.io/
- Europe PMC provides an official REST API operated by EMBL-EBI (with the Europe PMC Funders' Group and NLM), making it a first-party institutional source rather than a scraper or third-party wrapper.
  - source: https://europepmc.org/RestfulWebService
- The API exposes large-scale free full-text and open-access content (10.2M full-text articles, 6.5M OA articles across 33M+ publications), directly supporting the 'Europe PMC = free full text' claim for the BIO/MED discipline lane.
  - source: https://europepmc.org/RestfulWebService
- The API provides citation-network and reference-list data (reference lists for 19.4M+ publications plus citation counts), which can feed citation EDGES into the app's local knowledge graph.
  - source: https://europepmc.org/RestfulWebService

## SOURCES fetched (26)
- https://unpaywall.org/products/api (primary, 5 claims)
- https://dev.elsevier.com/policy.html (primary, 5 claims)
- https://developer.ieee.org/API_Terms_of_Use2 (primary, 5 claims)
- https://dev.springernature.com/ (primary, 5 claims)
- https://graph.openaire.eu/docs/apis/graph-api/ (primary, 5 claims)
- https://core.ac.uk/services/api (primary, 5 claims)
- https://developer.osf.io/ (primary, 5 claims)
- https://europepmc.org/RestfulWebService (primary, 5 claims)
- https://api.biorxiv.org/ (primary, 5 claims)
- https://dblp.org/faq/How+to+use+the+dblp+search+API.html (primary, 5 claims)
- https://api.zbmath.org/static/terms-and-conditions.html (primary, 5 claims)
- https://blog.google/technology/safety-security/serpapi-lawsuit/ (primary, 5 claims)
- https://www.theregister.com/2026/02/21/serpapi_google_scraping_lawsuit/ (secondary, 5 claims)
- https://serpapi.com/pricing (primary, 5 claims)
- https://blog.openalex.org/openalex-api-new-features-and-usage-based-pricing/ (primary, 5 claims)
- https://www.semanticscholar.org/product/api (primary, 5 claims)
- https://support.khanacademy.org/hc/en-us/community/posts/360055082872-API-removal-notice (primary, 5 claims)
- https://openlibrary.org/developers/api (primary, 5 claims)
- https://github.com/garethbjohnson/gutendex (primary, 5 claims)
- https://www.mediawiki.org/wiki/Wikimedia_APIs/Rate_limits (primary, 5 claims)
- https://docs.openalex.org/api-entities/works/filter-works (primary, 5 claims)
- https://developers.openalex.org/api-reference/introduction (primary, 5 claims)
- https://api.semanticscholar.org/api-docs/ (primary, 5 claims)
- https://api.semanticscholar.org/api-docs/recommendations (primary, 5 claims)
- https://support.lens.org/knowledge-base/lens-patent-and-scholar-api/ (primary, 5 claims)
- https://effortlessacademic.com/litmaps-vs-researchrabbit-vs-connected-papers-the-best-literature-review-tool-in-2025/ (blog, 5 claims)

## RAW agent findings (resultPreviews — the pre-verification search/fetch signal)
```
{"question":"Deep-dive the ACADEMIC layer of a ResearchHub for Epistemos (native macOS PKM, MAS-sandboxed, Swift/URLSession client-side, optional tiny proxy, keys in Keychain, arXiv already built): discipline-deep and college-resource-deep source audit — for every source document official API, auth, mid-2026 cost, rate limits, content licensing/ToS for display, MAS client-side viability, S/M/L eff…
```
```
{"results":[{"url":"https://unpaywall.org/products/api","title":"Unpaywall REST API — official docs","relevance":"high","snippet":"The backbone of the DOI→OA-copy resolution chain: free REST API, no auth key (just an email param), ~100,000 calls/day politeness limit, returns best_oa_location.url_for_pdf for one-click legal OA PDF resolution. Client-side URLSession friendly, MAS-viable, effort S. D…
```
```
{"results":[{"url":"https://developer.osf.io/","title":"OSF APIv2 Documentation (developer.osf.io)","relevance":"high","snippet":"THE key insight for the coverage map: OSF is the single shared API behind PsyArXiv, SocArXiv, engrXiv, LawArXiv, Thesis Commons, EdArXiv and other discipline preprint servers. The /v2/preprints/ endpoint takes a `provider` filter (e.g. 'psyarxiv'), so ONE Swift/URLSessi…
```
```
{"results":[{"url":"https://blog.google/technology/safety-security/serpapi-lawsuit/","title":"Google: Why we're taking legal action against SerpApi's unlawful scraping","relevance":"high","snippet":"Official Google statement on the lawsuit filed Dec 19, 2025 (N.D. Cal., Case 5:25-cv-10826) accusing SerpApi of circumventing its 'SearchGuard' anti-bot system with cloaking and bot networks, and resel…
```
```
{"results":[{"url":"https://support.khanacademy.org/hc/en-us/community/posts/360055082872-API-removal-notice","title":"Khan Academy Help Center — API removal notice","relevance":"high","snippet":"Official confirmation that Khan Academy's public API was retired: most endpoints removed Jan 6, 2020, the rest (including /topictree content calls) on July 1, 2020, with no replacement or third-party deve…
```
```
{"results":[{"url":"https://docs.openalex.org/api-entities/works/filter-works","title":"Filter works — OpenAlex technical documentation","relevance":"high","snippet":"The single most important page for citation-edge ingestion AND client-side alerts: `filter=cites:W...` returns all incoming citations of a paper, `authorships.author.id` + `from_publication_date` gives new-papers-by-author polling, a…
```
```
{"claims":[{"claim":"The Unpaywall REST API is free and requires no API key — authentication is just an email query parameter appended to each request, and the live API enforces this by rejecting placeholder emails (a call with an example.com address returns HTTP 422 'Please use your own email address in API calls'). This makes it fully MAS-viable client-side from Swift/URLSession with nothing to …
```
```
{"claims":[{"claim":"Elsevier's free API use cases require the client application itself to be free of charge, non-commercial, and advertising-free — meaning a paid Mac App Store app would not qualify for the free-tier Scopus/SciVal display use cases without a separate commercial agreement.","quote":"The client application needs to be free of use and non-commercial. This also means that it should …
```
```
{"claims":[{"claim":"The IEEE Xplore API license scope is restricted to non-commercial educational, research, or scientific use inside the licensee's own educational institution, so embedding it in a commercially distributed macOS app (like Epistemos on MAS) without a separately negotiated commercial license would violate the terms.","quote":"non-commercial educational, research, or scientific act…
```
```
{"claims":[{"claim":"Springer Nature offers a 'Meta API' that exposes metadata and abstracts for millions of its documents — this is the publisher-sanctioned route for a third-party client app (like Epistemos) to display abstracts and metadata for Springer/Nature papers, including paywalled ones, without touching full text.","quote":"Access metadata and abstracts for millions of scientific documen…
```
```
{"claims":[{"claim":"The OpenAIRE Graph API enforces a rate limit of 60 requests per hour for unauthenticated requests and 7,200 requests per hour for authenticated requests, with no payment tier mentioned — making it a free API whose practical ceiling depends only on whether the client registers.","quote":"Authenticated requests: up to 7200 requests per hour … Non-authenticated requests: up to 60…
```
```
{"claims":[{"claim":"The CORE API is free to use without registration at a baseline tier, but organisations that register for faster rates typically pay; Supporting/Sustaining Members get the faster rate free as a member benefit.","quote":"CORE API is free and does not require registration, subject to our rate limits . However, organisations that register get a faster rate that is typically not fr…
```
```
{"claims":[{"claim":"OpenAlex /works supports citation-edge filters `cites`, `cited_by`, and `related_to` (all marked filterable in the works field table), and every work record carries a `referenced_works` array of outbound citation edges; verified live with a keyless request `api.openalex.org/works?filter=cites:W2741809807`, which returned meta.count=1,218 citing works — so OpenAlex can feed bot…
```
```
{"claims":[{"claim":"As of mid-2026, the OpenAlex API is officially a freemium service with metered free daily usage — roughly $0.10/day of usage with no key and $1/day with a free API key — superseding the older 'free, no-auth, polite pool' characterization assumed in the research question; usage beyond the free budget is paid.","quote":"The API is a freemium service with free daily usage—$0.10/d…
```
```
{"claims":[{"claim":"The Semantic Scholar Academic Graph API (base /graph/v1) exposes dedicated citation-edge endpoints — /paper/{paper_id}/citations and /paper/{paper_id}/references — and the citations endpoint can return per-edge citation metadata (citation contexts, intents, and an isInfluential flag) via the fields parameter, making it directly usable for ingesting typed citation edges into a …
```
```
{"claims":[{"claim":"Semantic Scholar operates an official, dedicated Recommendations API (v1.0) that returns recommended papers given input papers, via two endpoints: GET /recommendations/v1/papers/forpaper/{paper_id} for single-paper 'more like this' queries, and POST /recommendations/v1/papers/ which accepts lists of positive and negative example papers — directly usable from a Swift/URLSession…
```
```
{"claims":[{"claim":"Lens.org's non-commercial Trial plan grants API access that expires 14 days after approval, so there is no free ongoing Lens API tier for a personal client app.","quote":"The Lens API is valid for 14 days from the approval date under this plan.","importance":"central"},{"claim":"Continued or integrated access to the Lens API requires the paid 'Member | Custom Access' plan, whi…
```
```
{"claims":[{"claim":"ResearchRabbit was acquired by Litmaps, and as of November 2025 ResearchRabbit was re-released under a freemium model — a 2024-2026 landscape change directly affecting which visual literature-mapping tools remain independent integration targets.","quote":"ResearchRabbit itself was acquired by Litmaps... As of November 2025, ResearchRabbit has been re-released","importance":"ce…
```
```
{"claims":[{"claim":"Google filed a lawsuit against SerpApi on December 19, 2025, alleging SerpApi circumvented security measures to scrape copyrighted content from Google Search results — meaning the leading commercial 'Google Scholar API' workaround is under active legal attack by Google as of 2026, a decisive integration risk for any app considering SerpApi.","quote":"We filed a suit today agai…
```
```
{"claims":[{"claim":"Google sued SerpApi in December 2025, alleging that SerpApi's web scraping of Google search results circumvents Google's security measures protecting copyrighted content — meaning the leading commercial Google/Scholar scraping API vendor is under active litigation from Google as of early 2026.","quote":"Google in December 2025 sued SerpApi, alleging that its web scraping circu…
```
```
{"claims":[{"claim":"SerpApi sells dedicated scraping-based Google Scholar endpoints in mid-2026 — a general Scholar search API, an author-profile API, and a case-law API — confirming a commercial workaround exists for Google Scholar's lack of an official API.","quote":"The page lists \"Google Scholar API,\" \"Google Scholar Author API,\" and \"Google Scholar Case Law API\" in the comprehensive AP…
```
```
{"claims":[{"claim":"As of this February 24, 2026 announcement, OpenAlex requires an API key for all API requests (keys are free and take ~30 seconds to obtain); unauthenticated access is limited to a few demo calls — ending the prior no-auth production access model assumed in the research question's 'free no-auth, polite pool' framing.","quote":"you'll need an API key for all requests.","importan…
```
```
{"claims":[{"claim":"The Semantic Scholar API is an official, free service from Ai2, and most endpoints work with no authentication at all — meaning a MAS-sandboxed Swift/URLSession client can call it directly with zero keys and zero cost.","quote":"Most Semantic Scholar endpoints are available to the public without authentication","importance":"central"},{"claim":"Unauthenticated access draws fro…
```
```
{"claims":[{"claim":"Khan Academy officially stopped supporting its public API in 2020 as part of a platform transition, with all subsequent API calls returning errors — confirmed in a badged 'Official comment' by Khan Academy staff (Johanna D., 2020-02-19) on the official Khan Academy Help Center.","quote":"We are making numerous changes as we transition to a new technical platform. As part of th…
```
```
{"claims":[{"claim":"Open Library's public APIs require no API key or payment for read access; rate limits are 1 request/second for anonymous requests and 3 requests/second for requests that identify themselves via a User-Agent header containing the application name and a contact email — a policy a sandboxed macOS app can satisfy client-side with URLSession by setting a custom User-Agent.","quote"…
```
```
{"claims":[{"claim":"Gutendex is a free, MIT-licensed, self-hostable web API that serves Project Gutenberg's book catalog metadata as JSON — so Epistemos can either query it directly or vendor/self-host it with no cost, no publisher licensing problem, and full MAS-sandbox client-side viability (plain HTTPS + URLSession).","quote":"Gutendex is a simple, self-hosted web API for serving book catalog …
```
```
{"claims":[{"claim":"Wikimedia introduced new global API rate limits in 2026, and they are still explicitly experimental and subject to change — a 2026 change any client integration must track.","quote":"The rate limits described on this page are new in 2026 and are subject to experimentation and change.","importance":"central"},{"claim":"The 2026 limits are tiered per minute: unidentified clients…
```
```
{"claims":[{"claim":"OSF APIv2 permits anonymous (unauthenticated) read access but caps it at 100 requests/hour, while authenticated requests get 10,000/day; 429 responses carry a Retry-After header. This makes a Keychain-stored personal token effectively required for any serious client-side preprint polling in Epistemos.","quote":"Wait at least the amount of time specified in the `Retry-After` he…
```
```
{"claims":[{"claim":"Europe PMC provides an official REST API operated by EMBL-EBI (with the Europe PMC Funders' Group and NLM), making it a first-party institutional source rather than a scraper or third-party wrapper.","quote":"Europe PMC is developed by EMBL-EBI with support from the Europe PMC Funders' Group, in collaboration with the National Library of Medicine (NLM)","importance":"central"}…
```
```
{"claims":[{"claim":"bioRxiv operates an official, free REST API covering both the bioRxiv and medRxiv preprint servers, with a content-detail endpoint pattern of https://api.biorxiv.org/details/[server]/[interval]/[cursor]/[format] where server is bioRxiv or medRxiv.","quote":"The format of the endpoint is _https://api.biorxiv.org/details/[server]/[interval]/[cursor]/[format]_ ... where 'server' …
```
```
{"claims":[{"claim":"dblp operates an official, free public search API with three dedicated endpoints — publication search, author search, and venue search — reachable at dblp.org/search/{publ,author,venue}/api, giving a CS/AI-discipline index that a client app can query directly.","quote":"Publication search: \"https://dblp.org/search/publ/api\" — Author search: \"https://dblp.org/search/author/a…
```
```
{"claims":[{"claim":"All data returned by the zbMATH Open REST API may be used under a CC BY-SA license, which permits display and reuse (including commercial use) in a client app provided attribution and share-alike terms are honored.","quote":"All data are allowed to be used under a CC-BY-SA license","importance":"central"},{"claim":"The zbMATH Open API exposes bibliographic metadata, DOIs, revi…
```
```
{"refuted":false,"evidence":"Live-verified 2026-07-03: (1) curl to api.unpaywall.org/v2/10.1038/nature12373?email=test@example.com returned HTTP/2 422 with body message \"Please use your own email address in API calls. See http://unpaywall.org/products/api\" — the claim's placeholder-rejection detail is verbatim-accurate. (2) Same DOI with a real email returned HTTP/2 200 with full OA-resolution J…
```
```
{"refuted":false,"evidence":"Live-tested the API directly on 2026-07-03: (1) GET api.unpaywall.org/v2/10.1038/nature12373?email=test@example.com returned HTTP 422 with body message \"Please use your own email address in API calls. See http://unpaywall.org/products/api\" — a verbatim match to the claim's 422 assertion; (2) the same DOI with a real email returned HTTP 200 with full OA JSON (best_oa_…
```
```
{"refuted":false,"evidence":"Live-tested the API directly on 2026-07-03, which confirms every component of the claim against the current production system: (1) GET https://api.unpaywall.org/v2/10.1038/nature12373?email=test@example.com returned HTTP 422 with body {\"error\": true, \"message\": \"Please use your own email address in API calls. See http://unpaywall.org/products/api\"} — a verbatim m…
```
```
{"refuted":false,"evidence":"Verified against the LIVE unpaywall.org site on 2026-07-03 by downloading the page's Vue bundle (https://unpaywall.org/js/app.7e8a2b6c.js): under an explicit \"Rate limits\" heading it contains verbatim \"Please limit use to 100,000 calls per day. If you need faster access, you'll be better served by downloading the entire database snapshot for local access.\" — exactl…
```
```
{"refuted":false,"evidence":"Claim survives adversarial review. (1) The quote fully supports it: \"Please limit use to 100,000 calls per day. If you need faster access, you'll be better served by downloading the entire database snapshot\" — request-phrased (\"please\") limit of 100k/day with bulk users directed to snapshots, exactly as claimed; no 429/hard-quota mechanism is documented. (2) Curren…
```
```
{"refuted":false,"evidence":"Claim matches the primary source nearly verbatim and survived a currency check across the biggest recent change to the service. Unpaywall docs state \"Please limit use to 100,000 calls per day. If you need faster access, you'll be better served by downloading the entire database snapshot for local access\" — the \"honor-system, not hard enforced per the docs\" characte…
```
```
{"refuted":false,"evidence":"Independently reproduced the claim live on 2026-07-03: `curl https://api.unpaywall.org/v2/10.1038/nature12373?email=...` returned HTTP 200 JSON with is_oa=true, oa_status=\"green\", an oa_locations array (3 entries), and best_oa_location containing url_for_pdf=https://arxiv.org/pdf/1304.1068 (exact match to the claimed URL), url_for_landing_page=http://arxiv.org/abs/13…
```
```
{"refuted":false,"evidence":"Independently live-replicated on 2026-07-03: GET https://api.unpaywall.org/v2/10.1038/nature12373?email=... returned HTTP 200 with is_oa=true, oa_status=\"green\", oa_locations array (3 entries), and best_oa_location containing url_for_pdf=\"https://arxiv.org/pdf/1304.1068\" (exact match to the claim), url_for_landing_page=\"http://arxiv.org/abs/1304.1068\", license (k…
```
```
{"refuted":false,"evidence":"Independently reproduced the live verification on 2026-07-03: GET https://api.unpaywall.org/v2/10.1038/nature12373?email=<real email> returned HTTP 200 with is_oa=true, oa_status=\"green\", oa_locations array (3 entries), and best_oa_location containing url_for_pdf=https://arxiv.org/pdf/1304.1068 (exact match to the claim's example), url_for_landing_page=http://arxiv.o…
```
```
{"refuted":false,"evidence":"Quote verified verbatim on the live primary source (https://dev.elsevier.com/policy.html): \"The client application needs to be free of use and non-commercial. This also means that it should be free of advertising.\" — attached to the \"Showing publications from Scopus\" and SciVal-metrics display use cases, exactly the use cases the claim names. Corroborated by Elsevi…
```
```
{"refuted":false,"evidence":"Verified against the live primary source (fetched 2026-07-03). The exact quote \"The client application needs to be free of use and non-commercial. This also means that it should be free of advertising.\" appears verbatim on https://dev.elsevier.com/policy.html under the \"Showing publications from Scopus on your website\" use case and again under \"SciVal institutiona…
```
```
{"refuted":false,"evidence":"Verified against the primary source (fetched live 2026-07-03). The quote exists essentially verbatim on https://dev.elsevier.com/policy.html in the Scopus website-display use case: \"The client application needs to be free of use and non-commercial. This also means that it should be free of advertising.\" The SciVal metrics-display use case carries the same requirement…
```
```
{"refuted":false,"evidence":"Verified against the live primary source (https://dev.elsevier.com/policy.html, fetched 2026-07-03, three consistent extractions). The Federated Search use case section contains verbatim: \"For Scopus and Engineering Village, the application can only show the core bibliographic data for each search result; abstracts and references are off-limits. For results from Scien…
```
```
{"refuted":false,"evidence":"Verified live on dev.elsevier.com/policy.html (fetched 2026-07-03). Both supporting quotes appear verbatim in the sections the claim attributes them to: \"For results from ScienceDirect, the display of abstracts is allowed\" is in the Federated Search use case, and \"The following Scopus items may not be displayed publicly: abstracts\" is in the \"Scopus institutional …
```
```
{"refuted":false,"evidence":"Verified directly against the live primary source https://dev.elsevier.com/policy.html (fetched 2026-07-03, twice with independent prompts). All three components check out verbatim: (1) Federated Search section: \"For results from ScienceDirect, the display of abstracts is allowed\" while for Scopus \"the application can only show the core bibliographic data for each s…
```
```
{"refuted":false,"evidence":"Quote verified verbatim on live https://dev.elsevier.com/policy.html: \"Data retrieved through the APIs cannot be indexed or stored in a data repository, other than temporarily for performance reasons (e.g. non-permanent caching)\" — it sits under the Federated Search use-case section, not as a global header (minor scope imprecision in the claim). The conclusion noneth…
```
```
{"refuted":false,"evidence":"Quote verified verbatim on the live primary source (https://dev.elsevier.com/policy.html, fetched 2026-07-03). Adversarial context check: the sentence sits in the Federated Search use-case section, not a global clause — but a full outline of all 16 use-case sections shows the ONLY in-perpetuity storage grants anywhere on the page are the institutional-repository/CRIS/V…
```
```
{"refuted":false,"evidence":"Primary source verified by direct fetch of https://developer.ieee.org/API_Terms_of_Use2 (July 2026): the quoted license-grant language \"non-commercial educational, research, or scientific activities within the Licensee's educational institution\" appears verbatim. The claim's inference is independently reinforced by Section 3(i) (\"you shall not distribute any portion…
```
```
{"refuted":false,"evidence":"Direct fetch of the cited primary source (developer.ieee.org/API_Terms_of_Use2, live July 2026) confirms the quote verbatim in the Grant of License: \"The foregoing activities may only be conducted for the following permitted purposes: non-commercial educational, research, or scientific activities within the Licensee's educational institution (the 'License').\" Additio…
```
```
{"refuted":false,"evidence":"Direct fetch of https://developer.ieee.org/API_Terms_of_Use2 (2026-07-03) confirms the quoted grant language verbatim in the Grant of License section: \"non-commercial educational, research, or scientific activities within the Licensee's educational institution.\" The inference in the claim is independently supported by three more clauses/pages: (1) same terms: \"Acces…
```
```
{"refuted":false,"evidence":"Fetched https://developer.ieee.org/API_Terms_of_Use2 live (2026-07-03), twice. The quoted language exists verbatim in Section 4(a): \"you may only present the Content in response to an individual query; you may not present the Content in bulk format.\" The claim's \"bulk retention\" half is also in the document: 4(f) \"you shall require all users accessing the Content …
```

## Verification vote log
- Q: Research question: Deep-dive the ACADEMIC layer of a "ResearchHub" for Epistemos…
- Decomposed into 5 angles: OA resolution & publisher paywall APIs, Discipline indexes & preprint server APIs, Google Scholar gap & substitute stack, Open courseware & learning-resource APIs, Citation-graph & discovery infrastructure
- OA resolution & publisher paywall APIs: 6 results
- Citation-graph & discovery infrastructure: 6 results
- Google Scholar gap & substitute stack: 6 results
- Google Scholar gap & substitute stack: 5 novel (1 filtered)
- Open courseware & learning-resource APIs: 6 results
- Open courseware & learning-resource APIs: 4 novel (2 filtered)
- Discipline indexes & preprint server APIs: 6 results
- Discipline indexes & preprint server APIs: 5 novel (1 filtered)
- Fetched 26 sources → 130 claims → verifying top 25
- "The Unpaywall REST API is free and requires no API…": 3-0 ✓
- "The GET /v2/:doi endpoint implements the core 'OA …": 3-0 ✓
- "Elsevier's free API use cases require the client a…": 3-0 ✓
- "The stated rate limit is 100,000 calls per day (an…": 3-0 ✓
- "Abstract display rights differ by Elsevier product…": 3-0 ✓
- "The IEEE Xplore API license scope is restricted to…": 3-0 ✓
- [v1:IEEE explicitly prohibits using any API] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:API access is gated to existing IEEE cus] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:API access is gated to existing IEEE cus] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:Springer Nature offers a 'Meta API' that] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:Springer Nature offers a 'Meta API' that] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Springer Nature offers a 'Meta API' that] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Springer Nature offers a 'Meta API' that exposes m…": 0-0 (3 errored) ?
- [v0:Springer Nature offers a dedicated 'Open] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:Elsevier's policy forbids persistently s] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Springer Nature offers a dedicated 'Open] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:Springer Nature offers a dedicated 'Open] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Springer Nature offers a dedicated 'Open Access AP…": 0-0 (3 errored) ?
- [v1:Full text of Springer Nature's paywalled] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:Full text of Springer Nature's paywalled] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Full text of Springer Nature's paywalled] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Full text of Springer Nature's paywalled corpus is…": 0-0 (3 errored) ?
- [v0:The OpenAIRE Graph API enforces a rate l] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:The OpenAIRE Graph API enforces a rate l] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:The OpenAIRE Graph API enforces a rate l] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "The OpenAIRE Graph API enforces a rate limit of 60…": 0-0 (3 errored) ?
- [v0:OpenAIRE Graph records are licensed CC-B] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:OpenAIRE Graph records are licensed CC-B] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:OpenAIRE Graph records are licensed CC-B] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "OpenAIRE Graph records are licensed CC-BY and may …": 0-0 (3 errored) ?
- [v0:The CORE API is free to use without regi] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:The CORE API is free to use without regi] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:The CORE API is free to use without regi] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "The CORE API is free to use without registration a…": 0-0 (3 errored) ?
- [v0:CORE's advertised baseline rate limit is] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:CORE's advertised baseline rate limit is] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:CORE's advertised baseline rate limit is] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "CORE's advertised baseline rate limit is one batch…": 0-0 (3 errored) ?
- [v1:Commercial use of the CORE API is explic] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:Commercial use of the CORE API is explic] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Commercial use of the CORE API is explic] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Commercial use of the CORE API is explicitly permi…": 0-0 (3 errored) ?
- [v0:The CORE API provides real-time machine] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:The CORE API provides real-time machine] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:The CORE API provides real-time machine] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "The CORE API provides real-time machine access to …": 0-0 (3 errored) ?
- [v0:OSF APIv2 permits anonymous (unauthentic] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:OSF APIv2 permits anonymous (unauthentic] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:OSF APIv2 permits anonymous (unauthentic] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "OSF APIv2 permits anonymous (unauthenticated) read…": 0-0 (3 errored) ?
- [v0:Authentication is a user-created Persona] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:Authentication is a user-created Persona] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Authentication is a user-created Persona] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Authentication is a user-created Personal Access T…": 0-0 (3 errored) ?
- [v0:One API serves all OSF-hosted preprint s] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:One API serves all OSF-hosted preprint s] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:One API serves all OSF-hosted preprint s] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "One API serves all OSF-hosted preprint servers: th…": 0-0 (3 errored) ?
- [v1:Europe PMC provides an official REST API] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:Europe PMC provides an official REST API] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:Europe PMC provides an official REST API] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Europe PMC provides an official REST API operated …": 0-0 (3 errored) ?
- [v0:The API exposes large-scale free full-te] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:The API exposes large-scale free full-te] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:The API exposes large-scale free full-te] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "The API exposes large-scale free full-text and ope…": 0-0 (3 errored) ?
- [v0:The API provides citation-network and re] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v1:The API provides citation-network and re] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v0:API access is gated to existing IEEE cus] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "API access is gated to existing IEEE customers (wi…": 0-0 (3 errored) ?
- [v0:IEEE explicitly prohibits using any API] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:The API provides citation-network and re] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "The API provides citation-network and reference-li…": 0-0 (3 errored) ?
- [v2:IEEE explicitly prohibits using any API] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "IEEE explicitly prohibits using any API content fo…": 0-0 (3 errored) ?
- [v1:IEEE's terms forbid bulk retention or bu] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- [v2:IEEE's terms forbid bulk retention or bu] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
- "Elsevier's policy forbids persistently storing or …": 2-0 (1 errored) ✓
- "IEEE's terms forbid bulk retention or bulk present…": 1-0 (2 errored) ?
- Verify done: 25 claims → 7 confirmed, 0 refuted, 18 unverified
- [synthesize] failed: You're out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.
