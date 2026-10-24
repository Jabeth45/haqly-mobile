# TASKS — small vertical slices

Format: ID | what | depends | acceptance | blocked by. Do ONE task per agent session. Update status in MEMORY.md after each.
Every task also meets the gates in TEST_PLAN section 1. "Blocked by" refers to OPEN_QUESTIONS.md.

## Phase 0 — Setup
| ID | Task | Dep | Acceptance | Blocked by |
|---|---|---|---|---|
| TASK-000 | [DONE] Create Flutter project (Android first), copy docs pack, git init, first commit. Choose application id with owner | - | `flutter run` shows a blank app; applicationId confirmed by owner | Completed |
| TASK-001 | [DONE] Strict `analysis_options.yaml` (lints, strict modes) | 000 | `flutter analyze` 0 issues | Completed |
| TASK-002 | [DONE] Add baseline dependencies one by one; record resolved versions + license in MEMORY.md | 001 | `flutter pub get` clean; table in MEMORY.md | Completed |
| TASK-003 | [DONE] `tool/check_layers.sh`: forbid illegal imports; forbid `Color(0x` outside tokens; forbid `print(` | 001 | Script fails on a planted violation, passes clean | Completed |
| TASK-004 | [DONE] CI: format, analyze, test, layer check, secret scan | 003 | Pipeline green on PR | Completed |
| TASK-005 | [DONE] `tokens.dart` + light/dark ThemeData; contrast check results recorded in DESIGN.md | 002 | All token pairs used for text measured; fails fixed | Completed |
| TASK-006 | [DONE] gen-l10n scaffold with EN/AM ARB; language switch; verify Ethiopic rendering on a low-end device | 002 | AM placeholder strings render; decision on bundling font recorded | Completed |

## Phase 1 — Domain (pure Dart, vector-driven)
| ID | Task | Dep | Acceptance |
|---|---|---|---|
| TASK-010 | [DONE] `Money` type: parse, minor units, format "Br x,xxx.xx" | 001 | `br` vectors pass; no double for storage; parse rejects negatives/3 decimals |
| TASK-011 | [DONE] `calcCheck` | 010 | All `calcCheck` vectors pass incl. boundaries |
| TASK-012 | [DONE] `calcValueScore` + labels | 010 | All score vectors pass; empty -> null |
| TASK-013 | [DONE] `Clock`, `greeting`, `dayLabel`, `localDate` helpers | 001 | Vectors pass with injected clock |
| TASK-014 | [DONE] `streak` (current, longest) | 013 | Streak vectors pass |
| TASK-015 | [DONE] `split` | 010 | Vectors pass; property test: sum == total |
| TASK-016 | [DONE] `InsightEngine` returning typed `Insight`; configurable order in one place | 012 | Existing 6 rules pass; income rules behind flag until OPEN-005 resolved |
| TASK-017 | [DONE] Balance + budget ring math + alert thresholds | 010 | Vectors pass |
| TASK-018 | [DONE] Stable avatar color hash (FNV-1a) | 001 | Same name same index across runs; test |

## Phase 2 — Data layer (no UI, no Supabase)
| ID | Task | Dep | Acceptance |
|---|---|---|---|
| TASK-020 | [DONE] Drift DB, all tables, indexes, schema version 1, migration test harness | 010 | Opens, creates tables, migration test runs |
| TASK-021 | [DONE] ExpenseRepository (expense+income): CRUD, soft delete, today/week/month totals, by-category, income/expense/balance | 020, 013 | Tests incl. `local_date` grouping; save writes row + outbox atomically |
| TASK-022 | [DONE] CheckRepository (+verdict list) | 020, 011 | |
| TASK-023 | [DONE] LedgerRepository (filters, open summary, settle, split-save) | 020, 015 | Filters All/Lent/Borrowed/Unsettled, settle toggle, open summary, split-save atomically writes lent entries + outbox |
| TASK-024 | [DONE] Budget, Contact, Category repositories | 020 | |
| TASK-025 | [DONE] Outbox: enqueue, coalesce, attempts, backoff | 020 | Unit tests incl. crash-safety |
| TASK-026 | [DONE] `RemoteGateway` interface + `FakeRemote` + SyncService drain | 025 | Offline, partial failure, retry tests pass |
| TASK-027 | Pull with `(updated_at,id)` cursors + tombstone apply | 026 | Two-fake-device test (M5, M6 logic) |
| TASK-028 | Sync triggers: lifecycle, connectivity hint, debounce | 026 | |
| TASK-029 | Sync state notifier (idle/syncing/offline/error) + pending count | 026 | |

