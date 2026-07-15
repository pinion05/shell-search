# 🐚 shell-search

> A [Claude Code Agent Skill](https://docs.anthropic.com/en/docs/claude-code/skills) for web research from the terminal using `curl` + Unix text tools.

## What is this?

`shell-search` is a skill that teaches Claude (or any SKILL.md-compatible agent) how to search, scrape, parse, and synthesize information from the web — **without a browser**. It covers:

- **Wikipedia scraping** (HTML + grep patterns)
- **Wikipedia API queries** (clean JSON extracts & search)
- **GitHub API queries** (repo search, contents browsing, raw file fetch)
- **Multi-language comparison** (cross-reference en/ko/ja editions)
- **HTML table parsing** (Python regex wikitable extraction)
- **Noise filtering** (battle-tested `grep -v` patterns)
- **Progressive refinement pipeline** (4-step research flow)

## Quick Start

### Option A: Clone into your Claude skills directory

```bash
git clone https://github.com/pinion05/shell-search.git ~/.claude/skills/shell-search
```

### Option B: Copy just the SKILL.md

```bash
mkdir -p ~/.claude/skills/shell-search
curl -s https://raw.githubusercontent.com/pinion05/shell-search/main/shell-search/SKILL.md \
  -o ~/.claude/skills/shell-search/SKILL.md
```

## File Structure

```
shell-search/
├── shell-search/
│   └── SKILL.md      # The skill definition
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
curl -s "https://en.wikipedia.org/w/api.php?action=query&titles=TOPIC&prop=extracts&exintro&format=json&explaintext" | python3 -m json.tool

# Wikipedia deep dive (HTML + grep + noise filter)
curl -s "https://en.wikipedia.org/wiki/TOPIC" | sed 's/<[^>]*>//g' | grep -v "doi:\|PMID\|ISBN\|function()\|RLCONF\|mw-\|vector-" | grep -i -B2 -A5 "KEYWORD" | head -80

# GitHub repo search
curl -s "https://api.github.com/search/repositories?q=QUERY&sort=stars&order=desc&per_page=5" | python3 -m json.tool

# GitHub raw file
curl -s "https://raw.githubusercontent.com/OWNER/REPO/main/PATH" | head -80
```

## License

MIT
