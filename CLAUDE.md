# User-level Claude Code config

Synced from `rrichardtang/claude-config` — see that repo's `README.md` for how the sync works.
This file loads in every session, on every project, before that project's own `CLAUDE.md`.

## caveman

The `caveman` skill (ultra-compressed output, ~65% token cut) is installed and available via
`/caveman` or by saying "caveman mode" / "less tokens" / etc. **It is off by default in
interactive sessions** — nothing here turns it on automatically. `bob-the-builder` and
`felix-the-fixer` (below) each turn it on for themselves as their first action, since they're
the token/latency-sensitive part of this setup; the main session stays normal prose unless you
ask for it directly.

## Coding ↔ Review Loop (opt-in)

`bob-the-builder` (implements) and `felix-the-fixer` (reviews) can work a plan back and forth
instead of you driving every change by hand. **This is opt-in** — only run it when explicitly
asked to, after a plan has been approved. Most tasks are still handled directly.

When running it:
- **Cap at 3 rounds** of `bob-the-builder` → `felix-the-fixer`. This is a hard cutoff, not a
  suggestion — an unbounded review loop is worse than a bounded one that sometimes needs a human.
- **Round 1:** `bob-the-builder` implements against the approved plan; `felix-the-fixer` reviews
  the diff.
- **Round 2+:** carry forward *every* prior round's findings into `bob-the-builder`'s next
  prompt — subagents are stateless per spawn, they don't remember earlier rounds on their own.
  `bob-the-builder` states up front whether the previous fix addressed the review's root cause
  or only patched the flagged lines before making new edits. Recurring or reshaped findings
  across rounds are the signal to fix the underlying cause, not keep patching symptoms — and
  `felix-the-fixer` is instructed to call this out explicitly as "not converging" when it sees it.
- **After round 3**, if `felix-the-fixer` still finds issues: stop. Do not start a 4th round
  automatically. Summarize what's still wrong and ask how to proceed.

`bob-the-builder` also runs a `thermo-nuclear-code-quality-review` self-check on its own diff
before stopping (its own instructions, "Finishing") — a structural pass (file size, spaghetti
conditionals, thin wrappers), not a substitute for `felix-the-fixer`'s independent correctness and
simplification review.

**Notes boundary:** if the repo you're in has a living-notes convention (a `PROJECT_NOTES/`
directory or equivalent), only the orchestrating (main) agent reads and writes it. Extract just
the task-relevant slice — the specific bug, decision, or preference that matters for this task —
into what you send `bob-the-builder`/`felix-the-fixer`; don't have them read the file directly.
After they report a completed round, you decide what (if anything) graduates into that repo's
notes. `bob-the-builder` and `felix-the-fixer` each keep their own smaller, role-scoped log
instead — `.claude/agent-notes/bob.md` and `.claude/agent-notes/felix.md` in whatever repo
they're working in — for things future rounds of *that specific role* should know, separate from
the project's higher-level notes.

## Planning skills (opt-in)

`wayfinder` and `grill-with-docs` are front doors for planning code changes in the main session —
**explicit-invoke only** (`disable-model-invocation: true`), so neither fires on its own; call
`Skill(wayfinder)` or `Skill(grill-with-docs)` by name. `grill-with-docs` sharpens a plan within
one session (interview via `grilling`, glossary/ADR capture via `domain-modeling`). `wayfinder`
is for work too large for one session: it charts a shared map of decision tickets on the repo's
issue tracker (falling back to local markdown) and works them one at a time — see
`skills/wayfinder/SKILL.md` for the full protocol before invoking it, its own body is denser than
this summary should try to restate.

Their building blocks are separate, standalone skills, each still available on its own:
- `grilling` — the interview primitive; auto-triggers on "grill" phrasing, not gated like the two
  above.
- `domain-modeling` — builds/sharpens a project's `CONTEXT.md` glossary and ADRs; can auto-trigger
  when terminology is being discussed.
- `research` — delegates a documentation/API question to a background agent; can auto-trigger.
- `prototype` — throwaway code to answer a design question (state-model logic or UI shape); can
  auto-trigger.

Unlike `wayfinder`/`grill-with-docs`, these four are not `disable-model-invocation`-gated — that's
upstream's design (they're useful standalone, e.g. "grill me about this" without going through
wayfinder), not something layered on here.
