# Docker backup runner

This is a portable backup system for Docker Compose based hosts.

It consists of:

* `backup-runner` as the orchestration script (extensionless executable, with `backup-runner.mjs` kept as the same source)
* one backup definition per container folder, using either:
  * `backup.toml` for the built-in backup engine
  * `backup.sh` for a custom Bash backup
  * `backup.ts` for a custom TypeScript backup

The runner scans a configured root directory recursively, finds backup tasks, executes them, logs success and failure, and writes timestamped `.tar.gz` archives into a central backup directory.

## What it solves

* one command for all container backups on a host
* works manually or from cron
* supports a simple default strategy for most Compose stacks
* supports fully custom backup logic per stack when needed
* supports optional upload hooks for off-site copies such as `rclone`

## Directory layout

Example:

```text
/srv/docker/
  portainer/
    docker-compose.yml
    data/
    backup.toml
  paperless/
    docker-compose.yml
    backup.sh
  bespoke-app/
    docker-compose.yml
    backup.ts
```

The runner is then pointed at `/srv/docker` and walks all subdirectories.

## Runner usage

Manual run from inside a Docker stacks directory:

```bash
cd /srv/docker
backup-runner --verbose
```

Explicit run with custom paths:

```bash
backup-runner \
  --root /srv/docker \
  --destination /srv/backups/docker \
  --verbose
```

Dry run:

```bash
cd /srv/docker
backup-runner --dry-run --verbose
```

With an upload command after each successful archive:

```bash
backup-runner \
  --root /srv/docker \
  --destination /srv/backups/docker \
  --after-each-command 'rclone copy ${archive} remote:docker-backups/${host}/'
```

## Built-in task type: `backup.toml`

Use `backup.toml` when the stack can be backed up by stopping the Compose project, archiving one or more data directories, and starting it again.

Example:

```toml
enabled = true
name = "portainer"
mode = "compose-copy"
service_root = "."
compose_file = "docker-compose.yml"
data_paths = ["data"]
stop_timeout_seconds = 30
compression = "tar.gz"
ignore_missing_paths = false

# pre_command = "echo Starting ${name}"
# post_command = "echo Finished ${archive}"
# upload_command = "rclone copy ${archive} remote:docker-backups/${host}/"
```

### Supported `backup.toml` fields

* `enabled`: `true` or `false`
* `name`: readable task name used in logs and archive names
* `mode`: `compose-copy` or `command`
* `service_root`: directory from which commands should run
* `compose_file`: Compose file path, default `docker-compose.yml`
* `data_paths`: folders to archive, relative to `service_root`
* `stop_timeout_seconds`: timeout passed to `docker compose down --timeout`
* `compression`: currently `tar.gz`
* `ignore_missing_paths`: skip missing paths instead of failing
* `pre_command`: optional command before backup
* `post_command`: optional command after backup
* `upload_command`: optional off-site copy command
* `command`: only for `mode = "command"`

### `mode = "compose-copy"`

This mode does the following:

* runs `pre_command` if configured
* runs `docker compose down`
* creates a timestamped `.tar.gz` archive from the configured `data_paths`
* runs `docker compose up -d`
* runs `post_command` if configured
* runs `upload_command` if configured

This is the best default for stacks where the data lives in bind-mounted folders.

### `mode = "command"`

Use this when the backup should still be declared in TOML but must call a special command.

Example:

```toml
enabled = true
name = "postgres"
mode = "command"
service_root = "."
command = "./scripts/backup-db.sh ${archive}"
```

## Custom task type: `backup.sh`

Use `backup.sh` when a service needs special logic, for example a database dump or an API export.

The runner executes the script with Bash and provides these environment variables:

* `BACKUP_NAME`
* `BACKUP_HOST`
* `BACKUP_TIMESTAMP`
* `BACKUP_TASK_DIR`
* `BACKUP_OUTPUT_DIR`
* `BACKUP_WORK_DIR`
* `BACKUP_ARCHIVE_PATH`
* `BACKUP_VERBOSE`

### Expected behaviour

A custom script should do one of the following:

* write backup files into `BACKUP_WORK_DIR`, then let the runner compress them automatically
* or create `BACKUP_ARCHIVE_PATH` itself if full control is needed

Minimal pattern:

```bash
#!/bin/bash
set -euo pipefail

mkdir -p "${BACKUP_WORK_DIR}"
cp -a "${BACKUP_TASK_DIR}/data" "${BACKUP_WORK_DIR}/data"
```

## Custom task type: `backup.ts`

Use `backup.ts` when Bash is not ideal or when the backup needs more structured logic.

The same environment variables are provided. The TypeScript script can write files into `BACKUP_WORK_DIR`, and the runner will compress the result.

Minimal pattern:

```ts
import { cp, mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';

const taskDirectory = process.env.BACKUP_TASK_DIR;
const workDirectory = process.env.BACKUP_WORK_DIR;

if (!taskDirectory || !workDirectory) {
  throw new Error('Required environment is missing.');
}

await mkdir(workDirectory, { recursive: true });
await cp(resolve(taskDirectory, 'data'), resolve(workDirectory, 'data'), { recursive: true });
```

## Archive naming

Archives are written like this:

```text
<destination>/<host>/<task-name>-2026-04-01T12-34-56Z.tar.gz
```

This keeps backups grouped by host and gives every archive a sortable UTC timestamp.

## Cron setup

Example cron entry for a daily backup at 03:15:

```cron
15 3 * * * cd /srv/docker && /usr/local/bin/backup-runner --verbose >> /var/log/docker-backups.log 2>&1
```

Recommended workflow:

* first run with `--dry-run`
* then run manually once without `--dry-run`
* only then put it into cron

## Portability notes

This setup is designed to stay portable across Linux hosts.

* the runner only requires Node.js 24+
* stack-specific logic can be Bash or TypeScript
* archives are plain `.tar.gz`
* upload is delegated to hook commands, so you can use `rclone`, `rsync`, `scp`, or anything similar
* no global config file is required; each stack is self-contained

## Suggested installation

* copy `backup-runner` to a shared location such as `/usr/local/bin/`
* or keep `backup-runner.mjs` and symlink `backup-runner` to it
* store your stacks under a common root such as `/srv/docker/`
* place one `backup.toml`, `backup.sh`, or `backup.ts` into each stack directory
* store backups under a separate path such as `/srv/backups/docker/`

## Recommended strategy per container type

* generic bind-mounted services: use `backup.toml` with `mode = "compose-copy"`
* databases that should be dumped logically: use `backup.sh` or `backup.ts`
* applications with vendor-provided backup commands: use `backup.sh` or `backup.ts`
* stacks with pre/post hooks: use `backup.toml` and its hook commands

## Example off-site upload commands

Rclone:

```bash
--after-each-command 'rclone copy ${archive} remote:docker-backups/${host}/'
```

Rsync to another machine:

```bash
--after-each-command 'rsync -av ${archive} backup@example.com:/srv/offsite/docker/${host}/'
```

## Files included

* `backup-runner`: the orchestrator
* `backup-runner.mjs`: same source kept with extension for editing/reference
* `examples/backup.toml`: built-in task example
* `examples/backup.sh`: custom Bash task example
* `examples/backup.ts`: custom TypeScript task example

## Default path behaviour

When no `--root` is given, the runner scans the current working directory.

When no `--destination` is given, archives are written to `./backups` relative to the selected root.

That means this works exactly as expected:

```bash
cd /srv/docker
backup-runner
```

The runner will then scan subfolders such as `/srv/docker/portainer`, `/srv/docker/paperless`, and so on, while skipping the backup output folder itself.
