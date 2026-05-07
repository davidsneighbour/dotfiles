# GitHub repository manager

A small TypeScript CLI to manage local Git repositories and compare them with repositories on GitHub via `gh`.

It is built to work with a local repository root such as `~/github.com/davidsneighbour`, where each direct subfolder is expected to be a Git repository.

## Features

* Scan a base directory and take inventory of all Git repositories inside it
* Pull updates for each local repository from its upstream or default remote
* Show local uncommitted changes, while staying silent for clean repositories
* Audit repositories for:
  * sync state
  * dirty working tree state
  * conflicted or interrupted Git state
  * remote-only commits
  * remote-only commits by authors outside your allowlist
  * broken repositories that require manual inspection
* Query GitHub repositories for a given owner via `gh`
* Retrieve repository metadata such as description, homepage, visibility, default branch, topics, latest release, and tags
* Clone repositories that match one or more GitHub repository topics
* Continue with the next repository when a single repository fails during `pull`, `status`, `audit`, or clone operations

## Requirements

* Node.js 22 or newer
* `git`
* `gh` (GitHub CLI)
* A valid GitHub CLI login via `gh auth login`

## File

Save the script as:

`github-manager.ts`

## Installation and setup

### 1. Make sure dependencies are available

Check that the required tools are installed:

```bash
node --version
git --version
gh --version
```

### 2. Authenticate GitHub CLI

The script uses `gh` for all GitHub-related operations. Log in once:

```bash
gh auth login
```

You can verify the login with:

```bash
gh auth status
```

### 3. Make the script executable

```bash
chmod +x github-manager.ts
```

### 4. Run it

You can run it directly with Node.js:

```bash
node github-manager.ts --help
```

Or, if your system honours the shebang:

```bash
./github-manager.ts --help
```

## Default behaviour

By default, the script assumes:

* Base path: `~/github.com/davidsneighbour`
* GitHub owner: `davidsneighbour`

That means local inventory and local Git operations run against the folder above, while remote GitHub operations query the GitHub account or organisation named `davidsneighbour`.

## Important note about tags vs labels vs topics

This script works with GitHub repository *topics* when filtering repositories on GitHub.

That matters because GitHub terminology is easy to mix up:

* *Git tags* are version markers in a repository, such as `v1.0.0`
* *Issue labels* belong to issues and pull requests
* *Repository topics* are metadata used to classify repositories

For repository filtering, this script uses *topics*. That is what `gh repo list --topic ...` supports.

So when this README mentions categorising repositories, the actual GitHub feature used is *topics*.

## Failure behaviour

The script has two levels of failure handling.

### Global failures

These stop the whole run immediately.

Examples:

* `git` is not available in `PATH`
* `gh` is not available in `PATH`
* `gh` is not authenticated
* the configured base path does not exist

### Per-repository failures

These do **not** stop the whole run.

Examples:

* a repository fails during `git pull`
* a repository fails during `git fetch --prune`
* a repository has broken submodule fetch behaviour
* a repository is in an unusual or partially broken Git state

In those cases, the script:

* prints an error for that repository
* marks the repository as broken where applicable
* continues with the next repository

This is especially important for `audit`, where a broken repository is reported with:

* `broken: yes`
* `manual-check-required: yes`

## Usage

```bash
node github-manager.ts <command> [options]
```

## Commands

### `inventory`

List all local Git repositories inside the base path.

This checks direct subfolders of the configured base directory and prints repository details such as current branch, upstream, and remote.

```bash
node github-manager.ts inventory
```

Example with explicit base path:

```bash
node github-manager.ts inventory --base-path ~/github.com/davidsneighbour
```

### `pull`

Pull updates for each local repository.

Behaviour:

* If the current branch has an upstream configured, the script runs `git pull --ff-only`
* If no upstream is configured, it falls back to the detected default remote plus current branch
* If no remote can be determined, the repository is skipped with a warning
* If one repository fails, the script reports it and continues with the next one

```bash
node github-manager.ts pull
```

Dry run example:

```bash
node github-manager.ts pull --dry-run
```

Verbose example:

```bash
node github-manager.ts pull --verbose
```

### `status`

Show local uncommitted changes.

The script runs `git status --short` in each repository and prints output only when there are changes. Clean repositories stay silent.

