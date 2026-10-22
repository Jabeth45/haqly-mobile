# Haqly Mobile — Documentation Pack

Flutter/Dart (Android first, iOS after) rebuild of Haqly, an Ethiopian personal-finance app (ETB).
Built to be handed to an AI coding tool (Google Antigravity) using a spec-driven workflow.

> Status: **planning complete, zero code written.** Read `docs/OPEN_QUESTIONS.md` before starting — some items block specific tasks.

## What is in this pack

| Path | Purpose | Read when |
|---|---|---|
| `AGENTS.md` | Short rules file the coding agent loads each session | Always (place at repo root) |
| `docs/PRD.md` | What we build and why, scope, requirements, acceptance criteria | Before any task |
| `docs/ARCHITECTURE.md` | Stack, layers, folder tree, data flow, sync design, schema | Before any task |
| `docs/DOMAIN_SPEC.md` | Exact business rules to port from the web app + test vectors | Before TASK-010 |
| `docs/DESIGN.md` | Tokens, screens, states, navigation, reference-image mapping | Before any UI task |
| `docs/RULES.md` | Hard coding rules and do-not-touch zones | Always |
| `docs/SECURITY.md` | Threat model, RLS requirements, mobile checklist | Before auth/sync/storage tasks |
| `docs/TEST_PLAN.md` | What "working" means, per phase gates | Before marking a task done |
| `docs/TASKS.md` | Numbered, small vertical-slice tasks | Every session |
| `docs/DECISIONS.md` | Permanent ADRs (why we chose X) | When tempted to change a choice |
| `docs/MEMORY.md` | Current state: done / in progress / known issues | Every session start and end |
| `docs/BIBLE_AUDIT.md` | What changed from the original Build Bible and why | When something differs from the Bible |
| `docs/OPEN_QUESTIONS.md` | Unanswered questions and what they block | Before planning a sprint |
| `docs/PROMPTS.md` | Copy-paste prompts for the agent (read-first, task, review, debug) | When driving the agent |
| `docs/backend/supabase_schema.sql` | PROPOSED target Supabase schema + RLS (not yet diffed against the live web project) | Before any backend task |
| `docs/test_vectors/domain_vectors.json` | Machine-readable expected outputs for the domain port | TASK-010 |
| `docs/references/` | The 4 UI reference images + how each maps to Haqly | Before UI tasks |
| `docs/source/` | Original Build Bible and App Flow (React Native era). **Superseded where `DECISIONS.md` says so.** | Background only |
| `env/dev.example.json` | Shape of build-time config. Never commit real values. | Setup |

## How to drive the agent (the loop)

READ docs -> PLAN one task -> IMPLEMENT -> TEST (gates in TEST_PLAN) -> REVIEW (report issues first, fix after) -> COMMIT -> UPDATE `MEMORY.md`/`TASKS.md`.
Never prompt "build the app". One vertical slice per prompt. See `docs/PROMPTS.md`.

## Honest limits of this pack

- Written without access to the web app's source (`lib/utils.ts`, translations, SQL schema). Anything depending on them is marked `OPEN-xxx`.
- The brand accent (violet) is **provisional** (OPEN-001). Tokens are centralized so a change is one file.
- Package versions are intentionally **not pinned**: the agent must run `flutter pub add`, record resolved versions in `docs/MEMORY.md`, and check each package's current docs.
- Antigravity rules-file behavior was taken from third-party guides, not Google's own docs. `AGENTS.md` at the repo root is documented by those guides as read by Antigravity; the `.agent/` vs `.agents/` folder name was inconsistent between sources, so this pack does not depend on that folder.
- No user research was done. Personas in the PRD are inferred from the Build Bible.
