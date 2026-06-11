# Bashrc/helpers documentation

This file is the central documentation map for every helper command, support file, and grouped helper under `bashrc/helpers`.

The implementation remains authoritative. Existing README or Markdown files are referenced from the relevant sections, and undocumented implementation details are summarised here.

<!-- markdownlint-disable-next-line title-case-style -->
## Execution and TypeScript note

Bash helpers are standalone helper commands unless noted otherwise. Several TypeScript files have Node shebangs but are still `.ts` source files; run them with the repository `node-run` helper, a Node version that supports direct type stripping, `ts-node`, or an equivalent TypeScript runner. Do not assume plain `node file.ts` works on older Node releases.

## Folder documentation

* [`_actions/`](./_actions/DOCUMENTATION.md)
* [`_lib/`](./_lib/DOCUMENTATION.md)
* [`api/`](./api/DOCUMENTATION.md)
* [`bash/`](./bash/DOCUMENTATION.md)
* [`daily-reports/`](./daily-reports/DOCUMENTATION.md)
* [`docker/`](./docker/DOCUMENTATION.md)
* [`docker/examples/`](./docker/examples/DOCUMENTATION.md)
* [`freshrss/`](./freshrss/DOCUMENTATION.md)
* [`gh/`](./gh/DOCUMENTATION.md)
* [`kando/`](./kando/DOCUMENTATION.md)
* [`logs/`](./logs/DOCUMENTATION.md)
* [`packages/`](./packages/DOCUMENTATION.md)
* [`raindrop.io/`](./raindrop.io/DOCUMENTATION.md)
* [`remarkable/`](./remarkable/DOCUMENTATION.md)
* [`theme/`](./theme/DOCUMENTATION.md)
* [`workspace/`](./workspace/DOCUMENTATION.md)

## Top-level helper files

### `dotbot`

Dotbot wrapper that initialises the Dotbot submodule if needed and runs a selected configs/dotbot/config*.yaml profile.

CLI option notes:

* --config CONFIG_NAME — run a specific configs/dotbot profile.
* --list — choose a config interactively with gum.
* -h, --help — show help.
* Positional CONFIG_NAME — preferred shorthand for selecting a config.

Functions/methods defined:

* `source_core_libs`
* `print_help`
* `ensure_dotbot_ready`
* `normalize_config_to_filename`
* `resolve_config_path`
* `run_dotbot_with_config`
* `pick_config_with_gum`
* `main`

Requirements:

* bash, git, python3 for Dotbot, modules/dotbot submodule.
* gum only for --list.

### `explore`

Opens a directory in the system file manager via xdg-open or gio.

CLI option notes:

* --path PATH — open this path instead of positional path.
* --verbose — print diagnostic output.
* --help — show help.
* Positional path — optional path to open; defaults to current directory or HOME.

Functions/methods defined:

* `explore`
* `_help`
* `_log`
* `_error`
* `_default_path`

Requirements:

* bash and either xdg-open or gio.

### `github-token`

Selects a GitHub token from environment variables or .env files by role and visibility; can print, export, or run a command with the token.

CLI option notes:

* --role ROLE — token role: read, content, or admin.
* --visibility VISIBILITY — repository visibility: public or private.
* --env-file PATH — load tokens from this explicit .env file.
* --verbose — print diagnostic output.
* --help — show help.
* Subcommand get — print only the selected token.
* Subcommand print-env — print export lines for GH_TOKEN and GITHUB_TOKEN.
* Subcommand run -- COMMAND — run COMMAND with token variables set.
* Subcommand show-config — print selected role, visibility, env file, and variable name.

Functions/methods defined:

* `print_usage`
* `print_verbose`
* `print_error`
* `die`
* `validate_role`
* `validate_visibility`
* `resolve_env_file`
* `load_env_file`
* `get_default_role`
* `get_default_visibility`
* `get_token_variable_name`
* `get_token_value`
* `cmd_get`
* `cmd_print_env`
* `cmd_show_config`
* `cmd_run`
* `main`

Requirements:

* bash and trusted environment/.env files containing the expected token variable.

### `interface-restart`

Minimal launcher that restarts configured Polybar and Conky startup scripts.

Requirements:

* Existing ~/.dotfiles/configs/system/polybar/start.sh and ~/.dotfiles/configs/system/conky/startup.sh.

### `lpack`

Packages the current directory into a zip file, with excludes from CLI, .gitignore, and optional TOML config.

CLI option notes:

* --exclude PATH — exclude a path; repeatable.
* --config PATH — read lpack.exclude from a TOML file.
* --no-gitignore — ignore .gitignore excludes.
* --dry-run — print files without creating a zip.
* --output FILE — output zip filename.
* --verbose — enable verbose logging.
* --help — show help.

Functions/methods defined:

* `lpack_help`
* `lpack_source_libs`
* `lpack_normalize_exclude`
* `lpack_append_unique`
* `lpack_collect_config_excludes`
* `main`

Requirements:

* bash, zip, git for .gitignore handling, optional python3/toml helper libraries from bashrc/lib.

### `node-run`

