# SECURITY — Haqly Mobile

Author's note: this is my own security review (no dedicated security skill was available). It is a design-time checklist, not a penetration test. Before store release, have the code and the Supabase policies reviewed against it and test with two real accounts.

## 1. Assets and actors
Assets: financial entries, ledger (names of people owed money), contacts, account credentials/session, local DB, PIN/biometric state.
Actors: honest user, attacker with a lost/stolen unlocked phone, attacker with root/backup access, malicious app on device, network attacker, another authenticated Supabase user (RLS bypass attempts), abuser creating mass anonymous accounts.

## 2. Findings carried over from the Bible audit and how this design addresses them
| ID | Sev | Issue | Requirement |
|---|---|---|---|
| S-01 | High | Session stored in plain preferences | Persist Supabase session in `flutter_secure_storage` via custom local storage adapter. Verify the supported hook in the current `supabase_flutter` docs |
| S-02 | High | Anon key ships in the app, security is RLS only | RLS enabled and forced on every table; policies for select/insert/update `user_id = auth.uid()` with `WITH CHECK`; no delete policy (soft delete). Tested with a second account (TEST_PLAN) |
| S-03 | High | "Newer timestamp wins" not enforced by plain upsert; client clocks untrusted | Server trigger (schema file): ignore older, clamp future, server `updated_at` |
| S-04 | High | No password reset / verification | FR-A5, FR-A1 |
| S-05 | Med | Local DB readable via backup/root | `android:allowBackup="false"` and exclude DB from device transfer; consider SQLCipher with key in secure storage (ADR-015); iOS: exclude DB file from backup (verify) |
| S-06 | Med | Biometric is only a UI gate; fallback was password (guests/Google users have none) | App PIN fallback, PIN stored as salted slow hash in secure storage, attempt counter with backoff. Guests: warn that forgetting PIN = data loss |
| S-07 | Med | Lock-screen notification leaks ledger names/amounts | Generic notification text by default; detail text is an opt-in setting |
| S-08 | Med | No account/data deletion | FR-A7 via Edge Function using service role (never in the app). Server deletes auth user (cascade) |
| S-09 | Med | Anonymous sign-in abuse | Enable only with captcha/rate limits as the Supabase project supports; RLS may check `auth.jwt() ->> 'is_anonymous'` to cap row counts for anonymous users; schedule cleanup of inactive anonymous users |
| S-10 | Low | Contacts permission policy | Use the system contact picker, no `READ_CONTACTS`. (Play has announced a Contacts permissions policy effective 2027-01-27.) |
| S-11 | Low | Sign in with Apple required with Google login on iOS? | Verify current App Store rule before iOS release (OPEN-014) |

## 3. Mobile checklist (aligned to OWASP MASVS v2 categories)
| Category | Must |
|---|---|
| STORAGE | Secrets only in secure storage; no PII in logs; no secrets in prefs; screenshots in app switcher blurred when locked; consider `FLAG_SECURE` for Settings/PIN screens |
| CRYPTO | No custom crypto. PIN hashing via a vetted KDF package (choose in TASK-052 and record) |
| AUTH | Server-side authorization only (RLS). Generic auth errors (no user enumeration where Supabase allows). OTP expiry handled. Re-auth before delete account |
| NETWORK | HTTPS only; cleartext disabled in manifest; no certificate pinning in v1 (rationale: maintenance risk with Supabase cert rotation; revisit with a pinning ADR) |
| PLATFORM | No exported components beyond the launcher activity; deep links minimal and validated; `allowBackup=false`; permission list reviewed (no SMS, no READ_CONTACTS, notifications runtime permission only) |
| CODE | `flutter analyze` clean; dependency audit (`flutter pub outdated`, check advisories) each phase; release builds obfuscated; no debug flags/logging in release |
| RESILIENCE | Root/tamper detection explicitly out of v1 (low value vs cost); document the decision |
| PRIVACY | Privacy policy URL before release; data safety/privacy declarations accurate; no ad/analytics SDKs (ADR-014); delete-account works; data minimization: name + email only |

## 4. Secrets
- Only `SUPABASE_URL` and the anon key in `env/*.json` (gitignored). The anon key is public by design; do not treat it as a secret, and do not rely on it for security.
- NEVER commit or embed the `service_role` key, DB password, JWT secret, keystore, or `key.properties`.
- Add secret scanning to CI (TASK-004). Rotate immediately if anything leaks.

## 5. RLS test matrix (run against a throwaway Supabase project or branch)
For each table (expenses, check_items, ledger_entries, budgets, contacts, user_categories) with users A and B:
1. A inserts a row. A can select it.
2. B cannot select A's row (0 rows).
3. B cannot update A's row (0 rows affected).
4. B cannot insert a row with `user_id = A`.
5. A cannot change `user_id` of own row to B.
6. Anonymous user C behaves like an authenticated user for own rows only, never others'.
7. A client cannot hard-delete (no delete policy).
8. Timestamp trigger: older `client_updated_at` write is ignored; far-future value clamped.
9. Unauthenticated (anon key, no session) gets zero rows and cannot insert.

## 6. Pre-release gate
All S-xx items closed or consciously deferred in DECISIONS.md; RLS matrix passed; privacy policy live; delete-account tested end to end; release build inspected (manifest permissions, debuggable=false, backup flags).
