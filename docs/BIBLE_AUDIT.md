# BIBLE_AUDIT — what changed from the original Build Bible and why

Original: `source/Haqly_Build_Bible.txt` (React Native/Expo). Product meaning kept; implementation and several contradictions resolved.

## Contradictions inside the Bible
| ID | Contradiction | Resolution |
|---|---|---|
| C1 | Two "PART 11" and two "PART 12" sections with conflicting duplicates | Single canonical version in PRD/DOMAIN_SPEC |
| C2 | Guest banner location: Home+More (not dismissable) vs More only | Settings only (ADR-016) |
| C3 | Guest id `guest_[timestamp]_[random]` vs UUID vs Supabase anonymous | ADR-004 |
| C4 | Migration "5 tables" but 6 data tables; queue rewritten with string `replace()` | Outbox stores pointers; uid adoption is one transaction |
| C5 | `user_categories` used but not in schema; categories in both prefs and DB | Single DB table |
| C6 | Supabase `type` column constrained in one place, bare default in another | Constrained version |
| C7 | Two different sync status vocabularies; per-row and queue status duplicated | One state machine; outbox only |
| C8 | Part 1 summary of regret/verdict thresholds contradicts the exact `calcCheck` | Exact rules win |
| C9 | `delete` "mark deleted" with no column | `deleted_at` tombstones |
| C10 | `registerDeviceToken` implies remote push; notifications are local | Removed |
| C11 | Ring ceiling: toggle Budget/Income vs manual-priority rule | ADR-017 |
| C12 | Tab count: 6 (Bible) vs 4 (reference) | 5 (ADR-007) |

## Security/architecture findings
See SECURITY.md S-01..S-11 plus: money as float (ADR-005), UTC date grouping bug for UTC+3 users (`local_date`), upsert not enforcing "newer wins" (trigger), shared-table soft delete impact on web (OPEN-003), Play SMS policy (ADR-009).

## Items the Bible assumed that I could not verify
Web `utils.ts` contents, translation files, web DB schema/RLS, Android-dominance assumption, store account feasibility, Ethiopian data-protection obligations.
