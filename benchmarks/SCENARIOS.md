# Shell-Search Failure Scenario Catalog

A benchmark of scenarios where `curl` + Unix text tools **cannot** produce
correct web research results, even when following the skill's patterns. Each
scenario was **reproduced live** before classification.

## Why this exists

The skill teaches you to research the web from the terminal. It's powerful,
but it has hard limits. This catalog documents those limits honestly so you:

1. **Don't waste time** trying to scrape the unscrapable — recognize the
   failure mode and switch tools.
2. **Know when to escalate** to a browser, an authenticated API, or a
   dedicated parser.
3. **Have a benchmark** to regression-test future skill versions against.

## Classification

| Class | Meaning | Action |
|---|---|---|
| 🔴 **HARD LIMIT** | curl+text-tools fundamentally cannot do this | Switch tool (browser, headless renderer, PDF extractor) |
| 🟡 **SOFT LIMIT** | Doable with extra steps the skill doesn't cover | Add workaround or use API alternative |
| ⚪ **OUT OF SCOPE** | Different paradigm (auth, streaming, POST) | Use proper client for that paradigm |
| 🟢 **HANDLED** | Skill documents this failure | Follow existing guidance |

---

## Scenarios

### 🟡 F1 — JavaScript-rendered SPA (partial hydration)
**Symptom:** `curl` returns a 200 OK HTML shell. Modern SPAs often
**server-render some content** (marketing copy, nav) for SEO, so stripping
tags yields *partial* text — but with fingerprints that the rendered page
lacks whitespace the JS would add: concatenated nav tokens like
`CtrlKLearnReferenceCommunityBlogReactThe`, and code samples as raw text.

**Repro:**
```
curl -sL https://react.dev/ | python3 -c "
import sys, re
s = sys.stdin.read()
s = re.sub(r'<script[^>]*>.*?</script>', '', s, flags=re.S)
s = re.sub(r'<[^>]*>', '', s)
stuck = re.findall(r'\b[A-Za-z]*[a-z][A-Z][A-Za-z]{6,}\b', s)
print(len(stuck), 'concatenated tokens')"
→ ~10+ concatenated-nav tokens (JS-hydration fingerprint)
```

**Why it's a soft→hard limit:** You get *something*, but interactive content
(docs body, search results, live data) is hydrated client-side. The extract
is unreliable as a research source.

**Workaround:** Look for a JSON API the SPA itself calls (browser DevTools →
Network tab → replay that endpoint with curl), or use a headless browser
(Playwright/Puppeteer) for the rendered DOM.

---

### 🔴 F2 — Cloudflare / bot-challenge protection
**Symptom:** HTTP 200, but the page is a "Just a moment..." interstitial
containing `cf-browser-verification` / `challenge-platform` / `__cf_bm`.

**Repro:** `curl -sL -H "User-Agent: Mozilla/5.0" https://nowsecure.nl/ | grep -c "challenge-platform"`

**Why it fails:** The challenge requires running obfuscated JS to compute a
clearance token. curl cannot execute JS.

**Workaround:** None with curl. Options: an authenticated session (cookies
from a real browser), a challenge-solving service, or a different data source.

---

### 🔴 F4 — Login wall / cookie-required content
**Symptom:** `HTTP 403` with a "Blocked"/"Access denied" page, or a 200 login
form where content should be.

**Repro:**
- `curl -sL https://www.reddit.com/r/programming/top.json` → `403 Blocked`
- `curl -sL https://x.com/elonmusk` → 358 KB login-wall HTML

**Why it fails:** The site gates content behind authentication. curl has no
session.

**Workaround:** Export cookies from a logged-in browser
(`cookies.txt` format) and pass `-b cookies.txt`. For Reddit/Twitter prefer
their official APIs (with auth tokens) over scraping.

---

### 🔴 F9 — PDF / binary document
**Symptom:** `curl` downloads the bytes fine (`Content-Type: application/pdf`),
but `sed`/`grep` produce garbage — the content is a compressed binary stream.

**Repro:**
```
curl -sL https://arxiv.org/pdf/1706.03762 | sed 's/<[^>]*>//g' | head -c 100
→ %PDF-1.5
  137 0 obj
  stream
  (binary noise)
```

**Why it fails:** PDF is a binary container. Text tools operate on text.

**Workaround:** Use a PDF text extractor:
- `pdftotext file.pdf -` (poppler-utils)
- `python3 -c "import pypdf; ..."` or `pdfminer.six`

---

### 🔴 F12 — Paywall / "are you a robot?"
**Symptom:** `HTTP 403` or a page saying "Are you a robot?" / "Subscribe to
continue". Common on Bloomberg, FT, NYT, Medium metered.

**Repro:** `curl -sL https://www.bloomberg.com/` → 403, "Bloomberg - Are you a robot?"

**Why it fails:** Publisher-grade bot detection + paywall. No client-side
content to extract.

**Workaround:** Use the publisher's API if available, or a different source
for the same fact. Archive.org / archive.today sometimes bypass metering.

---

### 🟡 F3 — Wikipedia disambiguation pages
**Symptom:** A query like "Mercury" is ambiguous (planet? element? god? car?).
The skill's `intro extract` returns the disambiguation list itself, which
*might* be what you want, or might not.

**Repro:**
```
curl -sL "...api.php?...&titles=Mercury&prop=extracts&exintro..."
→ "Mercury most commonly refers to: Mercury (planet)... Mercury (element)..."
```

