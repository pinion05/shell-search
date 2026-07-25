# 🐚 shell-search

> A [Claude Code Agent Skill](https://docs.anthropic.com/en/docs/claude-code/skills) for web research from the terminal using `curl` + Unix text tools.

## What is this?

`shell-search` is a skill that teaches Claude (or any SKILL.md-compatible agent) how to search, scrape, parse, and synthesize information from the web — **without a browser**. It covers:

- **Wikipedia scraping** (HTML + script/style strip + grep patterns)
- **Wikipedia API queries** (clean JSON extracts & search, with snippet cleaning)
- **GitHub API queries** (repo search with field extraction, contents browsing, raw file fetch)
- **Multi-language comparison** (cross-reference en/ko/ja editions)
- **HTML table parsing** (Python regex wikitable extraction)
- **HTML entity decoding** (`html.unescape` for `&amp;` `&#39;`)
- **Noise filtering** (battle-tested `grep -v` patterns + script/style removal)
- **Progressive refinement pipeline** (4-step research flow)

## Quick Start

### Option A: Clone into your Claude skills directory

```bash
git clone https://github.com/pinion05/shell-search.git ~/.claude/skills/shell-search
```

### Option B: Copy just the SKILL.md

```bash
mkdir -p ~/.claude/skills/shell-search
curl -sL https://raw.githubusercontent.com/pinion05/shell-search/main/shell-search/SKILL.md \
  -o ~/.claude/skills/shell-search/SKILL.md
```

## File Structure

```
shell-search/
├── shell-search/
│   └── SKILL.md      # The skill definition (v1.1.1)
├── README.md
└── LICENSE
```

## Skill Triggers

Claude will activate this skill when you ask things like:

| Trigger | Example |
|---|---|
| "Search" or "research" something | "맥그리거 부상 조사해줘" |
| Need current data | "2025년 LLM 최신 동향 알려줘" |
| Multi-source comparison | "독도 관련 한국/일본 위키백과 비교해줘" |
| Structured data extraction | "가장 비싼 그림 순위 표로 정리해줘" |
| API or GitHub lookup | "skill.md 포맷 조사해줘" |

## Core Patterns (Cheat Sheet)

```bash
# Wikipedia clean summary (API)
curl -sL "https://en.wikipedia.org/w/api.php?action=query&titles=TOPIC&prop=extracts&exintro&format=json&explaintext" | python3 -m json.tool

# Wikipedia search with cleaned snippets (strip <span class="searchmatch"> + entities)
curl -sL "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=QUERY&format=json" | python3 -c "
import sys,json,re,html
d=json.load(sys.stdin); r=d.get('query',{}).get('search',[])
if not r:
    if 'error' in d: print('ERROR:', d['error']); raise SystemExit(1)
    print('(no results)'); raise SystemExit(0)
for x in r: print('- '+x['title']+': '+html.unescape(re.sub(r'<[^>]*>','',x['snippet']))[:120])"

# Wikipedia deep dive (HTML + multiline script/style strip + grep + entity decode)
curl -sL "https://en.wikipedia.org/wiki/TOPIC" \
  | python3 -c "
import sys,re,html
s=sys.stdin.read()
s=re.sub(r'<script[^>]*>.*?</script>','',s,flags=re.S|re.I)
s=re.sub(r'<style[^>]*>.*?</style>','',s,flags=re.S|re.I)
sys.stdout.write(html.unescape(re.sub(r'<[^>]*>','',s)))" \
  | grep -vE "doi:|PMID|ISBN|RLCONF|RLSTATE|mw-|skin-|vector-|client-" \
  | grep -i -B2 -A5 "KEYWORD" | head -80

# GitHub repo search (extract only stars + name + description, error-safe)
curl -sL "https://api.github.com/search/repositories?q=QUERY&sort=stars&order=desc&per_page=5" | python3 -c "
import sys,json
d=json.load(sys.stdin)
if 'items' not in d: print('ERROR:', d.get('message',d)); raise SystemExit(1)
for r in d['items']:
    print(str(r['stargazers_count']).rjust(7)+' ★  '+r['full_name'])
    if r.get('description'): print('         '+r['description'][:100])"

# GitHub rate limit (both buckets — search uses 'search', not 'core')
curl -sL "https://api.github.com/rate_limit" | python3 -c "
import sys,json
r=json.load(sys.stdin)['resources']; c=r.get('core',{}); s=r.get('search',{})
print('core', str(c.get('remaining'))+'/'+str(c.get('limit')), ' search', str(s.get('remaining'))+'/'+str(s.get('limit')))"

# GitHub raw file
curl -sL "https://raw.githubusercontent.com/OWNER/REPO/main/PATH" | head -80
```

> **Why `-sL` everywhere?** Sites (Wikipedia, GitHub) issue `301`/`302` redirects.
> Without `-L`, curl silently returns the redirect page instead of the content.
>
> **Why Python for `<script>`/`<style>` removal?** Real blocks span multiple
> lines, but `sed` is line-oriented — `sed 's/<script>.*<\/script>//'` only
> matches single-line blocks and leaks multiline JS/CSS into the output.
> Python's `re.S` (or `perl -0777`) reads the whole input as one record so
> `.` matches newlines, and `.*?` is non-greedy. Avoid `sed -z`: GNU sed is
> greedy-only, so multiple `<script>` blocks make it delete all content
> between the first opening and last closing tag.

## Failure Benchmark

`curl` + Unix text tools have hard limits. The `benchmarks/` directory is a
**sub-agent-driven benchmark** that measures where the skill succeeds and
where it fundamentally cannot — by having constrained agents attempt real
tasks using *only* the patterns in SKILL.md.

**Why sub-agent-driven:** the benchmark evaluates the *skill*, not the agent's
cleverness. Each task is dispatched to a `general-purpose` sub-agent under a
strict contract (see `benchmarks/PROMPT.md`): only SKILL.md patterns, only
the Bash tool, only the exact URL given, no improvisation. If a smart agent
salvages a result by inventing a workaround, the measurement is contaminated.

### Layout

- **`benchmarks/PROMPT.md`** — the constraint contract every sub-agent runs
  under (skill-only, Bash-only, no workarounds, report failures honestly).
- **`benchmarks/tasks/F<n>.md`** — 13 self-contained task cards (the goal +
  required URL + deliverable). No hints or expected answers — those would
  bias the agent.
- **`benchmarks/SCENARIOS.md`** — the **answer key** for human reviewers:
  expected outcome per task + judgment rubric + what counts as a contract
  violation. Not shown to sub-agents.
- **`benchmarks/SUMMARY.md`** — tallied results from the latest run.
- **`benchmarks/results/`** — per-run sub-agent output (gitignored; each run
  regenerates fresh evidence).

### How to run

Dispatch each task in `tasks/` to a constrained sub-agent using the contract
in `PROMPT.md`, collect the raw response into `results/F<n>.md`, then judge
against `SCENARIOS.md`. See `SUMMARY.md` for the 2026-07-25 baseline
(3 SUCCESS, 1 HANDLED, 2 PARTIAL, 6 FAILURE/OUT-OF-SCOPE — the failures are
the *expected* finding, mapping the skill's hard limits).

### What the benchmark covers

JS-rendered SPAs, Cloudflare challenges, login walls, PDFs, paywalls,
Wikipedia disambiguation, RTL scripts, TLS cert errors, rate limits,
redirects, GraphQL/POST endpoints, non-ASCII URLs, static-HTML extraction.

## License

MIT
