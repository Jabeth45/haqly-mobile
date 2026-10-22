# DECISIONS (ADRs) — permanent. Do not relitigate silently.

Format: status | decision | why | consequences. "Owner" = decided by Yaba. "Default" = Yaba accepted my recommended default. "Provisional" = made by me because the owner left it open; flagged in OPEN_QUESTIONS.

| ID | Status | Decision | Why | Consequences |
|---|---|---|---|---|
| ADR-001 | Owner | Build in Flutter/Dart, hybrid Android/iOS | Owner's stack choice; Bible's React Native plan is superseded | Bible Parts 2,3,6,7 and rule 4 translated in ARCHITECTURE.md |
| ADR-002 | Default | Riverpod + Drift + go_router | Typed, testable, agent-friendly | |
| ADR-003 | Bible | Offline-first; SQLite is the read source; UI never waits on network | Connectivity and data cost in target market | Outbox sync (ADR-006) |
| ADR-004 | Default (adapted) | Guest via Supabase anonymous sign-in then link to an account; local `LOCAL` sentinel until an identity exists | Stable uid avoids Bible's row/queue rewrite. Anonymous sign-in needs network, so first-launch offline guests stay `LOCAL` and are adopted later | Needs BK-005 and abuse controls; guests are not strictly zero-network (OPEN-008) |
| ADR-005 | Proposal | Money as integer minor units locally; `numeric(14,2)` remotely | Avoid float drift; compatible with web either way | Mappers at sync boundary; domain math for verdict stays double like web |
| ADR-006 | Proposal | Outbox of pointers (not payloads), soft deletes, server-enforced LWW via trigger, `(updated_at,id)` pull cursors | Fixes Bible C4, C7, C9 and the "upsert doesn't compare timestamps" flaw | Web must honor `deleted_at` (OPEN-003) |
| ADR-007 | Default | 5 bottom tabs (Home, Add, Check, Ledger, History); Settings via avatar | Six tabs exceeds standard mobile nav; overrides Bible "match web nav" | |
| ADR-008 | Default | Android first, iOS after | Market assumption (not verified by me) and store logistics | Keep iOS-safe code; Apple login decision later |
| ADR-009 | Default | SMS auto-capture out of v1 | Play restricts SMS permissions to default handlers or approved exceptions; review risk | Revisit v1.5 with distribution plan |
| ADR-010 | Provisional | Brand accent violet #9710FF (sampled from reference 2); Bible neutrals and semantic colors kept | Refs and icon are violet; frees green for income/lent/worth meaning | One-file swap if owner prefers green (OPEN-001) |
| ADR-011 | Default | Ethiopian calendar and Ethiopian-clock time out of v1; store dates as UTC instants + local `YYYY-MM-DD` so a calendar layer can be added later | Scope control | Revisit post-v1 |
| ADR-012 | Proposal | Google sign-in P1 on Android; Sign in with Apple decision before iOS | Store rules (verify) | OPEN-014 |
| ADR-013 | Proposal | In-app account and data deletion is a P0 for release | Store requirements (verify current rules) | Edge Function BK-004 |
| ADR-014 | Provisional | No analytics or crash-reporting SDK in v1 | Privacy stance; competitor contrast | Harder diagnostics; revisit with opt-in design (OPEN-009) |
| ADR-015 | Open | Local DB encryption (SQLCipher) decided in TASK-065 | Defense in depth vs build complexity | Record outcome either way |
| ADR-016 | Proposal | Settings reached from avatar; guest banner only in Settings (resolves Bible C2) | Less intrusive | |
| ADR-017 | Proposal | Ring ceiling: manual budget, else income; toggle only when both exist | Resolves Bible contradiction | Confirm OPEN-005 |
| ADR-018 | Proposal | Foreground sync is primary; background sync is opportunistic only | iOS background limits; Android doze | No UX promise of 15-minute sync |
