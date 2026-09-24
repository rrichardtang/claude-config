#!/usr/bin/env bash
# Copies plugins from this marketplace into a project's .claude/skills/, where Claude Code loads
# each one as a skills-directory plugin straight from the clone. That is the one way a plugin
# reaches a Claude Code web session from the repository itself: a web session does not install
# plugins a repository declares under enabledPlugins. The copy is pinned to the version in its
# plugin.json and to the commit recorded beside it; upgrading is re-running this and committing.
#
#   ./vendor.sh <project-dir> [plugin ...]     # default: harness harness-gates
set -euo pipefail

TARGET="${1:?usage: vendor.sh <project-dir> [plugin ...]}"
shift
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMIT="$(git -C "$SRC" rev-parse HEAD)"
# The recorded commit must be what was copied, so refuse to vendor uncommitted plugin changes.
if [ -n "$(git -C "$SRC" status --porcelain -- plugins)" ]; then
  echo "vendor.sh: plugins/ has uncommitted changes; commit them first" >&2
  exit 1
fi

[ $# -gt 0 ] || set -- harness harness-gates
for plugin in "$@"; do
  [ -d "$SRC/plugins/$plugin" ] || { echo "vendor.sh: no plugin named $plugin" >&2; exit 1; }
  dest="$TARGET/.claude/skills/$plugin"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -r "$SRC/plugins/$plugin" "$dest"
  echo "$COMMIT" > "$dest/.vendored-from"
  version="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$dest/.claude-plugin/plugin.json")"
  echo "vendor.sh: $plugin $version (rrichardtang/claude-config@${COMMIT:0:8}) -> $dest"
done
