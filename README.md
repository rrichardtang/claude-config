# claude-config

A Claude Code plugin marketplace with rrichardtang's working setup: two review/build subagents,
the protocol for running them, the skills they use, and opt-in guardrails for projects you ship.

| Plugin | What it bundles | Install it |
|---|---|---|
| `harness` | `bob-the-builder` and `felix-the-fixer` subagents, the `protocol` skill (how to run them and pick their models), and the `caveman`, `ponytail`, `thermo-nuclear-code-quality-review`, `wayfinder`, `grill-with-docs`, `grilling`, `domain-modeling`, `research` and `prototype` skills | Everywhere you work |
| `harness-gates` | A `PreToolUse` hook that holds `git push` until `felix-the-fixer` has reviewed HEAD, and a `PostToolUse` hook that flags TODO markers and placeholder stubs as they are written. Wired into a project as repository hooks. It asks for `harness:felix-the-fixer`, so install `harness` wherever that project is opened | Per project, on projects you ship |
| `explain-to-a-baby` | An output style that makes every reply three short plain-English parts (What changed, Why?, What's next), switched on as soon as the plugin is installed, plus a skill to apply it on demand | Wherever you want replies written that way |

Everything is namespaced by plugin: `/harness:wayfinder`, subagent `harness:felix-the-fixer`.

## Install

Where Claude Code runs decides how the plugins get there.

| Where | `harness` | `harness-gates` |
|---|---|---|
| Your machine (terminal, desktop app) | `/plugin marketplace add rrichardtang/claude-config`, then `/plugin install harness@rrichardtang`, once per machine | A hook in the project's `.claude/settings.json` (below) |
| Claude Code on the web | The cloud environment's setup script, once per environment (below) | Same repository hook: it runs on the web too |
| A teammate's machine | `extraKnownMarketplaces` + `enabledPlugins` in the project's `.claude/settings.json`, installed when they trust the folder | Same repository hook |

Web sessions never install plugins a repository declares, and they skip plugin directories
committed under `.claude/skills/`, because those wait for a trust dialog a web session never
shows. What does reach a web session is anything installed before Claude Code starts (the setup
script) and the repository's own `.claude/settings.json` hooks.

**Setup script** (environment menu in the session title bar → Edit → Setup script). It runs
before Claude Code launches and its result is cached for about seven days, so a version bump
reaches web sessions when the cache rebuilds, or at once if you edit the script:

```bash
claude plugin marketplace add rrichardtang/claude-config || true
claude plugin install harness@rrichardtang || true
claude plugin install explain-to-a-baby@rrichardtang || true    # optional
```

**Push gate for one project.** Copy the scripts in, pinned, then wire them into that project's
`.claude/settings.json`:

```bash
./vendor.sh /path/to/project            # -> .claude/vendor/harness-gates/
```

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command",
        "command": "sh \"$CLAUDE_PROJECT_DIR/.claude/vendor/harness-gates/scripts/push-gate.sh\"" }] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [{ "type": "command",
        "command": "node \"$CLAUDE_PROJECT_DIR/.claude/vendor/harness-gates/scripts/checkPractices.js\"" }] }
    ]
  }
}
```

The gate lives in the repository rather than in anyone's install, so it applies to exactly the
projects that opt in, for everyone who opens them, wherever they open them. Don't also enable
`harness-gates@rrichardtang` in a project that has these hooks, or the gate runs twice.

`INSTALL.md` walks a Claude Code session through all of this.

## What the push gate is, and isn't

It is a nudge. The receipt is a file in the clone's git directory, written by
`prePushReview.js --record`, and nothing checks that a review actually happened before it was
written. It never leaves the machine, so GitHub cannot see it. For enforcement, use branch
protection on the server: require a pull request and an approving review before merging to the
default branch.

## Versions and updates

Each plugin's version is the `version` in its `.claude-plugin/plugin.json`. Installs update only
when that string changes, so bump it on every change. `/plugin update harness@rrichardtang`
pulls the new version; the setup script picks it up when the environment cache rebuilds;
vendored gate copies update when `vendor.sh` is re-run.

## Where the skills come from

- `caveman`: vendored verbatim (MIT) from [`JuliusBrussee/caveman`](https://github.com/JuliusBrussee/caveman).
- `thermo-nuclear-code-quality-review`: vendored verbatim (MIT) from
  [`cursor/plugins`](https://github.com/cursor/plugins). Left model-invocable on purpose:
  `bob-the-builder` calls it on its own diff before stopping.
- `wayfinder`, `grill-with-docs`, `grilling`, `domain-modeling`, `research`, `prototype`:
  vendored verbatim (MIT) from [`mattpocock/skills`](https://github.com/mattpocock/skills).
  `wayfinder` and `grill-with-docs` are explicit-invoke only.
- `ponytail`: from [`nikvdp/ponytail`](https://github.com/nikvdp/ponytail).

## Design skills live on the claude.ai account, not here

The frontend design and image-direction skills are claude.ai account skills, because they carry
`disable-model-invocation: true` and so can only be reached from the `/` menu, which an account
skill reaches in every repository and in web sessions.

## Legacy sync

`install.sh` and `hooks/session-start.sh` are the old copy-based sync: a `SessionStart` hook
clones this repository and copies skills, agents and a `CLAUDE.md` block into `~/.claude/`. It
stays only until the projects that vendor that hook (`rrichardtang/guideme`) move to the plugin.
It now reads the plugin's files, so there is one source of truth. `INSTALL.md` covers removing it
from a machine.
