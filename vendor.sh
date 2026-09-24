#!/usr/bin/env bash
# Copies a plugin from this marketplace into a project's .claude/vendor/<plugin>/, pinned to the
# version in its plugin.json and to the commit recorded beside it. Upgrading is re-running this
# and committing, so the diff is the upgrade.
#
# This exists for harness-gates. Its hooks have to be wired into the project's own
# .claude/settings.json, because that is the one place a hook reaches both local and web sessions:
# a web session installs no plugins the repository declares, and skips plugin directories under
# .claude/skills/ because it never shows the trust dialog they wait for. .claude/vendor/ is not a
# plugin location, so the copy is only ever run through those settings hooks, never twice.
#
#   ./vendor.sh <project-dir> [plugin ...]     # default: harness-gates
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

[ $# -gt 0 ] || set -- harness-gates
for plugin in "$@"; do
  [ -d "$SRC/plugins/$plugin" ] || { echo "vendor.sh: no plugin named $plugin" >&2; exit 1; }
  dest="$TARGET/.claude/vendor/$plugin"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -r "$SRC/plugins/$plugin" "$dest"
  echo "$COMMIT" > "$dest/.vendored-from"
  version="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$dest/.claude-plugin/plugin.json")"
  echo "vendor.sh: $plugin $version (rrichardtang/claude-config@${COMMIT:0:8}) -> $dest"
done
