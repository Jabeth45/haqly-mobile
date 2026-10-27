# MEMORY — current state (update at the end of EVERY session)

Last updated: 2026-10-27 by: agent (TASK-037)

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
- Phase 2 (Data Layer) Complete:
  - TASK-020: Drift SQLite database implemented in `lib/data/db/` (`tables.dart`, `app_database.dart`, `app_database.g.dart`) with schema version 1. All 8 tables (`expenses`, `check_items`, `ledger_entries`, `budgets`, `contacts`, `user_categories`, `outbox`, `sync_meta`), constraints, default values (`user_id = 'LOCAL'`), and 10 query optimization indexes created. In-memory testing constructor and schema migration test harness implemented with 100% passing tests.
  - TASK-021: `ExpenseRepository` implemented in `lib/data/repositories/expense_repository.dart` backed by `AppDatabase` and pure Dart domain models (`Expense`, `TransactionType`, `CategoryTotal`). Atomically writes local records and coalesced outbox pointers in a single DB transaction. Soft delete sets `deleted_at` and enqueues outbox pointer. Stream watchers (`watchAll`, `watchByDate`, `watchByDateRange`), aggregations (`getTotalsForDate`, `getTotalsForDateRange`, `getByCategoryTotals`), and balance calculations (`getBalanceForDateRange`, `getMonthBalance`) fully covered by 10 comprehensive unit tests with in-memory SQLite.
  - TASK-022: `CheckRepository` implemented in `lib/data/repositories/check_repository.dart` backed by `AppDatabase` and pure Dart domain model `CheckItem`. Writes/upserts and soft deletes execute atomically with coalesced outbox sync pointers. Provides reactive streams (`watchAll`, `watchByDate`) and query filters (`getVerdicts`, `getRecentVerdicts`) for value score calculations. Fully covered by 8 automated real-SQLite tests.
  - TASK-023: `LedgerRepository` implemented in `lib/data/repositories/ledger_repository.dart` backed by `AppDatabase` and pure Dart domain entities (`LedgerEntry`, `LedgerType`, `LedgerSummary`, and RFC 4122 v4 generator in `uuid_utils.dart`). Atomically writes records and coalesced outbox pointers in a single DB transaction. Settle toggle updates `settled` flag and outbox pointer. Soft delete sets `deleted_at` and enqueues outbox pointer. Supports filtering by `type` (lent/borrowed) and `settled` status. Reactive and one-shot open summaries track ETB and USD net balances independently without conversion (per OPEN-015). `saveSplit` converts `SplitResult` into individual lent debt entries excluding payer in a single DB transaction. Fully covered by 20 automated real-SQLite tests.
  - TASK-024: Budget, Contact, and Category repositories implemented in `lib/data/repositories/` (`budget_repository.dart`, `contact_repository.dart`, `category_repository.dart`) backed by `AppDatabase` and pure Dart domain models (`Budget`, `Contact`, `UserCategory`, `CategoryKind`, `CategoryConstants`). All writes and soft-deletes enqueue coalesced outbox pointers atomically. `BudgetRepository` safely handles the unique `userId` constraint, providing `setBudget`, `clearBudget`, and reactive streams. `ContactRepository` implements case-insensitive search and lookups without requiring runtime phone permissions (`S-10`). `CategoryRepository` combines canonical defaults (6 expense, 7 income per DOMAIN_SPEC §9) with custom categories and handles soft deletion. Domain models and all 3 repositories are covered by 33 comprehensive automated tests (123 total project tests passing green).
  - TASK-025: Outbox queue implemented in `lib/data/sync/outbox.dart` (`OutboxEntry`, `BackoffPolicy`, `OutboxQueue`) backed by Drift SQLite `outbox` table. Pointers (`table_name`, `row_id`, `created_at`, `attempts`, `last_error`) store references instead of stale payloads. Successive writes to the same row coalesce into a single pointer, resetting attempts and clearing errors. Configurable exponential backoff caps at `maxDelay` (5 mins default). Provides FIFO ready filtering (`getReadyEntries`), distinct reactive stream for pending count (`watchPendingCount`), deletion on sync success, tap-to-retry reset (`resetAttempts`), and strict SQLite transaction rollback crash-safety verified by 11 automated unit tests (134 total project tests passing green).
  - TASK-026: Remote gateway abstraction, fake test double, mappers, and sync drain orchestrator implemented:
  - `RemoteGateway` interface in `lib/data/remote/remote_gateway.dart` (`upsert`, `upsertBatch`, `isAuthenticated`, `currentUserId`, `SyncException`, `SyncOfflineException`).
  - `FakeRemoteGateway` test double in `lib/data/remote/fake_remote_gateway.dart` with online/offline toggling, table/row failure simulation, transient attempts counter, and row store.
  - `RemoteMappers` in `lib/data/remote/remote_mappers.dart` converting Drift SQLite rows into Supabase remote JSON schemas and bidirectional decimal conversion (`minorToDecimal`, `decimalToMinor`).
  - `SyncService` in `lib/data/sync/sync_service.dart` orchestrating `drain()`: builds current payload on the fly from SQLite, halts safely on offline, increments attempts and triggers backoff on partial failure, skips unadopted guest rows (`user_id == 'LOCAL'`), and discards stale pointers.
  - Covered by 11 unit and integration tests across `sync_service_drain_test.dart` and `remote_mappers_test.dart` (145 total project tests passing green).
  - TASK-027: Pull synchronization implemented in `lib/data/sync/pull.dart` (`PullService`, `PullResult`) with cursor tracking in `sync_meta` and remote-to-local companions in `remote_mappers.dart`. Paginates across all 6 tables using composite cursors `(cursor_updated_at, cursor_id)`. Resolves conflicts against local pending outbox edits (newer local edit preserved; remote newer/equal overwrites). Soft-delete tombstones (`deleted_at`) applied locally. Acceptance verified with 6 automated tests in `pull_test.dart` and `two_device_sync_test.dart` passing scenarios M5 (concurrent offline edits on two devices resolved by newer timestamp without duplicates) and M6 (tombstone propagation across devices) with 151 total project tests green.
  - TASK-028: Sync triggers implemented in `lib/data/sync/sync_triggers.dart` (`SyncTriggerCoordinator`) with `ConnectivityService` abstraction in `lib/core/services/connectivity_service.dart`. Coordinates local write debouncing (~2s window), immediate sync triggers (`requestSync(immediate: true)`), app lifecycle resume (`onAppForegrounded()`), connectivity hint transitions (offline-to-online recovery), re-entrancy protection, and clean resource cancellation. Verified with 6 automated tests in `sync_triggers_test.dart` (157 total project tests green).
  - TASK-029: Sync state machine and reactive notifier implemented in `lib/data/sync/sync_state.dart` and `lib/data/sync/sync_state_notifier.dart` (`SyncStatus`, `SyncState`, `SyncStateNotifier`). Drives the quiet app header sync icon (`isIconVisible` hidden in `idle`, visible only in `syncing`/`offline`/`error`). Subscribes reactively to `OutboxQueue.watchPendingCount()` and provides `tapToRetry()` to reset backoff attempts and trigger immediate retry. Fully tested with 6 automated unit tests in `sync_state_notifier_test.dart` (163 total project tests green).
