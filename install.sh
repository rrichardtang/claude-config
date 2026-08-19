#!/usr/bin/env bash
# Syncs this repo's skill/agents/CLAUDE.md into ~/.claude/. Safe to re-run: skills and agents
# are copied wholesale (they live in a namespace this repo owns outright), but ~/.claude/CLAUDE.md
# is user-owned and may carry content unrelated to this repo, so it's merged via a marked block
# instead of being overwritten.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
START='<!-- claude-config:start (managed by rrichardtang/claude-config, do not edit by hand) -->'
END='<!-- claude-config:end -->'

mkdir -p "$DEST/skills" "$DEST/agents"

rm -rf "$DEST/skills/caveman"
cp -r "$SRC/skills/caveman" "$DEST/skills/caveman"
cp "$SRC/agents/bob-the-builder.md" "$DEST/agents/bob-the-builder.md"
cp "$SRC/agents/felix-the-fixer.md" "$DEST/agents/felix-the-fixer.md"

BLOCK=$(printf '%s\n%s\n%s\n' "$START" "$(cat "$SRC/CLAUDE.md")" "$END")

if [ -f "$DEST/CLAUDE.md" ] && grep -qF "$START" "$DEST/CLAUDE.md"; then
  # Replace the existing managed block in place, leaving anything else in the file untouched.
  awk -v start="$START" -v end="$END" -v block="$BLOCK" '
    $0 == start { print block; skipping = 1; next }
    $0 == end && skipping { skipping = 0; next }
    skipping { next }
    { print }
  ' "$DEST/CLAUDE.md" > "$DEST/CLAUDE.md.tmp"
  mv "$DEST/CLAUDE.md.tmp" "$DEST/CLAUDE.md"
else
  # No managed block yet — append (creating the file if it doesn't exist), preserving whatever
  # else is already there.
  { [ -f "$DEST/CLAUDE.md" ] && printf '\n'; printf '%s\n' "$BLOCK"; } >> "$DEST/CLAUDE.md"
fi

echo "claude-config: synced caveman skill, bob-the-builder, felix-the-fixer, and CLAUDE.md into $DEST"
