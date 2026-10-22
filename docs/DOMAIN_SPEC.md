# DOMAIN_SPEC — business rules to port (Dart, `lib/domain/`)

Source: Build Bible "BUSINESS LOGIC RULES — EXACT". **The web file `lib/utils.ts` was not available when this pack was written.** Everything below is the Bible's description. Machine-readable expected outputs: `test_vectors/domain_vectors.json` (computed from these rules, not yet verified against web, OPEN-004).
Tests in `test/domain/` MUST load the JSON and assert every case. Do not hand-edit expected values to make a test pass.

## 1. Money
- Local storage: integer minor units (1 Birr = 100 santim; 1 USD = 100 cents).
- `Money.format()` -> `"Br " + grouped integer part with commas + "." + 2 decimals`. Non-finite or unparseable input -> `"Br 0.00"`. Accepts numeric strings.
- Parity trap: the web `toLocaleString('en', {minimumFractionDigits: 2})` has no max, so JS defaults max fraction digits to 3. Money has 2 decimals so this should not show, but confirm against web (vector `br` last case).
- Parsing user input: digits plus one decimal separator, max 2 decimals. Reject negatives. Conversion to minor units must not use binary-float multiplication on the raw string (parse the decimal string).

## 2. Value Check — `calcCheck(price, uses)`
Computed in Birr as doubles exactly like the web:
```
costPerUse = price / uses
verdict: costPerUse < 1 -> worth ; costPerUse <= 5 -> maybe ; else -> not
regret : <1 -> 1 ; <=3 -> 2 ; <=5 -> 3 ; <=10 -> 4 ; >10 -> 5
```
Boundaries are inclusive/exclusive exactly as written (1 -> maybe/regret 2; 3 -> regret 2; 5 -> maybe/regret 3; 10 -> regret 4).
The Bible Part 1 summary ("maybe -> regret 3", "worth -> regret 1-2") contradicts these exact rules; **the exact rules win** (Bible audit C8).
`uses <= 0`: unspecified (OPEN-006). UI must prevent it: uses must be >= 1 (or define fractional behavior with the owner).
UI result texts: "WORTH IT / MAYBE / SKIP IT"; scale reference: under Br 1/use Worth it; Br 1-5/use Maybe; over Br 5/use Skip it.

## 3. Value Score — `calcValueScore(verdicts)`
```
total = n ; worthPct = round(worth/total*100) ; maybePct = round(maybe/total*100) ; notPct = round(not/total*100)
score = round((worth*100 + maybe*50) / total)
labels: 75-100 Smart spender ; 50-74 On track ; 25-49 Needs attention ; 0-24 Review spending
```
`round` = JS `Math.round` (half up). Dart `num.round()` matches for non-negative values. Percent parts may sum to 99 or 101; that is expected web behavior. `total == 0` -> return null; Home hides the card.

## 4. Greeting and dates
- `greeting(hour)`: hour < 12 Good morning; < 18 Good afternoon; else Good evening. Clock injected (testable).
- `dayLabel(date)`: compare in **local** timezone. Today -> "Today"; Yesterday -> "Yesterday"; else English "Tuesday, Oct 20" style (weekday long, month short, day numeric). Amharic formatting comes from `intl` locale `am`; verify output with the owner (OPEN-004).
- Every stored entry gets `local_date` (device-local `YYYY-MM-DD`) at creation; History grouping, streak and week/month totals use `local_date`, never `substr(created_at)` in UTC.
- Week definition (Mon- or Sun-start) is **not specified in the Bible** -> check web behavior (OPEN-005). Month = calendar month in local date.

## 5. Streak
- A day counts if it has at least one non-deleted expense OR income entry (`local_date`).
- Walk back from today. If today has no entry, start from yesterday (day not over). If yesterday also has none -> 0.
- Display only if streak >= 3. Milestones: 7 days -> subtle glow on badge; 30 days -> insight banner acknowledges once (needs a "shown" flag in prefs). Longest streak is computed over all history (Stats screen).
- Deleting an entry can reduce/break the streak; that is accepted.

## 6. Balance and budget ring
- `monthIncome`, `monthExpense` over the current local month; `left = income - expense` (negative allowed; display rule OPEN-005).
- Balance strip shows only if at least one income entry exists in the month [Bible says "at least one income entry exists"; month vs all-time unspecified -> assume current month, confirm OPEN-005].
- Ring ceiling: manual monthly budget if set; else monthly income if income exists; else no ring percent. A "Budget | Income" toggle is shown only when both exist [Proposal, resolves a Bible contradiction between Part 12 and the later section; confirm OPEN-005].
- Budget alerts: 80% and 100% of monthly budget, once each per month.

## 7. Split
Integer minor units. `share = floor(total / n)`; the remainder minor units go one each to the first `r` people in list order so the shares sum exactly to the total [Proposal]. Whether the list includes the payer ("me") is unspecified (OPEN-016); if it does, the payer's share must not be saved as a lent entry. Saves one `lent` ledger entry per person (excluding payer), same currency as chosen.

## 8. Insights — `generateInsight()`
Bible priority (first match wins):
1. 50%+ of check verdicts are `not` -> warn about purchase quality
2. 80%+ are `worth` -> reinforce smart spending
3. one category > 50% of spend -> surface dominant category (period unspecified, OPEN-005)
4. nothing logged today -> nudge to log
5. 10+ expenses total -> "patterns are emerging"
6. default -> consistency nudge
Income rules (Bible): if monthExpense > monthIncome -> "spending exceeds income this month"; if monthExpense > 75% of monthIncome -> "You've used 75% of this month's income — mostly on [top category]"; if source is Student and spending is high -> gentler tone.
**Where the income rules sit in the priority list, how "source is Student" is detected, and the exact English/Amharic strings are NOT specified** -> OPEN-004/005. The agent must implement the engine returning a typed `Insight(kind, params)` and render text from ARB keys, with the order configurable in one place, and must not invent copy.

## 9. Categories
Expense defaults (order): Meals, Transport, Extras, Bills, Health, Other. Emoji: Meals 🍽️, Transport 🚗, Extras ✨, Bills 📋, Health 💊, Other 📦, fallback 📦.
Income (order): Salary, Freelance, Business, Investment, Bonus, Student, Other. Income emoji not specified (OPEN-004).

## 10. Person avatar color
Deterministic from the name (stable hash -> palette index). The web algorithm is unknown; any stable hash is acceptable if the palette comes from DESIGN.md. Do not use `String.hashCode` (not guaranteed stable across runs/platforms); implement a small explicit hash (e.g., FNV-1a over UTF-8 bytes).