- Phase 3 (Shell and Identity):
  - TASK-030: App shell implemented with `go_router`, Material 3 persistent bottom navigation (`ScaffoldWithNavBar`), and 5 destination tabs (Home, Add, Check, Ledger, History) using `StatefulShellRoute.indexedStack` (ADR-007). Sub-routes (`/settings`) routed above bottom bar via root navigator. Tab switching, state preservation (form input survives tab transitions), and bilingual navigation labels verified with 4 automated widget tests in `router_test.dart` (167 total project tests green).
  - TASK-031: Local guest mode, session restore, and auth guard implemented:
    - Pure Dart immutable `AuthState` in `lib/domain/models/auth_state.dart` with `LOCAL` sentinel.
    - `SessionRepository` and `LocalSessionRepository` in `lib/data/repositories/session_repository.dart` backed by `SharedPreferences` (with in-memory test factory).
    - Riverpod state management in `lib/features/auth/providers/auth_providers.dart` (`authStateProvider`, `authListenableProvider`).
    - Guarded `createAppRouter` in `lib/app/router.dart` preventing auth flash during loading (FR-A6) and redirecting unauthenticated cold boots to `/welcome`.
    - Minimalist, brand-aligned `WelcomeScreen` in `lib/features/onboarding/presentation/welcome_screen.dart` with localized "Continue as Guest" CTA.
    - Covered by 7 automated tests across `session_repository_test.dart` and `auth_boot_test.dart` verifying fresh install, cold-boot restore, and Scenario M1 offline data writes (174 total project tests green).
  - TASK-032: Supabase initialization from `--dart-define-from-file` and secure storage session adapter implemented:
    - `AppConfig` in `lib/core/config/app_config.dart` reading `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `APP_ENV`.
    - `SecureLocalStorage` and `SecureGotrueAsyncStorage` in `lib/data/remote/secure_local_storage.dart` implementing Supabase's `LocalStorage` and `GotrueAsyncStorage` interfaces backed by `FlutterSecureStorage` (resolving Security finding S-01; verified session is absent from `SharedPreferences`).
    - Supabase bootstrap in `lib/data/remote/supabase_client.dart` with auto-refresh and PKCE flow storage.
    - `main.dart` decoupled from Supabase internals via data/remote facade.
    - Verified by 7 tests in `secure_local_storage_test.dart` and `app_config_test.dart` (181 total project tests green).
  - TASK-033: Email sign up/in and OTP verification implemented:
    - Pure Dart `AuthResult` domain model in `lib/domain/models/auth_result.dart`.
    - `AuthRepository` interface and `FakeAuthRepository` in `lib/data/repositories/auth_repository.dart` for test isolation.
    - `SupabaseAuthRepository` in `lib/data/remote/supabase_auth_repository.dart` handling email registration, password login, OTP verification, and generic error mapping (SECURITY.md §3).
    - `AuthNotifier` updated with `signUpWithEmail`, `signInWithEmail`, and `verifyOtp` methods that persist authenticated sessions into `SessionRepository`.
    - `LoginScreen`, `RegisterScreen`, and `OtpVerifyScreen` built with bilingual ARB keys (English and Amharic).
    - Router updated with `/login`, `/register`, and `/verify-otp` outside the bottom navigation bar.
    - Covered by 8 automated tests in `auth_repository_test.dart` and `email_auth_test.dart` (189 total project tests green).
  - TASK-034: Forgot password flow with recovery OTP implemented:
    - Added `sendPasswordResetEmail` and `resetPasswordWithOtp` to `AuthRepository` and `SupabaseAuthRepository` with enumeration-resistant generic success responses.
    - Extended `AuthNotifier` with recovery actions.
    - Built `ForgotPasswordScreen` with two-step recovery flow (email dispatch -> 6-digit OTP verification + new password update).
    - Linked from `LoginScreen` and routed at `/forgot-password`.
    - Added localized strings in English and Amharic.
    - Verified by 3 tests in `auth_repository_test.dart` and `forgot_password_test.dart` (192 total project tests green).
  - TASK-035: Anonymous sign-in and idempotent guest adoption (M3) implemented:
    - `AdoptionService` in `lib/data/sync/adopt.dart`: atomically scans all 6 tables (`expenses`, `check_items`, `ledger_entries`, `budgets`, `contacts`, `user_categories`) where `user_id == 'LOCAL'` (or specified `fromUserId`), reassigns `user_id` to the target user ID, bumps `client_updated_at`, and enqueues outbox sync pointers.
    - Idempotency verified: running adoption a second time produces 0 updates and 0 duplicate outbox queue entries.
    - Added `signInAnonymously()` to `AuthRepository`, `FakeAuthRepository`, and `SupabaseAuthRepository`.
    - Integrated automatic post-sign-in adoption hook in `AuthNotifier.signInAnonymously()`.
    - Verified by 4 automated unit and integration tests in `adopt_test.dart` (196 total project tests green).
  - TASK-036: Account upgrade (link email) and existing-account choice (M3 & M4) implemented:
    - Extended `AuthResult` with `emailAlreadyInUse` flag and constructor for detecting existing cloud accounts.
    - Added pure Dart `ExistingAccountChoice` domain model (`keepCloud`, `replaceWithDevice`).
    - Extended `AdoptionService` in `lib/data/sync/adopt.dart` with `hasGuestData()`, `countGuestData()`, and atomic SQLite `discardGuestData()`.
    - Added `linkEmail()` to `AuthRepository`, `FakeAuthRepository`, and `SupabaseAuthRepository` converting anonymous/guest sessions while retaining UUID.
    - Implemented `AccountRepository` and `AccountRepositoryImpl` in `lib/data/repositories/account_repository.dart` coordinating SQLite adoption/discard, auth linking, and pull hydration.
    - Built modern, accessible `UpgradeScreen` in `lib/features/auth/presentation/upgrade_screen.dart` with conflict resolution sheet for keep-cloud vs replace choices.
    - Registered `/upgrade` route in router with guest guard.
    - Added localized strings in English and Amharic for upgrade flows and choice dialog.
    - Covered by 10 comprehensive tests in `upgrade_account_test.dart` and `adopt_test.dart` verifying M3, M4 Keep Cloud, and M4 Replace with Device scenarios (206 total project tests green).
  - TASK-037: Google sign-in (FR-A2, ADR-012) implemented:
    - Added `signInWithGoogle` and `linkGoogle` to `AuthRepository`, `FakeAuthRepository`, and `SupabaseAuthRepository` (`OAuthProvider.google` with deep-link callback).
    - Extended `AccountRepository` and `AccountRepositoryImpl` with `upgradeWithGoogle()` and `adoptGuestData()` integrating `AdoptionService` to automatically preserve guest records and outbox pointers.
    - Extended `AuthNotifier` with `signInWithGoogle({bool adoptGuestData = true})` and `upgradeWithGoogle()`.
    - Added clean, accessible `GoogleSignInButton` respecting design tokens without hardcoded colors.
    - Integrated Google Sign-In into `WelcomeScreen`, `LoginScreen`, `RegisterScreen`, and `UpgradeScreen`.
    - Added bilingual ARB keys for `continueWithGoogle` and `orDivider` in English and Amharic.
    - Fully covered by 9 automated tests across `auth_repository_test.dart` and `google_auth_test.dart` (215 total project tests green).

## In progress
- Phase 3: Shell and identity (TASK-031 to TASK-037 completed).
  - Next: TASK-038: Delete account (blocked by BK-004) or TASK-040: Home providers.

## Next
- TASK-038: Delete account (blocked by BK-004) / TASK-040: Home providers.

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
