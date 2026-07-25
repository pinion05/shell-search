---
name: shell-search
description: >-
  Search the web from the shell using curl, grep, sed, and python for research,
  fact-checking, and data gathering. Activates when the user asks to search,
  research, look up, investigate, or find information online — especially when
  structured extraction, multi-source comparison, or automated pipeline-style
  research is needed. Covers Wikipedia scraping, GitHub API queries, REST API
  consumption, multi-language comparison, and HTML table parsing.
metadata:
  version: "1.1.0"
---

# Shell Search — Web Research from the Terminal

Search, scrape, parse, and synthesize information from the web using
`curl` + Unix text tools. No browser required.

## When to Use This Skill

| Trigger | Example |
|---|---|
| User asks to "search" or "research" something | "맥그리거 부상 조사해줘" |
| Need current data beyond training cutoff | "2025년 LLM 최신 동향" |
| Multi-language or multi-source comparison | "독도 관련 한국/일본 위키백과 비교" |
| Structured data extraction from web pages | "가장 비싼 그림 순위 표로 정리" |
| API lookup or GitHub repo search | "skill.md 포맷 조사해줘" |

## Tool Inventory

| Tool | Role | Key Flags |
|---|---|---|
| `curl` | Fetch raw HTML/JSON | `-s` (silent), `-L` (follow redirects), `-H` (headers), `-o` (output file) |
| `sed` | Strip HTML tags | `'s/<[^>]*>//g'` (tags only — entities & script/style bodies survive) |
| `grep` | Filter & extract lines | `-i` (case-insensitive), `-B/-A N` (context), `-v` (exclude), `-E` (extended regex) |
| `python3 -m json.tool` | Pretty-print JSON | Piped after curl for API responses |
| `python3 -c "import html,sys;..."` | Custom parsing + entity decode | For tables, nested JSON, and decoding `&amp;` `&#39;` etc. |

---

## Phase 1: Basic HTML Search (Wikipedia Scraping)

### 1.1 The Core Pattern

```bash
curl -sL "https://en.wikipedia.org/wiki/TOPIC" \
  | sed 's/<[^>]*>//g' \
  | grep -i -B2 -A5 "KEYWORD1\|KEYWORD2\|KEYWORD3" \
  | head -80
```

**Example** — Conor McGregor injury:
```bash
curl -sL "https://en.wikipedia.org/wiki/Conor_McGregor" \
  | sed 's/<[^>]*>//g' \
  | grep -i -B2 -A8 "tibia\|UFC 264\|broken\|fracture" \
  | head -80
```

**`-L` is required:** Wikipedia, GitHub, and most sites issue `301`/`302`
redirects (e.g. `http://` → `https://`, or canonical title moves). Without
`-L`, curl silently returns the redirect HTML instead of the page you wanted.
Always pass `-L` (or `-sL` together).

### 1.2 Noise Filtering — The #1 Pain Point

**Problem:** Wikipedia HTML has massive amounts of JS/CSS/metadata noise. A
bare `sed 's/<[^>]*>//g'` strips the *tags* but leaves the JS/CSS *bodies*
exposed (`RLCONF={...}`, `body{background:#eee}`, `function(){...}`). On
non-English wikis (ko/ja) this boilerplate can dwarf the actual article.

**Solution:** Chain `grep -v` with the noise patterns observed across
en/ko/ja editions:

```bash
grep -vE "doi:|PMID|ISBN|↑|Retrieved|Archived|function\(|RLCONF|RLSTATE|RLPAGEMODULES|mw-|skin-|vector-|client-|cdx-|wg[A-Z]|mw-parser-output|\.org/wiki|class=\""
```

**Better — strip `<script>`/`<style>` blocks BEFORE `sed`:**

```bash
curl -sL "https://ko.wikipedia.org/wiki/독도" \
  | sed -E 's/<script[^>]*>.*<\/script>//g; s/<style[^>]*>.*<\/style>//g' \
  | sed 's/<[^>]*>//g' \
  | grep -i "키워드" | head -30
```

