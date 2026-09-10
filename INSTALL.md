# Installing this harness

Instructions for a Claude Code session. Read this file, then carry out the steps below in the
repository the session is running in. Everything here is idempotent — re-running any step is safe.

Hand this to a session with:

> Read https://raw.githubusercontent.com/rrichardtang/claude-config/main/INSTALL.md and follow it.

## What gets installed

| Component | Lands in | Scope |
|---|---|---|
| `bob-the-builder`, `felix-the-fixer` subagents | `~/.claude/agents/` | Every project on the machine |
| Orchestration protocol (the bob↔felix loop, planning skills, caveman) | a managed block in `~/.claude/CLAUDE.md` | Every project, loaded before the project's own `CLAUDE.md` |
| Skills (`ponytail`, `caveman`, `wayfinder`, …) | `~/.claude/skills/` | Every project on the machine |
| Self-refresh hook | `~/.claude/settings.json` | Re-runs the sync at every session start |

Nothing is copied into the repository. Skills and agents that live in a repo freeze at the commit
that added them and drift from this repo, which is the failure mode this layout exists to avoid.

## Step 1 — Machine-level install

Required once per machine. After this the hook keeps itself current; you never run it by hand again.

```bash
curl -fsSL https://raw.githubusercontent.com/rrichardtang/claude-config/main/hooks/session-start.sh \
  -o /tmp/claude-config-bootstrap.sh
bash /tmp/claude-config-bootstrap.sh
```

Expect two lines:

```
claude-config: self-refresh hook registered in <home>/.claude/settings.json
claude-config: synced N skills, bob-the-builder, felix-the-fixer, and CLAUDE.md into <home>/.claude
```

If the first line instead reads `jq not found, skipping self-refresh hook registration`, everything
else still applied. Install `jq` (`brew install jq` / `apt install jq`) and re-run to get the hook.

**Verify before continuing.** If any of these fail, stop and report — do not proceed to step 2:

```bash
ls ~/.claude/agents/                                  # bob-the-builder.md, felix-the-fixer.md
grep -c 'claude-config:start' ~/.claude/CLAUDE.md     # 1
jq '.hooks.SessionStart' ~/.claude/settings.json      # an entry running session-start.sh
```

## Step 2 — Repository-level install

**Only needed if this repository will be opened from Claude Code on the web.** Skip it for a
local-only project; step 1 already covers those, in every repo on the machine.

A cloud session gets a fresh container whose `~/.claude/` starts empty, so the user-level hook from
step 1 does not exist yet when it would need to run. Something committed to the repository has to
perform the first sync.

```bash
mkdir -p .claude/hooks
curl -fsSL https://raw.githubusercontent.com/rrichardtang/claude-config/main/hooks/session-start.sh \
  -o .claude/hooks/session-start.sh
chmod +x .claude/hooks/session-start.sh
```

Then register it in `.claude/settings.json`. If that file does not exist, create it with exactly
this content:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh\""
          }
        ]
      }
    ]
  }
}
```

If it already exists, **merge** — add the `SessionStart` entry alongside whatever is there. Do not
overwrite the file; it may carry other hooks, permissions, or settings.

If the repository's `.gitignore` ignores `.claude/`, add exceptions, or the two files above will
not commit and web sessions will silently get nothing:

```
.claude/*
!.claude/settings.json
!.claude/hooks/
```

Verify both files are actually tracked before committing:

```bash
git check-ignore -v .claude/settings.json .claude/hooks/session-start.sh   # no output = good
```

Commit both files.

## Step 3 — Push gate (optional)

The orchestration protocol *describes* the bob↔felix loop but nothing enforces it. To make a
`felix-the-fixer` review mandatory before every `git push`, copy two scripts from
`rrichardtang/GuideMe` — `scripts/prePushReview.js` and `scripts/checkPractices.js` — and add their
hook entries to `.claude/settings.json`:

```json
"PreToolUse": [
  { "matcher": "Bash", "hooks": [{ "type": "command", "command": "node scripts/prePushReview.js" }] }
],
"PostToolUse": [
  { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "node scripts/checkPractices.js" }] }
]
```

`prePushReview.js` blocks `git push` until a review has been recorded against the exact commit;
`checkPractices.js` fails any edit that leaves a TODO/FIXME/placeholder behind. Both require Node.

Worth adopting on any project you actually ship. Skip on throwaways — the gate is deliberately
hard to satisfy, and it will block you.

## Verifying the whole thing

Start a new Claude Code session in the repository and ask it to list its available subagents. It
should name `bob-the-builder` and `felix-the-fixer`. For a web session, check the session's startup
output for the `claude-config: synced …` line.

`/skill-doctor` shows what the skills cost per turn. Skills marked `disable-model-invocation: true`
read `-` there — they cost nothing until invoked by name from the `/` menu, and cannot be called by
an agent at all.

## Re-running and updating

Nothing needs re-running. The step-1 hook re-clones-or-pulls this repo and re-applies the sync at
every session start, so a push here reaches every machine and project at their next session.

Both hooks firing in one session (the user-level one from step 1 and the repo one from step 2) is
harmless — `install.sh` is idempotent and `flock`-serialized, so the second run is one shallow
fetch.