**Why it's a soft limit:** The API behaves correctly — but the agent has to
*recognize* it got a disambiguation page and pick a target, rather than
treating the list as the answer.

**Workaround:** Check for a `disambiguation` page category, or use
`action=query&titles=X&prop=pageprops` to detect `disambiguation` flag, then
re-query the specific article.

---

### 🟡 F5 — Right-to-left / non-Latin scripts
**Symptom:** Arabic, Hebrew, Persian Wikipedia content extracts fine
character-wise, but logical/visual ordering and bidirectional context are
lost. Output may render garbled when piped through tools that assume LTR.

**Repro:** `curl -sL https://ar.wikipedia.org/wiki/مركب` → text extracted but
directionality metadata gone.

**Why it's a soft limit:** The bytes are correct. The *rendering* depends on
the terminal/consumer applying Unicode bidi.

**Workaround:** Accept the extracted text as data (search/grep works), but
don't expect display-perfect output. For clean RTL text, prefer the API
(`explaintext=1`) over HTML scraping.

---

### ⚪ F10 — GraphQL / POST-only endpoints
**Symptom:** Modern APIs (GitHub GraphQL, Shopify Admin) require `POST` with
a JSON body and an auth token. The skill's GET-only patterns don't apply.

**Repro:** `curl -X POST https://api.github.com/graphql` → `403 rate limit`
(unauthenticated; even with token, needs `{"query": "..."}` body).

**Why out of scope:** This is a different request shape, not a parsing
problem. The skill is about *consuming* responses, not constructing complex
requests.

**Workaround:** Add `-X POST -H "Authorization: ..." -d '{"query":"..."}'`.
Outside this skill's scope — document in a "next steps" pointer.

---

### ⚪ F11 — WebSocket / SSE streaming responses
**Symptom:** Streaming endpoints (live tickers, chat, logs) hold the
connection open and emit frames incrementally. `curl | grep` blocks or
returns immediately without the live data.

**Repro:** SSE/crypto sockets require a persistent connection and a frame
parser. curl can fetch the stream but the text-tools pipeline model
(request → response → process) doesn't fit.

**Why out of scope:** Streaming is a different consumption pattern.

**Workaround:** Use `curl -N` (no buffering) into a stateful parser
(`jq --stream`, a custom Python loop), or use a WebSocket client
(`websocat`, `websockets.py`).

---

### 🟢 F6 — Rate limiting (GitHub search 10/min)
**Handled by skill §2.3 + §4.1.** Verified live: 10 rapid unauthenticated
`/search/repositories` calls succeeded, the 11th–15th returned 403.

**The skill already:** prints both `core` and `search` buckets, warns about
60/hr vs 10/min, and recommends a token for higher limits. ✅

---

### 🟢 F7 — Missing `-L` (silent redirect failure)
**Handled by skill §1.1 + §4.1.** Verified live: `curl -s http://github.com/...`
returns `301` with no content; `curl -sL` follows to 200.

**The skill already:** mandates `-sL` everywhere, explains it's the #1 silent
failure, lists it in troubleshooting. ✅

---

### 🟢 F13 — Non-ASCII (Korean) URLs
**Handled (works as-is).** Verified live: both bare
`https://ko.wikipedia.org/wiki/독도` and percent-encoded
`https://ko.wikipedia.org/wiki/%EB%8F%85%EB%8F%84` return 200.

**The skill already:** mentions URL encoding in §3.1 and notes modern curl
handles bare UTF-8 paths. ✅

---

### 🟡 F14 — TLS certificate errors (expired / self-signed)
**Symptom:** `HTTP 000` and curl refuses to connect:
`curl: (60) SSL certificate problem: certificate has expired`.

**Repro:**
```
curl -sL https://expired.badssl.com/        → HTTP 000 (refused)
curl -sLk https://expired.badssl.com/       → HTTP 200 (forced)
```

**Why it's a soft limit:** The skill doesn't mention cert errors. `-k`
silences them but disables a security check.

**Workaround:** Add `-k` only for known test endpoints; otherwise fix the
server cert or pin with `--cacert`.

---

## Summary table

| ID | Scenario | Class | Skill covers? |
|---|---|---|---|
| F1 | JS-rendered SPA (partial) | 🟡 SOFT | ❌ |
| F2 | Cloudflare challenge | 🔴 HARD | ❌ |
| F4 | Login wall | 🔴 HARD | ❌ (mention cookies) |
| F9 | PDF binary | 🔴 HARD | ❌ (mention pdftotext) |
| F12 | Paywall / bot-block | 🔴 HARD | ❌ |
| F3 | Disambiguation pages | 🟡 SOFT | ❌ |
| F5 | RTL / non-Latin | 🟡 SOFT | partial |
| F14 | TLS cert errors | 🟡 SOFT | ❌ |
| F10 | GraphQL / POST | ⚪ SCOPE | ❌ |
| F11 | Streaming | ⚪ SCOPE | ❌ |
| F6 | Rate limit | 🟢 OK | ✅ |
| F7 | Missing `-L` | 🟢 OK | ✅ |
| F13 | Non-ASCII URL | 🟢 OK | ✅ |

## How to run the live benchmark

```bash
bash benchmarks/run.sh
```

The script attempts each scenario live and reports PASS / FAIL / SKIP with
the observed evidence, so you can regression-test the catalog against
real-world site behavior.
