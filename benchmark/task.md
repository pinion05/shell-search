# shell-search benchmark

This benchmark measures `shell-search/SKILL.md`'s **information access
capability** — how well the skill's patterns let an agent retrieve specific
information from the web using only `curl` + Unix text tools.

It is **not** an absolute performance grade. It is an **iterative
improvement tool**: improve `SKILL.md`, re-run this benchmark, compare the
score. If the score goes up and no task regressed, the change is an
improvement.

---

## How to use this

### As a user
Ignore this file. Use `shell-search/SKILL.md`.

### As an improver
1. Edit `shell-search/SKILL.md`.
2. Run the benchmark (below).
3. Compare the new score against the **BASELINE** column in each task.
4. A change is an improvement if: total score went up AND no task's score
   went down.

### How to run the benchmark

This file is consumed by a parent agent. The parent:
1. Reads `shell-search/SKILL.md`.
2. For each task below, dispatches a `general-purpose` **sub-agent** with
   the constraint contract (next section) + the SKILL.md content + that
   one task.
3. Collects each sub-agent's raw response.
4. Scores each response against the task's EXPECTED field using the rubric
   (next section).
5. Reports: per-task score, total, and diff vs baseline.

The sub-agent never sees EXPECTED or BASELINE — only GOAL and URL.

---

## Sub-agent constraint contract (skill-only)

Paste this into every sub-agent dispatch:

```
You are running ONE benchmark task for the shell-search skill.

STRICT CONSTRAINTS — violating any invalidates the result:
1. Use ONLY techniques documented in the SKILL.md provided. Do not invent
   commands, do not "improve" patterns, do not apply prior knowledge of
   how the target site works.
2. Use ONLY the Bash tool. No web search, no WebFetch, no browser, no MCP
   tools, no other agents.
3. Use the EXACT URL given in the task. Do not substitute a "better" URL.
4. If the skill's pattern fails (empty output, error, garbage), DO NOT
   debug, retry, or work around it. Report the failure honestly. A failure
   is a valid finding.
5. Consult no documentation other than the SKILL.md provided.

OUTPUT FORMAT — your entire response:
- Heading with the task ID (e.g. "## T1")
- The exact commands you ran (copied from SKILL.md patterns)
- The raw output you observed (verbatim, max 30 lines)
- A one-line "RESULT:" stating what information you obtained (or failed to).

No commentary, no suggestions, no improvements.
```

---

## Scoring rubric (parent agent applies this to each sub-agent response)

| Score | Meaning |
|---|---|
| **0** | No access — error, empty, blocked, or garbage output |
| **1** | Accessed the source but did not obtain the target information |
| **2** | Obtained the target information partially (noisy, incomplete, or wrong shape) |
| **3** | Obtained the target information clearly and correctly |

A response is INVALID (not scored) if the sub-agent violated the contract:
used a non-Bash tool, substituted the URL, added patterns not in SKILL.md,
applied prior site knowledge, or salvaged a failure with an off-skill
workaround. Treat INVALID as a forced 0 for scoring purposes and flag it.

---

## Tasks

Each task below is one dispatch. The improver's goal is to raise scores
without regressing others. Current total baseline: **24 / 42**.

### T1 — React 19 features
- **GOAL:** List the new features introduced in React 19, from the official React site.
- **URL:** `https://react.dev/`
- **EXPECTED:** Specific named features (e.g. Actions, `use`, `useFormStatus`, `useOptimistic`, Server Components, Asset Loading). A version badge like "v19.2" alone does not satisfy this.
- **BASELINE: 1** — SSR text loads (version badge, marketing copy) but the feature list is not in the static HTML; goal not met.

### T2 — Cloudflare-protected blog
- **GOAL:** List the article titles/topics on the nowsecure.nl blog.
- **URL:** `https://nowsecure.nl/`
- **EXPECTED:** Actual article titles or topic names. A "Just a moment" / Turnstile challenge page does not satisfy this.
- **BASELINE: 0** — Cloudflare Turnstile challenge; no article content in static HTML.