**Hard-won lesson:** `sed 's/<[^>]*>//g'` removes *tags* but not the *text
inside* `<script>`/`<style>`. After tag removal, that text becomes ordinary
lines indistinguishable from article content. Always nuke script/style
blocks first, then strip tags, then apply `grep -v` for what remains.

### 1.3 HTML Entity Decoding

`sed 's/<[^>]*>//g'` does **not** decode entities. You'll see `Q&amp;A`,
`&#39;`, `&lt;`, `caf&eacute;` littering otherwise-clean text. Decode with
Python's `html` module:

```bash
curl -sL "https://en.wikipedia.org/wiki/TOPIC" \
  | sed 's/<[^>]*>//g' \
  | grep -i "KEYWORD" \
  | python3 -c "import sys,html; print(html.unescape(sys.stdin.read()))"
```

### 1.4 Context Window Tuning

| Flag | Effect | When to Use |
|---|---|---|
| `-B2` | 2 lines BEFORE match | Understanding context of a mention |
| `-A5` | 5 lines AFTER match | Reading the actual content around keyword |
| `-B2 -A8` | Generous context | Long paragraphs, detailed explanations |
| `-A3` only | Minimal context | Quick fact extraction, scanning many results |
| `head -N` | Limit total output | Prevent flooding the terminal/context |

**Rule of thumb:** Start with `-B1 -A3`. If results are incomplete, widen to
`-B2 -A8`. Use `head -N` to cap total output at 50–100 lines.

---

## Phase 2: Structured API Queries (Clean Data)

### 2.1 Wikipedia API — Intro Extract

When you only need a clean summary (no HTML parsing):

```bash
curl -sL "https://en.wikipedia.org/w/api.php?action=query&titles=TOPIC&prop=extracts&exintro&format=json&explaintext" \
  | python3 -m json.tool
```

**Example:**
```bash
curl -sL "https://en.wikipedia.org/w/api.php?action=query&titles=Salvator_Mundi&prop=extracts&exintro&format=json&explaintext" \
  | python3 -m json.tool
```

**Why this matters:** The API returns **plain text** — no HTML stripping, no
noise filtering, no grep guessing. This is the cleanest path for factual
summaries.

### 2.2 Wikipedia API — Search (Find the Right Page)

When you're not sure of the exact article title:

```bash
curl -sL "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=SEARCH_TERMS&format=json" \
  | python3 -c "
import sys, json, re, html
d = json.load(sys.stdin)
for r in d['query']['search']:
    title = r['title']
    # search snippets contain <span class=\"searchmatch\">...</span> HTML plus entities
    snippet = html.unescape(re.sub(r'<[^>]*>', '', r['snippet']))
    print(f\"- {title}: {snippet[:120]}\")
"
```

**Hard-won lesson:** The search API wraps matched terms in
`<span class="searchmatch">...</span>`. Piping through
`python3 -m json.tool` leaves those tags intact, so the "clean" output is
still half-HTML. Strip tags when extracting snippets.

**Pattern:** Use search API first → identify exact page title → then either
fetch full HTML (Phase 1) or intro extract (Phase 2.1).

### 2.3 GitHub API — Repository Search

GitHub's search response is huge (every item ships full owner object, URLs,
scores, timestamps). Pretty-printing it all burns context. Extract only what
you need:

```bash
curl -sL "https://api.github.com/search/repositories?q=QUERY&sort=stars&order=desc&per_page=5" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d['items']:
    print(f\"{r['stargazers_count']:>7} ★  {r['full_name']}\")
    if r.get('description'):
        print(f\"         {r['description'][:100]}\")
"
```

