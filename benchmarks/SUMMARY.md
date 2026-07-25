# Benchmark Run Summary — 2026-07-25

Sub-agent execution of all 13 benchmark tasks. Each task was dispatched to a
`general-purpose` agent constrained to use ONLY the patterns in SKILL.md
(Bash-only, no improvisation, exact URLs). Results recorded in `results/F<n>.md`.

## Tally

| Outcome | Count | Tasks |
|---|---|---|
| ✅ SUCCESS | 3 | F7, F8, F13 |
| 🟢 HANDLED (skill documents the limit correctly) | 1 | F6 |
| ⚠️ PARTIAL | 2 | F3, F5 |
| ❌ FAILURE (hard limit) | 5 | F2, F4, F9, F12, F14 |
| ⚪ OUT OF SCOPE | 1 | F10 |
| ⚠️→❌ (partial extraction, goal not met) | 1 | F1 |

## Per-task outcomes

| ID | Task | Skill verdict | Notes |
|---|---|---|---|
| F1 | React 19 features from react.dev | ⚠️→❌ | Page text extracted but no feature list — homepage doesn't carry it as SSR text |
| F2 | nowsecure.nl articles | ❌ | Cloudflare Turnstile challenge; no content in static HTML |
| F3 | "What is Mercury?" | ⚠️ | API returns disambiguation list; skill has no disambiguation handling |
| F4 | Reddit top posts | ❌ | 403 — Reddit gates `.json` behind auth |
| F5 | Arabic Wikipedia (RTL) | ⚠️ | Text extracted; directionality lost; agent over-stepped by translating (minor contract drift) |
| F6 | 12 rapid GitHub searches | 🟢 HANDLED | Exactly 10 success then 403 at #11 — confirms skill's rate-limit docs |
| F7 | `http://` GitHub URL | ✅ | `-L` follows redirect; README extracted |
| F8 | Top 10 HN stories | ✅ | Static HTML; all 30 titles extracted |
| F9 | arXiv PDF | ❌ | Binary PDF; UnicodeDecodeError; no PDF pattern in skill |
| F10 | GitHub GraphQL | ⚪ | Skill has no POST pattern; needs POST+auth+query |
| F12 | Bloomberg headlines | ❌ | 403 "Are you a robot?" |
| F13 | Korean Wikipedia (bare URL) | ✅ | Bare UTF-8 path works; first paragraph extracted |
| F14 | expired.badssl.com | ❌ | curl exit 60 — cert error; skill doesn't document `-k` |

## Contract adherence

12 of 13 sub-agent runs respected the constraints cleanly. One minor drift:

- **F5** — the agent translated Arabic to English in its FINDING. Translation
  is not a SKILL.md-sanctioned operation (no LLM tool, Bash only). The raw
  Arabic extraction was legitimate; the translations should be discounted
  when judging. Flagged for awareness, not invalidating.

Several agents were exemplary in honoring the contract — explicitly citing
why they refused to work around failures (F9: "rather than substituting...
or introducing a PDF text-extraction tool outside the skill"; F14: "per the
constraints I will not work around that by adding `-k`").

## What the benchmark tells us about the skill

**Strengths (confirmed live):**
- `-L`-everywhere rule works — silent redirect failures avoided (F7).
- Multi-line script/style stripping with Python `re.S` cleanly removes JS noise.
- Bare UTF-8 URLs work without manual encoding (F13).
- Static HTML sites (HN) extract cleanly with one pattern (F8).
- Rate-limit documentation is accurate — the skill's guidance predicts the
  observed 10/min ceiling exactly (F6), and the error-safe extractor surfaces
  the server message instead of a KeyError.

**Hard limits (fundamental to curl+text-tools):**
- JS-hydrated SPAs (F1), Cloudflare challenges (F2), login walls (F4),
  PDFs (F9), paywalls (F12), expired TLS certs (F14). These are not solvable
  within the skill's paradigm — users must escalate to a browser, headless
  renderer, PDF extractor, or authenticated API.

**Skill gaps worth considering for future versions:**
- **Disambiguation handling** (F3): the skill could teach detecting
  disambiguation pages (pageprops API) and re-querying a specific target.
- **Cert errors / `-k`** (F14): a one-line troubleshooting entry would help.
- **POST/GraphQL** (F10): explicitly out of scope, but a pointer would orient
  users who hit it.

## How to re-run

See `PROMPT.md` for the constraint contract and the per-task procedure. Each
`tasks/F<n>.md` is a self-contained task card. Dispatch them to constrained
sub-agents and collect raw responses into `results/F<n>.md`, then judge
against `SCENARIOS.md`.

The `results/` directory is gitignored — each run produces fresh evidence.
This `SUMMARY.md` captures the 2026-07-25 baseline.
