# claude-config

Personal Claude Code global config, synced into `~/.claude/` at the start of every session in
any project wired up to pull from this repo.

## What's in here

- `skills/caveman/SKILL.md` — the [`caveman`](https://github.com/JuliusBrussee/caveman) skill,
  vendored verbatim (MIT-licensed). Ultra-compressed output mode, off by default, turned on with
  `/caveman` or a phrase like "caveman mode".
- `skills/thermo-nuclear-code-quality-review/SKILL.md` — vendored verbatim (MIT-licensed) from
  [`cursor/plugins`](https://github.com/cursor/plugins). An unusually strict maintainability
  review (abstraction quality, file size, spaghetti growth). Intentionally left model-invocable —
  `bob-the-builder` calls it on its own diff before stopping (see `agents/bob-the-builder.md`,
  "Finishing"), and `disable-model-invocation` would block exactly that call.
- `skills/{wayfinder,grill-with-docs,grilling,domain-modeling,research,prototype}/` — vendored
  verbatim (MIT-licensed) from [`mattpocock/skills`](https://github.com/mattpocock/skills).
  Planning skills for the main session — see `CLAUDE.md`'s "Planning skills" section for which are
  explicit-invoke-only front doors (`wayfinder`, `grill-with-docs`) versus standalone building
  blocks that can auto-trigger on their own (the other four).
- `skills/ponytail/SKILL.md` — the [`ponytail`](https://github.com/nikvdp/ponytail) skill. Forces the
  simplest solution that works (YAGNI, stdlib before custom code, shortest working diff). Listed
  in the prompt so it can auto-trigger on "yagni", "be lazy", "over-engineered" and the like.
- `agents/bob-the-builder.md` — a generic coding subagent. Implements against an approved plan,
  runs tests, runs a `thermo-nuclear-code-quality-review` self-check, does not otherwise review
  its own work or push.
- `agents/felix-the-fixer.md` — a generic code-review subagent. Reviews a diff for correctness
  bugs and behavior-preserving simplifications; never edits.
- `CLAUDE.md` — synced to `~/.claude/CLAUDE.md`. Documents the opt-in
  `bob-the-builder` ↔ `felix-the-fixer` loop protocol (3-round cap, root-cause-vs-patch check,
  notes-ownership boundary), the planning skills, and that caveman is available but off by
  default for the main session.
- `hooks/session-start.sh` — the bootstrap: clone-or-update this repo's cache, then run
  `install.sh`. `install.sh` copies it to `~/.claude/session-start.sh` and registers it as a
  user-level `SessionStart` hook, which is what makes the sync self-refreshing. Also committed
  here so a project can vendor it as its own project hook (see "How the sync works").
- `install.sh` — does the actual sync. Safe to re-run: `skills/` and `agents/` are copied
  wholesale (this repo owns that namespace outright — every directory under `skills/` syncs, not
  just caveman), `~/.claude/CLAUDE.md` is merged via a marked block so any unrelated content
  already there survives, and `~/.claude/settings.json` has only this repo's own `SessionStart`
  entry replaced, leaving other hooks and settings alone.

## Design skills live on the claude.ai account, not here

The frontend design/image-direction skills (`design-taste-frontend`, `imagegen-frontend-web`,
`brandkit`, and friends) are deliberately **not** in this repo. They are uploaded as claude.ai
account skills instead, because this repo's sync target (`~/.claude/skills/`) is not read by a
cloud session's `/` menu, and those skills carry `disable-model-invocation: true` — which blocks
the `Skill` tool as well as auto-triggering, leaving the `/` menu as their only entry point. An
account skill reaches every repo, both local and cloud sessions, and shows up in that menu.

The same reasoning applies to anything else gated this way: gate it, and it has to live somewhere
the `/` menu can see.

## Installing on a new machine or repository

`INSTALL.md` is written for a Claude Code session to execute. Point one at it:

> Read https://raw.githubusercontent.com/rrichardtang/claude-config/main/INSTALL.md and follow it.

It covers the machine-level install (once per machine, after which the hook keeps itself current),
the repository-level bootstrap needed only for projects opened from Claude Code on the web, and the
optional push gate.

## How the sync works

`install.sh` registers itself. It copies `hooks/session-start.sh` to `~/.claude/session-start.sh`
and adds a user-level `SessionStart` hook pointing at it, so from then on **every session in every
project** re-clones-or-pulls this repo and re-runs the sync before the agent starts working.
Install once, anywhere, and the config follows you — including into projects that know nothing
about this repo.

The one thing that hook cannot do is bootstrap itself where `~/.claude/` does not survive between
sessions — Claude Code on the web, where each session gets a fresh container. There the
user-level hook is gone by the time it would run, so something inside the repo has to do the first
sync. A project that gets used from the web therefore also carries its own copy of the bootstrap
as a project hook (`.claude/hooks/session-start.sh` + a `SessionStart` entry in that project's
`.claude/settings.json`); `rrichardtang/guideme` is the working example. Both hooks firing in the
same session is harmless — `install.sh` is idempotent and `flock`-serialized, so the second run is
one shallow fetch.

## Adding this to a new project

Nothing to do for local sessions — the user-level hook already covers every project on the
machine. Only if the project will be used from Claude Code on the web does it need its own
bootstrap: copy `hooks/session-start.sh` into the project's `.claude/hooks/` and add a
`SessionStart` hook running it in that project's `.claude/settings.json`, mirroring
`rrichardtang/guideme`.

## Editing

Change the source files here and push — every session in every wired-up project picks up the
change the next time it starts (nothing to manually re-sync). `bob-the-builder` and
`felix-the-fixer` are meant to be repo-agnostic: they never assume a `PROJECT_NOTES/`-style
convention exists, and if a project has one, they work from context handed to them rather than
reading it directly (see the loop protocol in `CLAUDE.md`).
