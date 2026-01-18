# Git Extras

## Branching and workflow management

Commands that simplify creating, cleaning up, merging, and inspecting branches as part of a day-to-day Git workflow.

| Command | Summary |
| --- | --- |
| [`git-brv`](https://github.com/tj/git-extras/blob/main/Commands.md#git-brv) | List branches sorted by last commit date. |
| [`git-create-branch`](https://github.com/tj/git-extras/blob/main/Commands.md#git-create-branch) | Create a new branch, optionally with remote tracking. |
| [`git-delete-branch`](https://github.com/tj/git-extras/blob/main/Commands.md#git-delete-branch) | Delete a local or remote branch. |
| [`git-delete-merged-branches`](https://github.com/tj/git-extras/blob/main/Commands.md#git-delete-merged-branches) | Remove branches that have already been merged. |
| [`git-delete-squashed-branches`](https://github.com/tj/git-extras/blob/main/Commands.md#git-delete-squashed-branches) | Delete branches that were squash-merged. |
| [`git-feature`](https://github.com/tj/git-extras/blob/main/Commands.md#git-feature) | Create or merge feature branches using conventions. |
| [`git-fresh-branch`](https://github.com/tj/git-extras/blob/main/Commands.md#git-fresh-branch) | Create a clean branch starting from HEAD. |
| [`git-graft`](https://github.com/tj/git-extras/blob/main/Commands.md#git-graft) | Merge a branch and remove it afterwards. |
| [`git-merge-into`](https://github.com/tj/git-extras/blob/main/Commands.md#git-merge-into) | Merge one branch into another without checking it out. |
| [`git-missing`](https://github.com/tj/git-extras/blob/main/Commands.md#git-missing) | Show commits missing between branches. |
| [`git-rename-branch`](https://github.com/tj/git-extras/blob/main/Commands.md#git-rename-branch) | Rename a branch locally and remotely. |

## Repository inspection and statistics

Commands focused on analysing history, authorship, contributions, and repository structure.

| Command | Summary |
| --- | --- |
| [`git-authors`](https://github.com/tj/git-extras/blob/main/Commands.md#git-authors) | List repository authors and their contributions. |
| [`git-commits-since`](https://github.com/tj/git-extras/blob/main/Commands.md#git-commits-since) | Show commits since a given date. |
| [`git-contrib`](https://github.com/tj/git-extras/blob/main/Commands.md#git-contrib) | Show contribution statistics per author. |
| [`git-count`](https://github.com/tj/git-extras/blob/main/Commands.md#git-count) | Count commits by author or globally. |
| [`git-delta`](https://github.com/tj/git-extras/blob/main/Commands.md#git-delta) | Show files changed between branches. |
| [`git-effort`](https://github.com/tj/git-extras/blob/main/Commands.md#git-effort) | Display effort statistics per file. |
| [`git-guilt`](https://github.com/tj/git-extras/blob/main/Commands.md#git-guilt) | Show blame or commit responsibility information. |
| [`git-info`](https://github.com/tj/git-extras/blob/main/Commands.md#git-info) | Display high-level information about the repository. |
| [`git-local-commits`](https://github.com/tj/git-extras/blob/main/Commands.md#git-local-commits) | List commits not yet pushed upstream. |
| [`git-root`](https://github.com/tj/git-extras/blob/main/Commands.md#git-root) | Print the repository root directory. |

## History rewriting and cleanup

Commands that modify commit history or aggressively clean up repository state. These should be used deliberately.

| Command | Summary |
| --- | --- |
| [`git-abort`](https://github.com/tj/git-extras/blob/main/Commands.md#git-abort) | Abort an in-progress merge, rebase, or cherry-pick. |
| [`git-clear`](https://github.com/tj/git-extras/blob/main/Commands.md#git-clear) | Remove untracked files and directories aggressively. |
| [`git-clear-soft`](https://github.com/tj/git-extras/blob/main/Commands.md#git-clear-soft) | Soft cleanup respecting ignore rules. |
| [`git-obliterate`](https://github.com/tj/git-extras/blob/main/Commands.md#git-obliterate) | Remove files and erase them from history. |
| [`git-psykorebase`](https://github.com/tj/git-extras/blob/main/Commands.md#git-psykorebase) | Rebase while preserving merge commits. |
| [`git-reauthor`](https://github.com/tj/git-extras/blob/main/Commands.md#git-reauthor) | Rewrite commit author information. |
| [`git-rebase-patch`](https://github.com/tj/git-extras/blob/main/Commands.md#git-rebase-patch) | Apply patches using rebase. |
| [`git-reset-file`](https://github.com/tj/git-extras/blob/main/Commands.md#git-reset-file) | Reset a single file to a given commit. |

## Releases, tags, and changelogs

Commands supporting release workflows, tagging, and change documentation.

| Command | Summary |
| --- | --- |
| [`git-changelog`](https://github.com/tj/git-extras/blob/main/Commands.md#git-changelog) | Generate a changelog from commit history. |
| [`git-release`](https://github.com/tj/git-extras/blob/main/Commands.md#git-release) | Tag, commit, and push a release. |
| [`git-delete-tag`](https://github.com/tj/git-extras/blob/main/Commands.md#git-delete-tag) | Delete tags locally and remotely. |
| [`git-rename-tag`](https://github.com/tj/git-extras/blob/main/Commands.md#git-rename-tag) | Rename an existing tag. |

## Remotes, hosting, and collaboration

Commands that integrate with hosting providers and support collaboration workflows.

| Command | Summary |
| --- | --- |
| [`git-browse`](https://github.com/tj/git-extras/blob/main/Commands.md#git-browse) | Open the repository page in a browser. |
| [`git-browse-ci`](https://github.com/tj/git-extras/blob/main/Commands.md#git-browse-ci) | Open the repository's CI page. |
| [`git-fork`](https://github.com/tj/git-extras/blob/main/Commands.md#git-fork) | Fork a GitHub repository. |
| [`git-get`](https://github.com/tj/git-extras/blob/main/Commands.md#git-get) | Clone repositories into a predefined directory. |
| [`git-gh-pages`](https://github.com/tj/git-extras/blob/main/Commands.md#git-gh-pages) | Create or update a gh-pages branch. |
| [`git-mr`](https://github.com/tj/git-extras/blob/main/Commands.md#git-mr) | Check out a merge request locally. |
| [`git-pr`](https://github.com/tj/git-extras/blob/main/Commands.md#git-pr) | Check out a pull request locally. |
| [`git-pull-request`](https://github.com/tj/git-extras/blob/main/Commands.md#git-pull-request) | Create a GitHub pull request from the CLI. |
| [`git-rename-remote`](https://github.com/tj/git-extras/blob/main/Commands.md#git-rename-remote) | Rename a Git remote. |

## File operations and repository structure

Commands that operate on files while preserving Git semantics or managing repository layout.

| Command | Summary |
| --- | --- |
| [`git-archive-file`](https://github.com/tj/git-extras/blob/main/Commands.md#git-archive-file) | Export repository content as an archive. |
| [`git-cp`](https://github.com/tj/git-extras/blob/main/Commands.md#git-cp) | Copy files while preserving history. |
| [`git-delete-submodule`](https://github.com/tj/git-extras/blob/main/Commands.md#git-delete-submodule) | Remove a submodule cleanly. |
| [`git-force-clone`](https://github.com/tj/git-extras/blob/main/Commands.md#git-force-clone) | Clone into an existing directory. |

## Ignore files and locking

Commands dealing with ignore rules and file-level locking.

| Command | Summary |
| --- | --- |
| [`git-ignore`](https://github.com/tj/git-extras/blob/main/Commands.md#git-ignore) | Add patterns to `.gitignore`. |
| [`git-ignore-io`](https://github.com/tj/git-extras/blob/main/Commands.md#git-ignore-io) | Generate `.gitignore` files from templates. |
| [`git-lock`](https://github.com/tj/git-extras/blob/main/Commands.md#git-lock) | Lock a file to prevent commits. |
| [`git-locked`](https://github.com/tj/git-extras/blob/main/Commands.md#git-locked) | List locked files. |

## Automation and power tools

Commands that streamline repetitive tasks or offer higher-level abstractions.

| Command | Summary |
| --- | --- |
| [`git-alias`](https://github.com/tj/git-extras/blob/main/Commands.md#git-alias) | Manage Git aliases. |
| [`git-bulk`](https://github.com/tj/git-extras/blob/main/Commands.md#git-bulk) | Run Git commands across multiple repositories. |
| [`git-magic`](https://github.com/tj/git-extras/blob/main/Commands.md#git-magic) | Automate add, commit, and push steps. |
| [`git-repl`](https://github.com/tj/git-extras/blob/main/Commands.md#git-repl) | Start an interactive Git REPL. |
| [`git-paste`](https://github.com/tj/git-extras/blob/main/Commands.md#git-paste) | Send patches to a pastebin service. |

## Others

Commands that are useful but do not clearly fit a single category.

| Command | Summary |
| --- | --- |
| [`git-merge-repo`](https://github.com/tj/git-extras/blob/main/Commands.md#git-merge-repo) | Merge the history of another repository into the current one. |
