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
  version: "1.0.0"
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
| `curl` | Fetch raw HTML/JSON | `-s` (silent), `-H` (headers), `-o` (output file) |
| `sed` | Strip HTML tags | `'s/<[^>]*>//g'` |
| `grep` | Filter & extract lines | `-i` (case-insensitive), `-B/-A N` (context), `-v` (exclude) |
| `python3 -m json.tool` | Pretty-print JSON | Piped after curl for API responses |
| `python3 -c` | Custom parsing logic | For tables, nested JSON, complex extraction |

---

## Phase 1: Basic HTML Search (Wikipedia Scraping)

### 1.1 The Core Pattern

```bash
curl -s "https://en.wikipedia.org/wiki/TOPIC" \
  | sed 's/<[^>]*>//g' \
  | grep -i -B2 -A5 "KEYWORD1\|KEYWORD2\|KEYWORD3" \
  | head -80
```

**Example** — Conor McGregor injury:
```bash
curl -s "https://en.wikipedia.org/wiki/Conor_McGregor" \
  | sed 's/<[^>]*>//g' \
  | grep -i -B2 -A8 "tibia\|UFC 264\|broken\|fracture" \
  | head -80
```

### 1.2 Noise Filtering — The #1 Pain Point

**Problem:** Wikipedia HTML has massive amounts of JS/CSS/metadata noise.
**Solution:** Chain `grep -v` with common noise patterns:

```bash
grep -v "doi:\|PMID\|ISBN\|↑\|Retrieved\|Archived\|function()\|RLCONF\|RLSTATE\|RLPAGEMODULES\|mw-\|skin-\|vector-\|client-\|cdx-"
```

**Hard-won lesson:** Without noise filtering, useful content is buried under
hundreds of lines of boilerplate. Always add this filter line.

### 1.3 Context Window Tuning

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
curl -s "https://en.wikipedia.org/w/api.php?action=query&titles=TOPIC&prop=extracts&exintro&format=json&explaintext" \
  | python3 -m json.tool
```

**Example:**
```bash
curl -s "https://en.wikipedia.org/w/api.php?action=query&titles=Salvator_Mundi&prop=extracts&exintro&format=json&explaintext" \
  | python3 -m json.tool
```

**Why this matters:** The API returns **plain text** — no HTML stripping, no
noise filtering, no grep guessing. This is the cleanest path for factual
summaries.

### 2.2 Wikipedia API — Search (Find the Right Page)

When you're not sure of the exact article title:

```bash
curl -s "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=SEARCH_TERMS&format=json" \
  | python3 -m json.tool
```

**Example:**
```bash
curl -s "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=oldest+company+still+operating&format=json" \
  | python3 -m json.tool
```

**Pattern:** Use search API first → identify exact page title → then either
fetch full HTML (Phase 1) or intro extract (Phase 2.1).

### 2.3 GitHub API — Repository Search

```bash
curl -s "https://api.github.com/search/repositories?q=QUERY&sort=stars&order=desc&per_page=5" \
  | python3 -m json.tool
```

**Example:**
```bash
curl -s "https://api.github.com/search/repositories?q=skill.md+claude+code&sort=stars&order=desc&per_page=5" \
  | python3 -m json.tool
```

### 2.4 GitHub API — Browse Repo Contents

```bash
# List files/dirs in a repo
curl -s "https://api.github.com/repos/OWNER/REPO/contents/" \
  | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    print(f\"{item['type']:10} {item['name']}\")
"
```

### 2.5 GitHub Raw Files — Fetch File Content

```bash
curl -s "https://raw.githubusercontent.com/OWNER/REPO/BRANCH/PATH/TO/FILE" \
  | head -80
```

**Example:**
```bash
curl -s "https://raw.githubusercontent.com/mxyhi/ok-skills/main/exa-search/SKILL.md" \
  | head -80
```

**Hard-won lesson:** `raw.githubusercontent.com` returns raw file content with
zero HTML wrapper. Much cleaner than scraping the GitHub web UI.

---

## Phase 3: Advanced Strategies

### 3.1 Multi-Language Comparison

Compare how the same topic is described across language editions:

```bash
# English version
curl -s "https://en.wikipedia.org/wiki/TOPIC_EN" | sed 's/<[^>]*>//g' | grep -i "KEYWORD" | head -30

# Korean version
curl -s "https://ko.wikipedia.org/wiki/TOPIC_KO" | sed 's/<[^>]*>//g' | grep -i "키워드" | head -30
```

**Use case:** Territorial disputes (Dokdo/Takeshima), historical events,
cultural topics — different perspectives emerge clearly.

**URL encoding:** Korean characters need URL encoding. Use `%EB%8F%85%EB%8F%84`
for `독도`, or let curl handle it with `--data-urlencode`.

### 3.2 HTML Table Parsing with Python

For structured table data (rankings, statistics, lists):

```bash
curl -s "https://en.wikipedia.org/wiki/PAGE_WITH_TABLES" | python3 -c "
import sys, re
html = sys.stdin.read()
# Find wikitable elements
tables = re.findall(r'<table class=\"wikitable.*?</table>', html, re.DOTALL)
if tables:
    rows = re.findall(r'<tr>(.*?)</tr>', tables[0], re.DOTALL)
    for row in rows[:15]:
        cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.DOTALL)
        cells = [re.sub(r'<[^>]*>', '', c).strip() for c in cells]
        if cells:
            print(' | '.join(cells[:6]))
