# Implementation plan: dotfiles-managed global skills

Objective: Track third-party skills installed through `npx skills` in the dotfiles repository, allowing reproducible installations across workstations without committing downloaded skill contents.

Selected architecture: A Git-tracked project `skills-lock.json`, a Bash management wrapper, and per-skill symlinks into global agent directories.

## 1. Repository structure

```bash
dotfiles/
└── configs/
    └── agents/
        ├── README.md
        ├── skills-lock.json
        ├── install-skills.sh
        ├── .gitignore
        └── .agents/
            └── skills/          # Ignored; managed by skills CLI
```

The installer must use its own location to resolve repository paths, not the current working directory.

Keep self-authored skills separate from third-party downloads, committed in their respective source repositories.

## 2. Installation model

Use `configs/agents/` as the dedicated project installation location.

1. Add a skill through `npx skills add`, selecting Claude Code and Codex as required.
2. Let the CLI generate or update `skills-lock.json`.
3. Commit only the lockfile and supporting management files.
4. Run the installer to synchronise the tracked skills with global agent skill directories.

Canonical installed skills live under the dotfiles-managed `.agents/skills/`. Global directories contain individual links, not symlinked directories.

Expected global targets:

```bash
~/.claude/skills/<skill-name>
~/.codex/skills/<skill-name>
```

Confirm the installed CLI's actual directory conventions before implementing the links.

## 3. Management commands

Implement one Bash script with these named operations:

| Command | Behaviour |
| ----------- | ---------------------------------------------------- |
| `--help` | Show commands, options and examples |
| `--install` | Restore locked skills and synchronise links |
| `--check` | Verify installations, lockfile consistency and links |
| `--update` | Update tracked skills and regenerate the lockfile |
| `--list` | Display managed, unmanaged and missing skills |
| `--dry-run` | Show intended changes without modifying anything |
| `--verbose` | Show detailed operations |

Also support `--yes` for unattended execution and `--strict` for validation failures.

The script must return non-zero exit codes for genuine errors and provide actionable error messages.

## 4. Lockfile restoration

First test the native restore command:

```bash
npx skills experimental_install --frozen-lockfile
```

Verify that it restores every recorded skill and preserves the intended source revisions.

If that works, use it directly. If not, implement a narrowly scoped compatibility layer that reads the lockfile without altering its schema.

Don't invent a second lockfile unless the CLI's format proves insufficient.

## 5. Symlink management

The script should:

* Create only individual skill symlinks.
* Preserve existing unmanaged skills.
* Detect conflicting files and links.
* Refuse to overwrite conflicts by default.
* Track which links it owns.
* Repair broken managed links.
* Never delete unmanaged skills.
* Handle partially completed installations safely.

Keep management metadata outside the lockfile so the CLI can continue to manage its own format.

If multiple skills have the same directory name, report the collision instead of silently choosing one.

## 6. Dotbot integration

Add the installer to the existing Dotbot provisioning process.

The Dotbot stage should:

* Verify that Node.js and `npx` are available.
* Restore the recorded skills.
* Reconcile managed global links.
* Run without interactive prompts.
* Be idempotent across repeated executions.
* Preserve unrelated global skill installations.

Use the repository's existing Node execution wrapper where appropriate.

A missing dependency should produce a clear failure rather than silently skipping skill installation.

## 7. Updates and drift detection

The native CLI has had inconsistencies between project and global lockfile handling. There is also an open upstream proposal addressing lockfile reconciliation. Therefore, don't assume `skills check` and `skills update` correctly reconcile the project lockfile without testing.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1

Implement checks for:

* Skills present in the lockfile but missing locally.
* Locally installed skills absent from the lockfile.
* Broken or incorrectly targeted global symlinks.
* Changes to the lockfile after an update.
* Agent-specific installations not matching the configured targets.

The update operation should modify the project lockfile deliberately, never silently upgrade skills during workstation bootstrap.

## 8. Initial migration

Before switching to the new system:

1. Inventory current global installations using `npx skills ls -g --json`.
2. Inspect the existing global lockfile and agent directories.
3. Identify duplicate skill names and locally maintained skills.
4. Reinstall selected third-party skills into the dotfiles project to generate its lockfile.
5. Verify restored copies before linking them globally.
6. Replace existing global installations only when their ownership and sources are confirmed.
7. Preserve untracked installations until explicitly reviewed.

Do not automatically delete existing global installations during migration.

## 9. Testing and acceptance criteria

| Scenario | Expected result |
| ----------------------------- | --------------------------------------------- |
| Fresh workstation | All tracked skills restored and linked |
| Repeated installation | No unnecessary changes |
| Missing skill directory | Skill restored |
| Broken managed symlink | Link repaired |
| Existing unmanaged skill | Left untouched |
| Conflicting skill name | Clear error, no overwrite |
| Offline or unavailable source | Actionable failure, existing skills preserved |
| Lockfile/content mismatch | Restore fails without changing lockfile |
| Update available | Reported; no automatic bootstrap update |
| Skill removed from lockfile | Reported; cleanup requires explicit approval |

Test against an isolated temporary `HOME` before touching existing installations.

## 10. Implementation phases

1

Investigate and inventory

Inspect the existing dotfiles structure, Dotbot configuration, Node wrapper, global skills and installed CLI version. Confirm lockfile behaviour and installation paths.

Deliverable: verified architecture and migration inventory

2

Build the manager

Create the management script, tracked lockfile, ignore rules, ownership tracking and documentation.

Deliverable: working installer with validation and dry-run support

3

Migrate existing skills

Import selected third-party skills, verify restored contents and reconcile agent symlinks without disturbing unmanaged installations.

Deliverable: reproducible manifest reflecting intended global skills

4

Integrate and test

Add Dotbot provisioning, test clean installs and repeat runs, and validate error recovery.

Deliverable: automated workstation provisioning

## 11. Final design decisions

* Repository: existing `davidsneighbour/dotfiles`, no separate repository.
* Manifest: native `skills-lock.json`, no custom replacement format.
* Downloaded skills: ignored by Git.
* Canonical installation: project `.agents/skills/` directory.
* Global exposure: individual symlinks for Claude Code and Codex.
* Provisioning: Dotbot invokes the Bash manager.
* Updates: explicit, never automatic during bootstrap.
* Safety: unmanaged skills are preserved.
* Custom skills: remain under version control in their originating repositories.
* Compatibility: pin or explicitly validate the skills CLI version, particularly while restoration remains experimental.

### Implementation constraint

The project's skill lockfile records sources and hashes, but should not be assumed to preserve your desired per-agent assignment. Initially, configure both Claude Code and Codex as targets for all managed skills. If different agent assignments become necessary, add a small separate configuration file for that purpose rather than modifying the CLI's lockfile schema.

Definition of done: On a clean Xubuntu workstation, running the normal dotfiles bootstrap restores every tracked skill, exposes it to the configured agents and leaves existing unmanaged skills untouched, without requiring interactive input.

Upstream references: [Skills CLI command reference](https://github.com/vercel-labs/skills/blob/main/docs/commands.md?utm_source=chatgpt.com) · [Lockfile reconciliation discussion](https://github.com/vercel-labs/skills/issues/2560?utm_source=chatgpt.com)