**Check remaining quota before bulk queries:**
```bash
curl -sL "https://api.github.com/rate_limit" \
  | python3 -c "import sys,json; d=json.load(sys.stdin)['resources']['core']; print(f\"{d['remaining']}/{d['limit']}\")"
```

### 2.4 GitHub API — Browse Repo Contents

```bash
curl -sL "https://api.github.com/repos/OWNER/REPO/contents/" \
  | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    print(f\"{item['type']:10} {item['name']}\")
"
```

### 2.5 GitHub Raw Files — Fetch File Content

```bash
curl -sL "https://raw.githubusercontent.com/OWNER/REPO/BRANCH/PATH/TO/FILE" \
  | head -80
```

**Example:**
```bash
curl -sL "https://raw.githubusercontent.com/mxyhi/ok-skills/main/exa-search/SKILL.md" \
  | head -80
```

**Hard-won lesson:** `raw.githubusercontent.com` returns raw file content with
zero HTML wrapper. Much cleaner than scraping the GitHub web UI.

---

## Phase 3: Advanced Strategies

### 3.1 Multi-Language Comparison

Compare how the same topic is described across language editions. **Apply the
same noise filtering as Phase 1** — non-English wikis (ko/ja) have even more
JS/CSS boilerplate relative to article length, so a bare `sed + grep` gets
drowned in `RLCONF={...}` walls.

```bash
# English version
curl -sL "https://en.wikipedia.org/wiki/TOPIC_EN" \
  | sed -E 's/<script[^>]*>.*<\/script>//g; s/<style[^>]*>.*<\/style>//g' \
  | sed 's/<[^>]*>//g' \
  | grep -ivE "doi:|PMID|RLCONF|RLSTATE|mw-|skin-|vector-|client-|wg[A-Z]" \
  | grep -i "KEYWORD" | head -30

# Korean version
curl -sL "https://ko.wikipedia.org/wiki/독도" \
  | sed -E 's/<script[^>]*>.*<\/script>//g; s/<style[^>]*>.*<\/style>//g' \
  | sed 's/<[^>]*>//g' \
  | grep -ivE "doi:|PMID|RLCONF|RLSTATE|mw-|skin-|vector-|client-|wg[A-Z]" \
  | grep -i "영토\|분쟁\|일본" | head -30
```

**Use case:** Territorial disputes (Dokdo/Takeshima), historical events,
cultural topics — different perspectives emerge clearly.

**URL encoding:** Non-ASCII path characters usually work bare in modern curl,
but if you hit `400`/empty results, URL-encode them
(`독도` → `%EB%8F%85%EB%8F%84`) or feed via `--data-urlencode`.

### 3.2 HTML Table Parsing with Python

For structured table data (rankings, statistics, lists):

```bash
curl -sL "https://en.wikipedia.org/wiki/PAGE_WITH_TABLES" | python3 -c "
import sys, re, html
src = sys.stdin.read()
# 1) drop script/style blocks (their text survives sed tag-stripping)
src = re.sub(r'<script[^>]*>.*?</script>', '', src, flags=re.DOTALL)
src = re.sub(r'<style[^>]*>.*?</style>', '', src, flags=re.DOTALL)
# 2) match wikitable by class substring (handles 'wikitable', 'wikitable sortable', ...)
tables = re.findall(r'<table[^>]*class=\"[^\"]*wikitable[^\"]*\"[^>]*>.*?</table>', src, re.DOTALL)
if tables:
    # 3) <tr style=...> and <tr class=...> must match — use <tr[^>]*>
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', tables[0], re.DOTALL)
    for row in rows[:15]:
        cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.DOTALL)
        # 4) strip nested tags AND decode entities (Q&amp;A -> Q&A, &#39; -> ')
        cells = [html.unescape(re.sub(r'<[^>]*>', '', c).strip()) for c in cells]
        if any(cells):
            print(' | '.join(c[:40] for c in cells[:6]))
"
```