If a repository fails during status collection, the script reports the error and continues.

```bash
node github-manager.ts status
```

Verbose example:

```bash
node github-manager.ts status --verbose
```

### `audit`

Audit local repositories for operational health.

This command is intended to answer the practical question:

*Is this repository currently in a healthy, usable state on this machine?*

The audit checks:

* whether the repository has an upstream configured
* whether the local branch is in sync with upstream
* whether the working tree is dirty
* whether unresolved conflicts exist
* whether merge, rebase, cherry-pick, or revert is in progress
* whether the repository is ahead, behind, or diverged
* whether remote-only commits exist
* whether remote-only commits are by authors outside your configured allowlist
* whether the repository is broken and requires manual inspection

```bash
node github-manager.ts audit
```

With author email allowlist:

```bash
node github-manager.ts audit \
  --author-email patrick@example.com \
  --author-email hello@davidsneighbour.com
```

#### Health model

A repository is considered operationally OK only when all of these are true:

* it has an upstream
* it is in sync with upstream
* it is not dirty
* it is not conflicted
* it is not in an interrupted Git state

That result is reported as:

* `state-ok: yes`
* `state-ok: no`

#### Author allowlist

The `--author-email` values are used only for *classification* of remote-only commits.

They answer this extra question:

*Are the commits that only exist on upstream authored by someone outside my expected identities?*

This is useful, but it is **not** the main health rule.

A repository can still be not OK even if all remote-only commits are yours, for example when you worked on another machine and this machine is now behind upstream.

#### Broken repositories

If audit cannot complete properly for a repository, the script does not abort the whole run.

Instead, it prints a broken marker such as:

```text
repo-name
  upstream: origin/main
  state-ok: no
  in-sync: no
  dirty: no
  conflicted: no
  diverged: no
  ahead: 0
  behind: 0
  broken: yes
  remote-commits-by-others: no
  manual-check-required: yes
  reason: Command failed: git fetch --prune
```

That means you need to inspect that repository manually.

### `remote-list`

Query GitHub for repositories owned by the configured user or organisation and show metadata plus Git tags.

This includes:

* description
* homepage
* visibility
* archived state
* fork state
* default branch
* latest release
* repository topics
* Git tags

If tag retrieval fails for one repository, the script continues and prints the rest.

```bash
node github-manager.ts remote-list --owner davidsneighbour
```

### `clone-by-topic`

Clone repositories from GitHub that match one or more repository topics.

If the local destination folder already exists, the repository is skipped.

If cloning a particular repository fails, the script reports the error and continues with the next one.

```bash
node github-manager.ts clone-by-topic --topic hugo
```

Multiple topics:

```bash
node github-manager.ts clone-by-topic --topic hugo --topic astro
```

Current behaviour for multiple topics is strict matching:

* a repository must contain *all* requested topics to match

### `sync-all`

Run a combined workflow:

* pull local repositories
* show local changes
* audit repository health
* optionally clone repositories by topic if one or more `--topic` values are supplied

Failures in individual repositories are reported and do not stop the rest of the run.

```bash
node github-manager.ts sync-all
```

With topic-based clone support:

```bash
node github-manager.ts sync-all --topic hugo
```

## Options

### `--base-path <path>`

Base directory to scan for local repositories.

Default:

`~/github.com/davidsneighbour`

Example:

```bash
node github-manager.ts inventory --base-path ~/github.com/davidsneighbour
```

### `--owner <name>`

GitHub owner or organisation name to query.

Default:

`davidsneighbour`

Example:

```bash
node github-manager.ts remote-list --owner davidsneighbour
```

### `--topic <topic>`

Repository topic filter. Repeatable.

Example:

```bash
node github-manager.ts clone-by-topic --topic astro --topic tailwind
```

### `--author-email <email>`

Allowed commit author email for audit classification. Repeatable.

These values are used to mark remote-only upstream commits as either:

* `ours=yes`
* `ours=no`

Example:

```bash
node github-manager.ts audit \
  --author-email patrick@example.com \
  --author-email hello@davidsneighbour.com
```

### `--include-archived`

Include archived repositories in remote GitHub queries.

By default, archived repositories are excluded.

Example:

```bash
node github-manager.ts remote-list --include-archived
```

### `--include-forks`

Include fork repositories in remote GitHub queries.

