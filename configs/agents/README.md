# Agent configuration

This folder holds the shared configuration for Claude Code and Codex: the global instructions and the third-party skills.

## Global agent instructions

[global-agents-instructions.md](global-agents-instructions.md) contains the user-wide instructions loaded by Claude Code and Codex in every session. It is not a repository instruction file. Its source filename avoids automatic discovery as a local `AGENTS.md` or `CLAUDE.md`.

The [Dotbot AI profile](../dotbot/config.ai.yaml) links this source to `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. Edit the source here to update the shared instructions.

## Third-party skills

Third-party skills are skills that other people publish, for example on GitHub, and that you install with the [skills CLI](https://github.com/vercel-labs/skills) (`npx skills`). This folder is a skills CLI project. Git tracks only the lockfile and the management files. The downloaded skill content is not committed. Every workstation restores the same skills from the lockfile.

Your own skills do not belong here. They stay under version control in their source repositories (`skillwerk`, `skills`) and [`skillz`](../../bashrc/helpers/skillz) links them.

### Files

| File | Purpose |
| --- | --- |
| `skills-lock.json` | The skills CLI project lockfile. It records the source and the content hash of every tracked skill. The skills CLI writes it. Do not edit it by hand. |
| `install-skills.sh` | The manager: restores, verifies, links, checks, updates, lists, and prunes. |
| `skills-state.ts` | Helper for `install-skills.sh`. It validates the lockfile and compares every installed skill with its recorded hash. |
| `tests/install-skills-test.sh` | Offline tests for the manager (part of `npm run test:shell`). |
| `.gitignore` | Ignores `.agents/` (the restored skills) and the per-agent folders that the skills CLI can create here (`.claude/`, `agent/`). |
| `.agents/skills/<name>/` | The restored skills (canonical copies). Ignored by Git. |

### How it works

1. The skills CLI restores every skill from `skills-lock.json` into `.agents/skills/`. The manager uses `npx skills experimental_install --frozen-lockfile`, so a restore never changes the lockfile. If the downloaded content does not match the recorded hash, the restore fails.
2. The manager computes the hash of every restored skill and compares it with the lockfile. It links only verified skills.
3. The manager links every verified skill into each agent skill folder, one symbolic link for each skill: `~/.claude/skills/<name>` and `~/.codex/skills/<name>`. The agent folders stay real folders.

All tracked skills go to both agents. The lockfile does not record agent assignments. If different assignments become necessary, add a small separate configuration file. Do not change the lockfile schema.

### Ownership and safety

A global entry is *managed* only when it is a symbolic link into `configs/agents/.agents/skills/`. The manager needs no other state: the link target is the ownership record. All other entries are *unmanaged* and the manager never changes them. Unmanaged entries include real folders, files, the `skillz` links, and the `.system` and `synced` folders of the agents.

* If an unmanaged entry has the same name as a tracked skill, this is a conflict. The manager reports an error and overwrites nothing.
* The manager repairs broken managed links and managed links with a wrong target.
* A managed link whose skill is no longer in the lockfile is an orphan. The manager reports it. Only `--prune` removes it, after confirmation or with `--yes`.
* A failed or interrupted restore keeps the skills that are already installed. The next `--install` restores the missing skills. A skill folder without a `SKILL.md` counts as missing.
* Operations that change files take a lock (`~/.local/state/dotfiles/agent-skills.lock`), so two runs cannot interfere.
* `skillz` does not remove or replace managed links. It also stops with an error if one of your own skills has the same name as a tracked third-party skill.

### Commands

Run the manager with one operation. Without arguments it shows the help.

```bash
configs/agents/install-skills.sh --install --yes    # restore and link (used by Dotbot)
configs/agents/install-skills.sh --install --dry-run
configs/agents/install-skills.sh --check            # read-only and offline
configs/agents/install-skills.sh --check --strict   # warnings also fail
configs/agents/install-skills.sh --list             # table of all skills and link states
configs/agents/install-skills.sh --update --dry-run # report available updates
configs/agents/install-skills.sh --update           # update after confirmation
configs/agents/install-skills.sh --prune --dry-run
```

| Operation | Behaviour |
| --- | --- |
| `--install` | Restores missing skills (network access is needed only then), verifies the hashes, and creates or repairs the managed links. It never updates a skill. A skill with local changes is an error. `--install --force` reinstalls it and keeps the local copy if the reinstall fails. |
| `--check` | Verifies the lockfile, the hashes, and every link. It also reports orphans, untracked folders in `.agents/skills/`, unexpected folders in this folder, tracked skills that are also installed in `~/.agents/skills`, and an uncommitted or untracked lockfile. |
| `--update` | Copies the project to a temporary folder and runs `npx skills update --project` there. Then it shows the lockfile diff, verifies the new content, and asks for confirmation (or uses `--yes`). It refuses to run when `skills-lock.json` has uncommitted changes. |
| `--list` | Prints `NAME`, `STATUS` (`managed`, `missing`, `modified`, `untracked`, `orphaned`, `unmanaged`), `SOURCE`, and the link state for each agent. |
| `--prune` | Removes orphaned managed links and untracked folders in `.agents/skills/`. It never removes unmanaged entries. |

Options: `--dry-run`, `--yes`, `--strict`, `--force` (only with `--install`), `--verbose`, `--quiet`, and `--help`.

Exit status: `0` success, `1` a problem was found or an operation failed, `2` usage error, `3` Node.js or npx missing, or confirmation was needed without a terminal. Every run writes a log to `~/.logs/agent-skills/YYYYMMDD-HHMMSS.log`. The log also contains the skills CLI output.

The manager finds `node` and `npx` through `PATH` first. If they are not there, it uses the NVM runtime behind `~/.local/bin/node-cron` (see [Node runtime maintenance](../../docs/node-runtime.md)).

### Add a skill

Run the pinned CLI in this folder. Select Codex: the universal `.agents/skills/` folder then receives the canonical copy, and the CLI creates no extra per-agent folders. The manager links the skill for Claude Code itself.

```bash
cd configs/agents
npx skills@1.7.6 add <owner/repository> --skill <name> --agent codex --yes
cd ../..
configs/agents/install-skills.sh --install --yes
git add configs/agents/skills-lock.json
```

Read a new skill before you use it. Skills run with full agent permissions.

### Remove a skill

```bash
cd configs/agents
npx skills@1.7.6 remove <name> --yes
cd ../..
configs/agents/install-skills.sh --prune --dry-run
configs/agents/install-skills.sh --prune
```

`skills remove` deletes the lockfile entry and the folder in `.agents/skills/`. The global links of the skill are then orphans, and `--prune` removes them. Commit the changed lockfile. On the other workstations, `--install` and `--check` report the orphans until you run `--prune` there.

### Update skills

Updates are always explicit. Workstation bootstrap never updates a skill.

```bash
configs/agents/install-skills.sh --update --dry-run
configs/agents/install-skills.sh --update
git diff -- configs/agents/skills-lock.json
```

Commit the changed lockfile. The other workstations get the update on their next `--install`, or the next Dotbot run of the AI profile.

### Dotbot integration

The [Dotbot AI profile](../dotbot/config.ai.yaml) runs `install-skills.sh --install --yes` after it links the agent configuration. The step does not ask questions and you can run it again and again. It keeps unrelated skills. A missing Node.js or npx, a failed restore, or a name conflict makes the step fail, and Dotbot reports this.

```bash
dotfiles ai
```

The AI profile is not part of the default `dotfiles` run (`config.yaml` and its includes in [includes.yaml](../dotbot/includes.yaml)).

### Skills CLI version

`install-skills.sh` pins the skills CLI (`SKILLS_CLI_VERSION`, now `1.7.6`). Project restoration is still experimental upstream. These facts were tested with 1.7.6:

* `experimental_install --frozen-lockfile` restores missing skills into `.agents/skills/` and does not change the lockfile. It fails on a hash mismatch. It skips every skill that already has a `SKILL.md` and does not check its content. For this reason, the manager checks the hashes itself.
* The lockfile records the source and a content hash, not a Git revision. A restore always downloads the current upstream content. If that content changed, the frozen restore fails, and you must run `--update` to accept the change.
* `update --project` updates the lockfile correctly. It can also write copies or links for other agents into the project (`.claude/skills/`, `agent/skills/`). For this reason, the manager runs updates in a temporary copy.
* The project-scope commands `add`, `experimental_install`, and `update --project` did not write to `HOME`.
* The content hash is SHA-256 over all regular files. The files are sorted by relative path (`localeCompare`), and the hash includes each relative path followed by the file content. `.git`, `node_modules`, and symbolic links are skipped. `skills-state.ts` repeats this algorithm.

Before you change the pinned version, test these points again with an isolated `HOME`. Also run `npm run test:shell`.

### Tests

`npm run test:shell` runs [tests/install-skills-test.sh](tests/install-skills-test.sh). The test uses a temporary dotfiles tree and a temporary `HOME`, and it needs no network. It covers a fresh install, repeated installs, broken and wrong links, conflicts, unmanaged entries, local changes, a skill removed from the lockfile, `--prune`, unexpected project folders, invalid lockfiles, and `--list`.

These cases need the network and you test them by hand with an isolated `HOME`: a restore of a missing skill, an unavailable source, a hash mismatch during a restore, and `--update`.
