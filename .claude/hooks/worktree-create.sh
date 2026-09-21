#!/bin/bash
# Creates and prepares a linked git worktree when Claude Code's EnterWorktree tool
# fires mid-session. The harness delegates creation entirely to this hook: it sends
# a JSON payload on stdin ({ name, cwd, ... }) and reads the new worktree's path from
# this hook's STDOUT. So the contract is strict:
#
#   * everything diagnostic goes to stderr,
#   * the ONLY thing printed to stdout is the final worktree path.
#
# We keep Claude Code's default location — <main checkout>/.claude/worktrees/<name>,
# on a branch "<name>" cut fresh from origin/main — then run bin/git-worktree-setup
# inside it (a free browser port and browser CSS). Idempotent: an existing
# worktree/branch is reused, and bin/git-worktree-setup is a no-op for the same worktree.
set -euo pipefail

log() { printf '[worktree-create] %s\n' "$*" >&2; }

payload="$(cat)"
field() { printf '%s' "$payload" | ruby -rjson -e 'print JSON.parse(STDIN.read).fetch(ARGV.fetch(0), "")' "$1"; }

name="$(field name)"
cwd="$(field cwd)"
[ -n "$cwd" ] || cwd="$PWD"
[ -n "$name" ] || name="worktree-$(date +%s)"
case "$name" in
  *[!a-zA-Z0-9_-]*|-*) log "invalid worktree name: $name"; exit 1 ;;
esac

# Resolve the main checkout (first entry of `git worktree list`) so the path and base
# ref are anchored there regardless of which worktree the session is in.
repo_root="$(git -C "$cwd" worktree list --porcelain | sed -n 's/^worktree //p' | head -1)"
[ -n "$repo_root" ] || { log "not in a git worktree (cwd=$cwd)"; exit 1; }

worktree_path="$repo_root/.claude/worktrees/$name"
branch="$name"

if git -C "$repo_root" worktree list --porcelain | grep -qxF "worktree $worktree_path"; then
  log "reusing existing worktree $worktree_path"
else
  log "creating worktree $worktree_path (branch $branch)"
  git -C "$repo_root" fetch --quiet origin main 1>&2 || log "fetch failed; using local refs"

  if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
    base=""                       # branch already exists — check it out as-is
  elif git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/main"; then
    base="origin/main"
  else
    base="HEAD"
  fi

  if [ -n "$base" ]; then
    git -C "$repo_root" worktree add -b "$branch" "$worktree_path" "$base" >&2
  else
    git -C "$repo_root" worktree add "$worktree_path" "$branch" >&2
  fi
fi

# Prepare the worktree (browser port and CSS). Force its output to
# stderr so it never contaminates the path we owe the harness on stdout.
setup="$worktree_path/bin/git-worktree-setup"
if [ -x "$setup" ]; then
  log "preparing resources for $worktree_path"
  ( cd "$worktree_path" && ./bin/git-worktree-setup ) >&2 ||
    log "setup failed; run ./bin/git-worktree-setup by hand in the worktree."
fi

printf '%s\n' "$worktree_path"
