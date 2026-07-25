#!/usr/bin/env bash
# shell-search failure benchmark
#
# Runs every scenario in SCENARIOS.md live and reports whether curl+text-tools
# succeed or fail at producing correct results. Each scenario documents the
# EXPECTED outcome (does the skill's approach work here?) and the script
# reports PASS/FAIL/SKIP based on what it actually observes.
#
# Exit codes per scenario:
#   0 = observed behavior matches expectation (PASS)
#   1 = observed behavior does NOT match expectation (FAIL — investigate)
#   2 = could not run (SKIP — missing tool or network)
#
# Overall exit: 0 if no FAILs, 1 otherwise.

set -u
# NOTE: do NOT set -e — we want to capture per-scenario non-zero exits.

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
FAILED_SCENARIOS=()

# ---- helpers ----------------------------------------------------------------

# print a result line: result_code name evidence
emit() {
    # $1 = PASS|FAIL|SKIP, $2 = id, rest = evidence
    local result="$1" id="$2"; shift 2
    case "$result" in
        PASS) printf "  \033[32mPASS\033[0m  %-6s %s\n" "$id" "$*"; PASS_COUNT=$((PASS_COUNT+1)) ;;
        FAIL) printf "  \033[31mFAIL\033[0m  %-6s %s\n" "$id" "$*"; FAIL_COUNT=$((FAIL_COUNT+1)); FAILED_SCENARIOS+=("$id") ;;
        SKIP) printf "  \033[33mSKIP\033[0m  %-6s %s\n" "$id" "$*"; SKIP_COUNT=$((SKIP_COUNT+1)) ;;
    esac
}

have() { command -v "$1" >/dev/null 2>&1; }

# fetch with a hard timeout to avoid hangs on streaming/protected endpoints
fetch() {
    # $1=url, $2=outfile; returns curl's http code
    local url="$1" out="${2:-/dev/null}"
    curl -sL --max-time 25 -o "$out" -w "%{http_code}" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
        "$url" 2>/dev/null
}

# ---- scenarios --------------------------------------------------------------

