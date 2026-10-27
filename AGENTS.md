<!-- markdownlint-disable-next-line dnb-title-case-style -->
# AGENTS.md

Production Linux workstation dotfiles: prioritise reproducibility, safety, maintainability, explicit state, and observable failures. Preserve behaviour during refactors. Avoid unnecessary frameworks, meta build systems, plugin-heavy solutions, and cross-platform promises. Keep the workstation usable without cloud dependencies or proprietary tooling.

## Discovery

This is the canonical entry point. Read matching `.agents/instructions/` files before editing; their non-global `applyTo` scopes define applicability. Load `.agents/references/` only for the relevant task. Read folder `README.md` and `INDEX.md` files before working there.

* For layout, environment, or related package locations, read [.agents/references/repository-layout.md](.agents/references/repository-layout.md).
* For Bash or interactive-shell work, including extensionless commands outside automatic scopes, read [.agents/instructions/bashrc/bashrc.instructions.md](.agents/instructions/bashrc/bashrc.instructions.md).
* For CLI work outside automatic scopes, read [.agents/instructions/cli.instructions.md](.agents/instructions/cli.instructions.md).
* For a PATH wrapper that exposes a Bash or Node script as a command from `bin/`, read [.agents/references/path-wrappers.md](.agents/references/path-wrappers.md).
* For logging in any language, read [.agents/instructions/bashrc/logging-and-verbosity.instructions.md](.agents/instructions/bashrc/logging-and-verbosity.instructions.md).
* For cronjobs, `.github/dnb.toml`, or log pruning, read the corresponding [automation](.agents/references/automation.md), [configuration](.agents/references/repository-config.md), or [pruning](.agents/references/logfile-pruning.md) reference.
* For any Tailscale-related work, including Tailnet connectivity, remote access, and service exposure, read [.agents/references/tailscale.md](.agents/references/tailscale.md).
* Before any graphical desktop work, read [SESSION.md](SESSION.md); update it when documented behaviour changes. Target i3. Replace obsolete XFCE behaviour with i3 equivalents only within requested feature work.

## Shared rules

* Inspect conventions and reuse existing helpers. Do not silently assume unclear intent or missing facts; ask. Never remove safeguards without justification. Breaking changes require explicit acknowledgement.
* Use npm and static dependency versions; `npm install` must work.
* Scripts are authoritative. Document code changes accurately, update related README/index files, and avoid duplication. Update source inputs rather than generated Bash documentation; see the [Bash instructions](.agents/instructions/bashrc/bashrc.instructions.md).
* Run `npm run check` before considering a change done; see [validation commands](.agents/references/validation.md).

## Secrets

* Credentials belong only in real, Git-ignored `.env` files or `protected/`, never templates or examples. Anonymise token-shaped examples, such as `gpd_######`.
* Load secrets from documented configuration. Missing secrets must produce a short, non-fatal skip without disrupting unrelated work. Never log secret values, including in debug output.
* Do not bypass `secretlint`, which checks tracked files through lint-staged, or narrow `.secretlintignore` to conceal a finding.

## Delivery

Commit directly to `main` only when authorised; branch only when explicitly asked. Use Conventional Commits and scopes from `.release-it.ts`. Do not push without authorisation.

`protected/` is a separate, Git-ignored repository; do not modify its contents unless explicitly asked. For tracked submodules, stage only the recorded HEAD from the parent; do not commit, amend, clean, reset, or modify submodule work without explicit authorisation.

## Request shorthand

* **Create a PATH wrapper for `<script>` as `<command>`:** add an executable Bash wrapper in `bin/<command>` so Bash can find it through `PATH`; follow [the PATH wrapper procedure](.agents/references/path-wrappers.md). If the command name is omitted, use the script basename without its extension unless that would conflict with an existing command.
* **Update your references:** fetch the repository in use, update to the latest main-branch HEAD, adapt code for upstream changes, and resolve conflicts.
* **Document:** update the relevant folder README, or link new documentation from it; explain behaviour and usage with concise, accurate prose.