By default, forks are excluded.

Example:

```bash
node github-manager.ts remote-list --include-forks
```

### `--dry-run`

Print intended actions without making changes.

Useful for:

* testing pull operations
* testing clone operations
* checking planned behaviour before execution

Example:

```bash
node github-manager.ts sync-all --topic hugo --dry-run
```

### `--verbose`

Show additional debug output.

Useful for troubleshooting skipped directories, repository detection, tag retrieval, audit details, and clone decisions.

```bash
node github-manager.ts inventory --verbose
```

### `--help`

Show command help.

```bash
node github-manager.ts --help
```

## Examples

### List all local repositories

```bash
node github-manager.ts inventory
```

### Pull all local repositories

```bash
node github-manager.ts pull
```

### Show local changes only

```bash
node github-manager.ts status
```

### Audit health of all local repositories

```bash
node github-manager.ts audit
```

### Audit with expected author identities

```bash
node github-manager.ts audit \
  --author-email patrick@example.com \
  --author-email hello@davidsneighbour.com
```

### Show remote GitHub repository metadata

```bash
node github-manager.ts remote-list --owner davidsneighbour
```

### Clone all repositories tagged with a topic

```bash
node github-manager.ts clone-by-topic --owner davidsneighbour --topic hugo
```

### Clone repositories matching multiple topics

```bash
node github-manager.ts clone-by-topic --topic astro --topic tailwind
```

### Full sync with dry run

```bash
node github-manager.ts sync-all --topic hugo --dry-run --verbose
```

## How local repository detection works

The script scans only the direct children of the configured base path.

Example:

If the base path is:

`~/github.com/davidsneighbour`

then the script checks folders such as:

* `~/github.com/davidsneighbour/repo-one`
* `~/github.com/davidsneighbour/repo-two`

A folder counts as a repository when it contains `.git`.

It currently does not recurse into deeper nested folder structures.

## How pull behaviour works

For each detected repository:

1. Try to detect the current branch
2. Try to detect the branch upstream
3. Try to detect the remote name
4. Pull conservatively with `--ff-only`

This design avoids accidental merge commits during bulk updates.

If a repository has a properly configured upstream branch, the script uses:

```bash
git pull --ff-only
```

If no upstream is configured, it falls back to:

```bash
git pull --ff-only <remote> <branch>
```

If the remote or branch cannot be determined, the repository is skipped.

If the pull fails for one repository, the script reports it and continues.

## How audit works

The audit command first tries to fetch repository state:

```bash
git fetch --prune
```

Then it checks:

### Dirty working tree

Using:

```bash
git status --short
```

### Unresolved conflict files

Using:

```bash
git diff --name-only --diff-filter=U
```

### Interrupted Git states

By checking for Git metadata such as:

* `MERGE_HEAD`
* `rebase-merge`
* `rebase-apply`
* `CHERRY_PICK_HEAD`
* `REVERT_HEAD`

### Ahead and behind counts

Using:

```bash
git rev-list --left-right --count HEAD...@{upstream}
```

### Remote-only upstream commits

Using:

```bash
git log HEAD..@{upstream} --format=%H%x09%an%x09%ae
```

This produces the extra classification:

* `remote-commits-by-others: yes/no`

## Audit output overview

### Healthy repository

A healthy repository in verbose mode may look like this:

```text
repo-one
  upstream: origin/main
  state-ok: yes
  in-sync: yes
  dirty: no
  conflicted: no
  diverged: no
  ahead: 0
  behind: 0
  broken: no
  remote-commits-by-others: no
```

By default, healthy repositories are hidden unless `--verbose` is used.

### Repository behind upstream

```text
repo-two
  upstream: origin/main
  state-ok: no
  in-sync: no
  dirty: no
  conflicted: no
  diverged: no
  ahead: 0
  behind: 2
  broken: no
  remote-commits-by-others: no
  remote-only-commits:
    abc1234 Patrick Kollitsch <patrick@example.com> ours=yes
    def5678 Patrick Kollitsch <patrick@example.com> ours=yes
```

Even though the commits are yours, the repository is still not OK because it is behind upstream.

### Repository with conflicts