### T3 — Wikipedia disambiguation ("Mercury")
- **GOAL:** Give a single clear answer to "what is Mercury?".
- **URL:** `https://en.wikipedia.org/w/api.php?action=query&titles=Mercury&prop=extracts&exintro&format=json&explaintext`
- **EXPECTED:** A specific subject (planet / element / mythology / etc.) chosen and described, not a "may refer to" list.
- **BASELINE: 3** (SKILL.md v1.3.0 §2.7) — `pageprops` detects the disambiguation page; the §2.7 flow resolves to `Mercury_(planet)` and extracts its intro.

### T4 — Reddit top posts
- **GOAL:** The current top posts on r/programming with titles (and ideally authors/scores).
- **URL:** `https://www.reddit.com/r/programming/` (the agent may use any in-skill pattern to read this subreddit — the exact endpoint is the agent's choice per SKILL.md).
- **EXPECTED:** 3+ actual post titles from the subreddit's current front page. A 403/empty response does not satisfy this.
- **BASELINE: 0** (pre-§2.6) — `.json` 403 without auth. After SKILL.md §2.6 added the `.rss` pattern, this task is improvable.

### T5 — Arabic Wikipedia (RTL)
- **GOAL:** The article text at this URL in a usable form (raw text acceptable; translation out of scope).
- **URL:** `https://ar.wikipedia.org/wiki/%D9%85%D8%B1%D9%83%D8%A8`
- **EXPECTED:** Substantial article text (not nav/error). Note this URL redirects to a disambiguation page — partial credit for extracting that list.
- **BASELINE: 2** — Text extracted cleanly; the URL is itself a disambiguation, so content is a list not a definition.

### T6 — GitHub search rate limit
- **GOAL:** Perform 12 rapid `/search/repositories` calls; report how many succeed.
- **URL:** `https://api.github.com/search/repositories?q=benchmark-test-i` (i = 1..12)
- **EXPECTED:** A correct count (~10 succeed, ~2 fail at the search quota ceiling). Note: this task measures whether the skill correctly anticipates/handles the limit, not whether 12 succeed.
- **BASELINE: 3** — Skill's rate-limit docs predict the 10/min ceiling exactly; agent's preflight + error-safe extractor correctly reports 10 OK then 403.

### T7 — HTTP→HTTPS redirect
- **GOAL:** Fetch the Linux kernel repo page via its `http://` URL.
- **URL:** `http://github.com/torvalds/linux`
- **EXPECTED:** Repository description / README content (the page must be reached, not a 301 body).
- **BASELINE: 3** — `curl -sL` follows the redirect; README extracted.

### T8 — Hacker News top stories
- **GOAL:** The top 10 story titles on the HN front page.
- **URL:** `https://news.ycombinator.com/`
- **EXPECTED:** 10 actual story titles.
- **BASELINE: 3** — Static HTML; all titles extracted in one pass.

### T9 — arXiv PDF text
- **GOAL:** The abstract / problem statement of "Attention Is All You Need".
- **URL:** `https://arxiv.org/pdf/1706.03762`
- **EXPECTED:** The paper's abstract text.
- **BASELINE: 0** — Binary PDF; UnicodeDecodeError; skill has no PDF pattern.

### T10 — GitHub GraphQL
- **GOAL:** The name and description of `torvalds/linux` via the GraphQL endpoint.
- **URL:** `https://api.github.com/graphql` (POST with a GraphQL query body)
- **EXPECTED:** Repository name and description.
- **BASELINE: 0** — Skill has no POST/GraphQL pattern; unauthenticated GET rate-limited.

### T11 — Bloomberg headlines
- **GOAL:** The top 5 business headlines on Bloomberg.
- **URL:** `https://www.bloomberg.com/`
- **EXPECTED:** 5 actual headlines.
- **BASELINE: 0** — 403 "Are you a robot?"; paywall/bot-block.

### T12 — Korean Wikipedia (bare UTF-8 URL)
- **GOAL:** The first paragraph of the Dokdo article, using the bare Korean URL.
- **URL:** `https://ko.wikipedia.org/wiki/독도`
- **EXPECTED:** The article's first paragraph (location/description of Dokdo).
- **BASELINE: 3** — Bare UTF-8 path works; first paragraph extracted cleanly.

### T13 — Expired TLS certificate
- **GOAL:** The content of the page at this URL.
- **URL:** `https://expired.badssl.com/`
- **EXPECTED:** The page body text.
- **BASELINE: 3** (SKILL.md v1.2.0 §4.1) — `curl: (60)` now has a documented fix (`-k` for known test endpoints); `curl -skL` retrieves the page body.

### T14 — Reddit post comments
- **GOAL:** Extract the top reader comments on a Reddit post.
- **POST PERMALINK:** `https://www.reddit.com/r/ExperiencedDevs/comments/1v5wrck/how_bad_is_a_toxic_csuite_member_for_senior/`
- **EXPECTED:** 3+ actual reader comments (not the OP self-post) with their text.
- **BASELINE: 3** (SKILL.md v1.2.0 §2.6) — `.rss` on the permalink yields ~17 comments after the documented rate-limit cooldown.

---

## Baseline summary (2026-07-25, SKILL.md v1.3.0)

| Task | Score | Notes |
|---|---|---|
| T1  | 1 | SSR text only; feature list not in static HTML |
| T2  | 0 | Cloudflare Turnstile |
| T3  | 3 | `pageprops` detects disambig (§2.7); resolves to `Mercury_(planet)` and extracts |
| T4  | 3 | `.rss` (§2.6) yields 25 posts with titles/authors |
| T5  | 2 | Text extracted (URL is itself a disambiguation) |
| T6  | 3 | Rate-limit docs predict 10/min exactly |
| T7  | 3 | `-L` follows redirect; README extracted |
| T8  | 3 | Static HTML; all titles extracted |
| T9  | 0 | Binary PDF; no PDF pattern |
| T10 | 0 | No POST/GraphQL pattern |
| T11 | 0 | Paywall/bot-block |
| T12 | 3 | Bare UTF-8 URL works |
| T13 | 3 | §4.1 documents `-k`; `curl -skL` retrieves the page body |
| T14 | 3 | `.rss` on a permalink (§2.6) yields ~17 comments |
| **Total** | **24 / 42** | |

**Improvement log:**
- v1.1.1 → v1.2.0: added §2.6 (Reddit RSS). T4 0 → 3, T14 added (3). 12/39 → 18/42.
- v1.2.0 → v1.3.0: added §2.7 (disambiguation detection) and §4.1 `-k` row.
  T3 1 → 3, T13 0 → 3. 18/42 → 24/42.

## Hard limits (do not try to "fix" in SKILL.md)

Some 0s are **not improvable** within the curl+text-tools paradigm — they
are fundamental limits, not skill gaps. Improvers should not chase these:

- **T2** (Cloudflare JS challenge) — requires executing JS. Out of paradigm.
- **T9** (PDF binary) — requires a PDF parser (`pdftotext`/pypdf). Out of
  paradigm; a pointer in SKILL.md is the most you can do (would not raise
  the score on this exact task).
- **T10** (GraphQL POST) — requires POST + auth + query body. Out of paradigm.
- **T11** (Bloomberg paywall/bot-block) — requires browser or auth. Out of
  paradigm.

**Note:** T4 (Reddit) was in this list at v1.1.1 as "requires auth". That
was wrong — the `.rss` endpoint works unauthenticated. v1.2.0 §2.6 lifted
T4 to 3. Before declaring a 0 a "hard limit", verify there isn't an
unauthenticated alternate endpoint (RSS, Atom, export, archive, mobile).

The improvable 0s/1s are: **T1** (if a better target URL or pattern exists
in-skill). T3 (disambiguation) and T13 (`-k`) were resolved in v1.3.0.

## Improver workflow

```
1. Edit shell-search/SKILL.md
2. Re-run the benchmark (dispatch all 14 tasks to sub-agents per the
   contract; parent scores each result against EXPECTED using the rubric)
3. Compare new score vs BASELINE column above
4. If total ↑ AND no task regressed: improvement accepted. Update the
   BASELINE column in this file with the new scores.
5. If any task regressed: fix or revert before accepting.
```