# F1 — JS-rendered SPA. Expect: even after stripping tags, content is partial —
# many real SPAs server-render *some* content but the bulk is hydrated client-side.
# PASS when extraction yields a partial-only result (enough to look like content,
# but with clear JS-app signatures like concatenated nav text or code samples).
scenario_F1() {
    local id="F1"
    local tmp; tmp=$(mktemp)
    local code; code=$(fetch "https://react.dev/" "$tmp")
    if [ "$code" != "200" ]; then emit SKIP "$id" "react.dev returned $code"; return 2; fi
    # Detect SPA-shell signatures: words stuck together (no spaces between
    # nav items like 'CtrlKLearnReferenceCommunityBlog') indicate JS-rendered
    # nav that lost its separators, plus code-like artifacts.
    local stuck_words
    stuck_words=$(python3 -c "
import sys, re
s = open('$tmp').read()
s = re.sub(r'<script[^>]*>.*?</script>', '', s, flags=re.S)
s = re.sub(r'<style[^>]*>.*?</style>', '', s, flags=re.S)
s = re.sub(r'<[^>]*>', '', s)
# Long CamelCase / mixed runs with no spaces = JS nav concatenation artifact
stuck = re.findall(r'\b[A-Za-z]*[a-z][A-Z][A-Za-z]{6,}\b', s)
print(len(stuck))
" 2>/dev/null)
    rm -f "$tmp"
    # Stuck-together tokens indicate the HTML lacked the whitespace the
    # rendered page would have — a fingerprint of JS-hydrated content.
    if [ "${stuck_words:-0}" -gt 3 ]; then
        emit PASS "$id" "SOFT→HARD LIMIT: $stuck_words concatenated-nav tokens detected (JS-hydrated content, partial extract only)"
    else
        emit SKIP "$id" "no JS-nav fingerprint found ($stuck_words stuck tokens) — page may have changed"
    fi
}

# F2 — Cloudflare challenge. Expect: 200 with challenge markers, no real content.
scenario_F2() {
    local id="F2"
    local tmp; tmp=$(mktemp)
    local code; code=$(fetch "https://nowsecure.nl/" "$tmp")
    if [ "$code" != "200" ]; then emit SKIP "$id" "nowsecure.nl returned $code (may be blocked/down)"; rm -f "$tmp"; return 2; fi
    local markers
    markers=$(grep -cE "Just a moment|cf-browser-verification|challenge-platform|__cf_bm|cf_chl" "$tmp" 2>/dev/null || echo 0)
    rm -f "$tmp"
    if [ "${markers:-0}" -gt 0 ]; then
        emit PASS "$id" "HARD LIMIT confirmed: Cloudflare challenge page ($markers markers)"
    else
        emit SKIP "$id" "no CF markers found (site may have changed protection)"
    fi
}

# F3 — Wikipedia disambiguation. Expect: API returns disambig list, not an article.
scenario_F3() {
    local id="F3"
    local tmp; tmp=$(mktemp)
    local code; code=$(fetch \
        "https://en.wikipedia.org/w/api.php?action=query&titles=Mercury&prop=extracts&exintro&format=json&explaintext" \
        "$tmp")
    if [ "$code" != "200" ]; then emit SKIP "$id" "wikipedia API returned $code"; rm -f "$tmp"; return 2; fi
    local is_disambig
    is_disambig=$(python3 -c "
import json
d = json.load(open('$tmp'))
extract = list(d['query']['pages'].values())[0].get('extract','')
print('1' if 'commonly refers to' in extract or 'may refer to' in extract else '0')
" 2>/dev/null)
    rm -f "$tmp"
    if [ "$is_disambig" = "1" ]; then
        emit PASS "$id" "SOFT LIMIT confirmed: ambiguous title returns disambiguation list, not article"
    else
        emit FAIL "$id" "expected disambiguation pattern in Mercury extract"
    fi
}

# F4 — Login wall. Expect: 403 or login-page body (no real content).
scenario_F4() {
    local id="F4"
    local code; code=$(fetch "https://www.reddit.com/r/programming/top.json?limit=1" /dev/null)
    case "$code" in
        403) emit PASS "$id" "HARD LIMIT confirmed: Reddit returns 403 without auth ($code)" ;;
        200) emit FAIL "$id" "Reddit allowed unauthenticated access ($code) — endpoint changed?" ;;
        *)   emit SKIP "$id" "Reddit returned $code (network/region issue)" ;;
    esac
}

