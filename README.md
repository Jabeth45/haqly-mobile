# Haqly — Offline-First Personal Finance for Ethiopia

[![CI](https://github.com/haqly/haqly-mobile/actions/workflows/ci.yml/badge.svg)](https://github.com/haqly/haqly-mobile/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-emerald.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2.svg)](https://dart.dev)
[![Architecture: Clean Offline-First](https://img.shields.io/badge/Architecture-Clean%20Offline--First-00C47A.svg)](docs/ARCHITECTURE.md)

> **Haqly** (from Amharic **ሓቅ**, meaning *Truth, Reality, Fairness*) is a privacy-first, offline-first personal finance application tailored for the Ethiopian economic reality. It helps users track cash flows in Ethiopian Birr (ETB), evaluate purchase value to curb impulse spending, and manage informal lent/borrowed debts with fair-split math.

---

## Why Haqly?

Most global finance apps (Mint, YNAB, Revolut) fail in Ethiopia:
- **Cash & Telebirr/CBE Reality:** Transactions are cash-heavy, informal, and split across mobile wallets without open bank APIs.
- **Spotty Connectivity:** Requiring a stable internet connection or mandatory cloud accounts blocks everyday expense logging.
- **Informal Debt & Equb Culture:** Lending to friends, family, and group bill splits are routine, yet poorly handled by single-user expense trackers.
- **Impulse Inflation Purchases:** High local inflation triggers impulsive spending where buyers struggle to reflect on whether purchases were truly worth the money.

**Haqly changes this with a 100% local-first, zero-latency experience designed specifically for Ethiopia.**

---

## Core Feature Walkthrough

### 1. Daily Expense & Cash Flow Tracking
- **Minor-Unit Financial Engine:** Stored strictly as 64-bit integer santim/cents (never floating-point `double`) to prevent fractional rounding drift.
- **Instant Birr Formatting:** Standardized Ethiopian currency representation (`Br 1,250.00` / `Br 0.00`).
- **Flexible Categorization:** Track food, transport, bills, entertainment, groceries, and custom categories.
- **Day-Grouped History:** Real-time daily, weekly, and monthly totals computed on-device.

### 2. The "Value Check" (ሓቅ ቼክ) — Impulse Brake
- A proprietary behavioral tool to combat post-purchase regret and impulse spending.
- Prompts the user on necessity, utility, and satisfaction to produce a clear verdict (`worth_it`, `regret`, `neutral`).
- Surfaces an aggregate **Value Score** over time, revealing the percentage of spend that genuinely added quality of life.

### 3. Lent & Borrowed Ledger (Friend & Equb Splits)
- **Informal Debt Tracking:** Keep a running balance of who owes you and who you owe.
- **Zero-Remainder Split Math:** When sharing restaurant or utility bills, odd cents/santim are distributed deterministically so `sum(shares) == total` down to the exact santim.
- **One-Tap Settle Up:** Clear balances when debts are paid.

### 4. 100% Offline-First Architecture
- **Instant Local Storage:** Powered by Drift SQLite on-device. The UI never waits on network requests.
- **Guest-First:** Use all features immediately with zero registration.
- **Background Outbox Sync:** Edits write to a local transactional outbox. When online, changes synchronize silently to Supabase via cursor-based replication.

### 5. Bilingual by Design
- Complete first-class support for **Amharic (አማርኛ)** and **English**.
- Ethiopic script rendering verified on low-end and high-density mobile displays.
- High-contrast, WCAG AAA-compliant emerald palette (`#00C47A`).

---

## App Walkthrough & How to Use

```
┌────────────────────────────────────────────────────────────────────────┐
│                                 HAQLY                                  │
│                                                                        │
│   [ Dashboard ]        [ Value Check ]         [ Friends / Ledger ]    │
│   • Today: Br 420.00   • Rate recent buy       • Abebe owes: Br 150    │
│   • Month: Br 6,800    • Verdict: Worth it!    • You owe: Br 0.00      │
│                                                                        │
│   [ Quick Add (+) ]    [ History & Charts ]    [ Settings & Sync ]     │
│   • Fast 3-second log  • Category breakdown    • Amharic / English     │
│   • Cash / Telebirr    • Budget burn ring      • Export / Local backup │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Log an Expense:** Tap `+`, type the amount (e.g. `120`), tap a category (e.g., *Lunch* or *Taxi*), and tap Done. Saved in under 2 seconds.
2. **Run a Value Check:** Unsure about a purchase or just bought something? Open the Check tab, input the amount, answer the 3 quick prompts, and see your immediate verdict.
3. **Split a Bill:** In the Ledger tab, enter the total bill amount and select friends. Haqly divides the amount, allocates any remainder santim fairly, and logs the lent amounts to each contact.
4. **Monitor Budget Health:** The dynamic budget ring shows your monthly burn rate and alerts you at 80% and 100% spending thresholds before overruns occur.

---

## Architecture & Engineering Standards

Haqly is built with clean, unidirectional layered architecture:

```
┌──────────────────────────────────────────────────────────────┐
│  Presentation Layer (lib/features/, Riverpod, GoRouter)     │
│  • Reactive state notifiers, 60fps UI, zero direct DB access │
└──────────────────────────────┬───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│  Repository Layer (lib/data/repositories/)                   │
│  • Atomic local DB writes + outbox queue in single txn       │
└──────────────────────────────┬───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│  Data Layer (lib/data/db/, Drift SQLite, lib/data/sync/)     │
│  • 8 normalized tables, 10 query indexes, cursor sync engine │
└──────────────────────────────┬───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│  Domain Layer (lib/domain/ — Pure Dart, Zero Dependencies)   │
│  • Money minor-unit math, split logic, streak, insight engine│
│  • 100% vector-tested against specification fixtures         │
└──────────────────────────────────────────────────────────────┘
```

### Engineering Guardrails
- **Zero Floating-Point Money:** Handled exclusively via `Money` minor-unit integers.
- **Layer Integrity Script:** Enforced via `tool/check_layers.dart` in CI to forbid cross-layer leakage.
- **Strict Dart Analysis:** `strict-casts`, `strict-inference`, and `strict-raw-types` enabled.
- **Zero Secrets in Code:** Build-time variables injected via `--dart-define-from-file`.

---

## Development & Local Setup

### Prerequisites
- **Flutter SDK:** `>= 3.24.0` (Stable channel)
- **Dart SDK:** `>= 3.5.0`
- Android Studio / Xcode for emulators or physical devices.

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/haqly/haqly-mobile.git
cd haqly-mobile

# 2. Install dependencies
flutter pub get

# 3. Generate Drift SQLite code & localizations
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n

# 4. Run automated tests (100% green)
flutter test

# 5. Run architectural layer check
dart run tool/check_layers.dart

# 6. Run on device or emulator
flutter run
```

---

## Current Status & Roadmap

| Milestone | Scope | Status |
|---|---|:---:|
| **Phase 0: Setup** | Scaffolding, strict linter, CI pipeline, design tokens, l10n scaffold | **Completed** |
| **Phase 1: Pure Domain** | Money minor-unit type, Value Check algorithm, split math, streaks, insights | **Completed** |
| **Phase 2: Local Data Layer** | Drift SQLite v1 schema, ExpenseRepository, CheckRepository, atomic outbox | **In Progress** |
| **Phase 3: Identity & Shell** | Navigation shell, guest session restore, Supabase auth integration | **Next** |
| **Phase 4: Core UI Screens** | Home dashboard, QuickAdd sheet, History filters, Ledger views, Settings | **Upcoming** |
| **Phase 5: Native Hardening** | Biometric app lock, Android WorkManager opportunistic sync, haptic engine | **Upcoming** |
| **Phase 6: Store Release** | Production build, privacy policy, performance profiling, Play Store / App Store | **Upcoming** |

---

## Project Documentation

Detailed architecture specifications, domain formulas, and design systems are maintained in `docs/`:

- [PRD.md](docs/PRD.md) — Product Requirements & User Personas
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — Data flow, schema design, and sync protocols
- [DOMAIN_SPEC.md](docs/DOMAIN_SPEC.md) — Exact financial and behavioral formulas
- [DESIGN.md](docs/DESIGN.md) — Design tokens, color system, and screen specifications
- [RULES.md](docs/RULES.md) — Architectural rules and prohibited patterns
- [SECURITY.md](docs/SECURITY.md) — Threat model and client-side encryption

---

## Contributing & Git Etiquette

We maintain high engineering standards for every commit:
1. Every write operation must go through a repository.
2. Code changes must pass `flutter analyze` with **zero warnings**.
3. All domain math must be accompanied by automated vector tests.
4. Run `dart run tool/check_layers.dart` before opening a pull request.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
