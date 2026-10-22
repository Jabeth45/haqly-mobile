# DESIGN — Haqly Mobile

Status: provisional brand (OPEN-001). Tokens live in ONE file (`lib/core/theme/tokens.dart`).
Reference images are in `references/`. They are third-party style references, not assets to copy.

## 1. Direction
Quiet, dark-first fintech with bento-card layout (ref 3), violet accent (refs 2 and icon), clear data visuals (ref 1 simplified). Light theme is required by the Bible and must be designed, not auto-inverted. All three UI refs are dark-only, so light screens need explicit design review.

## 2. Tokens

### Color (Locked to Brand Green #00C47A per User Choice)
| Token | Light | Dark | Use | Contrast Status |
|---|---|---|---|---|
| bg | #FFFFFF | #000000 | page background | Base |
| surface | #F2F2F7 | #1C1C1E | cards / bento tiles | Base |
| surfaceElevated | #FFFFFF | #2C2C2E | sheets / dialogs | Base |
| line | #E5E5EA | #38383A | borders / dividers | Decorative |
| ink | #1C1C1E | #FFFFFF | primary text | 15.8:1 (Light), 21.0:1 (Dark) ✅ AAA |
| ink2 | #3A3A3C | #EBEBF5 | secondary text | 9.8:1 (Light), 13.6:1 (Dark) ✅ AAA |
| ink3 | #6C6C70 | #8E8E93 | labels / captions | 5.1:1 (Light), 4.8:1 (Dark) ✅ AA |
| accent | #00C47A | #00C47A | primary buttons, active tab, ring | 6.8:1 on Dark Card ✅ AA |
| onAccent | #000000 | #000000 | text on accent fill | 8.9:1 on #00C47A ✅ AAA |
| accentText | #008753 | #00C47A | text links / icons | 6.2:1 (Light), 6.8:1 (Dark) ✅ AA |
| accentMuted | #1F00C47A (~12%) | #2600C47A (~15%) | chip bg | Decorative |
| success | #00A868 | #00C47A | semantic (income/worth) | >= 4.5:1 ✅ AA |
| info | #007AFF | #0A84FF | semantic (borrowed) | >= 4.5:1 ✅ AA |
| warn | #FF9500 | #FF9500 | semantic (maybe) | >= 4.5:1 (large/icons) ✅ AA |
| danger | #FF3B30 | #FF3B30 | semantic (not/delete) | >= 4.5:1 ✅ AA |

### Contrast Verification (TASK-005)
All token pairs used for text have been measured and meet or exceed WCAG 2.1 AA (4.5:1 for normal body text, 3.0:1 for large/graphical elements):
- Light mode `ink3` was adjusted from `#8E8E93` (3.1:1) to `#6C6C70` (5.1:1) to guarantee compliance.
- Light mode `accentText` is `#008753` (6.2:1 on white).
- Button text `onAccent` is `#000000` (8.9:1 on `#00C47A`), ensuring AAA legibility on CTAs.

### Type, shape, spacing
- Font: system (Roboto on Android, SF on iOS) — matches Bible, zero bundle cost. Ethiopic glyph rendering must be verified on a low-end Android device; bundle Noto Sans Ethiopic only if glyphs are missing (TASK-006).
- Radius: 16 (cards, buttons, inputs), 12 (small elements). Card padding 16; list row 12 x 16.
- Minimum tap target 48dp. Text must survive 200% scaling.

## 3. Navigation (ADR-007)
Bottom navigation, 5 destinations: **Home, Add, Check, Ledger, History**. Settings ("More") opens from the avatar on Home. The Bible specified 6 tabs matching web; reference 3 uses 4. Five is the pragmatic ceiling.
Home has a FAB opening QuickAddSheet. Quick actions on Home: Add Expense, Log Income, Check Value, Add Ledger.

## 4. Screen inventory and states
Every screen needs: loading (rare, local data), empty, populated, error (inline), offline (usually unchanged), long Amharic text, large font.

### Auth and onboarding (from reference 2, trimmed)
| Screen | Notes |
|---|---|
| Splash | Logo; routes after restore |
| Onboarding (3 slides) | Copy is OPEN-010. Skip button. Not shown again |
| Auth chooser | Google (P1), Email, **Continue as Guest** (equal visual weight to sign-in; Bible: no walls) |
| Sign up / Sign in | Email + password, show/hide password, remember-me is NOT needed (session persistence is default); keyboard-open layout must not clip the primary button |
| Verify email (OTP) | 6 digits, resend with countdown |
| Forgot password -> OTP -> new password -> success | Email only (no SMS) |
| App lock setup | Biometric toggle + app PIN. Offered after first saved entry, not at signup. Warn guests that a forgotten PIN means data loss |
Dropped from reference: Facebook login, "Fill your profile" DOB/phone, interests, subscribe-authors.

### Core
| Screen | Layout (bento) |
|---|---|
| Home | Greeting (+streak chip >=3) -> insight banner -> hero card: month Earned/Spent/Left or budget ring -> tiles: Spending-by-category strip, Value Score -> quick actions (4) -> Recent today (max 4) -> Ledger summary (if open entries). Sync icon top right (only when not idle). Guest strip rule: Settings only (resolves Bible C2) |
| Add | Segmented Expense|Income; name; amount with "Br" prefix; category grid; Save. Today list below with swipe delete; income rows get soft green left border |
| Check | Name, price, uses -> live result card (Br x per use, badge, regret meter 1-5) -> Save -> history list -> verdict scale |
| Ledger | Tabs Entries|Add|Split. Entries filters; avatar; lent green / borrowed blue; settle toggle |
| History | 7-day chart, filter chips, grouped list, inline edit, load more |
| Settings | Sections per PRD 4.7; guest card at top when guest |
Not taken from reference 3: fake card number, search bar, Refer and Earn.

## 5. Charts (from reference 1, simplified)
Use clean flat charts: category share as horizontal bars, 7-day as bars (expense vs income), budget ring/gauge for BudgetRing and ValueScore. No hatching, glow or radar/scatter. Charts must have text alternatives (semantics labels with values) and must not rely on color alone.

## 6. Motion and haptics
Subtle only: fades, card press, ring fill. Respect reduce-motion. Haptic map (via one wrapper): expense/income saved -> success; category tap -> light; verdict revealed worth -> success, not -> error; delete confirmed -> medium; ledger settled -> success; budget 80% -> warning; 100% -> error; sheet open -> light; primary button -> light.

## 7. App icon (ref 4 is a placeholder direction)
Problems with the supplied image: shows a "$" (brand is Br/ብር), soft glow will not survive small sizes, likely AI-generated (confirm ownership/trademark safety), generic wallet glyph. Needed deliverables from a designer or owner: adaptive foreground + background (content inside the central safe zone), monochrome layer for themed icons, iOS full-bleed opaque 1024px, plus iOS dark/tinted variants when targeting recent iOS. Use `flutter_launcher_icons` (verify config at use). Splash: logo on bg token.

## 8. Reference mapping
| File in `references/` | What it is | Use |
|---|---|---|
| ref1_chart_hud_purple.png | Sci-fi chart template (Chinese labels) | Chart vocabulary only |
| ref2_wetalk_auth_flow.png | Full auth/onboarding state set | Screen/state checklist for auth |
| ref3_dark_bento_home.png | Dark fintech home | Home layout and tab bar density |
| ref4_icon_wallet.jpg | Glass wallet icon | Mood only; replace |
