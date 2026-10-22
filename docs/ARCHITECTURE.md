# ARCHITECTURE — Haqly Mobile

Status: Draft. Replaces Parts 2, 3, 4, 5, 6, 7 of the original Build Bible (React Native). Business meaning is unchanged; implementation is Flutter.

## 1. Stack (unpinned versions — see README)

| Concern | Choice | Replaces (Bible) | Note |
|---|---|---|---|
| Language/UI | Dart + Flutter (Material 3) | React Native/Expo | Android first |
| State/DI | Riverpod (`flutter_riverpod`; codegen optional) | Zustand | ADR-002 |
| Routing | `go_router` | expo-router | Auth guards via redirect |
| Local DB | Drift over SQLite | expo-sqlite | Typed queries, migrations. SQLCipher option in Phase 5 (ADR-015) |
| Prefs | `shared_preferences` | AsyncStorage | Non-sensitive only |
| Secrets | `flutter_secure_storage` | expo-secure-store | Tokens, PIN hash, DB key |
| Remote | `supabase_flutter` | supabase-js | Session persisted in secure storage via custom `LocalStorage` (see SECURITY S-01) |
| Charts | `fl_chart` or `CustomPainter` | react-native-svg | Decide in TASK-050 |
| Biometrics | `local_auth` | expo-local-authentication | |
| Notifications | `flutter_local_notifications` | expo-notifications | Local only |
| Background | `workmanager` | expo-background-fetch | Android best-effort; iOS very limited |
| Connectivity | `connectivity_plus` | NetInfo | Hint only; real success = request success |
| Haptics | Flutter `HapticFeedback` behind wrapper | expo-haptics | |
| i18n | `flutter_localizations` + `intl` + gen-l10n ARB | custom translations | EN + AM |
| Slidable rows | `flutter_slidable` | Gesture Handler | |
| Icons | `flutter_launcher_icons` | app.json | verify config at use |
| CI | GitHub Actions (or Codemagic) | EAS | |

Rule: the agent adds each package with `flutter pub add`, checks its current README, and records the resolved version in MEMORY.md. If a package is unmaintained or incompatible, stop and record a new ADR instead of silently swapping.

## 2. Layering (enforced)

```
features/*  (widgets, screen controllers)      -> may import: domain, shared, providers
providers (Riverpod, in features/ or app/)     -> may import: domain, data/repositories (interfaces)
data/repositories                              -> may import: data/db, data/sync (outbox only), domain
data/sync, data/remote                         -> may import: data/db, domain, supabase
domain/                                        -> imports NOTHING from flutter, drift, supabase
```

`tool/check_layers.sh` greps imports and fails CI on violations (TASK-003).

## 3. Folder tree

```
haqly-mobile/
├── AGENTS.md
├── docs/ (this pack)
├── env/dev.example.json            # real env files gitignored
├── tool/check_layers.sh
├── lib/
│   ├── main.dart                   # bootstrap: DB, prefs, env, providers
│   ├── app/                        # MaterialApp.router, router.dart, theme wiring
│   ├── core/
│   │   ├── theme/                  # tokens.dart (ALL colors/spacing/radii), theme_light.dart, theme_dark.dart
│   │   ├── l10n/                   # app_en.arb, app_am.arb (generated classes)
│   │   ├── logging/                # logger.dart (no PII)
│   │   └── services/               # haptics.dart, biometric.dart, notifications.dart, clock.dart
│   ├── domain/                     # PURE DART
│   │   ├── models/                 # Expense, CheckItem, LedgerEntry, Budget, Contact, enums
│   │   ├── money.dart              # Money value type (minor units), Br formatting
│   │   ├── check_calculator.dart   # calcCheck
│   │   ├── value_score.dart        # calcValueScore + labels
│   │   ├── insight_engine.dart     # generateInsight
│   │   ├── streak.dart
│   │   ├── split.dart
│   │   └── date_utils.dart         # dayLabel, greeting, local-date helpers (clock injected)
│   ├── data/
│   │   ├── db/                     # drift database, tables, migrations, DAOs
│   │   ├── repositories/           # Expense/Check/Ledger/Budget/Contact/Category repos
│   │   ├── sync/                   # outbox.dart, sync_service.dart, pull.dart, sync_state.dart
│   │   └── remote/                 # supabase_client.dart, auth_repository.dart, remote_mappers.dart
│   ├── features/
│   │   ├── onboarding/ auth/ home/ expense/ check/ ledger/ history/ settings/
│   │   └── (each: presentation/, providers.dart)
│   └── shared/widgets/             # Card, AppButton, AppTextField, VerdictBadge, SyncIcon, ...
├── test/
│   ├── domain/                     # vector-driven parity tests
│   ├── data/                       # in-memory Drift repo tests, sync tests with FakeRemote
│   └── features/                   # widget tests
└── integration_test/               # device flows (airplane mode etc.)
```