Runs a Node/TypeScript script through nvm with optional Node version installation and working-directory control.

CLI option notes:

* --script FILE — Node/TypeScript script to execute.
* --node-version VERSION, -v VERSION — nvm version to use or install.
* --cwd DIR — change working directory before execution.
* --verbose — enable verbose output.
* --debug — enable full debug output.
* --help — show help.
* -- — separates node-run options from script arguments.

Functions/methods defined:

* `node_run`
* `get_help_node_context`
* `usage`
* `log_message`
* `load_nvm`
* `use_or_install_node_version`
* `use_project_or_default_node_version`

Requirements:

* bash, nvm, Node.js.

### `registry.toml`

Registry metadata for helper commands and their documented properties.

### `screencaps.ts`

Extracts multiple screenshots from a video via ffmpeg/ffprobe.

CLI option notes:

* --video FILE — input video, equivalent to first positional argument.
* --screens N — number of screenshots; minimum 2.
* --padding SECONDS — trim from start/end before sampling.
* --mode single|multi — one ffmpeg run or multiple accurate seeks.
* --outdir DIR — output directory.
* --format png|jpg|webp — output image format.
* --jpg-quality N — ffmpeg JPG q:v value, lower is better.
* --png-compression N — PNG compression 0..9.
* --webp-lossless — force lossless WEBP.
* --no-webp-lossless — allow lossy WEBP.
* --webp-quality N — lossy WEBP quality 0..100.
* --jobs N|auto — concurrent workers for multi mode.
* --scale W:H — resize output.
* --overwrite — replace existing screenshots.
* --plan — print sampling plan without extraction.
* --dry-run — print ffmpeg/ffprobe commands only.
* --verbose — show ffmpeg/ffprobe output.
* --help, -h — show help.

Functions/methods defined:

* `log`
* `logErr`
* `isString`
* `commandExists`
* `run`
* `getDurationSeconds`
* `buildSamplingPlan`
* `fmtTimeLabel`
* `parseMode`
* `parseFormat`
* `parseNumberStrict`
* `parseIntStrict`
* `parseJobs`
* `buildQualityArgs`
* `mergeScaleFilter`
* `extractSingleRun`
* `extractMultiRun`
* `one`
* `helpText`
* `parseArgs`
* `errToString`
* `main`

Requirements:

* Node.js with TypeScript execution support.
* ffmpeg and ffprobe.

### `set_max_listeners.cjs`

Node preload/snippet that raises EventEmitter.defaultMaxListeners to 20.

Requirements:

* Node.js CommonJS runtime.

### `synch-devspace.sh`

Synchronises a Git workspace tree to a local or remote target using rsync.

CLI option notes:

* --target PATH|USER@HOST:PATH — required destination root.
* --source PATH — source root; default is ~/github.com.
* --delete — delete target files missing from source.
* --dry-run — preview rsync changes.
* --verbose — print more output.
* --exclude-file PATH — additional rsync exclude file.
* --ssh-port PORT — SSH port for remote targets.
* --no-compress — disable rsync compression.
* --help — show help.
* --version — show script version.

Functions/methods defined:

* `print_usage`
* `print_version`
* `print_info`
* `print_warn`
* `print_error`
* `print_debug`
* `require_command`
* `is_remote_target`
* `ensure_directory_exists`
* `create_temp_exclude_file`
* `cleanup`
* `build_rsync_command`
* `validate_arguments`
* `show_summary`
* `parse_arguments`
* `get_remote_connection_parts`
* `run_remote_github_check`
* `post_checks`
* `main`

Requirements:

* bash and rsync.
* ssh for remote targets.
* git for post-checks.

### `update-npm.sh`

Updates nvm itself and reinstalls global npm packages into installed Node versions.

Requirements:

* bash, curl, nvm, npm, network access to nvm install script.

### `web-mirror.sh`

Mirrors a webpage and assets with wget and optionally compresses the result.

CLI option notes:

* --url URL — required HTTP/HTTPS URL to mirror.
* --compress true|false — archive output and remove folder by default when true.
* --keep-folder — keep mirrored folder after compression.
* --output NAME — output base name.
* --verbose — more output.
* --help — show help.

Functions/methods defined:

* `print_help`
* `log_init`
* `log`
* `die`
* `require_cmd`
* `safe_slug`
* `pick_archiver`

Requirements:

* bash, wget, and one archiver: tar, zip, or 7z.

## Grouped helper summary

### `_actions/`

See [`_actions/DOCUMENTATION.md`](./_actions/DOCUMENTATION.md).

* `_actions/README.md`: Existing user documentation for the actions helper; keep aligned with actions.sh.
* `_actions/actions.sh`: Unified Bash helper for actions, autostart symlink management, and Dotbot profile discovery/execution.

### `_lib/`

See [`_lib/DOCUMENTATION.md`](./_lib/DOCUMENTATION.md).

* `_lib/node.ts`: Shared TypeScript helper exporting ensureNodeVersion(requiredMajor), which exits if process.versions.node is below the required major.

### `api/`

See [`api/DOCUMENTATION.md`](./api/DOCUMENTATION.md).