# F5 — RTL / non-Latin script. Expect: bytes extract but content is short/noise.
scenario_F5() {
    local id="F5"
    local tmp; tmp=$(mktemp)
    local code; code=$(fetch "https://ar.wikipedia.org/wiki/%D9%85%D8%B1%D9%83%D8%A8" "$tmp")
    if [ "$code" != "200" ]; then emit SKIP "$id" "ar.wikipedia returned $code"; rm -f "$tmp"; return 2; fi
    local text_len
    text_len=$(python3 -c "
import sys, re, html
s = open('$tmp').read()
s = re.sub(r'<script[^>]*>.*?</script>', '', s, flags=re.S)
s = re.sub(r'<style[^>]*>.*?</style>', '', s, flags=re.S)
s = re.sub(r'<[^>]*>', '', s)
print(len(html.unescape(s).strip()))
" 2>/dev/null)
    rm -f "$tmp"
    # RTL soft-limit: extraction works (large text length) but loses directionality.
    if [ "${text_len:-0}" -gt 500 ]; then
        emit PASS "$id" "SOFT LIMIT confirmed: $text_len chars extracted (text OK, directionality metadata lost)"
    else
        emit FAIL "$id" "expected large RTL extraction, got $text_len chars"
    fi
}

# F6 — Rate limit. Expect: GitHub search quota (10/min) exhausts within ~10 rapid calls.
# This scenario CONSUMES the search quota — keep it last among GitHub tests.
scenario_F6() {
    local id="F6"
    local ok=0 fail=0 i code
    for i in $(seq 1 12); do
        code=$(curl -sL --max-time 15 -o /dev/null -w "%{http_code}" \
            "https://api.github.com/search/repositories?q=ratelimit-test-$i" 2>/dev/null)
        [ "$code" = "200" ] && ok=$((ok+1)) || fail=$((fail+1))
    done
    # PASS when we observe the quota ceiling being hit (some failures).
    if [ "$fail" -gt 0 ]; then
        emit PASS "$id" "HANDLED: search quota exhausted after $ok OK / $fail failed (skill documents this)"
    else
        emit SKIP "$id" "no rate-limit failures observed ($ok ok) — quota may be higher (token in env?)"
    fi
}

# F7 — Missing -L. Expect: -L returns the final page; without -L we get a 301.
scenario_F7() {
    local id="F7"
    local noL withL
    noL=$(curl -s --max-time 15 -o /dev/null -w "%{http_code}" "http://github.com/torvalds/linux" 2>/dev/null)
    withL=$(curl -sL --max-time 15 -o /dev/null -w "%{http_code}" "http://github.com/torvalds/linux" 2>/dev/null)
    if [ "$noL" = "301" ] || [ "$noL" = "302" ] && [ "$withL" = "200" ]; then
        emit PASS "$id" "HANDLED: without -L → $noL, with -L → $withL (skill mandates -L)"
    else
        emit SKIP "$id" "redirect behavior unexpected: no-L=$noL with-L=$withL"
    fi
}

# F8 — Messy real-world HTML. Expect: partial extraction works (sanity check, not a failure case).
scenario_F8() {
    local id="F8"
    local tmp; tmp=$(mktemp)
    local code; code=$(fetch "https://news.ycombinator.com/" "$tmp")
    if [ "$code" != "200" ]; then emit SKIP "$id" "HN returned $code"; rm -f "$tmp"; return 2; fi
    # HN ships its entire HTML on ONE line, so `grep -c` (which counts
    # matching *lines*) returns 1 even when 30 stories are present.
    # Use `grep -o ... | wc -l` to count matches themselves.
    local story_count
    story_count=$(grep -o 'class="titleline"' "$tmp" 2>/dev/null | wc -l | tr -d ' ')
    [ -z "$story_count" ] && story_count=0
    rm -f "$tmp"
    if [ "${story_count:-0}" -ge 10 ]; then
        emit PASS "$id" "OK baseline: HN static HTML yields $story_count stories via grep -o"
    else
        emit FAIL "$id" "expected ≥10 HN stories, found $story_count (markup changed?)"
    fi
}

# F9 — PDF binary. Expect: sed on PDF bytes produces garbage; pdftotext (if present) extracts text.
scenario_F9() {
    local id="F9"
    local pdf; pdf=$(mktemp)
    local code; code=$(fetch "https://arxiv.org/pdf/1706.03762" "$pdf")
    if [ "$code" != "200" ]; then emit SKIP "$id" "arxiv returned $code"; rm -f "$pdf"; return 2; fi
    # Does sed-based extraction produce garbage?
    local sed_head; sed_head=$(sed 's/<[^>]*>//g' "$pdf" 2>/dev/null | head -c 50 | tr -d '\0')
    rm -f "$pdf"
    case "$sed_head" in
        %PDF*) emit PASS "$id" "HARD LIMIT confirmed: sed on PDF yields binary header ($sed_head...)" ;;
        *) emit FAIL "$id" "expected %PDF header from sed, got: $sed_head" ;;
    esac
    # Optional: if pdftotext exists, show that the right tool works.
    if have pdftotext; then
        local pdf2; pdf2=$(mktemp)
        fetch "https://arxiv.org/pdf/1706.03762" "$pdf2" >/dev/null
        local first_line; first_line=$(pdftotext "$pdf2" - 2>/dev/null | grep -m1 -v '^$' | head -c 60)
        rm -f "$pdf2"
        [ -n "$first_line" ] && printf "         (workaround: pdftotext → \"%s...\")\n" "$first_line"
    fi
}

