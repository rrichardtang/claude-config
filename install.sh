#!/usr/bin/env bash
# Syncs this repo's skills/agents/CLAUDE.md into ~/.claude/, and wires itself to re-run on every
# session start so the sync is self-refreshing across every project. Safe to re-run: skills and
# agents are copied wholesale (they live in a namespace this repo owns outright), but
# ~/.claude/CLAUDE.md is user-owned and may carry content unrelated to this repo, so it's merged
# via a marked block instead of being overwritten, and ~/.claude/settings.json is edited by
# replacing only this repo's own SessionStart entry.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
START='<!-- claude-config:start (managed by rrichardtang/claude-config, do not edit by hand) -->'
END='<!-- claude-config:end -->'

mkdir -p "$DEST/skills" "$DEST/agents"

for skill in "$SRC"/skills/*/; do
  name="$(basename "$skill")"
  rm -rf "$DEST/skills/$name"
  cp -r "$skill" "$DEST/skills/$name"
done
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

# Self-refresh: install the bootstrap and register it as a user-level SessionStart hook, so every
# future session in every project re-runs this sync before doing any work. Only this repo's own
# entry is rewritten, leaving any other SessionStart hooks the user has registered untouched.
# Write via a temp file rather than over the destination: session-start.sh is the script bash is
# executing right now, and bash reads a script lazily by byte offset.
cp "$SRC/hooks/session-start.sh" "$DEST/session-start.sh.tmp"
chmod +x "$DEST/session-start.sh.tmp"
mv "$DEST/session-start.sh.tmp" "$DEST/session-start.sh"

if ! command -v jq >/dev/null; then
  echo "claude-config: jq not found, skipping self-refresh hook registration" >&2
  exit 0
fi

SETTINGS="$DEST/settings.json"
HOOK_CMD="bash \"$DEST/session-start.sh\""
# -s not -f: a zero-byte settings.json would leave jq emitting nothing at exit 0, silently
# registering no hook at all.
[ -s "$SETTINGS" ] || echo '{}' > "$SETTINGS"
jq --arg cmd "$HOOK_CMD" '
  .hooks.SessionStart = (
    ((.hooks.SessionStart // []) | map(select([.hooks[]?.command] | index($cmd) | not)))
    + [{matcher: "startup|resume", hooks: [{type: "command", command: $cmd}]}]
  )
' "$SETTINGS" > "$SETTINGS.tmp"
mv "$SETTINGS.tmp" "$SETTINGS"

skill_count=$(find "$SRC/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
echo "claude-config: synced $skill_count skills, bob-the-builder, felix-the-fixer, and CLAUDE.md into $DEST"
echo "claude-config: self-refresh hook registered in $SETTINGS"
