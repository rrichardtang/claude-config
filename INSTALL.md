# Installing this harness

Instructions for a Claude Code session. Read this file, then carry out the steps that fit the
repository the session is running in. Every step is safe to re-run.

Hand this to a session with:

> Read https://raw.githubusercontent.com/rrichardtang/claude-config/main/INSTALL.md and follow it.

## What gets installed

Two plugins from this repository's marketplace, `rrichardtang`:

| Plugin | Contents | Where it belongs |
|---|---|---|
| `harness` | `harness:bob-the-builder`, `harness:felix-the-fixer`, the `harness:protocol` skill, nine working skills | Every project |
| `harness-gates` | Push-review gate and TODO/stub check. Wired into a project as repository hooks (step 3), not installed | Projects you ship; skip throwaways, since the gate will block you |

Nothing is written into `~/.claude/CLAUDE.md` or copied into `~/.claude/skills/`. The protocol
that used to be a `CLAUDE.md` block is the `harness:protocol` skill, which loads when a session is
about to spawn one of the agents, pick a model, or push.

## First: where does Claude Code run?

A web session starts from a fresh clone with an empty `~/.claude/`. It does not install plugins a
repository declares in `.claude/settings.json`, and it skips plugin directories committed under
`.claude/skills/`, because they wait for a trust dialog a web session never shows. Two things do
reach it: whatever the cloud environment's setup script installs before Claude Code starts, and
the repository's own `.claude/settings.json` hooks.

```bash
[ -n "${CLAUDE_CODE_REMOTE:-}" ] && echo "web session" || echo "local machine"
```

- **Local machine:** step 1. Step 2 as well if teammates should get the harness from the repo.
- **Web session:** step 1 cannot stick (the container is discarded). Tell the user to add the
  setup script in step 1b; you cannot edit environment settings yourself.
- **Either, for a project you ship:** step 3.

## Step 1: Install `harness` on this machine

In a terminal session:

```
/plugin marketplace add rrichardtang/claude-config
/plugin install harness@rrichardtang
/plugin install explain-to-a-baby@rrichardtang     # optional: plain three-part replies
```

Verify: `claude plugin list` shows `harness@rrichardtang` as enabled, and asking the session for
its subagents lists `harness:bob-the-builder` and `harness:felix-the-fixer`.

### Step 1b: Install `harness` in a cloud environment

The user adds this to the environment's setup script (environment menu in the session title bar →
Edit → Setup script). It runs as root before Claude Code launches, so the plugin is installed at
user scope, which needs no trust dialog:

```bash
claude plugin marketplace add rrichardtang/claude-config || true
claude plugin install harness@rrichardtang || true
claude plugin install explain-to-a-baby@rrichardtang || true    # optional
```

`|| true` keeps a network blip from failing the session's start (a setup script that exits
non-zero stops the session), so check the result rather than trusting the script. The
environment is cached for about seven days, so a new plugin version reaches web sessions when
the cache rebuilds; editing the script rebuilds it at once. Verify in a new web session:
`claude plugin list` shows `harness@rrichardtang`.

## Step 2: Declare `harness` for a local team

Merge into the project's `.claude/settings.json`; don't overwrite other keys:

```json
{
  "extraKnownMarketplaces": {
    "rrichardtang": { "source": { "source": "github", "repo": "rrichardtang/claude-config" } }
  },
  "enabledPlugins": {
    "harness@rrichardtang": true
  }
}
```

A teammate who trusts the folder gets the marketplace added and `harness` installed. This does
nothing on the web; step 1b covers that.

## Step 3: Wire the push gate into a project

From a checkout of this repository:

```bash
./vendor.sh /path/to/project            # copies harness-gates to .claude/vendor/harness-gates/
```

Then merge these hooks into the project's `.claude/settings.json`:

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

If the project's `.gitignore` ignores `.claude/`, add exceptions so both commit:

```
.claude/*
!.claude/settings.json
!.claude/vendor/
```

Check with `git check-ignore -v .claude/settings.json .claude/vendor/harness-gates/scripts/push-gate.sh`
(no output means both will commit), then commit. Don't also enable `harness-gates@rrichardtang`
in this project, or the gate runs twice. The copy's own `hooks/hooks.json` is unused here; the
project's `.claude/settings.json` is the wiring. To upgrade, re-run `vendor.sh` from a newer checkout
and commit; the diff is the upgrade.

The gate blocks a `git push` until a receipt for the exact HEAD commit exists. The block message
names the command that writes it; run that as its own command, after `harness:felix-the-fixer`
has reviewed the diff. Without Node, the gate blocks any command that mentions a git push rather
than letting it through.

It is a nudge, not enforcement. Anyone can write the receipt, and it stays inside the clone's
`.git/`. For enforcement, turn on branch protection for the default branch on GitHub: require a
pull request and at least one approving review.

## Removing the legacy sync from a machine

Earlier versions installed by copying files into `~/.claude/`. After step 1, remove those so the
bare copies don't sit beside the namespaced plugin:

```bash
rm -rf ~/.claude/agents/bob-the-builder.md ~/.claude/agents/felix-the-fixer.md ~/.claude/session-start.sh
for s in caveman domain-modeling grill-with-docs grilling ponytail prototype research \
         thermo-nuclear-code-quality-review wayfinder; do rm -rf ~/.claude/skills/$s; done
jq '.hooks.SessionStart |= (. // [] | map(select([.hooks[]?.command] | any(test("session-start.sh")) | not)))' \
  ~/.claude/settings.json > ~/.claude/settings.json.tmp && mv ~/.claude/settings.json.tmp ~/.claude/settings.json
```

Then delete the block between `<!-- claude-config:start` and `<!-- claude-config:end -->` in
`~/.claude/CLAUDE.md`, and in each project that vendored it, remove
`.claude/hooks/session-start.sh` and its `SessionStart` entry in `.claude/settings.json`.

## How the pieces fit

**There is no orchestrator agent.** The main session orchestrates: neither subagent has `Agent`
in its tools, so only the main session can spawn both, carry findings between rounds (subagents
are stateless per spawn), enforce the 3-round cap, and choose each spawn's model. The rules are in
the `harness:protocol` skill.

**Neither agent pins a model.** With no frontmatter model and no configured default, a subagent
inherits the caller's model, so pass `model` on every spawn.

**Subagents don't inherit skills.** Each agent preloads what it needs by namespaced name in its
frontmatter: `bob-the-builder` preloads `harness:ponytail` and `harness:caveman`,
`felix-the-fixer` preloads `harness:caveman`.
