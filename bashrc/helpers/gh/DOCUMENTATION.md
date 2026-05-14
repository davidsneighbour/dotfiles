# `gh/` documentation

This file documents every file currently present in `bashrc/helpers/gh`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Existing Markdown references

* [`github-manager.md`](./github-manager.md)

## Files

### `gh/cdg`

Changes to a local GitHub repository directory by fuzzy-selecting a subdirectory under a base path; meant to be sourced/evaluated when used to affect the current shell.

CLI option notes:

* --github-user USER — GitHub account to list.
* --repo-path TEMPLATE — local path template or owner directory.
* --cache-path DIR — cache directory.
* --cache-minutes NUMBER — cache freshness.
* --refresh — ignore cache.
* --print-cd-command — print shell-quoted cd command.
* --verbose — enable verbose logging.
* --quiet — disable verbose logging.
* --help — show help.

Functions/methods defined:

* `cdg_script_name`
* `cdg_source_libs`
* `cdg_init_logging`
* `cdg_log_verbose`
* `cdg_error`
* `cdg_usage`
* `cdg_die`
* `cdg_expand_path`
* `cdg_is_positive_int`
* `cdg_cache_file`
* `cdg_cache_is_fresh`
* `cdg_repo_path_template_has_placeholder`
* `cdg_normalize_repo_path_template`
* `cdg_fetch_repositories`
* `cdg_repository_count`
* `cdg_select_repository`
* `cdg_repo_field`
* `cdg_render_repo_path`
* `cdg_source_glone`
* `cdg_clone_if_missing`
* `cdg_main`

### `gh/git-sig-lint.sh`

Scans recent Git commits and reports signature status.

CLI option notes:

* --repo PATH — repository path.
* --check-commits N — verify last N commits.
* --help — show help.

Functions/methods defined:

* `git_sig_lint`

### `gh/git-sync.sh`

Synchronises a Git repository with remote state using fetch/pull/push-style operations implemented by the script.

CLI option notes:

* --repo URL — repository URL.
* --dir PATH — target directory.
* --branch NAME — branch to use.
* --force — hard reset to origin/branch.
* --rebase — rebase local branch.
* --depth N — shallow clone/fetch depth; 0 means full.
* --dry-run — print commands only.
* --verbose — verbose output.
* --help — show help.
* Positional repo dir — accepted as shorthand.

Functions/methods defined:

* `print_help`
* `log`
* `die`
* `run`
* `is_positive_int`
* `get_remote_default_branch`
* `remote_branch_exists`

### `gh/git-verify-committer.sh`

Validates Git commit author/committer identity for recent commits.

CLI option notes:

* --commit SHA — commit/ref to inspect.
* --help — show help.

Functions/methods defined:

* `git_verify_debug`

### `gh/git-verify-identity.sh`

Validates the local repository Git identity configuration.

CLI option notes:

* --repo PATH — repository path.
* --help — show help.

Functions/methods defined:

* `git_identity_audit`

### `gh/github-manager.md`

Existing detailed guide for github-manager.ts.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `gh/github-manager.ts`

GitHub repository manager for inventory, pull, status, audit, remote listing, topic cloning, and sync-all workflows.

CLI option notes:

* --base-path PATH — base directory for local repos.
* --owner NAME — GitHub owner/user.
* --topic TOPIC — topic filter; repeatable.
* --author-email EMAIL — allowed author email; repeatable.
* --include-archived — include archived repos.
* --include-forks — include forks.
* --dry-run — preview changes.
* --verbose — extra output.
* --help — show help.
* Commands: inventory, pull, status, audit, audit-manual, remote-list, clone-by-topic, sync-all, help.

Functions/methods defined:

* `main`
* `parseArgs`
* `printHelp`
* `getCommandName`
* `isCommandName`
* `expandHomeDirectory`
* `log`
* `ensureCommandAvailable`
* `ensureGhAuthenticated`
* `execCommand`
* `inventoryLocalRepositories`
* `getCurrentBranch`
* `getUpstreamRef`
* `getDefaultRemoteName`
* `pullRepository`
* `showRepositoryChanges`
* `fetchRepository`
* `getGitMetadataPath`
* `getConflictFiles`
* `getDirtyFiles`
* `isMergeInProgress`
* `isRebaseInProgress`
* `isCherryPickInProgress`
* `isRevertInProgress`
* `getAheadBehind`
* `getRemoteOnlyCommits`
* `auditRepository`
* `printBrokenAuditResult`
* `printAuditResult`
* `requiresManualIntervention`
* `fetchRemoteRepositories`
* `fetchRemoteRepositoryInventory`
* `fetchRepositoryTags`
* `filterRepositoriesByTopics`
* `cloneRepositoryIfMissing`
* `parseJson`
* `isRecord`
* `isString`
* `isBoolean`
* `isNullableString`
* `isGhRepositorySummary`
* `isGhRepositorySummaryArray`
* `isGhRepositoryTag`
* `isGhRepositoryTagArray`

Requirements:

* Node.js 25+ per ensureNodeVersion(25).
* git.
* gh authenticated with gh auth login.

### `gh/label-migration.sh`

Migrates GitHub issue/PR labels between repositories or from a definition source using gh.

CLI option notes:

* --repo OWNER/REPO — repository to update; repeatable.
* --apply — apply changes; default is dry-run.
* --clear — remove existing labels before applying taxonomy; only with --apply.
* --verbose — detailed progress.
* --help — show help.

Functions/methods defined:

* `usage`
* `log`
* `info`
* `warn`
* `error`
* `die`
* `command_exists`
* `require_command`
* `verbose`
* `configure_gh_auth`
* `is_git_repository`
* `get_origin_url`
* `parse_github_repo_from_url`
* `detect_current_repo`
* `run_gh_label_create`
* `apply_labels_to_repo`
* `run_gh_label_delete`
* `clear_labels_for_repo`
* `main`
