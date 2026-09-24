# claude-config

A Claude Code plugin marketplace with rrichardtang's working setup: two review/build subagents,
the protocol for running them, the skills they use, and opt-in guardrails for projects you ship.

| Plugin | What it bundles | Install it |
|---|---|---|
| `harness` | `bob-the-builder` and `felix-the-fixer` subagents, the `protocol` skill (how to run them and pick their models), and the `caveman`, `ponytail`, `thermo-nuclear-code-quality-review`, `wayfinder`, `grill-with-docs`, `grilling`, `domain-modeling`, `research` and `prototype` skills | Everywhere you work |
| `harness-gates` | A `PreToolUse` hook that holds `git push` until `felix-the-fixer` has reviewed HEAD, and a `PostToolUse` hook that flags TODO markers and placeholder stubs as they are written. Depends on `harness`, so the reviewer always comes with the gate | Per project, on projects you ship |

Everything is namespaced by plugin: `/harness:wayfinder`, subagent `harness:felix-the-fixer`.

## Install

On your own machine:

```
/plugin marketplace add rrichardtang/claude-config
/plugin install harness@rrichardtang
```

For a project, so teammates get it when they trust the repository, commit this to its
`.claude/settings.json`:

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

**Claude Code on the web does not install plugins a repository declares that way.** For a
project you open from the web, commit a pinned copy instead:

```bash
./vendor.sh /path/to/project            # copies both plugins into .claude/skills/
```

A plugin under a repository's `.claude/skills/<name>/` loads as a skills-directory plugin
(`harness@skills-dir`) straight from the clone, locally and on the web. The copy is pinned: it
carries its `plugin.json` version and a `.vendored-from` file naming the commit it came from, and
it changes only when someone re-runs `vendor.sh` and commits. Use one mechanism per project, not
both, or the same plugin name loads twice.

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
pulls the new version; vendored copies update when `vendor.sh` is re-run.

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