* `api/porkbun-api.ts`: Porkbun API inspector. Lists domains or gathers metadata, nameservers, DNS, forwards, glue, and SSL information for one domain.

### `bash/`

See [`bash/DOCUMENTATION.md`](./bash/DOCUMENTATION.md).

* `bash/startup-profiler.sh`: Profiles Bash startup with xtrace timestamps and writes a TSV report of slow startup lines.

### `daily-reports/`

See [`daily-reports/DOCUMENTATION.md`](./daily-reports/DOCUMENTATION.md).

* `daily-reports/README.md`: Existing overview for daily report helpers.
* `daily-reports/commit-report-to-dailynote.sh`: Generates commit reports and replaces the marked daily-repo-logs block in matching Obsidian daily notes.
* `daily-reports/commits-to-notes.sh`: Generates Markdown commit reports for one repository, direct child repositories, or username directory trees.

### `docker/`

See [`docker/DOCUMENTATION.md`](./docker/DOCUMENTATION.md).

* `docker/README.md`: Existing Docker backup runner guide; documents backup task formats and examples.
* `docker/backup-runner.ts`: Executable TypeScript orchestrator for the docker backup runner.

### `docker/examples/`

See [`docker/examples/DOCUMENTATION.md`](./docker/examples/DOCUMENTATION.md).

* `docker/examples/backup.sh`: Example custom Bash backup task for backup-runner.
* `docker/examples/backup.toml`: Example TOML backup task for backup-runner.
* `docker/examples/backup.ts`: Example custom TypeScript backup task for backup-runner.

### `freshrss/`

See [`freshrss/DOCUMENTATION.md`](./freshrss/DOCUMENTATION.md).

* `freshrss/export.ts`: FreshRSS Google Reader API exporter that emits RSS XML for starred items or one label stream.

### `gh/`

See [`gh/DOCUMENTATION.md`](./gh/DOCUMENTATION.md).

* `gh/cdg`: Changes to a local GitHub repository directory by fuzzy-selecting a subdirectory under a base path; meant to be sourced/evaluated when used to affect the current shell.
* `gh/git-sig-lint.sh`: Scans recent Git commits and reports signature status.
* `gh/git-sync.sh`: Synchronises a Git repository with remote state using fetch/pull/push-style operations implemented by the script.
* `gh/git-verify-committer.sh`: Validates Git commit author/committer identity for recent commits.
* `gh/git-verify-identity.sh`: Validates the local repository Git identity configuration.
* `gh/github-manager.md`: Existing detailed guide for github-manager.ts.
* `gh/github-manager.ts`: GitHub repository manager for inventory, pull, status, audit, remote listing, topic cloning, and sync-all workflows.
* `gh/label-migration.sh`: Migrates GitHub issue/PR labels between repositories or from a definition source using gh.

### `kando/`

See [`kando/DOCUMENTATION.md`](./kando/DOCUMENTATION.md).

* `kando/kando-vscode-menu-creator.ts`: Updates a Kando menu from VS Code .code-workspace files.

### `logs/`

See [`logs/DOCUMENTATION.md`](./logs/DOCUMENTATION.md).

* `logs/ToDo.md`: Backlog notes for the log cleanup helper.
* `logs/cleanup.ts`: Config-driven log cleanup and archive helper.
* `logs/config.toml`: Default log cleanup configuration.
* `logs/log-cleanup.config.schema.json`: JSON Schema for logs/config.toml.

### `packages/`

See [`packages/DOCUMENTATION.md`](./packages/DOCUMENTATION.md).

* `packages/README.md`: Existing guide for package archive helper configuration.
* `packages/create.sh`: Creates zip archives from line-oriented `[packages.NAME]` TOML sections.

### `raindrop.io/`

See [`raindrop.io/DOCUMENTATION.md`](./raindrop.io/DOCUMENTATION.md).

* `raindrop.io/getTags.ts`: Fetches and prints tags for a Raindrop.io collection.

### `remarkable/`

See [`remarkable/DOCUMENTATION.md`](./remarkable/DOCUMENTATION.md).

* `remarkable/README.md`: Existing user guide for reMarkable transfers.
* `remarkable/transfer.ts`: Transfers PDF/EPUB files to/from a reMarkable tablet and supports raw rsync backups.

### `theme/`

See [`theme/DOCUMENTATION.md`](./theme/DOCUMENTATION.md).

* `theme/color-steps.md`: Existing guide for the CSS colour variable generator.
* `theme/color-steps.todo.md`: Todo notes for future colour generator documentation/features; not implemented behaviour.
* `theme/color-steps.ts`: Generates HSL CSS custom properties for colour ramps.

### `workspace/`

See [`workspace/DOCUMENTATION.md`](./workspace/DOCUMENTATION.md).

* `workspace/wm-detect.sh`: Detects the current X11 window manager through EWMH properties.
* `workspace/wm-wsname.sh`: Sets XFCE workspace names by positional number/name pairs.
* `workspace/workspace-setup.sh`: Configures XFCE workspace count/names and optionally starts or moves applications by workspace.
