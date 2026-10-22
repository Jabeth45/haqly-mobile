# PROMPTS — copy/paste into Antigravity

Place `AGENTS.md` at the repo root and `docs/` next to it. Never prompt "build the app".

## Prompt 1 — Orientation (read-only; run first, once per session)
```
Read these files before making any changes:
AGENTS.md, docs/PRD.md, docs/ARCHITECTURE.md, docs/RULES.md, docs/SECURITY.md,
docs/DECISIONS.md, docs/OPEN_QUESTIONS.md, docs/TASKS.md, docs/MEMORY.md
(also docs/DESIGN.md and docs/DOMAIN_SPEC.md if the task touches UI or calculations).
Do not modify anything yet.

1. Summarize the product and the architecture in your own words (max 15 lines).
2. List every OPEN-xxx item that affects TASK-XXX.
3. List missing information and contradictions you notice between the docs.
4. Propose the implementation plan for TASK-XXX: files to create/change, tests to write.
Do not write code yet. Wait for my approval.
```

## Prompt 2 — Implement one task (6 parts)
```
CONTEXT: Haqly Flutter app. Docs: PRD, ARCHITECTURE, RULES, SECURITY, (DESIGN/DOMAIN_SPEC if relevant).
TASK: TASK-XXX — <paste title and acceptance criteria from docs/TASKS.md>.
FILES: <paths you expect to touch>.
CONSTRAINTS: Follow docs/RULES.md. Do not touch docs/source/, docs/test_vectors/, env/*.json, generated code.
  No new dependency without recording it in docs/MEMORY.md. If anything is marked OPEN, stop and ask.
ACCEPTANCE CRITERIA: <copy from TASKS.md>.
TESTING: run dart format, flutter analyze, flutter test, tool/check_layers.sh and report results.
When done: update docs/MEMORY.md and docs/TASKS.md status. Make one focused commit.
```

## Prompt 3 — Review (report first, fix later)
```
Review the changes for TASK-XXX against PRD, ARCHITECTURE, DESIGN, RULES, TEST_PLAN and SECURITY.
Produce a numbered list of ALL issues with severity (high/med/low) and file:line.
Do NOT fix anything yet. Wait for my approval of the list.
```

## Prompt 4 — Debug
```
ERROR: <message/stack>
EXPECTED: <behavior>
ACTUAL: <behavior>
STEPS TO REPRODUCE: <steps>
CONSTRAINT: smallest possible fix, no unrelated refactors.
First find and explain the root cause. Do not change code until I confirm.
```

## Prompt 5 — Security review of a slice
```
Act as a mobile/AppSec reviewer for TASK-XXX. Check against docs/SECURITY.md (S-01..S-11, MASVS table, RLS matrix).
List concrete findings with evidence (file:line) and a proposed fix each. Do not modify code.
```

## Before big tasks
Confirm the last working state is committed (git status clean). If the agent goes off-plan, revert and restart with a smaller task.
