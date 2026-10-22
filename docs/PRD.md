# PRD — Haqly Mobile v1

Status: Draft for build. Owner: Yaba. Last updated: 2026-10-22.
Legend: **[Bible]** = taken from the Build Bible. **[New]** = added in this pack. **[Proposal]** = my suggestion, needs owner OK. **OPEN-xxx** = see OPEN_QUESTIONS.md.

## 1. Scope gate (the five questions)

| Question | Answer | Source |
|---|---|---|
| Problem | People record what they spent but never ask whether it was worth it; local tooling for Ethiopian users is thin. | [Bible] thesis "not just what did you spend, but was it worth it" |
| User | Ethiopian smartphone users who manage small, irregular money flows; students are called out explicitly (Student income category). | Inferred from Bible. **No user research done.** |
| Core outcome | Log a transaction in under ~10 seconds, offline, and get an honest read on whether a purchase is worth it. | [Bible] + [Proposal] on the time target |
| MVP | Expense/Income tracking, Value Check, Value Score, Ledger (+split), History, Insights, Guest mode, Streak, EN/AM, Light/Dark, biometric lock, 3 local notifications. | [Bible] + decisions in DECISIONS.md |
| Out of v1 | See section 7. | |

## 2. Users (inferred, not researched)

| Persona | Situation | Needs |
|---|---|---|
| Student | Monthly allowance/scholarship, small daily spends, borrows/lends with friends | Fast logging, "how much is left", gentle tone, ledger for small debts |
| Early-career earner | Salary/freelance income, bills, transport | Balance view, category patterns, budget alerts |
| Both | Often low or intermittent connectivity, mid/low-end Android | Offline-first, small app, low data use, Amharic |

## 3. Product principles

1. Local first: the phone database is the source of truth; the network is an optimization.
2. Quiet UI: no confetti, no sync spinners, no toasts on sync success. Sync state is one small icon.
3. No paywalls for local features. Account = backup and sync, not a gate.
4. Honest numbers: all calculations are deterministic, tested against shared vectors, and match the web app.

## 4. Functional requirements

Priority: P0 = v1 blocker, P1 = v1 if time, P2 = after v1.

### 4.1 Auth and identity
| ID | Requirement | Pri | Acceptance |
|---|---|---|---|
| FR-A1 | Email+password sign up / sign in | P0 | New user can register, verify email by OTP, sign in; wrong password shows generic error |
| FR-A2 | Google sign-in | P1 | Works on Android release build; account created/linked |
| FR-A3 | Continue as Guest on first launch, fully offline | P0 | With airplane mode on a fresh install, user reaches Home and can log data |
| FR-A4 | Guest -> account upgrade keeps all data and history | P0 | After upgrade, row count unchanged, streak unchanged, data appears on second device |
| FR-A5 | Forgot password (email OTP -> new password) | P0 | Full flow works; OTP expiry handled |
| FR-A6 | Session restore on launch with no flash of auth screen | P0 | Cold start routes straight to Home when session or guest exists |
| FR-A7 | Delete account and cloud data in-app | P0 before store release | Account and all rows removed server-side; local data wiped. Needs Edge Function (SECURITY.md) |
| FR-A8 | Sign out keeps local data only if user opts in [Proposal] | P1 | Prompt explains: keep on device or wipe |

### 4.2 Expense and income
| ID | Requirement | Pri | Acceptance |
|---|---|---|---|
| FR-E1 | Log expense: name, amount, category | P0 | Saved locally in one tap after fields valid; appears in Today list immediately |
| FR-E2 | Log income via Expense/Income toggle, 7 income categories incl. Student | P0 | Category grid swaps; entry stored with type=income |
| FR-E3 | Default expense categories: Meals, Transport, Extras, Bills, Health, Other + user custom add/remove | P0 | Custom categories persist and sync; removing a category does not delete past entries |
| FR-E4 | Last-used category pre-selected, per type | P1 | |
| FR-E5 | Swipe to delete with confirm | P0 | Soft delete (tombstone) |
| FR-E6 | QuickAdd bottom sheet from Home | P0 | Opens in <1 frame budget, Expense/Income toggle, autofocus name |
| FR-E7 | Amount input: digits and one decimal separator, max 2 decimals, "Br" prefix | P0 | Cannot enter negative, letters, or >2 decimals |

### 4.3 Value Check and Value Score
| ID | Requirement | Pri | Acceptance |
|---|---|---|---|
| FR-C1 | Live cost-per-use, verdict, regret as the user types | P0 | Matches DOMAIN_SPEC vectors exactly |
| FR-C2 | Save check to history; list with verdict badge; swipe delete | P0 | |
| FR-C3 | Value Score (0-100) + label + breakdown | P0 | Hidden when zero checks. Matches vectors |
| FR-C4 | Examples (4 presets) and verdict scale reference | P1 | Preset content is OPEN-004 (needs web copy) |

