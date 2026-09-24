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
| `harness-gates` | Push-review gate and TODO/stub check, as plugin hooks. Pulls in `harness` | Projects you ship; skip throwaways, since the gate will block you |

Nothing is written into `~/.claude/CLAUDE.md` or copied into `~/.claude/skills/`. The protocol
that used to be a `CLAUDE.md` block is the `harness:protocol` skill, which loads when a session is
about to spawn one of the agents, pick a model, or push.

## First: will this repository be opened from Claude Code on the web?

A web session starts from a fresh clone. It does not install plugins a repository declares in
`.claude/settings.json`, and it has none of your local `~/.claude/`. What it does load is anything
committed under the repository's `.claude/`, including plugin directories under
`.claude/skills/`. So:

- **Opened from the web (or both):** do step 2 (vendor).
- **Local only:** do step 1 (marketplace), and step 3 if the project should carry it for teammates.

Never combine step 2 with step 3 in one repository: the same plugin name would load twice.

## Step 1: Install on this machine

In a terminal session:

```
/plugin marketplace add rrichardtang/claude-config
/plugin install harness@rrichardtang
```

Verify: `claude plugin list` shows `harness@rrichardtang` as enabled, and asking the session for
its subagents lists `harness:bob-the-builder` and `harness:felix-the-fixer`.

## Step 2: Vendor a pinned copy into the repository

From a checkout of this repository:

```bash
./vendor.sh /path/to/project                   # harness + harness-gates
./vendor.sh /path/to/project harness           # harness only
```

This copies each plugin to `/path/to/project/.claude/skills/<plugin>/` with a `.vendored-from`
file naming the commit. If the project's `.gitignore` ignores `.claude/`, add an exception so the
copies commit:

```
.claude/*
!.claude/settings.json
!.claude/skills/
```

Check with `git check-ignore -v .claude/skills/harness/.claude-plugin/plugin.json` (no output
means it will commit), then commit. After the workspace is trusted, `claude plugin list` in the
project shows `harness@skills-dir` as loaded.

To upgrade, re-run `vendor.sh` from a newer checkout and commit. The diff is the upgrade.

## Step 3: Declare it for a local team

Merge into the project's `.claude/settings.json`; don't overwrite other keys:

```json
{
  "extraKnownMarketplaces": {
    "rrichardtang": { "source": { "source": "github", "repo": "rrichardtang/claude-config" } }
  },
  "enabledPlugins": {
    "harness@rrichardtang": true,
    "harness-gates@rrichardtang": true
  }
}
```

A teammate who trusts the folder gets the marketplace added and both plugins installed.

## The push gate

`harness-gates` blocks a `git push` until a receipt for the exact HEAD commit exists. The block
message names the command that writes it; run that as its own command, after
`harness:felix-the-fixer` has reviewed the diff. Without Node, the gate blocks any command that
mentions a git push rather than letting it through.

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