## Phase 3 — Shell and identity
| ID | Task | Dep | Acceptance | Blocked by |
|---|---|---|---|---|
| TASK-030 | App shell: go_router, 5-tab nav, empty screens, theme | 005 | Navigation works, state preserved across tabs | |
| TASK-031 | Local guest + boot/restore (LOCAL sentinel), no flash of auth | 020, 030 | M1 passes (data layer only) | |
| TASK-032 | Supabase init from `--dart-define-from-file`; session in secure storage | 002 | Session survives restart; not in plain prefs | OPEN-002 (project) |
| TASK-033 | Email sign up/in + OTP verify | 032 | FR-A1 | BK-005 |
| TASK-034 | Forgot password flow | 033 | FR-A5 | |
| TASK-035 | Anonymous sign-in + adopt (idempotent) | 031, 032 | M3 first half; adopt twice = no change | BK-005, OPEN-008 |
| TASK-036 | Upgrade (link email/Google) + existing-account choice | 035 | M3, M4 | |
| TASK-037 | Google sign-in | 036 | FR-A2 | OPEN-014 for iOS |
| TASK-038 | Delete account (client + Edge Function) | 036 | M14 | BK-004 |

## Phase 4 — Core screens (local-only first)
| ID | Task | Dep | Acceptance |
|---|---|---|---|
| TASK-040 | Home providers (aggregated streams) | 021-024 | Providers unit-tested; no UI |
| TASK-041 | Add screen: Expense/Income toggle, category grid, amount input, Today list | 021, 030 | FR-E1..E5, E7 |
| TASK-042 | QuickAddSheet | 041 | FR-E6 |
| TASK-043 | Check screen: live result, save, list, scale | 022 | FR-C1, C2 |
| TASK-044 | History: grouping, filters, pagination, inline edit | 021 | FR-H1, H2, H4, H5 |
| TASK-045 | Ledger Entries tab | 023 | FR-L2, L3 |
| TASK-046 | Ledger Add + calculator + contacts autocomplete (system picker) | 023, 024 | FR-L1, L4, L5 |
| TASK-047 | Ledger Split tab | 015, 023 | FR-L6 (OPEN-016) |
| TASK-048 | Charts: weekly, category, budget ring, value score ring | 040 | FR-H3; semantics labels |
| TASK-049 | Home assembly | 040, 048 | FR-HM1..HM6; sync icon hidden when idle |
| TASK-050 | Settings: profile, budget, categories, contacts | 024 | |
| TASK-051 | Settings: appearance, language, stats, guest card, sign out | 050 | |

## Phase 5 — Native and hardening
| ID | Task | Acceptance |
|---|---|---|
| TASK-060 | Haptics wrapper + wiring | Only wrapper calls HapticFeedback |
| TASK-061 | Swipe-delete confirm sheet, pull-to-refresh | |
| TASK-062 | App PIN + biometric lock (KDF choice recorded) | M12 |
| TASK-063 | Local notifications x3 + permission handling | M13 |
| TASK-064 | WorkManager opportunistic sync (Android) | Does not break foreground sync |
| TASK-065 | Local DB encryption decision + implementation (ADR-015) | Decision recorded either way |
| TASK-066 | Manifest/backup hardening, release flags | SECURITY S-05, PLATFORM items |

## Phase 6 — Release
| ID | Task | Acceptance |
|---|---|---|
| TASK-070 | Icon + splash from designer assets | Adaptive + monochrome layers present |
| TASK-071 | Signing + release build in CI | Signed AAB built |
| TASK-072 | Full M1-M17 on real low-end device | Report in MEMORY.md |
| TASK-073 | Performance profile (profile mode) + APK size report | |
| TASK-074 | RLS matrix executed and recorded | All 9 pass |
| TASK-075 | Privacy policy + store listing + data-safety answers | Owner approved |
| TASK-076 | Internal testing track upload | Installable by testers |
| TASK-077 | iOS pass (Sign in with Apple decision, signing, TestFlight) | After Android stable |

## Backend / owner tasks (not for the coding agent unless asked)
| ID | Task | Why |
|---|---|---|
| BK-001 | Export and share the live web Supabase schema + RLS policies; diff against `backend/supabase_schema.sql` | OPEN-002 |
| BK-002 | Apply migration on a staging project first | |
| BK-003 | Update the web app to filter `deleted_at is null` before mobile sync ships | OPEN-003 |
| BK-004 | Edge Function for account deletion | S-08 |
| BK-005 | Enable anonymous sign-ins and manual identity linking; configure captcha/rate limits; email OTP template | Supabase dashboard settings |
| BK-006 | Provide web `lib/utils.ts`, translation files (en/am), CSS/tailwind tokens | OPEN-004 |
| BK-007 | Store developer accounts (Play, later Apple) | OPEN-007 |
