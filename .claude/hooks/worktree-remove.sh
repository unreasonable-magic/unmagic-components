#!/bin/bash
# Drops a worktree's localroast hostname when Claude Code removes
# the worktree. WorktreeRemove fires for cleanup only — it can't block or modify
# the removal, and Claude Code still runs `git worktree remove` itself, so we
# pass --keep to drop only the resources. The worktree path comes from the hook
# payload's `worktree_path` on stdin. A no-op if the worktree was never set up
# (no matching hostname). Manual `git worktree remove` doesn't fire this — use
# `bin/git-worktree-teardown --prune` to sweep those.
set -euo pipefail

payload="$(cat)"
worktree_path="$(printf '%s' "$payload" | ruby -rjson -e 'print JSON.parse(STDIN.read).fetch("worktree_path", "")')"
[ -n "$worktree_path" ] || exit 0

teardown="$CLAUDE_PROJECT_DIR/bin/git-worktree-teardown"
[ -x "$teardown" ] || exit 0

echo "[worktree-remove] dropping resources for $worktree_path"
"$teardown" --keep "$worktree_path" || echo "[worktree-remove] teardown failed; run bin/git-worktree-teardown --prune later."