## 4. Data flow

### Write path
Screen -> provider calls `Repository.save()` -> repository, **in one DB transaction**: write row (with `client_updated_at`, `local_date`), insert outbox entry -> UI re-renders from Drift stream instantly -> `SyncService.requestSync()` (debounced) -> drains outbox -> Supabase upsert -> outbox row deleted on success.

### Read path
Screens watch Drift streams (`watch()` queries) through providers. They never wait on the network. When online, `pull()` runs silently; changed rows land in Drift and the stream updates the UI.

### Delete
Delete = set `deleted_at` + `client_updated_at` and outbox upsert. Repositories filter `deleted_at IS NULL`. There is no hard delete from the client (except local wipe on sign-out/delete-account). Reason: other devices must learn about deletions.

### Outbox (replaces per-row `sync_status` + payload JSON; fixes Bible C4/C7)
`outbox(id INTEGER PK AUTOINCREMENT, table_name, row_id, created_at, attempts, last_error)`
The outbox stores **pointers, not payloads**. At drain time the payload is built from the current row, so user-id adoption (section 6) and later edits never leave stale JSON. Multiple outbox entries for the same row coalesce to one upsert.

### Sync state machine (single definition)
`idle -> syncing -> idle | offline | error`. `error` keeps pending count and supports tap-to-retry. Icon is hidden in `idle`.

### Triggers
App foreground, connectivity regained, after local write (debounced ~2s), pull-to-refresh, WorkManager periodic task on Android (opportunistic).

### Conflict resolution
Last-write-wins **enforced on the server**, not assumed from `upsert`:
- Every local write sets `client_updated_at` (UTC).
- A Postgres BEFORE UPDATE trigger keeps the existing row if `NEW.client_updated_at <= OLD.client_updated_at`, clamps client timestamps to `now() + 5 min`, and sets `updated_at = now()` (server clock) for pull cursors. See `backend/supabase_schema.sql`.
- Pull cursor: `(updated_at, id)` per table stored in `sync_meta`.
- Acceptable because data is single-user personal data. Two-device edit of the same row within seconds is rare; the test plan still covers it.

### Initial hydration
After first real login (not anonymous): page through each table (500/page) by cursor into Drift. If the account already has cloud data and the device has local guest data, show the choice "Keep cloud data / Replace with device data" (never silent merge) — Bible edge case, kept.

## 5. Local schema (Drift) — v1

Money columns are integer minor units. Dates: `created_at` and `client_updated_at` are UTC ISO-8601 text; `local_date` is `YYYY-MM-DD` in the device timezone at creation time (fixes the UTC streak/grouping bug).

```
expenses(id TEXT PK, user_id TEXT, name TEXT, amount_minor INTEGER, category TEXT,
         type TEXT CHECK(type IN ('expense','income')) DEFAULT 'expense',
         local_date TEXT, created_at TEXT, client_updated_at TEXT, deleted_at TEXT NULL)
check_items(id, user_id, name, price_minor INTEGER, uses REAL, cost_per_use_minor INTEGER?, verdict TEXT, regret_level INTEGER,
            local_date, created_at, client_updated_at, deleted_at)
ledger_entries(id, user_id, person TEXT, amount_minor INTEGER, currency TEXT CHECK IN ('ETB','USD'),
               type TEXT CHECK IN ('lent','borrowed'), note TEXT NULL, settled INTEGER 0/1,
               local_date, created_at, client_updated_at, deleted_at)
budgets(id, user_id UNIQUE, monthly_minor INTEGER NULL, weekly_minor INTEGER NULL, updated_at, client_updated_at)
contacts(id, user_id, name, phone NULL, note NULL, created_at, client_updated_at, deleted_at)
user_categories(id, user_id, name, kind TEXT CHECK IN ('expense','income'), created_at, client_updated_at, deleted_at)
outbox(...)           sync_meta(table_name PK, cursor_updated_at, cursor_id)
```