**Hard-won lessons (regex table parsing is fragile):**
- `<tr>` literal fails on `<tr style="...">` / `<tr class="...">` → use
  `<tr[^>]*>`. The original `<tr>` pattern returns **zero rows** on tables
  where every row carries attributes.
- `<table class="wikitable...">` matches, but
  `<table class="wikitable sortable">` and `<table class="infobox wikitable">`
  need the substring match above.
- Entities like `&amp;` `&#39;` `&eacute;` survive tag-stripping → always run
  `html.unescape` on each cell.
- Still breaks on: nested tables, `rowspan`/`colspan`, `<ref>...</ref>` and
  `data-mw` JSON blobs embedded in cells.

**When table parsing fails:** Fall back to API or manual grep extraction.

### 3.3 Progressive Refinement Pipeline

The proven 4-step research flow:

```
Step 1: SEARCH API → find correct page title
Step 2: INTRO EXTRACT API → get clean summary
Step 3: FULL HTML + grep → get specific details/sections
Step 4: RAW FILE / NESTED API → deep dive into references/sources
```

**Example flow (researching SKILL.md format):**
```
1. GitHub search: "skill.md claude code" → find repos
2. List repo contents → find SKILL.md files
3. Fetch raw SKILL.md → read format/structure
4. Fetch 3+ examples → identify common patterns
```

### 3.4 Multi-Keyword OR Queries

Use `\|` in basic grep, or `-E "a|b|c"` for extended regex (cleaner with
many keywords):

```bash
grep -iE "keyword1|keyword2|keyword3|keyword4"
```

**Example** — finding dream theories:
```bash
grep -iE "activation-synthesis|threat simulation|memory consolidation|Freud|Jung|Revonsuo"
```

---

## Phase 4: Troubleshooting & Anti-Patterns

### 4.1 Common Failures

| Problem | Cause | Fix |
|---|---|---|
| Empty output, `301`/`302` in `-w` | Missing `-L` (no redirect follow) | Always use `curl -sL` |
| Wrong page silently returned | Redirect not followed | Use `-L`; inspect with `-w "%{http_code} %{url_effective}\n"` |
| Empty output | Wrong URL encoding | URL-encode special chars; try `--data-urlencode` |
| Wall of `RLCONF`/CSS noise | script/style bodies not removed | Strip `<script>`/`<style>` blocks before `sed` (§1.2) |
| `Q&amp;A` / `&#39;` in text | Entities not decoded | `python3 -c "import html..."` (§1.3) |
| Wall of noise | No `grep -v` filter | Always add noise filter (§1.2) |
| Table parser returns 0 rows | `<tr>` literal; rows have attributes | Use `<tr[^>]*>` (§3.2) |
| Incomplete content | `head -N` too small | Increase to `head -150` or remove cap |
| Garbled Unicode | Missing `LANG`/`UTF-8` | Add `--compressed` to curl |
| 403 Forbidden | Missing User-Agent | Add `-H "User-Agent: Mozilla/5.0"` |
| 404 on raw file | Wrong branch name | Default is `main`, not `master` |
| GitHub `403 rate limit` | >60 req/hr unauthenticated | Check `/rate_limit`; add token header |

### 4.2 Anti-Patterns to Avoid

❌ **Forgetting `-L`** — Without redirect-following, you'll get the redirect
page, not the content. This is the most common silent failure. Use `curl -sL`.

❌ **`sed` only, no script/style stripping** — Tag-stripping leaves JS/CSS
bodies as plain text. Remove `<script>`/`<style>` blocks first.

❌ **Skipping entity decode** — `&amp;` `&#39;` `&lt;` will corrupt your
extracted text. Always finish with `html.unescape`.

❌ **Scraping when API exists** — Wikipedia API is always cleaner than HTML
scraping. Use scraping only for specific sections or tables.

❌ **`json.tool` on huge API responses** — GitHub search dumps owner objects,
URLs, timestamps per item. Extract only the fields you need with `python3 -c`.

