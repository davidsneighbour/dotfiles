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
| `install-skills.sh` | The manager: adds, adopts, restores, verifies, links, checks, updates, lists, and prunes. [`bin/agent-skills`](../../bin/agent-skills) runs it from `PATH`. |
| `skills-state.ts` | Helper for `install-skills.sh`. It validates the lockfile, compares every installed skill with its recorded hash, compares two lockfiles, and reads the global skills CLI lockfile. |
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
* `--add` and `--adopt` are the only operations that remove something outside this folder: the global skills CLI installs of the skills that they add (see [Global installs](#global-installs)).

### Commands

Run the manager with one operation: `agent-skills` (the [PATH wrapper](../../bin/agent-skills)) or `configs/agents/install-skills.sh`. Both are the same. Without arguments it shows the help.

```bash
agent-skills --add --source greensock/gsap-skills --dry-run   # show what would be added
agent-skills --add --source blader/humanizer --skill humanizer
agent-skills --adopt --dry-run      # show global skills CLI installs to move here
agent-skills --adopt                # move them after confirmation
agent-skills --install --yes        # restore and link (used by Dotbot)
agent-skills --install --dry-run
agent-skills --check                # read-only and offline
agent-skills --check --strict       # warnings also fail
agent-skills --list                 # table of all skills and link states
agent-skills --update --dry-run     # report available updates
agent-skills --update               # update after confirmation
agent-skills --prune --dry-run
```

| Operation | Behaviour |
| --- | --- |
| `--add` | Adds skills from `--source` to the lockfile, installs them, and links them. `--skill <name>` selects skills (repeat it for more). Without `--skill`, all skills of the source are added. The skills CLI runs in a temporary copy of this folder. The manager verifies the result, checks for conflicts, shows the plan, and asks for confirmation (or uses `--yes`). It removes the global skills CLI install of every skill that it adds. It refuses to change a skill that is already tracked (use `--update`). |
| `--adopt` | Moves skills that were installed globally with `npx skills add -g` into the lockfile. It reads the sources from the global lockfile, so you do not need to type them again. `--skill <name>` selects skills; without it, all global installs are adopted. For a skill that is already tracked, it only removes the global install. |
| `--install` | Restores missing skills (network access is needed only then), verifies the hashes, and creates or repairs the managed links. It never updates a skill. A skill with local changes is an error. `--install --force` reinstalls it and keeps the local copy if the reinstall fails. |
| `--check` | Verifies the lockfile, the hashes, and every link. It also reports orphans, untracked folders in `.agents/skills/`, unexpected folders in this folder, tracked skills that are also installed in `~/.agents/skills`, global skills CLI installs that are not tracked, and an uncommitted or untracked lockfile. |
| `--update` | Copies the project to a temporary folder and runs `npx skills update --project` there. Then it shows the lockfile diff, verifies the new content, and asks for confirmation (or uses `--yes`). It refuses to run when `skills-lock.json` has uncommitted changes. |
| `--list` | Prints `NAME`, `STATUS` (`managed`, `missing`, `modified`, `untracked`, `orphaned`, `global`, `unmanaged`), `SOURCE`, and the link state for each agent. `global` is a skill in the global skills CLI lockfile. |
| `--prune` | Removes orphaned managed links and untracked folders in `.agents/skills/`. It never removes unmanaged entries. |

Options: `--source` (only with `--add`), `--skill` (only with `--add` and `--adopt`), `--dry-run`, `--yes`, `--strict`, `--force` (only with `--install`), `--verbose`, `--quiet`, and `--help`.

Exit status: `0` success, `1` a problem was found or an operation failed, `2` usage error, `3` Node.js or npx missing, or confirmation was needed without a terminal. Every run writes a log to `~/.logs/agent-skills/YYYYMMDD-HHMMSS.log`. The log also contains the skills CLI output.

The manager finds `node` and `npx` through `PATH` first. If they are not there, it uses the NVM runtime behind `~/.local/bin/node-cron` (see [Node runtime maintenance](../../docs/node-runtime.md)).

### Add a skill

Use `agent-skills --add`, not `npx skills add -g`. The source is the same as for the skills CLI, for example `owner/repository` or `https://github.com/owner/repository`.

```bash
agent-skills --add --source <owner/repository> --skill <name> --dry-run
agent-skills --add --source <owner/repository> --skill <name>
git add configs/agents/skills-lock.json
```

The manager runs the pinned CLI with `--agent codex` in a temporary copy of this folder. The universal `.agents/skills/` folder then receives the canonical copy, and no extra per-agent folders are created. The manager links the skill for Claude Code and Codex itself.

Read a new skill before you use it. Skills run with full agent permissions.

### Global installs

`npx skills add -g` installs a skill in the global scope of the skills CLI: `~/.agents/skills/<name>`, a link `~/.claude/skills/<name>`, and an entry in `~/.agents/.skill-lock.json`. The dotfiles do not track that scope. `--check` reports every such skill, and `--list` shows it as `global`.

To move global installs here, run `agent-skills --adopt` (all of them) or `agent-skills --adopt --skill <name>`. `--add` does the same for the skills that it adds. For each skill, the manager:

1. adds the skill from the source in the global lockfile, in a temporary copy, and verifies it,
2. checks for conflicts,
3. asks for confirmation,
4. runs `npx skills@1.7.6 remove -g <name>`,
5. installs the skill here, updates the lockfile, and links it.

`skills remove -g` also deletes `~/.claude/skills/<name>` when that is a link to somewhere else. For this reason, the manager accepts only the links that the CLI created itself (links to `~/.agents/skills/<name>`) and managed links. Any other entry with the same name, for example a `skillz` link to one of your own skills, is a conflict, and nothing is changed. Remove the skill from its source repository and run `skillz`, or keep your own skill and remove only the global install.

The content of an adopted skill is downloaded again. It can be newer than the global copy, because the global lockfile records a Git tree hash, not the content hash of the project lockfile. A global skill from a local path is skipped, because other workstations cannot restore it.

### Remove a skill

```bash
cd configs/agents
npx skills@1.7.6 remove <name> --yes
cd ../..
agent-skills --prune --dry-run
agent-skills --prune
```

`skills remove` deletes the lockfile entry and the folder in `.agents/skills/`. The global links of the skill are then orphans, and `--prune` removes them. Commit the changed lockfile. On the other workstations, `--install` and `--check` report the orphans until you run `--prune` there.

### Update skills

Updates are always explicit. Workstation bootstrap never updates a skill.

```bash
agent-skills --update --dry-run
agent-skills --update
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
* `add` without `--skill` and with `--yes` installs all skills of the source.
* The global scope (`add -g`) uses `~/.agents/skills/` and the lockfile `~/.agents/.skill-lock.json` (version 3). With Claude Code selected, it links `~/.claude/skills/<name>` to `../../.agents/skills/<name>`. It replaces an existing link in `~/.agents/skills/` (for example a `skillz` link).
* `remove -g <name> --yes` deletes `~/.agents/skills/<name>`, `~/.claude/skills/<name>` (even when that is a link to somewhere else), and the global lockfile entry. It did not change a link in `~/.codex/skills/`.
* The content hash is SHA-256 over all regular files. The files are sorted by relative path (`localeCompare`), and the hash includes each relative path followed by the file content. `.git`, `node_modules`, and symbolic links are skipped. `skills-state.ts` repeats this algorithm.

Before you change the pinned version, test these points again with an isolated `HOME`. Also run `npm run test:shell`.

### Tests

`npm run test:shell` runs [tests/install-skills-test.sh](tests/install-skills-test.sh). The test uses a temporary dotfiles tree and a temporary `HOME`, and it needs no network. It covers a fresh install, repeated installs, broken and wrong links, conflicts, unmanaged entries, local changes, a skill removed from the lockfile, `--prune`, unexpected project folders, invalid lockfiles, and `--list`. For `--add` and `--adopt`, it uses a fake `npx` that copies skills from local folders and emulates `remove -g`: global installs, confirmation, conflicts with unmanaged links, a changed source of a tracked skill, and unknown sources and skills.

These cases need the network and you test them by hand with an isolated `HOME`: a restore of a missing skill, an unavailable source, a hash mismatch during a restore, `--update`, and `--add` or `--adopt` with the real skills CLI.
