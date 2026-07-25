# Sub-Agent Prompt Template (for benchmark runners)

This file is the **constraint contract** handed to every sub-agent that runs
a benchmark task. It exists to keep the benchmark honest: we are evaluating
**the skill**, not the agent's reasoning ability. The agent must follow the
skill mechanically, with no improvisation.

## Why these rules exist

If the sub-agent invents a workaround (uses a web-search tool, falls back to
a browser, applies knowledge from training, picks a different URL), the
result no longer reflects what the *skill* teaches — it reflects what a
smart agent can salvage. That contaminates the measurement.

## The contract (paste into each sub-agent task)

```
You are running a benchmark task for the `shell-search` skill.

STRICT CONSTRAINTS — violation invalidates the result:
1. You may ONLY use techniques documented in the SKILL.md provided below.
   Do not invent commands, do not "improve" the patterns, do not apply
   prior knowledge of how websites work.
2. You may ONLY use the `Bash` tool. No web search, no WebFetch, no browser,
   no MCP tools, no other agents.
3. You MUST use the exact URL given in the task. Do not substitute a
   "better" URL, do not try a different site to get cleaner data.
4. If the skill's pattern fails (empty output, error, garbage), DO NOT
   debug, retry with a different approach, or work around it. Report the
   failure honestly as the result. A failure is a valid finding.
5. Do not consult any documentation other than the SKILL.md provided.
   Do not recall how Wikipedia/GitHub/etc. work from training; only the
   patterns written in SKILL.md are available to you.

OUTPUT FORMAT — your entire response must be exactly:
  - A heading with the task ID
  - The exact commands you ran (copy-paste from SKILL.md patterns)
  - The raw output you observed (verbatim, truncated to 50 lines max)
  - A one-line "FINDING:" stating whether the skill's pattern produced
    usable information for the stated goal. Do NOT classify it as
    success/failure — just describe what you got.

Do not add commentary, suggestions, or improvements. The human reviewer
will judge success/failure.

--- SKILL.md (the only reference you may use) ---
<skill content pasted here>
--- END SKILL.md ---

--- TASK ---
<task content pasted here>
--- END TASK ---
```

## How to run a single task

From the parent agent:

1. Read `shell-search/SKILL.md`.
2. Read `benchmarks/tasks/F<n>.md`.
3. Read this template.
4. Compose the prompt: template + SKILL.md content + task content.
5. Dispatch to a `general-purpose` sub-agent with **Bash as the only
   permitted tool** (the parent must enforce this when spawning).
6. Append the sub-agent's verbatim response to
   `benchmarks/results/F<n>.md`.
7. A human reads the results file and judges against the expectation in
   `SCENARIOS.md`.

## What NOT to do as the parent runner

- Do not pre-process the sub-agent's output (no scoring, no cleaning).
- Do not give the sub-agent hints from `SCENARIOS.md` — that file contains
  the expected outcome and would bias the run.
- Do not retry a task because the result "looks wrong" — wrong-looking
  results *are* the data.