```text
repo-three
  upstream: origin/main
  state-ok: no
  in-sync: no
  dirty: yes
  conflicted: yes
  diverged: no
  ahead: 0
  behind: 0
  broken: no
  remote-commits-by-others: no
  merge-in-progress: yes
  conflict-files: src/index.ts, README.md
```

### Broken repository

```text
repo-four
  upstream: origin/main
  state-ok: no
  in-sync: no
  dirty: no
  conflicted: no
  diverged: no
  ahead: 0
  behind: 0
  broken: yes
  remote-commits-by-others: no
  manual-check-required: yes
  reason: Command failed: git fetch --prune
```

## How remote GitHub lookup works

The script uses `gh` instead of directly managing tokens or building raw HTTP requests internally.

It uses two GitHub data paths:

* `gh repo list` to retrieve repository summaries
* `gh api repos/<owner>/<repo>/tags` to retrieve Git tags

This keeps the script simple and relies on the existing `gh` authentication setup.

## Output overview

### Inventory output

Example:

```text
repo-one | path=/home/patrick/github.com/davidsneighbour/repo-one | branch=main | upstream=origin/main | remote=origin
repo-two | path=/home/patrick/github.com/davidsneighbour/repo-two | branch=develop | upstream=origin/develop | remote=origin
```

### Status output

Only repositories with changes are shown:

```text
repo-one
 M README.md
?? notes.txt
```

Clean repositories do not print anything.

### Remote list output

Example:

```text
davidsneighbour/repo-one
  description: Example repository
  homepage: https://example.com
  visibility: PUBLIC
  archived: false
  fork: false
  default-branch: main
  latest-release: v1.2.0
  topics: astro, tailwind, blog
  tags: v1.2.0, v1.1.0, v1.0.0
```

## Extending the script

The script is intentionally structured around discrete commands and helper functions.

The main extension points are:

* command registry
* local repository inventory
* GitHub repository fetch functions
* clone and pull workflows
* topic filtering
* audit classification and reporting
* per-repository error wrappers

Useful future additions could include:

* `missing-local` to list remote repositories that are not cloned locally
* `missing-remote` to list local repositories that no longer exist on GitHub
* `fetch` to run `git fetch --all --prune` across all local repositories
* `json` output mode for machine-readable automation
* a config file such as `repo-manager.config.json`
* recursive directory scanning
* topic filter modes such as `any` vs `all`
* checks for dirty working trees before pull
* support for organisations and personal accounts in one config

## Limitations

Current behaviour has a few intentional limits:

* Only direct subfolders of the base path are scanned
* Topic filtering requires all requested topics to be present
* The script assumes `gh` authentication is already configured
* Remote metadata is limited to fields currently requested in the script
* Tag retrieval requests up to 100 tags per repository in the current implementation
* Pull uses `--ff-only`, so repositories that require a merge or rebase will fail rather than auto-resolve
* Audit relies on local Git metadata and author email values, not GitHub actor resolution
* The `.git` handling is suitable for standard repositories, but unusual layouts may still require manual checking

## Troubleshooting

### `Required command "gh" is not available in PATH.`

Install GitHub CLI and make sure it is available in your shell `PATH`.

### `GitHub CLI is not authenticated. Run "gh auth login" first.`

Log in with:

```bash
gh auth login
```

### `Base path does not exist`

Make sure the configured base path exists:

```bash
node github-manager.ts inventory --base-path ~/github.com/davidsneighbour
```

### A repository is skipped during pull

Common reasons:

* no remote exists
* current branch could not be determined
* the repository is not in a normal Git state
* `git pull --ff-only` would require a merge or rebase

### Audit reports `broken: yes`

That means the repository could not be checked cleanly and needs manual inspection.

Typical causes:

* submodule fetch failures
* broken remotes
* unusual Git internals
* partial clone or submodule issues
* local repository corruption

### A repository is not detected locally

The script only looks at direct child folders and only counts folders containing `.git`.

## Recommended workflow

A practical workflow could be:

1. Run inventory
2. Run pull
3. Run status
4. Run audit
5. Run remote-list when you want to inspect GitHub-side metadata
6. Run clone-by-topic when you want to bring in a set of related repositories

Example:

```bash
node github-manager.ts inventory --verbose
node github-manager.ts pull --verbose
node github-manager.ts status
node github-manager.ts audit --author-email patrick@example.com
node github-manager.ts clone-by-topic --topic astro --dry-run
```
