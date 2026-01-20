## Introducing `dnb_repo_config_get`: repository-local configuration for dotfiles

Over time, repositories tend to accumulate small, implicit bits of metadata. A launcher icon here, a role or visibility flag there, a note about what this repo is actually for. This information usually ends up scattered across scripts, README files, or worse, hard-coded into tooling.

`dnb_repo_config_get` introduces a small, explicit, repository-local configuration scheme that lives alongside your code and can be queried consistently from the command line and from scripts.

The goal is deliberately narrow:

* Per-repository metadata
* Stored in a predictable place
* Optional by default
* Zero noise when absent
* Easy to consume from Bash

No more, no less.

## Design overview

Each repository *may* define a TOML configuration file at `.github/dnb.toml`. The file either exists or it does not.

* If it exists, it is parsed and queried.
* If it does not exist, nothing breaks.
* Consumers receive a clear `false` signal and can decide what to do.

The accessor is a single Bash function:

```bash
dnb_repo_config_get
```

This function is shipped via your dotfiles, lives in:

```bash
bin/helpers/dnb_repo_config.sh
```

and is available on the CLI via `PATH`.

## Why TOML

TOML hits a pragmatic sweet spot:

* Readable and writable by humans
* Explicit typing
* First-class support for nested structures
* Safe to parse using standard tooling

No ad-hoc parsing, no fragile conventions.

## Repository root resolution

The repository root is resolved using Git:

```bash
git rev-parse --show-toplevel
```

This has important consequences:

* Works reliably with subdirectories, worktrees, and submodules
* Avoids manual directory traversal
* Fails cleanly outside Git repositories

If you are not inside a Git repository, the function simply returns `false`.

## Basic configuration example

A minimal `.github/dnb.toml`:

```toml
[launcher]
icon = "material-symbols-rounded:globe"
```

Querying it:

```bash
dnb_repo_config_get launcher.icon
```

Output:

```plaintext
material-symbols-rounded:globe
```

Exit code:

```bash
0
```

## Nested sections and dotted paths

Nested TOML tables map directly to dotted query paths.

Example:

```toml
[meta]
owner = "davidsneighbour"

[meta.social]
bluesky = "@davidsneighbour"
```

Queries:

```bash
dnb_repo_config_get meta.owner
dnb_repo_config_get meta.social.bluesky
```

Output:

```plaintext
davidsneighbour
@davidsneighbour
```

The path separator is always `.` (dot).

* Keys containing literal dots are intentionally not supported.
* This keeps the Bash interface simple and predictable.

## Supported value types

The function supports the following TOML value types:

### Strings

```toml
[repo]
notes = ""
```

```bash
dnb_repo_config_get repo.notes
```

* Empty strings are valid.
* They return exit code `0`.
* They print nothing to stdout.

This avoids conflating “missing” with “intentionally empty”.

### Numbers

```toml
[repo]
priority = 10
```

```bash
dnb_repo_config_get repo.priority
```

Output:

```plaintext
10
```

### Booleans

```toml
[repo]
archived = false
```

```bash
dnb_repo_config_get repo.archived
```

Output:

```plaintext
false
```

Exit code:

```plaintext
0
```

Note that this is distinct from a missing key, which also prints `false` but exits with code `1`.

### Arrays

```toml
[repo]
tags = ["dotfiles", "infra", "cli"]
```

```bash
dnb_repo_config_get repo.tags
```

Output:

```plaintext
dotfiles
infra
cli
```

Arrays are printed one item per line, making them easy to consume in shell pipelines.

### Tables (objects)

Tables themselves are not returned.

```toml
[repo]
[repo.meta]
created_by = "patrick"
```

```bash
dnb_repo_config_get repo.meta
```

Output:

```plaintext
false
```

Exit code:

```plaintext
1
```

Tables are treated as structural containers, not values.

## Missing keys and missing config

If any of the following apply:

* `.github/dnb.toml` does not exist
* The key path does not exist
* You are not inside a Git repository

Then:

```bash
dnb_repo_config_get something.missing
```

Output:

```plaintext
false
```

Exit code:

```plaintext
1
```

No error messages. No noise. This is the expected control path.

## Error handling

The only time stderr is used is for *actual errors*:

* Invalid TOML
* No TOML parser available (Python < 3.11 without `tomli`)

Example stderr:

```plaintext
dnb_repo_config_get: TOML parse error: ...
```

Stdout still prints:

```plaintext
false
```

Exit code:

```plaintext
2
```

This allows tooling to distinguish between “not configured” and “broken configuration”.

## Discoverability: listing available keys

To inspect what a repository exposes:

```bash
dnb_repo_config_get --list-keys
```

Example output:

```plaintext
launcher.icon
repo.role
repo.visibility
repo.notes
```

This is particularly useful for:

* Debugging
* Writing shell completions
* Exploring unfamiliar repositories

---

## Documented schema

The function exposes a documented, human-readable schema via `--help`.

```bash
dnb_repo_config_get --help
```

Excerpt:

```plaintext
Schema (documented contract, informational):
  launcher.icon        (string)
    Icon identifier for your launcher.

  launcher.name        (string, optional)
    Human-readable name override.

  launcher.group       (string, optional)
    Launcher grouping/category.

  repo.role            (string)
    One of: dotfiles, client, product, lab, archive

  repo.visibility      (string)
    One of: public, private

  repo.notes           (string, optional)
    Short freeform description.
```

Important points:

* The schema is **informational**, not enforced.
* It documents intent, not constraints.
* Enforcement can be added later without breaking consumers.

## Typical usage patterns

### Conditional behaviour in scripts

```bash
icon="$(dnb_repo_config_get launcher.icon)"

if [[ "${icon}" != "false" ]]; then
  launch_with_icon "${icon}"
fi
```

### Defaulting with fallback

```bash
role="$(dnb_repo_config_get repo.role)"
[[ "${role}" == "false" ]] && role="unknown"
```

### Looping over tags

```bash
while read -r tag; do
  echo "Tag: ${tag}"
done < <(dnb_repo_config_get repo.tags)
```

## What this deliberately does not do

By design, `dnb_repo_config_get` does *not*:

* Validate schema correctness
* Enforce enums or types
* Write configuration
* Modify repositories
* Depend on non-standard CLI tools

Those concerns belong in separate, explicit commands if and when they become necessary.

## Closing thoughts

This approach treats repository metadata as a first-class concept without turning it into a system.

* Local, optional configuration
* Clear contracts
* Minimal surface area
* Shell-friendly semantics

It is intentionally boring. That is exactly why it works.