Notes
- `cost_per_use` and `verdict`/`regret` are derived. Store verdict/regret (web parity, history stability) and recompute for display from price/uses via domain. Whether `cost_per_use_minor` is stored at all is a TASK-020 decision; rounding must not change the verdict (DOMAIN_SPEC section 2).
- `user_id` holds the sentinel `LOCAL` until an identity exists (section 6).
- Indexes: `(user_id, local_date)`, `(user_id, category)`, `(user_id, type, created_at DESC)`, `(user_id, settled)` on ledger.
- Remote columns use `numeric(14,2)` for money; mappers convert minor units <-> numeric at the sync boundary, which keeps web compatibility whether the web used float or numeric (OPEN-002 to confirm).
- Custom categories: removing one hides it from pickers; existing entries keep the string (no orphan problem).

## 6. Identity and guest mode (ADR-004)

Facts verified in Supabase docs: anonymous users get the `authenticated` role, RLS must check `is_anonymous` to tell them apart, they can be converted by linking an email (`updateUser`, email verified by link/OTP, then a password can be set) or an OAuth identity (`linkIdentity`, manual linking must be enabled), and an anonymous user cannot recover the account after sign-out/data clear/other device. Creating one requires a network call.

Design for offline-first-launch:
1. First launch, no network: create local guest. All rows get `user_id = 'LOCAL'`. Nothing hits Supabase.
2. When online and guest mode active: attempt `signInAnonymously()` once (background, failure is silent). On success, run **adopt**: in one transaction `UPDATE <all tables> SET user_id = <anon uid> WHERE user_id = 'LOCAL'` and enqueue outbox pointers for them. Idempotent.
3. Upgrade to account: `updateUser(email)` -> verify OTP -> set password (or `linkIdentity(google)`). The uid does not change, so no row rewrite and no queue rewrite. Sync drains.
4. If the email already belongs to an account: do NOT merge silently. Show the keep-cloud vs replace choice (Bible edge case).
5. Guests who never go online remain `LOCAL` forever; that is fine and disclosed ("saved on this device only").
6. Product decision to confirm: whether to call `signInAnonymously()` at all, or keep guests purely local until they create an account. Calling it gives a stable uid but means guests are not strictly "no network contact", and it needs abuse controls (SECURITY S-09). Default in this pack: **do it, opt-out via a settings switch is NOT provided in v1**. Revisit in OPEN-008.

## 7. Auth guard and boot sequence
`main()` -> load env -> open Drift -> read prefs/secure storage -> init Supabase -> `AuthController.restore()` -> router `redirect`: no session and no guest flag -> onboarding/auth; else -> biometric gate (if enabled and >=5 min since last foreground) -> Home. `initialized` flag prevents the auth flash (FR-A6).

## 8. Theming and i18n
- `core/theme/tokens.dart` is the only place with color literals. Widgets use `Theme.of(context)` / token extensions. A grep check forbids `Color(0x` outside tokens (TASK-003).
- ARB files: no string literals in widgets. Amharic strings come from the web translation file (OPEN-004); never machine-write Amharic.
- Number formatting through `Money.format()` only.

## 9. Notifications (local)
Daily nudge (default OFF, 9pm default time user-settable), budget alert (80% and 100% once per month; default ON if budget set), ledger reminder (default OFF, weekly Monday 10am, generic text by default). Android 13+ needs the runtime notification permission; avoid exact-alarm permissions. Verify current plugin docs at implementation.

## 10. Error handling
Repositories return typed results/throw typed exceptions; UI maps them to inline messages. Sync errors only change the sync icon. Unexpected exceptions are logged without PII and shown as a generic message.

## 11. Build and config
`flutter run --dart-define-from-file=env/dev.json`. Release builds: `--obfuscate --split-debug-info=<dir>`; keep symbols out of git. Android signing via `android/key.properties` (gitignored). Cleartext traffic disabled. `allowBackup=false` (SECURITY S-05).
