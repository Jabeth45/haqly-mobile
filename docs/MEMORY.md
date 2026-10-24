# MEMORY — current state (update at the end of EVERY session)

Last updated: 2026-10-24 by: agent (TASK-025)

## Done
- Documentation pack created and audited.
- Architecture and domain decisions locked in (Brand Green #00C47A, pure local guest sentinel, bundled Noto Sans Ethiopic, appId `com.haqly.app`).
- Phase 0 (Setup) Complete:
  - TASK-000: Scaffolded Flutter project (Android/iOS), docs pack integrated, git repo initialized, Android manifest allowBackup=false set.
  - TASK-001: Strict `analysis_options.yaml` configured with strict-casts, strict-inference, strict-raw-types and clean linter rules.
  - TASK-002: Baseline runtime and dev dependencies added, versions and licenses audited and recorded.
  - TASK-003: `tool/check_layers.dart` and `tool/check_layers.sh` created and verified with planted violation tests (clean zero violations).
  - TASK-004: GitHub Actions CI workflow created with format, analysis, layer check, secret scan, and test suite.
  - TASK-005: `tokens.dart` created with Brand Emerald Green (#00C47A), light and dark `ThemeData` implemented, WCAG 2.1 AA/AAA contrast ratios verified and documented.
  - TASK-006: Localization scaffolded with English (`app_en.arb`) and Amharic (`app_am.arb`), `AppLocalizations` generated, widget tests verifying bilingual rendering passing. Font bundling decision confirmed for Phase 0 exit.
- Phase 1 (Domain) Complete:
  - TASK-010: Pure Dart `Money` value type implemented (minor units storage, decimal parse rejecting negatives/3 decimals, formatting "Br x,xxx.xx" matching `domain_vectors.json`). All vector tests green.
  - TASK-011: `calcCheck` implemented in `lib/domain/check_calculator.dart` matching web parity and all 12 vector test cases including exact boundaries.
  - TASK-012: `calcValueScore` implemented in `lib/domain/value_score.dart` with score labels and breakdown percentages matching all 8 vector cases and empty null behavior.
  - TASK-013: Injectable `Clock` (`SystemClock`, `FixedClock`), `greeting(hour)`, `dayLabel(date)`, and `toLocalDateString` helpers implemented in `lib/domain/date_utils.dart` with 100% vector parity.
  - TASK-014: `calcStreak` implemented in `lib/domain/streak.dart` computing current streak, longest streak, visibility condition (>=3), and 7/30-day milestone flags matching all vector test cases.
  - TASK-015: `splitBill` implemented in `lib/domain/split.dart` distributing remainder minor units, distinguishing payer expense share from friends' lent shares, with 100% vector parity and 1000-iteration randomized property test invariant `sum(shares) == total`.
  - TASK-016: `generateInsight` implemented in `lib/domain/insight_engine.dart` returning typed `Insight` with parameter maps, priority-ordered rules matching DOMAIN_SPEC, and income rules configurable behind flags.
  - TASK-017: `MonthBalance` and `BudgetRing` implemented in `lib/domain/balance_calculator.dart` with negative balance formatting ("-Br 250.00"), ceiling priority (budget > income), and 80%/100% alert thresholds matching all vectors.
  - TASK-018: FNV-1a 32-bit stable cross-platform hash and bilingual initials extraction implemented in `lib/domain/avatar_utils.dart` tested with English and Amharic names.
- Phase 2 (Data Layer) In Progress:
  - TASK-020: Drift SQLite database implemented in `lib/data/db/` (`tables.dart`, `app_database.dart`, `app_database.g.dart`) with schema version 1. All 8 tables (`expenses`, `check_items`, `ledger_entries`, `budgets`, `contacts`, `user_categories`, `outbox`, `sync_meta`), constraints, default values (`user_id = 'LOCAL'`), and 10 query optimization indexes created. In-memory testing constructor and schema migration test harness implemented with 100% passing tests.
  - TASK-021: `ExpenseRepository` implemented in `lib/data/repositories/expense_repository.dart` backed by `AppDatabase` and pure Dart domain models (`Expense`, `TransactionType`, `CategoryTotal`). Atomically writes local records and coalesced outbox pointers in a single DB transaction. Soft delete sets `deleted_at` and enqueues outbox pointer. Stream watchers (`watchAll`, `watchByDate`, `watchByDateRange`), aggregations (`getTotalsForDate`, `getTotalsForDateRange`, `getByCategoryTotals`), and balance calculations (`getBalanceForDateRange`, `getMonthBalance`) fully covered by 10 comprehensive unit tests with in-memory SQLite.
  - TASK-022: `CheckRepository` implemented in `lib/data/repositories/check_repository.dart` backed by `AppDatabase` and pure Dart domain model `CheckItem`. Writes/upserts and soft deletes execute atomically with coalesced outbox sync pointers. Provides reactive streams (`watchAll`, `watchByDate`) and query filters (`getVerdicts`, `getRecentVerdicts`) for value score calculations. Fully covered by 8 automated real-SQLite tests.
  - TASK-023: `LedgerRepository` implemented in `lib/data/repositories/ledger_repository.dart` backed by `AppDatabase` and pure Dart domain entities (`LedgerEntry`, `LedgerType`, `LedgerSummary`, and RFC 4122 v4 generator in `uuid_utils.dart`). Atomically writes records and coalesced outbox pointers in a single DB transaction. Settle toggle updates `settled` flag and outbox pointer. Soft delete sets `deleted_at` and enqueues outbox pointer. Supports filtering by `type` (lent/borrowed) and `settled` status. Reactive and one-shot open summaries track ETB and USD net balances independently without conversion (per OPEN-015). `saveSplit` converts `SplitResult` into individual lent debt entries excluding payer in a single DB transaction. Fully covered by 20 automated real-SQLite tests.
  - TASK-024: Budget, Contact, and Category repositories implemented in `lib/data/repositories/` (`budget_repository.dart`, `contact_repository.dart`, `category_repository.dart`) backed by `AppDatabase` and pure Dart domain models (`Budget`, `Contact`, `UserCategory`, `CategoryKind`, `CategoryConstants`). All writes and soft-deletes enqueue coalesced outbox pointers atomically. `BudgetRepository` safely handles the unique `userId` constraint, providing `setBudget`, `clearBudget`, and reactive streams. `ContactRepository` implements case-insensitive search and lookups without requiring runtime phone permissions (`S-10`). `CategoryRepository` combines canonical defaults (6 expense, 7 income per DOMAIN_SPEC §9) with custom categories and handles soft deletion. Domain models and all 3 repositories are covered by 33 comprehensive automated tests (123 total project tests passing green).
  - TASK-025: Outbox queue implemented in `lib/data/sync/outbox.dart` (`OutboxEntry`, `BackoffPolicy`, `OutboxQueue`) backed by Drift SQLite `outbox` table. Pointers (`table_name`, `row_id`, `created_at`, `attempts`, `last_error`) store references instead of stale payloads. Successive writes to the same row coalesce into a single pointer, resetting attempts and clearing errors. Configurable exponential backoff caps at `maxDelay` (5 mins default). Provides FIFO ready filtering (`getReadyEntries`), distinct reactive stream for pending count (`watchPendingCount`), deletion on sync success, tap-to-retry reset (`resetAttempts`), and strict SQLite transaction rollback crash-safety verified by 11 automated unit tests (134 total project tests passing green).

## In progress
- Phase 2: Data Layer (Drift SQLite local DB, repositories, outbox sync).
  - Next: TASK-026: `RemoteGateway` interface + `FakeRemote` + SyncService drain.

## Next

- TASK-026: `RemoteGateway` interface + `FakeRemote` + SyncService drain.
- TASK-027: Pull with `(updated_at,id)` cursors + tombstone apply.

## Known issues / risks
- Web schema to be diffed against proposed schema.
- Amharic strings to be aligned with web translations once available.

## Dependency log (agent fills in at TASK-002)
| Package | Resolved version | Why | License checked |
|---|---|---|---|
| flutter_riverpod | 3.4.3 | Reactive state management & DI | MIT |
| go_router | 18.1.1 | Declarative URL-friendly routing | BSD-3-Clause |
| drift | 2.35.2 | Type-safe reactive SQLite ORM | MIT |
| sqlite3_flutter_libs | 0.6.0+eol | Native SQLite C-libraries | MIT |
| path_provider | 2.1.6 | Host filesystem directories for SQLite | BSD-3-Clause |
| path | 1.9.1 | Filesystem path manipulation | BSD-3-Clause |
| shared_preferences | 2.5.6 | Key-value non-sensitive prefs | BSD-3-Clause |
| flutter_secure_storage | 11.2.0 | Encrypted Keystore/Keychain for tokens/PIN | BSD-3-Clause |
| supabase_flutter | 2.18.3 | Remote Postgres and Auth client | MIT |
| intl | 0.20.3 | Currency formatting and i18n | BSD-3-Clause |
| connectivity_plus | 7.3.2 | Network connection hints | BSD-3-Clause |
| flutter_slidable | 4.0.3 | Swipe-to-delete action UI | MIT |
| drift_dev (dev) | 2.35.1 | Drift code generator | MIT |
| build_runner (dev) | 2.16.2 | Dart builder execution | BSD-3-Clause |

## Environment notes
- Flutter: 3.47.7 (stable)
- Dart: 3.13.5 (stable)
- Host: Windows x64
- Target appId: com.haqly.app
- Min Android SDK: 21 (Flutter default)