❌ **Single grep without context** — `grep "keyword"` alone returns isolated
lines with no meaning. Always use `-B` and `-A`.

❌ **Fetching entire HTML to memory** — For very large pages, use `curl -o
file.html` then process the file. Avoid context overflow.

❌ **Ignoring rate limits** — GitHub's `core` resource allows 60 req/hr
unauthenticated (verified: it is `core`, not a generic "60/hr" — search uses
`search` resource, separate quota). Add
`-H "Authorization: token YOUR_TOKEN"` for 5000/hr.

---

## Quick Reference Card

```bash
# ═══ Wikipedia Summary (cleanest) ═══
curl -sL "https://en.wikipedia.org/w/api.php?action=query&titles=TOPIC&prop=extracts&exintro&format=json&explaintext" | python3 -m json.tool

# ═══ Wikipedia Search (find page, snippets cleaned) ═══
curl -sL "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=QUERY&format=json" | python3 -c "
import sys,json,re,html
for r in json.load(sys.stdin)['query']['search']:
    print(f\"- {r['title']}: {html.unescape(re.sub(r'<[^>]*>','',r['snippet']))[:120]}\")"

# ═══ Wikipedia Deep Dive (HTML + script/style strip + grep + entity decode) ═══
curl -sL "https://en.wikipedia.org/wiki/TOPIC" \
  | sed -E 's/<script[^>]*>.*<\/script>//g; s/<style[^>]*>.*<\/style>//g' \
  | sed 's/<[^>]*>//g' \
  | grep -vE "doi:|PMID|ISBN|RLCONF|RLSTATE|mw-|skin-|vector-|client-" \
  | grep -i -B2 -A5 "KEYWORD" \
  | python3 -c "import sys,html; print(html.unescape(sys.stdin.read()))" \
  | head -80

# ═══ GitHub Search (stars + name + description only) ═══
curl -sL "https://api.github.com/search/repositories?q=QUERY&sort=stars&order=desc&per_page=5" | python3 -c "
import sys,json
for r in json.load(sys.stdin)['items']:
    print(f\"{r['stargazers_count']:>7} ★  {r['full_name']}\")
    if r.get('description'): print(f\"         {r['description'][:100]}\")"

# ═══ GitHub Rate Limit Check ═══
curl -sL "https://api.github.com/rate_limit" | python3 -c "import sys,json; d=json.load(sys.stdin)['resources']['core']; print(f\"{d['remaining']}/{d['limit']}\")"

# ═══ GitHub Raw File ═══
curl -sL "https://raw.githubusercontent.com/OWNER/REPO/main/PATH" | head -80

# ═══ Generic Web Page ═══
curl -sL -H "User-Agent: Mozilla/5.0" "https://example.com/page" \
  | sed -E 's/<script[^>]*>.*<\/script>//g; s/<style[^>]*>.*<\/style>//g' \
  | sed 's/<[^>]*>//g' | grep -i "KEYWORD" | head -50
```

---

## Decision Tree: Which Strategy to Use

```
Need to search something?
├── Is it a factual summary?
│   └── YES → Wikipedia API intro extract (§2.1)
├── Is it on GitHub?
│   ├── Need to find repos? → GitHub search API, extract fields (§2.3)
│   ├── Need file contents? → raw.githubusercontent.com (§2.5)
│   └── Need repo structure? → GitHub contents API (§2.4)
├── Is it a Wikipedia deep dive?
│   └── HTML scrape + script/style strip + grep + entity decode (§1.1-1.4)
├── Need multi-language comparison?
│   └── Fetch en + ko versions, BOTH with noise filter (§3.1)
├── Need table/structured data?
│   └── Python regex wikitable parser, <tr[^>]*> + html.unescape (§3.2)
└── Generic web page?
    └── curl -sL + script/style strip + sed + grep (Quick Reference §Generic)
```
