# TEST_PLAN — what "working" means

Rule: "it compiled" is not "it works". A task is done only when its acceptance criteria in TASKS.md and the gates below pass.

## 1. Gates (every task)
`dart format --set-exit-if-changed .` -> `flutter analyze` (0 issues) -> `flutter test` -> `tool/check_layers.sh` -> secret scan -> build (`flutter build apk --debug` at minimum). Phase exits add integration and manual checks below.

## 2. Test layers
| Layer | What | Tooling |
|---|---|---|
| Domain parity | Every case in `test_vectors/domain_vectors.json` | `flutter test`, loads JSON |
| Domain property | Split shares always sum to total; streak never negative; score within 0-100 | simple randomized loops |
| Repository | CRUD, soft delete, filters, totals, transactionality (row + outbox atomic) | in-memory Drift |
| Sync | Drain order, coalescing, retry, offline, partial failure, pull cursors, tombstones, adopt (LOCAL -> uid) idempotent | FakeRemote with injectable failures and clock |
| Widget | Forms validate, live verdict, empty/long-text/large-font states, EN and AM | `flutter_test` |
| Integration | Core flows on device/emulator | `integration_test` |
| Backend/RLS | Matrix in SECURITY.md section 5 | SQL on throwaway project |
| Manual | Scenarios below | Real low-end Android |

## 3. Manual scenarios (run at each phase exit that touches them)
| # | Scenario | Expected |
|---|---|---|
| M1 | Fresh install, airplane mode, Continue as Guest, log expense/income/check/ledger | All work; no network errors shown |
| M2 | Airplane mode: add 5 entries, reconnect | Sync icon pulses then disappears; rows in cloud; count matches |
| M3 | Guest with data goes online, signs in anonymously (adopt), upgrades with email | Row count, streak, history identical; data visible on second device |
| M4 | Upgrade with an email that already has an account | User gets keep-cloud vs replace choice; no silent merge |
| M5 | Edit same row on two devices offline, reconnect both | Newer `client_updated_at` wins everywhere; no duplicates |
| M6 | Delete on device A, sync, open device B | Row disappears on B (tombstone) |
| M7 | Device clock set +1 day then back | Server clamps; no future-dated dominance; streak sane |
| M8 | Log at 00:30 and 23:30 local time | Each lands on correct local date; streak correct (UTC bug regression) |
| M9 | Change device timezone | Existing entries keep their `local_date`; labels stay consistent |
| M10 | Language AM, font scale 200% | No clipped buttons; Ethiopic glyphs render (check low-end device) |
| M11 | Kill app mid-sync | No duplicates after restart; outbox resumes |
| M12 | Biometric on: background >5 min, return | Lock shown; 3 failures -> PIN; PIN wrong repeatedly -> backoff |
| M13 | Notifications: deny permission | Features degrade gracefully; settings explain |
| M14 | Sign out / delete account | Local wipe behavior as chosen; deleted account cannot sign in; cloud rows gone |
| M15 | Token expiry / revoked session | Returns to auth without data loss |
| M16 | 10,000 history rows | Profile mode scroll without jank; memory stable |
| M17 | Low storage / DB write failure | Clear inline error; no crash |

## 4. Security tests
SECURITY.md section 5 (RLS matrix) and section 6 (pre-release gate). Also inspect the release APK/AAB manifest (permissions, backup flags, debuggable) and run a dependency check.

## 5. Phase exit criteria
| Phase | Exit |
|---|---|
| 0 Setup | App builds; CI green; layer/token/string checks active |
| 1 Domain | All vectors pass; coverage on domain >= agreed target (set after first run) |
| 2 Data | M2, M5, M6, M11 pass against FakeRemote; migration tests pass |
| 3 Identity | M1, M3, M4, M15 pass; RLS matrix passed (needs backend) |
| 4 Screens | All P0 screens work offline; M8, M10, M16 pass |
| 5 Native | M12, M13 pass; hardening items closed |
| 6 Release | M1-M17 pass on a real low-end device; SECURITY pre-release gate closed |
