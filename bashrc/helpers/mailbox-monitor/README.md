# Mailbox quota monitor

The monitor reads Pair's mailbox overview with Playwright, calculates quota usage, writes local reports, and sends Discord warnings for mailboxes at or above the configured threshold. It does not modify mailboxes.

## Authentication and 2FA

Scheduled checks reuse a saved browser session, including the authenticated mailbox page URL, cookies, local storage, IndexedDB, and session storage. The saved page opens directly; navigation is skipped when the mailbox table is already visible. The monitor does not submit an admin password. You enter the current password and complete 2FA yourself in a visible browser.

From this directory, create or renew the session:

```bash
./run-mailbox-monitor.sh --login
```

Complete login in the browser, open **Email → Manage Mailboxes**, and press Enter in the terminal. The monitor checks the mailbox table before saving the session. Login mode does not send quota alerts or replace reports.

Run a normal check:

```bash
./run-mailbox-monitor.sh --env-file .env
```

Sessions can expire or be revoked. Failed checks exit non-zero and attempt a Discord failure notification when a webhook is configured. Renew the session with the same command and environment file. A navigation or table change can also cause a check to fail; a renewal message does not prove that authentication was the cause.

## Configuration

Keep configuration in a private, gitignored `.env` file:

```bash
MAILBOX_MONITOR_START_URL="https://my.pair.com/"
MAILBOX_MONITOR_PROJECT_NAME="Customer mailboxes"
MAILBOX_MONITOR_NAV_PATH="Email|Manage Mailboxes"
MAILBOX_MONITOR_HEADLESS="true"
MAILBOX_MONITOR_SESSION_FILE="${HOME}/.local/state/mailbox-monitor/session.json"
MAILBOX_MONITOR_OUTPUT_DIR="${HOME}/.logs/mailbox-monitor"
MAILBOX_MONITOR_YELLOW_THRESHOLD="80"
MAILBOX_MONITOR_RED_THRESHOLD="95"
DISCORD_WEBHOOK=""
```

The wrapper defaults to `.env` beside itself, regardless of your current directory. Use `--env-file FILE` to select another configuration. Only `MAILBOX_MONITOR_START_URL` is required. The session and output paths above are the defaults. Remove obsolete `MAILBOX_MONITOR_USERNAME` and `MAILBOX_MONITOR_PASSWORD` entries from your local configuration. Never commit credentials, webhook URLs, or session files.

Optional table settings are `MAILBOX_MONITOR_ROW_SELECTOR` (default `.newui-table-row`), `MAILBOX_MONITOR_MAILBOX_SELECTOR` (`td:nth-child(2)`), `MAILBOX_MONITOR_USAGE_SELECTOR` (`td:nth-child(3)`), `MAILBOX_MONITOR_DATA_SORT_UNIT` (`KB`), and `MAILBOX_MONITOR_TIMEOUT_MS` (`30000`).

## Installation and cron

Install dependencies with `npm ci`, then install Chromium with `npx playwright install chromium`. Manual login requires a graphical session and an interactive terminal. Chromium receives `DISPLAY` and `XAUTHORITY` from that terminal so it can open a window in the i3/X11 session. Browser launch failures report display and Chromium setup guidance instead of asking you to renew a session. Normal checks run headless by default.

Keep the existing cron schedule and wrapper invocation. Add `--login` only for manual session renewal. The wrapper uses Node from PATH, then the installed nvm default if PATH has no Node. Set `MAILBOX_MONITOR_NODE_BIN` only when a fixed executable path is required; an invalid explicit path fails with an actionable message. It must run as the same Unix user that saved the session, with the same session path.

Create the log directory before using shell output redirection:

```bash
install --directory --mode=0700 "${HOME}/.logs/mailbox-monitor"
```

Example daily run at 07:15 in cron's configured timezone:

```cron
15 7 * * * /bin/bash -c 'umask 077; exec "$HOME/.dotfiles/bashrc/helpers/mailbox-monitor/run-mailbox-monitor.sh" --env-file "$HOME/.dotfiles/bashrc/helpers/mailbox-monitor/.env" >> "$HOME/.logs/mailbox-monitor/$(date +\%Y\%m\%d-\%H\%M\%S).log" 2>&1'
```

## Reports and failures

Successful checks write `latest-mailboxes.json`, `latest-alerts.json`, `latest-summary.md`, and `latest-mailboxes.html` under the output directory. Yellow starts at 80%, and red starts at 95%, unless configured otherwise. Discord quota alerts are sent only when at least one mailbox meets the yellow threshold.

Failed checks attempt to save `latest-error.png` and send a Discord failure notification. Existing reports can therefore be stale after a failure.

## Session privacy

The saved session contains authentication cookies, browser storage, and a page URL that can contain session tokens. Treat the whole file like a password. If your session was saved by the earlier cookies-only implementation, run `--login` once more to capture the authenticated page URL. The monitor creates its parent directory with mode `0700` and writes the session atomically with mode `0600`. Use a dedicated session directory: the monitor enforces `0700` on that directory. Successful checks refresh the saved browser state. Do not run login and scheduled checks concurrently.

Session files default to a location outside the repository. Reports, HTML, and screenshots can contain mailbox details and control-panel session links. Keep the output directory private, and do not publish these files. The `.env` file should have mode `0600`.

## Implementation reference

See [DOCUMENTATION.md](DOCUMENTATION.md) for the helper function reference.
