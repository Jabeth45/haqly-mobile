# OPEN_QUESTIONS — unanswered, and what they block

Owner answers go here; then update PRD/DECISIONS and remove or mark resolved. The agent must STOP and ask when a task depends on an open item.

| ID | Question | Blocks | My default until answered |
|---|---|---|---|
| OPEN-001 | Brand accent: keep green (#00C47A, web parity) or go violet (#9710FF)? | Nothing structural (tokens only) | Violet (ADR-010, provisional) |
| OPEN-002 | What is the live web Supabase schema and RLS state? Are RLS policies enabled on every table? Money column type? ID type? | All backend tasks (TASK-032+), BK-001/002 | `backend/supabase_schema.sql` is only a proposal |
| OPEN-003 | Will the web app be updated to filter `deleted_at is null` (soft delete) before mobile sync launches? | Cloud sync release | Not assumed |
| OPEN-004 | Provide web `lib/utils.ts`, translation files (en.ts, am.ts), globals.css/tailwind tokens, examples copy, income category emoji | Exact insight copy, all Amharic text, preset examples, final vector verification | Placeholders clearly marked; never invent Amharic |
| OPEN-005 | Insight order with income rules; how "source is Student" is detected; dominant-category period; week start day; negative "left" display; balance strip month vs all-time; where 30-day streak acknowledgement sits | TASK-016, 017 | Order in DOMAIN_SPEC section 8 with income rules flagged off |
| OPEN-006 | Behavior when uses <= 0 or there are no checks | TASK-011/012 UI | UI prevents uses < 1; score card hidden |
| OPEN-007 | Can you create and pay for Google Play (and later Apple) developer accounts from Ethiopia? (I did not verify) | Release (TASK-076/077) | Unknown; check early |
| OPEN-008 | Guest + anonymous sign-in: confirm guests may contact Supabase anonymously after going online, or keep guests purely local until they sign up | TASK-035 | Anonymous sign-in on (ADR-004) |
| OPEN-009 | Analytics/crash reporting and how to measure retention privately | Metrics | None in v1 (ADR-014) |
| OPEN-010 | Onboarding slide copy (EN/AM), app tagline, store listing text | TASK-030, 075 | Placeholder |
| OPEN-011 | Data-protection law review for storing Ethiopian users' financial data; privacy policy and terms author (I did not research Ethiopian law) | TASK-075 | Get it checked |
| OPEN-012 | PIN recovery for guests (none possible without cloud) — accept data loss warning? | TASK-062 | Warn and accept |
| OPEN-013 | Minimum Android/iOS versions and application id | TASK-000 | Flutter defaults; decide with device targets |
| OPEN-014 | Sign in with Apple requirement for iOS when offering Google (verify current App Store rule) | TASK-077 | Add Apple or drop Google on iOS |
| OPEN-015 | Offline USD handling in ledger: any exchange-rate feature? (Bible says only ETB/USD labels) | none now | No conversion |
| OPEN-016 | Split: does the people list include the payer ("me")? | TASK-047 | Payer excluded from saved entries if flagged |
| OPEN-017 | Icon: provide final brand mark (Br/ብር), adaptive layers, ownership confirmation of the generated reference | TASK-070 | Placeholder |
| OPEN-018 | Sign-out behavior: keep local data or wipe? | FR-A8 | Ask user at sign-out |
