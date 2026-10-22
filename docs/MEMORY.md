# MEMORY — current state (update at the end of EVERY session)

Last updated: 2026-10-22 by: agent (TASK-020)

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

## In progress
- Phase 2: Data Layer (Drift SQLite local DB, repositories, outbox sync).
  - Next: TASK-021: ExpenseRepository (expense+income): CRUD, soft delete, today/week/month totals, by-category, income/expense/balance.

## Next
- TASK-021: ExpenseRepository.
- TASK-022: CheckRepository.
- TASK-023: LedgerRepository.

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