"
```

**Hard-won lesson:** Wikitable parsing is fragile. Regex-based extraction
breaks on:
- Nested tables
- `rowspan`/`colspan` attributes
- Non-standard class names (`wikitable sortable`)

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

Use `\|` in grep for OR matching across many keywords:

```bash
grep -i "keyword1\|keyword2\|keyword3\|keyword4"
```

**Example** — finding dream theories:
```bash
grep -i "activation-synthesis\|threat simulation\|memory consolidation\|Freud\|Jung\|Revonsuo"
```

---

## Phase 4: Troubleshooting & Anti-Patterns

### 4.1 Common Failures

| Problem | Cause | Fix |
|---|---|---|
| Empty output | Wrong URL encoding | URL-encode special chars; try `--data-urlencode` |
| Wall of noise | No `grep -v` filter | Always add noise filter (§1.2) |
| Incomplete content | `head -N` too small | Increase to `head -150` or remove cap |
| Garbled Unicode | Missing `LANG`/`UTF-8` | Add `--compressed` to curl |
| 403 Forbidden | Missing User-Agent | Add `-H "User-Agent: Mozilla/5.0"` |
| 404 on raw file | Wrong branch name | Default is `main`, not `master` |

### 4.2 Anti-Patterns to Avoid

❌ **Scraping when API exists** — Wikipedia API is always cleaner than HTML scraping.
Use scraping only for specific sections or tables.

❌ **Single grep without context** — `grep "keyword"` alone returns isolated
lines with no meaning. Always use `-B` and `-A`.

❌ **Fetching entire HTML to memory** — For very large pages, use `curl -o
file.html` then process the file. Avoid context overflow.

❌ **Ignoring rate limits** — GitHub API allows 60 req/hr unauthenticated.
Add `-H "Authorization: token YOUR_TOKEN"` for 5000/hr.

---

## Quick Reference Card

```bash
# ═══ Wikipedia Summary (cleanest) ═══
curl -s "https://en.wikipedia.org/w/api.php?action=query&titles=TOPIC&prop=extracts&exintro&format=json&explaintext" | python3 -m json.tool

# ═══ Wikipedia Search (find page) ═══
curl -s "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=QUERY&format=json" | python3 -m json.tool

# ═══ Wikipedia Deep Dive (HTML + grep) ═══
curl -s "https://en.wikipedia.org/wiki/TOPIC" | sed 's/<[^>]*>//g' | grep -v "doi:\|PMID\|ISBN\|↑\|Retrieved\|Archived\|function()\|RLCONF\|RLSTATE\|mw-\|skin-\|vector-\|client-" | grep -i -B2 -A5 "KEYWORD" | head -80

# ═══ GitHub Search ═══
curl -s "https://api.github.com/search/repositories?q=QUERY&sort=stars&order=desc&per_page=5" | python3 -m json.tool

# ═══ GitHub Raw File ═══
curl -s "https://raw.githubusercontent.com/OWNER/REPO/main/PATH" | head -80

# ═══ Generic Web Page ═══
curl -s -H "User-Agent: Mozilla/5.0" "https://example.com/page" | sed 's/<[^>]*>//g' | grep -i "KEYWORD" | head -50
```

---

## Decision Tree: Which Strategy to Use

```
Need to search something?
├── Is it a factual summary?
│   └── YES → Wikipedia API intro extract (§2.1)
├── Is it on GitHub?
│   ├── Need to find repos? → GitHub search API (§2.3)
│   ├── Need file contents? → raw.githubusercontent.com (§2.5)
│   └── Need repo structure? → GitHub contents API (§2.4)
├── Is it a Wikipedia deep dive?
│   └── HTML scrape + grep + noise filter (§1.1-1.3)
├── Need multi-language comparison?
│   └── Fetch en + ko versions, grep both (§3.1)
├── Need table/structured data?
│   └── Python regex wikitable parser (§3.2)
└── Generic web page?
    └── curl + sed + grep (Quick Reference §Generic)
```