### 4.4 Ledger
| ID | Requirement | Pri | Acceptance |
|---|---|---|---|
| FR-L1 | Add entry: person, amount, currency ETB/USD, lent/borrowed, note | P0 | |
| FR-L2 | Entries list with filters All/Lent/Borrowed/Unsettled; settle toggle; swipe delete | P0 | |
| FR-L3 | Person initials avatar with deterministic color | P1 | Same name -> same color across launches |
| FR-L4 | Contacts: saved list, autocomplete in Add; use system contact picker, no READ_CONTACTS permission | P1 | |
| FR-L5 | Built-in +/- calculator for amount | P1 | |
| FR-L6 | Split: total, people list, equal share, save as multiple lent entries | P0 | Remainder santim handling defined in DOMAIN_SPEC |
| FR-L7 | Home shows open entries summary only when any exist | P0 | |

### 4.5 History and Insights
| ID | Requirement | Pri | Acceptance |
|---|---|---|---|
| FR-H1 | Timeline grouped by local date with Today/Yesterday labels | P0 | Local timezone, not UTC |
| FR-H2 | Filter chips: All, Expenses, Income, each category | P0 | |
| FR-H3 | 7-day chart (expense + income bars) | P0 | |
| FR-H4 | Pagination 20 per page | P0 | Smooth scroll with 10,000 rows (see TEST_PLAN) |
| FR-H5 | Inline edit name/amount/category | P1 | |
| FR-I1 | Rule-based insight banner | P0 | Priority order in DOMAIN_SPEC; **income rules order is OPEN-005** |

### 4.6 Home
| ID | Requirement | Pri |
|---|---|---|
| FR-HM1 | Greeting by time of day + name | P0 |
| FR-HM2 | Streak badge when >= 3 days | P0 |
| FR-HM3 | Today spend, week, month; budget ring | P0 |
| FR-HM4 | Balance strip (Earned / Spent / Left) only when income exists | P0 |
| FR-HM5 | ValueScore card, recent today (max 4), ledger summary, quick actions | P0 |
| FR-HM6 | Sync icon visible only when offline/syncing/error | P0 |

### 4.7 Settings (via avatar)
Profile, budget (monthly, optional weekly), categories, contacts, theme, language (EN/AM), privacy (biometric + PIN), notifications (3 toggles), stats, delete account, sign out. All **P0** except stats longest-streak **P1**.

### 4.8 Native features
| ID | Requirement | Pri |
|---|---|---|
| FR-N1 | Haptics at the listed interaction points (DESIGN.md) via one wrapper | P1 |
| FR-N2 | Biometric lock: opt-in, after >= 5 min in background; fallback app PIN | P0 |
| FR-N3 | 3 local notifications, all opt-in; generic text by default on lock screen | P1 |
| FR-N4 | Background sync opportunistic on Android; foreground sync is primary | P1 |

## 5. Non-functional requirements

All numeric targets are **[Proposal]** and must be validated on a real low-end Android device.

| Area | Target |
|---|---|
| Offline | Every P0 feature works in airplane mode, including first launch |
| Cold start | Home visible < 2.5 s on a mid-range Android (measure, then adjust) |
| Scroll | No dropped-frame jank on History with 10k rows in profile mode |
| Size | Release APK/AAB size tracked each phase; investigate regressions > 10% |
| Data use | Sync sends only changed rows; no images; payloads small (data is expensive) |
| Accessibility | Text scales to 200% without clipping; tap targets >= 48dp; contrast per DESIGN.md |
| i18n | EN + AM; no hard-coded UI strings; Ethiopic glyphs verified on low-end devices |
| Privacy | No ad SDKs. No analytics/crash SDK in v1 (ADR-014). No SMS or contacts-wide permissions |
| Security | SECURITY.md checklist passes before any store build |

## 6. Success metrics [Proposal, no baseline exists]
Day-7 retention, share of users logging >= 3 days/week, checks saved per active user, guest->account conversion. Because ADR-014 removes analytics from v1, measuring these needs a privacy-respecting method decided later (OPEN-009). Do not invent numbers until a baseline exists.

## 7. Out of scope for v1
SMS auto-capture; bank/Telebirr/CBE integrations; receipt OCR; multi-user shared ledgers; remote push notifications; subscriptions/paywall; cards, cashback, referral (from UI reference); Ethiopian calendar and Ethiopian-clock time display (ADR-011); CSV export (P2); unequal splits (P2); multi-currency for expenses.

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Unknown state of web Supabase schema/RLS (OPEN-002) | Data exposure or incompatible sync | Backend tasks blocked until audited; schema file is a proposal |
| Adding soft-delete to shared tables breaks web display (OPEN-003) | Deleted rows reappear on web | Web must filter `deleted_at is null` before mobile sync ships |
| Local competitor with SMS auto-capture (SpendGuard, unverified) | Users prefer zero typing | Differentiate on value check + ledger; revisit SMS in v1.5 with Play policy plan |
| Play SMS permission restrictions | Feature impossible via Play | SMS out of v1 (ADR-009) |
| Store account/payment access from Ethiopia unverified (OPEN-007) | Cannot publish | Owner to verify early |
| Domain drift from web | Different numbers on web vs mobile | Shared vectors, parity tests |

## 9. Release plan
Phases 0-6 in TASKS.md. Internal testing track first, then closed beta, then production. iOS after Android stable; Sign in with Apple decision before iOS (OPEN-014).
