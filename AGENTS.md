# AGENTS.md — Haqly Mobile (Flutter)

You are working on **Haqly**, an offline-first personal-finance app for Ethiopia (currency ETB, shown "Br 1,250.00").
This file is the short version. The full truth is in `docs/`.

## Before you change anything (every session)
1. Read: `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/RULES.md`, `docs/SECURITY.md`, `docs/TASKS.md`, `docs/MEMORY.md`.
   Read `docs/DESIGN.md` for UI work and `docs/DOMAIN_SPEC.md` for any calculation.
2. Say which TASK-ID you are doing and your plan. **Do not write code until the plan is stated.**
3. Do exactly one task. If the task is bigger than one vertical slice, stop and propose a split.

## Non-negotiable rules (full list: docs/RULES.md)
- Layers: `features/*` (UI) -> Riverpod providers -> `data/repositories` -> Drift SQLite. UI never imports `data/` internals or Supabase.
- Only `data/sync/` talks to Supabase (plus `data/remote/` for auth calls via the auth repository). No exceptions.
- Every write goes through a repository. Local write first, then outbox. Never block UI on network.
- `lib/domain/` is pure Dart: no `package:flutter`, no Drift, no Supabase imports. All money math and business rules live there.
- Money is stored as integer minor units (santim/cents), never `double`, in the local DB.
- No secrets in git. Only the Supabase anon key may ship in the app. NEVER put a service_role key in the app or repo.
- No `print`. Use the logger wrapper. Never log amounts, names, tokens, emails.
- Do not invent business rules, Amharic strings, or colors. If a spec item is marked OPEN in `docs/OPEN_QUESTIONS.md`, stop and ask.
- Do not touch: `docs/source/`, `docs/test_vectors/` (change only via a task that says so), generated files.

## Definition of done (every task)
`dart format` clean -> `flutter analyze` zero issues -> `flutter test` green -> layer check script passes -> acceptance criteria in TASKS.md met -> `docs/MEMORY.md` + `docs/TASKS.md` updated -> one focused commit.

## When reviewing or debugging
Report ALL issues first. Fix only after the human has seen the list. Debugging: root cause first, smallest fix, no unrelated refactors.
