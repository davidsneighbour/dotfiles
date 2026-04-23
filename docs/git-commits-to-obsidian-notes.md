# Daily Git commit reports to Obsidian daily notes

This setup adds Git commit summaries to an existing Obsidian daily note.

It's built around two scripts in `bashrc/helpers/daily-reports/`:

* `commits-to-notes.sh`
  * generates Markdown commit reports
  * supports one repository (`--repo`) or all direct child repositories in a folder (`--dir`)
  * supports one day (`--date`) or date ranges (`--from` + `--to`)

* `commit-report-to-dailynote.sh`
  * calls `commits-to-notes.sh`
  * appends successful output to matching Obsidian daily notes
  * supports one day (`--date`) or date ranges (`--from` + `--to`)

## Timezone handling

The reporting day is interpreted in a fixed timezone.

Default timezone:

* `Asia/Bangkok`

That means:

* the selected date is treated as a Bangkok day
* the commit timestamps shown in the note are also rendered in Bangkok time
* this stays consistent even if you travel or commit from another timezone

Example:

* report date: `2026-04-01`
* timezone: `Asia/Bangkok`

The script includes all commits that fall between:

* `2026-03-31 17:00:00 UTC`
* `2026-04-01 16:59:59 UTC`

This is intentional and correct for a Bangkok-based daily note workflow.

## Daily note path format

The target note path is built from the report date as:

`10 Daily Notes/YYYY/MM-MMMM/YYYY-MM-DD-DDDD.md`

Example for `2026-04-01`:

`10 Daily Notes/2026/04-April/2026-04-01-Wednesday.md`

## Markdown output format

Each repository block looks like this:

```markdown
### [davidsneighbour/dotfiles](https://github.com/davidsneighbour/dotfiles)

- 10:34 [[83c4571](https://github.com/davidsneighbour/dotfiles/commit/83c4571d1234567890abcdef1234567890abcd)] Fix shell completion
- 11:12 [[a1b2c3d](https://github.com/davidsneighbour/dotfiles/commit/a1b2c3d4e5f6789012345678901234567890abcd)] Add commit daily note workflow
```

Important details:

* one block per repository
* one list item per commit
* each block ends with two trailing newlines
* the runner appends blocks one repository at a time

## Requirements

The scripts expect:

* `bash`
* `git`
* `date` with GNU `date` features
* `obsidian` CLI
* repositories with a GitHub `origin` remote

Supported GitHub origin forms include:

* `git@github.com:owner/repo.git`
* `https://github.com/owner/repo.git`
* `ssh://git@github.com/owner/repo.git`

Repositories without a supported GitHub `origin` are skipped.

## Installation

Make both scripts executable:

```bash
chmod +x commits-to-notes.sh
chmod +x commit-report-to-dailynote.sh
```

Place them somewhere on your `PATH`, or reference them by absolute path.

Example helper path:

* `~/.dotfiles/bashrc/helpers/commits-to-notes.sh`
* `~/.dotfiles/bashrc/helpers/commit-report-to-dailynote.sh`

## Usage

### Generate output for one repository

Example with your requested sample values:

```bash
commits-to-notes.sh --repo ~/github.com/davidsneighbour/dotfiles --date 2026-04-01
```

Explicit timezone:

```bash
commits-to-notes.sh --repo ~/github.com/davidsneighbour/dotfiles --date 2026-04-01 --timezone Asia/Bangkok
```

### Append reports for all direct subfolders

Example with your requested sample values:

```bash
commit-report-to-dailynote.sh --date 2026-04-01 --dir ~/github.com/davidsneighbour
```

Explicit timezone:

```bash
commit-report-to-dailynote.sh --date 2026-04-01 --dir ~/github.com/davidsneighbour --timezone Asia/Bangkok
```

## How the runner behaves

For each direct subfolder of the selected base directory:

* if the folder is not a Git repository, it is skipped
* if Git commands fail, the issue is logged to STDERR and the script continues
* if the repository has no commits for that day, nothing is appended
* if the formatter returns output, that block is appended to the daily note
* if `obsidian append` fails, the failure is logged and the script continues

The script is intentionally tolerant towards repository problems.

## Example target directory

The examples in this README use:

`~/github.com/davidsneighbour`

The runner scans only the direct subfolders there, for example:

* `~/github.com/davidsneighbour/dotfiles`
* `~/github.com/davidsneighbour/hugo-darkskies`
* `~/github.com/davidsneighbour/kollitsch.dev`

## Example Obsidian append call

The runner internally uses the same pattern as this working example:

```bash
obsidian append path="10 Daily Notes/2026/04-April/2026-04-01-Wednesday.md" content="### [davidsneighbour/dotfiles](https://github.com/davidsneighbour/dotfiles)

- 10:34 [[83c4571](https://github.com/davidsneighbour/dotfiles/commit/83c4571d1234567890abcdef1234567890abcd)] Fix shell completion


"
```

## Cron example

Run every morning at 07:15 for the previous day:

```cron
15 7 * * * /home/patrick/.dotfiles/bashrc/helpers/commit-report-to-dailynote.sh --date "$(date -d 'yesterday' +\%F)" --dir "/home/patrick/github.com/davidsneighbour" --timezone "Asia/Bangkok" >> "/home/patrick/.logs/commit-report-to-dailynote.log" 2>&1
```

## Notes and limitations

* The daily note is assumed to already exist.
* Re-running the script for the same day will append duplicate blocks.
* Only repositories with a recognised GitHub `origin` are included.
* Commit subjects are used as-is from Git.
* The runner scans only one level below the selected base directory.

## Suggested file layout

Example:

```text
~/.dotfiles/bashrc/helpers/commits-to-notes.sh
~/.dotfiles/bashrc/helpers/commit-report-to-dailynote.sh
~/.dotfiles/bashrc/helpers/README-commit-to-notes.md
```

## Quick test commands

Generate a single repository block:

```bash
commits-to-notes.sh --repo ~/github.com/davidsneighbour/dotfiles --date 2026-04-01 --timezone Asia/Bangkok
```

Append all repository blocks for the same day:

```bash
commit-report-to-dailynote.sh --date 2026-04-01 --dir ~/github.com/davidsneighbour --timezone Asia/Bangkok
```

## ToDo

* [ ] add environment variable support for
  * [ ] default timezone
  * [ ] default base directory for obsidian notes
  * [ ] date path format of the daily notes
