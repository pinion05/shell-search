# Shell-Search Benchmark — Expected Outcomes (for human reviewers)

This file is the **answer key**. It is NOT shown to the sub-agent.
Each entry documents what a competent reviewer should expect the skill to
achieve on the matching task in `tasks/`, so the reviewer can judge the
sub-agent's raw output consistently.

**Workflow:**
1. A sub-agent runs `tasks/F<n>.md` constrained by `PROMPT.md` (skill-only,
   no improvisation, Bash only).
2. Its raw response is saved to `results/F<n>.md`.
3. A human reads this file alongside `results/F<n>.md` and judges:
   **did the skill's pattern produce usable output for the stated goal?**

Judgment values:
- ✅ **SUCCESS** — skill produced the requested information
- ❌ **FAILURE** — skill's pattern broke or yielded nothing usable
- ⚠️ **PARTIAL** — skill produced something, but incomplete/noisy/wrong-shape

---

## F1 — React 19 features from react.dev

**Expected: ⚠️ PARTIAL → ❌**

The page is a JS-hydrated SPA. The skill's HTML scraping pattern will return
a 200 response but the body is mostly a JS bootstrap shell with some
server-rendered nav/marketing. The agent will get *something* (concatenated
nav tokens like `CtrlKLearnReferenceBlog`), but **not** the structured list
of React 19 features the task asks for. Watch for the agent reporting the
page "loaded" while actually missing the goal.

**Why:** React.dev hydrates content client-side. curl cannot execute JS.
This is a fundamental limit of the curl+text-tools approach.

---

## F2 — nowsecure.nl article topics

**Expected: ❌**

The site is behind Cloudflare's bot-challenge. curl will get a 200 with a
"Just a moment..." interstitial page containing `cf-browser-verification` /
`challenge-platform` markers, not the article list. The skill has no
mechanism to solve the JS challenge.

**Why:** Cloudflare requires executing obfuscated JS to compute a clearance
token. Out of scope for curl.

---

## F3 — "What is Mercury?" via Wikipedia API

**Expected: ⚠️ PARTIAL**

The skill's API pattern works mechanically (returns JSON), but "Mercury" is
ambiguous. The intro extract will be a *disambiguation list* ("Mercury most
commonly refers to: Mercury (planet)... Mercury (element)..."), not a single
clear answer. The task asked for "a single clear answer about the most
prominent subject" — the skill does not teach the agent to detect
disambiguation pages and pick a target.

**Watch for:** the agent quoting the disambiguation list as if it were an
answer, vs. recognizing it doesn't satisfy "single clear answer."

---

## F4 — Top 3 r/programming posts

**Expected: ❌**

Reddit's `.json` endpoint now requires authentication. Without a token/cookie
the request returns HTTP 403 with a "Blocked" page. The skill does not cover
authenticated scraping. The agent should report the failure honestly rather
than fabricate posts.

**Why:** Reddit gated public JSON access. curl has no session.

---

## F5 — Arabic Wikipedia article (RTL)

**Expected: ⚠️ PARTIAL**

The skill's scraping pattern will extract Arabic text successfully (the bytes
are correct), but bidirectional/directionality context is lost. For a
"non-Arabic-reader" deliverable, the agent cannot translate (no LLM tool
allowed — Bash only). The agent will report it extracted text but cannot
fulfill the "what concept it describes" goal without translation.

