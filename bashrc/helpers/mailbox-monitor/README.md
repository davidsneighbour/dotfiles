# Mailbox quota monitor

The monitor reads mailbox quotas from the Pair mail server over SSH, writes local reports, and sends Discord warnings for mailboxes at or above the configured threshold. It does not modify mailboxes.

## How it works

One SSH connection runs a small `sh` script on the server. For each domain directory below the boxes directory, the script takes every regular file as a mailbox (the mbox INBOX; other folders are in the matching `name^` directory). It runs `doveadm quota get` for each mailbox. Dovecot returns the used size and the limit in KB, and these are the same values as the Pair control panel shows.

Files without a matching mail account (for example, empty leftovers of deleted accounts) are skipped with a warning. Other `doveadm` errors fail the check.

No browser, login, or 2FA is necessary. Changes to quota limits in the Pair control panel are still made manually in the web interface; the monitor reads the new limits on the next run.

## Configuration

Keep configuration in a private, gitignored `.env` file with mode `0600`:

```bash
MAILBOX_MONITOR_SSH_TARGET="user@host.pair.com"
MAILBOX_MONITOR_BOXES_DIR="/usr/boxes/user"
MAILBOX_MONITOR_SSH_KEY="${HOME}/.ssh/id_ed25519"
MAILBOX_MONITOR_DOMAINS=""
MAILBOX_MONITOR_PROJECT_NAME="Customer mailboxes"
MAILBOX_MONITOR_OUTPUT_DIR="${HOME}/.logs/mailbox-monitor"
MAILBOX_MONITOR_HISTORY_FILE=""
MAILBOX_MONITOR_YELLOW_THRESHOLD="80"
MAILBOX_MONITOR_RED_THRESHOLD="95"
DISCORD_WEBHOOK=""
```

`MAILBOX_MONITOR_SSH_TARGET` and `MAILBOX_MONITOR_BOXES_DIR` are required. `MAILBOX_MONITOR_DOMAINS` is a comma-separated list; when it is empty, all domain directories (names that contain a dot) are checked. `MAILBOX_MONITOR_TIMEOUT_MS` (default `120000`) limits the SSH run.

The SSH key must work without a passphrase prompt, because the monitor uses `BatchMode=yes`. Connect once manually to accept the host key.

The wrapper defaults to `.env` beside itself, regardless of your current directory. Use `--env-file FILE` to select another configuration. Never commit webhook URLs or other private values.

## Running and cron

The monitor has no npm dependencies. It needs Node and the `ssh` client. The wrapper uses Node from PATH, then the installed nvm default if PATH has no Node. Set `MAILBOX_MONITOR_NODE_BIN` only when a fixed executable path is required.

```bash
./run-mailbox-monitor.sh --env-file .env
```

Create the log directory before using shell output redirection:

```bash
install --directory --mode=0700 "${HOME}/.logs/mailbox-monitor"
```

Example daily run at 07:15 in cron's configured timezone:

```cron
15 7 * * * /bin/bash -c 'umask 077; exec "$HOME/.dotfiles/bashrc/helpers/mailbox-monitor/run-mailbox-monitor.sh" --env-file "$HOME/.dotfiles/bashrc/helpers/mailbox-monitor/.env" >> "$HOME/.logs/mailbox-monitor/$(date +\%Y\%m\%d-\%H\%M\%S).log" 2>&1'
```

If cron runs without your SSH agent, the key file given in `MAILBOX_MONITOR_SSH_KEY` is used directly.

## Reports and failures

Successful checks write `latest-mailboxes.json`, `latest-alerts.json`, and `latest-summary.md` under the output directory. Yellow starts at 80%, and red starts at 95%, unless configured otherwise. Discord quota alerts are sent only when at least one mailbox meets the yellow threshold.

Failed checks exit non-zero and send a Discord failure notification when a webhook is configured. Existing reports can therefore be stale after a failure.

## Usage history

Each successful check appends one JSON line per mailbox to `history.jsonl` in the output directory (set `MAILBOX_MONITOR_HISTORY_FILE` to use another path). A line holds `checkedAt`, `mailbox`, `usedKb`, and `limitKb` (`null` when the mailbox has no limit). The monitor only appends to this file. It never reads, rewrites, or prunes it. Failed checks add no lines.

The separate `analyse-history.mjs` script reads the history and shows, for each mailbox, the current usage, the change and growth rate over the selected period, and the estimated days until the mailbox is full. It does not connect to the server.

```bash
node analyse-history.mjs                       # summary of all mailboxes
node analyse-history.mjs --days 30             # last 30 days only
node analyse-history.mjs --mailbox example.com --series   # every check of matching mailboxes
node analyse-history.mjs --json                # machine-readable output
```

Without `--file`, it uses `MAILBOX_MONITOR_HISTORY_FILE`, then `MAILBOX_MONITOR_OUTPUT_DIR/history.jsonl`, then `~/.logs/mailbox-monitor/history.jsonl`. The growth rate is the difference between the first and last check of the period, so a deletion of mail inside the period lowers it.

## Implementation reference

See [DOCUMENTATION.md](DOCUMENTATION.md) for the helper function reference.
