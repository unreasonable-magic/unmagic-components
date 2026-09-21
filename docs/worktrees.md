# Git worktrees

Adapted from hoops for this gem's standalone component browser. Each worktree
gets a browser port starting at 5702; the main checkout defaults to 5701.
Setup installs the bundle and builds the browser stylesheet. It needs no database
or background services.

```sh
bin/git-worktree checkout my-existing-branch
bin/git-worktree checkout https://github.com/unreasonable-magic/unmagic-components/pull/123
bin/git-worktree list
bin/git-worktree cleanup                  # report only
bin/git-worktree cleanup --delete --dry-run
bin/git-worktree cleanup --delete
```

Checkout fetches from origin, reuses existing worktrees, and otherwise creates
`.claude/worktrees/<branch>`. For a new branch, use Git first:

```sh
git worktree add .claude/worktrees/my-change -b my-change
cd .claude/worktrees/my-change
bin/git-worktree setup
bin/dev
```

Setup writes an ignored `.env` with `PORT` and `APP_URL`. Re-running setup keeps
its port; an environment copied from another worktree is regenerated. It skips
ports already assigned to siblings or currently bound. `PORT=5800 bin/dev`
overrides the file. If localroast is installed, setup also maps
`https://unmagic-components--<worktree-name>.localhost` to that port.
For screenshots use `BROWSER_URL=http://localhost:<port> bin/screenshots button`.

The Claude Code WorktreeCreate/WorktreeRemove hooks and `supacode.json` use the
setup and teardown shims automatically. New worktrees need a branch containing
these scripts. Setup uses mise when available to select the project's Ruby.

```sh
bin/git-worktree teardown .claude/worktrees/my-change
bin/git-worktree teardown --keep .claude/worktrees/my-change
bin/git-worktree teardown --prune --dry-run
```

Teardown removes a clean, unlocked worktree and its optional vanity hostname.
`--keep` removes only the hostname, for editor-managed removal. `--prune` removes
orphaned hostnames and prunes Git's stale worktree registrations.
Cleanup compares against `origin/main` (or the main checkout's branch without an
origin), preserving unmerged changes, dirty files, and branch stashes. It also
keeps locked or active worktrees unless `--force` is supplied. It never deletes
the main checkout or the checkout running cleanup. Review its report first.

The visible-browser smoke demo is saved in
[`demos/worktree-browser.js`](demos/worktree-browser.js). Start `PORT=5799 bin/dev`,
then replay it through `cua_repl` to show the button examples in light and dark
mode in Safari. Worktree lifecycle checks run with
`bundle exec rspec spec/bin/git_worktree_spec.rb` in disposable repositories.
