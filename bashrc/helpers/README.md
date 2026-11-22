# Bash helper commands

The shell adds this directory to `PATH`. Executable helpers run as separate processes.

## Rebase and publish a branch

`git-rebase-push` fetches the selected base and working branches, rebases the local working branch onto the remote base, runs your check command from the repository root, and pushes with an explicit `--force-with-lease`. Defaults are `main`, `origin`, and the current branch. The local base branch stays unchanged.

```bash
git-rebase-push -- npm run check
git-rebase-push --base development -- npm run check
git-rebase-push --base main --remote origin --branch rework/header -- make test
```

Supply the relevant check command after `--`; it runs directly as an argument array. For several checks, use an existing repository check script. Use `--help` for all options and `--verbose` for progress.

Both remote branches and the local working branch must exist. The helper requires a clean worktree and refuses active Git operations or remote working-branch commits missing locally. Selecting `--branch` switches to that branch and leaves it checked out. The push updates only that branch, and the lease rejects a remote branch changed since the fetch.

A rebase conflict stops before checks or publication. Resolve it with `git rebase --continue`, or cancel with `git rebase --abort`. A check failure leaves the rebased branch local. After completing a rebase manually or fixing failed checks, rerun the relevant checks, review the local and remote histories, and publish manually with `git push --force-with-lease origin <branch>` using your selected remote and branch. A retry can refuse the rewritten history because the remote commits are no longer ancestors. The helper does not stash, reset, or automatically resolve conflicts.

Source functions in `git-rebase-push`: `print_help` prints safe help, `die` reports an error and exits, and `run` executes an argument array and stops on failure.