**Watch for:** did the agent stay in scope (report extracted text + admit it
can't translate) vs. hallucinate a translation?

---

## F6 — 12 rapid GitHub searches (rate limit)

**Expected: ⚠️ PARTIAL (success rate drops mid-run)**

The skill correctly documents GitHub search quota = 10/min unauthenticated.
Expect ~10 successes then 403s. The agent's count should reflect this. The
skill's rate-limit guidance **holds up** — this is more a confirmation than
a failure, but the task does fail partway through.

**Watch for:** the agent applying the skill's `/rate_limit` preflight or
correctly reporting the 10-then-fail pattern, vs. being surprised.

---

## F7 — `http://` GitHub URL (redirect)

**Expected: ✅ SUCCESS** *(because the skill mandates `-L`)*

`http://github.com/...` 301-redirects to HTTPS. The skill's patterns all use
`curl -sL`, which follows the redirect. The agent should obtain the page
content. This task exists to confirm the skill's `-L`-everywhere rule works
under load — it's the skill's strongest correctness point.

**Watch for:** if the agent somehow uses `curl -s` (no `-L`) and gets empty
output, that's an agent error, not a skill failure.

---

## F8 — Top 10 HN stories

**Expected: ✅ SUCCESS**

HN is server-rendered static HTML. The skill's scraping pattern works here.
Caveat for the reviewer: HN ships all HTML on one line, so naive `grep -c`
undercounts, but the skill's `grep -i -B/-A` context patterns work fine.

**Watch for:** the agent obtaining actual story titles (not just counts).

---

## F9 — arXiv PDF text

**Expected: ❌**

The URL is a PDF. The skill's `sed`/`grep` patterns produce binary garbage
(`%PDF-1.5` header, compressed stream noise). The skill does not cover PDF
extraction — `pdftotext` is mentioned only in this catalog, not in SKILL.md.
The agent has no SKILL.md-sanctioned way to extract the abstract.

**Why:** PDF is a binary format. Text tools operate on text.

---

## F10 — GitHub GraphQL query

**Expected: ❌**

The skill covers GET-based REST API consumption. GraphQL requires POST with
a JSON body and authentication. The skill has no POST pattern and no GraphQL
guidance. The agent should report it cannot perform this with the skill's
patterns (and get a 403/401 unauthenticated).

**Why:** Different request shape (POST + auth + query language). Out of
scope for this skill.

---

## F12 — Bloomberg top headlines

**Expected: ❌**

Bloomberg returns 403 with an "Are you a robot?" / paywall page. No
client-side content to extract. The skill has no paywall bypass.

**Watch for:** the agent reporting the 403 honestly vs. claiming it found
headlines.

---

## F13 — Korean Wikipedia (bare UTF-8 URL)

**Expected: ✅ SUCCESS**

Modern curl handles bare UTF-8 in URL paths. The skill notes this in §3.1.
The agent should obtain the article. This task confirms non-ASCII URLs work
without explicit encoding — a skill strength.

---

## F14 — `expired.badssl.com` (TLS cert error)

**Expected: ❌**

The site's certificate is expired. `curl` refuses to connect (HTTP 000, exit
non-zero with SSL error). The skill does not document cert errors or the
`-k` flag. The agent should report the connection failure.

**Watch for:** the agent adding `-k` to force the connection would be
improvisation beyond the skill — flag as a contract violation, not a success.

---

## Scoring rubric (for the reviewer's final report)

After running all tasks, tally:

| Outcome | Meaning |
|---|---|
| ✅ SUCCESS count | Tasks the skill genuinely handles |
| ❌ FAILURE count | Tasks where the skill's approach fundamentally cannot work |
| ⚠️ PARTIAL count | Tasks where the skill gets something but not the goal |

The benchmark's purpose is **not** to maximize SUCCESS. It's to honestly
map where the skill works and where it doesn't, so users know when to
escalate to a browser/API/different tool. A high FAILURE count on
hard-limit scenarios (JS SPA, Cloudflare, PDF, paywall) is the *expected,
correct* finding — those are not solvable in the skill's paradigm.

## Contract violations to watch for

If the sub-agent does any of these, mark the result INVALID (do not score):
- Uses `WebSearch`, `WebFetch`, a browser, or any non-Bash tool
- Substitutes a different URL than the one in the task
- Adds flags/patterns not in SKILL.md (e.g. `-k`, `--resolve`, custom auth)
- Applies prior knowledge ("I know Reddit blocks this, so...") instead of
  reporting the observed failure
- Retries with a "better" approach after the skill's pattern fails

These violate the benchmark's premise: we are measuring the **skill**, not
the agent.
