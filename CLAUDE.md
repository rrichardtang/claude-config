# claude-config

This repository is a Claude Code plugin marketplace (`.claude-plugin/marketplace.json`) with two
plugins under `plugins/`. It is not loaded as anyone's user config any more; the harness protocol
that used to live in this file is now the `harness:protocol` skill
(`plugins/harness/skills/protocol/SKILL.md`).

## Working here

- **Bump `version` in a plugin's `.claude-plugin/plugin.json` on every change to that plugin.**
  Installs only update when the version string changes, so an unbumped change never ships.
- Run `npm test` (the push-gate and practices-check tests) and
  `claude plugin validate . --strict` plus `claude plugin validate plugins/<name> --strict`
  before pushing.
- Reference skills and agents by their namespaced names (`harness:caveman`,
  `harness:felix-the-fixer`) inside the plugins. `install.sh` strips the prefix for the legacy
  copy-based sync.
- Paths inside a plugin go through `${CLAUDE_PLUGIN_ROOT}`; never write `~/.claude/...` or an
  absolute path into a skill, agent or hook.
- `install.sh` and `hooks/session-start.sh` are the legacy sync, kept only until every project
  that vendors the bootstrap has moved to the plugin. Keep them working; don't extend them.
