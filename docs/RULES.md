# RULES — how the AI (and humans) must code here

## Architecture rules
1. UI (`features/`, `shared/`) never imports `data/db`, `data/sync`, `data/remote`, or `supabase_flutter`.
2. Only `data/sync/` and `data/remote/` talk to Supabase.
3. Every write goes through a repository, in a single DB transaction with its outbox pointer.
4. `lib/domain/` is pure Dart (no Flutter, Drift, Supabase, platform channels).
5. No network wait in the UI path for local data. No spinners for data already in Drift.
6. Sync feedback = the sync icon only. No success toasts. No failure modals.
7. All calculations live in `domain/`. Widgets display; providers fetch; domain calculates.
8. Haptics, biometrics, notifications, clock are accessed only through `core/services/` wrappers (so they can be faked in tests).
9. Money is integer minor units locally. No `double` for stored money.
10. Time is injected (`Clock`) in domain and providers; no raw `DateTime.now()` in domain.

## Code rules
- Null-safe Dart, strict analysis (`flutter_lints` + `strict-casts`, `strict-inference`, `strict-raw-types`).
- No `print`; use `Logger`. Never log money amounts, names, emails, tokens, OTPs, PIN.
- No hard-coded user-facing strings; ARB keys only. No hard-coded colors, radii, spacing outside `core/theme/tokens.dart`.
- Widgets small and const where possible; lists use builders; no work in `build()`.
- Generated files are never edited by hand.

## Process rules
- One task per branch (`feature/task-xxx-short-name`), one focused commit per working state, conventional messages.
- Do not add a dependency without recording why in `docs/MEMORY.md` (name, resolved version, reason, license check).
- Do not change DB schema without: a Drift migration, a migration test, and an update to ARCHITECTURE.md + SECURITY.md if sync/RLS is affected.
- Do not change anything in `docs/test_vectors/` to fix a failing test.
- If a requirement is marked OPEN, stop and ask. Do not guess Amharic text, insight copy, colors, or backend schema.

## Do-not-touch zones
`docs/source/`, `docs/test_vectors/` (unless a task says so), `android/key.properties`, anything under `env/` except `*.example.json`, generated code.

## Review prompt contract
Review output is a numbered list of issues with severity and file:line, produced BEFORE any fix. Fixes happen only after the human approves the list.