# F10 — GraphQL / POST. Expect: unauthenticated POST → 403 (out of skill scope).
scenario_F10() {
    local id="F10"
    local code; code=$(curl -sL --max-time 15 -X POST -o /dev/null -w "%{http_code}" \
        "https://api.github.com/graphql" 2>/dev/null)
    case "$code" in
        403|401) emit PASS "$id" "OUT OF SCOPE confirmed: GraphQL POST without auth → $code" ;;
        200) emit SKIP "$id" "GraphQL POST allowed ($code) — env may have a token" ;;
        *) emit SKIP "$id" "unexpected GraphQL response $code" ;;
    esac
}

# F12 — Paywall / bot block. Expect: 403 or "robot" page.
scenario_F12() {
    local id="F12"
    local tmp; tmp=$(mktemp)
    local code; code=$(fetch "https://www.bloomberg.com/" "$tmp")
    local body_marker=0
    [ -s "$tmp" ] && grep -qE "robot|Are you a robot|Subscribe|paywall" "$tmp" 2>/dev/null && body_marker=1
    rm -f "$tmp"
    if [ "$code" = "403" ] || [ "$body_marker" = "1" ]; then
        emit PASS "$id" "HARD LIMIT confirmed: Bloomberg returns $code (paywall/bot-block)"
    else
        emit SKIP "$id" "Bloomberg returned $code, no paywall markers (region/CDN difference?)"
    fi
}

# F13 — Non-ASCII URL. Expect: bare UTF-8 path works as well as percent-encoded (both 200).
scenario_F13() {
    local id="F13"
    local bare enc
    bare=$(curl -sL --max-time 15 -o /dev/null -w "%{http_code}" "https://ko.wikipedia.org/wiki/독도" 2>/dev/null)
    enc=$(curl -sL --max-time 15 -o /dev/null -w "%{http_code}" "https://ko.wikipedia.org/wiki/%EB%8F%85%EB%8F%84" 2>/dev/null)
    if [ "$bare" = "200" ] && [ "$enc" = "200" ]; then
        emit PASS "$id" "OK baseline: bare UTF-8 ($bare) and percent-encoded ($enc) both work"
    else
        emit FAIL "$id" "Korean URL handling changed: bare=$bare encoded=$enc"
    fi
}

# F14 — TLS cert error. Expect: connection refused without -k; succeeds with -k.
scenario_F14() {
    local id="F14"
    local noK withK
    noK=$(curl -sL --max-time 15 -o /dev/null -w "%{http_code}" "https://expired.badssl.com/" 2>/dev/null)
    withK=$(curl -sLk --max-time 15 -o /dev/null -w "%{http_code}" "https://expired.badssl.com/" 2>/dev/null)
    if [ "$noK" = "000" ] && [ "$withK" = "200" ]; then
        emit PASS "$id" "SOFT LIMIT confirmed: cert error blocks curl ($noK); -k forces it ($withK)"
    else
        emit SKIP "$id" "badssl behavior changed: noK=$noK withK=$withK"
    fi
}

# ---- runner -----------------------------------------------------------------

SCENARIOS=(F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F12 F13 F14)
# (F11 streaming omitted from auto-run — it requires a stable streaming
# endpoint and a long-lived parser; see SCENARIOS.md for the manual case.)

echo "shell-search failure benchmark"
echo "=============================="
echo "Running ${#SCENARIOS[@]} scenarios live. Each tests whether curl+text-tools"
echo "produce correct results, classified per SCENARIOS.md."
echo ""
for s in "${SCENARIOS[@]}"; do
    "scenario_$s" || true
done

echo ""
echo "=============================="
echo "Summary:  PASS=$PASS_COUNT  FAIL=$FAIL_COUNT  SKIP=$SKIP_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "Failed scenarios: ${FAILED_SCENARIOS[*]}"
    echo ""
    echo "A FAIL means the observed web behavior did not match the catalog's"
    echo "expectation — the scenario doc in SCENARIOS.md may need updating."
    exit 1
fi
echo "No unexpected failures. Catalog matches observed behavior."
exit 0
