# Mailbox quota monitor

This project monitors mailbox disk usage for a hosting control panel that does not send early quota warnings.

The script logs in to the hosting admin UI with Playwright, follows the configured navigation path, reads the mailbox table, calculates mailbox usage percentages, and sends a Discord alert when one or more mailboxes are at or above the configured warning threshold.

The intended deployment target is a personal local machine via cron.

## What it does

The monitor performs the following steps:

1. Loads configuration from an `.env` file.

2. Opens the configured hosting control panel URL with Playwright.

3. Logs in with the configured admin username and password.

4. Follows the configured navigation path, for example:

   ```text
   Email|Manage Mailboxes
   ```

5. Extracts mailbox rows from the mailbox overview table.

6. Parses current disk usage and mailbox quota.

7. Calculates the used percentage per mailbox.

8. Classifies each mailbox:

   * `green`: below 80%
   * `yellow`: 80% or higher
   * `red`: 95% or higher

9. Writes local report files.

10. Sends a Discord message only when at least one mailbox is 80% full or more.

The script does not modify mailboxes. It only reads the table.

## Files

Expected local structure:

```text
~/scripts/mailbox-monitor/
├── .env
├── monitor-mailboxes.mjs
├── package.json
├── package-lock.json
└── run-mailbox-monitor.sh
```

Generated logs and reports:

```text
~/.logs/mailbox-monitor/
├── cron.log
├── reboot.log
├── latest-mailboxes.html
├── latest-mailboxes.json
├── latest-alerts.json
├── latest-summary.md
└── latest-error.png
```

## Requirements

* Node.js
* npm
* Playwright
* Chromium installed through Playwright
* A Discord webhook URL
* A valid hosting admin account

Install dependencies:

```bash
npm install --save-dev playwright
npx playwright install chromium
```

## Configuration

The script is configured through `.env`.

Example:

```bash
DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."

MAILBOX_MONITOR_START_URL="https://example-control-panel-login-url.invalid/"
MAILBOX_MONITOR_USERNAME="admin-username"
MAILBOX_MONITOR_PASSWORD="admin-password"
MAILBOX_MONITOR_PROJECT_NAME="Customer mailboxes"

MAILBOX_MONITOR_NAV_PATH="Email|Manage Mailboxes"
MAILBOX_MONITOR_YELLOW_THRESHOLD="80"
MAILBOX_MONITOR_RED_THRESHOLD="95"
MAILBOX_MONITOR_HEADLESS="true"

MAILBOX_MONITOR_OUTPUT_DIR="${HOME}/.logs/mailbox-monitor"
```

Optional selector overrides:

```bash
MAILBOX_MONITOR_USERNAME_SELECTOR='input[name="username"]'
MAILBOX_MONITOR_PASSWORD_SELECTOR='input[type="password"]'
MAILBOX_MONITOR_LOGIN_SELECTOR='button[type="submit"]'

MAILBOX_MONITOR_ROW_SELECTOR=".newui-table-row"
MAILBOX_MONITOR_MAILBOX_SELECTOR=".col-7"
MAILBOX_MONITOR_USAGE_SELECTOR=".col-2"
MAILBOX_MONITOR_DATA_SORT_UNIT="KB"
MAILBOX_MONITOR_TIMEOUT_MS="30000"
```

## Navigation path

The navigation path is configured as a pipe-separated list:

```bash
MAILBOX_MONITOR_NAV_PATH="Email|Manage Mailboxes"
```

The script clicks each item in order.

For normal visible navigation links, it uses the visible text. For icon-only buttons or links, it also checks attributes such as:

* `data-bs-title`
* `title`
* `aria-label`

This allows it to click the `Manage Mailboxes` cogwheel even when the text is only present as a Bootstrap tooltip title.

## Manual test

Run once with a visible browser:

```bash
MAILBOX_MONITOR_HEADLESS=false ./run-mailbox-monitor.sh --env-file .env
```

For normal unattended operation:

```bash
MAILBOX_MONITOR_HEADLESS=true ./run-mailbox-monitor.sh --env-file .env
```

## Cron setup

Daily run at 07:15:

```cron
15 7 * * * ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor/run-mailbox-monitor.sh --env-file ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor/.env >> ${HOME}/.logs/mailbox-monitor/cron.log 2>&1
```

Optional reboot run:

```cron
@reboot sleep 90; ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor/run-mailbox-monitor.sh --env-file ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor/.env >> ${HOME}/.logs/mailbox-monitor/reboot.log 2>&1
```

The `sleep 90` gives the system time to bring up networking and DNS before Playwright tries to log in.

For cron, keep this setting enabled:

```bash
MAILBOX_MONITOR_HEADLESS="true"
```

Headless mode does not require a desktop login session.

## Discord alerts

Discord messages are only sent when one or more mailboxes are at or above the yellow threshold.

Example alert content:

```text
Customer mailboxes: mailbox quota warning
Flagged: 3/60 mailboxes. Red: 1. Yellow: 2.

red 100.00% - user@example.com - 1000.01 MB / 1000M
yellow 91.36% - mailbox@example.com - 913.58 MB / 1000M
yellow 82.54% - another@example.com - 2.66 GB / 3300M
```

If no mailbox is at or above the yellow threshold, the script does not send a Discord message.

## Local output files

The script writes the latest full result to:

```text
latest-mailboxes.json
```

The filtered warning result is written to:

```text
latest-alerts.json
```

The readable summary is written to:

```text
latest-summary.md
```

The rendered mailbox page is stored as:

```text
latest-mailboxes.html
```

On failure, the script attempts to save a screenshot:

```text
latest-error.png
```

The screenshot is useful for debugging login or navigation failures.

## Security model

This monitor is designed for local use on a personal machine.

The password is stored in `.env` and loaded into the local Node.js process when the script runs. It is not passed as a command-line argument, which avoids exposing it through shell history or normal process command listings.

The script does not intentionally log the password.

Normal log output contains only:

* success/failure status
* mailbox counts
* flagged mailbox names
* mailbox usage values
* error messages

The Discord alert also contains only mailbox names and usage values. It does not contain the admin username or password.

## Security limitations

This setup is not suitable for shared servers or hostile multi-user systems.

The following local users can potentially access sensitive information:

* the same Unix user
* `root`
* any process with sufficient local debugging or filesystem permissions

The password exists briefly in:

* the `.env` file
* the shell environment while the wrapper runs
* the Node.js process environment while the script starts
* the in-memory Playwright login flow

This is acceptable for the intended personal-machine deployment, but it is still a secret and should be treated accordingly.

## Recommended file permissions

The `.env` file should be readable only by the local user:

```bash
chmod --changes 0600 ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor/.env
```

The script directory should not be writable by other users:

```bash
chmod --changes 0700 ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor
```

The log directory should also be private:

```bash
install --directory --mode=0700 ${HOME}/.logs/mailbox-monitor
```

Check the result:

```bash
ls -ld ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor
ls -l ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor/.env
ls -ld ${HOME}/.logs/mailbox-monitor
```

Expected permissions:

```text
drwx------ ... ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor
-rw------- ... ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor/.env
drwx------ ... ${HOME}/.logs/mailbox-monitor
```

## Git safety

The `.env` file must never be committed.

Add this to `.gitignore`:

```gitignore
.env
*.env
.env.*
!.env.example

node_modules/
playwright-report/
test-results/
```

A safe example file can be committed as `.env.example`:

```bash
DISCORD_WEBHOOK=""

MAILBOX_MONITOR_START_URL=""
MAILBOX_MONITOR_USERNAME=""
MAILBOX_MONITOR_PASSWORD=""
MAILBOX_MONITOR_PROJECT_NAME="Mailbox Monitor"

MAILBOX_MONITOR_NAV_PATH="Email|Manage Mailboxes"
MAILBOX_MONITOR_YELLOW_THRESHOLD="80"
MAILBOX_MONITOR_RED_THRESHOLD="95"
MAILBOX_MONITOR_HEADLESS="true"

MAILBOX_MONITOR_OUTPUT_DIR="${HOME}/.logs/mailbox-monitor"
```

## Screenshots and privacy

On failure, the script writes `latest-error.png`.

The admin username may appear in screenshots. That is acceptable for this deployment.

The password field should normally be masked by the browser because it is a password input. However, screenshots should still be considered private because they may contain:

* the hosting account name
* mailbox names
* admin UI state
* customer-specific information

Do not upload screenshots to public issue trackers or public repositories.

## Hardening already applied or recommended

Recommended hardening:

1. Keep `.env` private with `0600` permissions.
2. Keep the project directory private with `0700` permissions.
3. Keep the log directory private with `0700` permissions.
4. Run Playwright headless from cron.
5. Do not enable Playwright traces, HAR capture, or video recording.
6. Do not print environment variables in shell scripts.
7. Do not use `set -x` in the wrapper script.
8. Do not pass the password as a command-line argument.
9. Remove the password from `process.env` after reading configuration.
10. Clear `config.password` after the login step.

Recommended JavaScript hardening after reading config:

```javascript
const config = getConfig();

delete process.env.MAILBOX_MONITOR_PASSWORD;
delete process.env.MAILBOX_MONITOR_USERNAME;
```

Recommended JavaScript hardening after successful login:

```javascript
await login(page, config);

config.password = "";
```

Optional Chromium environment hardening:

```javascript
browser = await chromium.launch({
  headless: config.headless,
  env: {
    HOME: process.env.HOME || "",
    PATH: process.env.PATH || "",
    LANG: process.env.LANG || "C.UTF-8",
    XDG_RUNTIME_DIR: process.env.XDG_RUNTIME_DIR || "",
  },
});
```

This prevents Chromium from inheriting the full wrapper environment.

## Failure behaviour

When the script fails, it:

1. prints a concise error to the cron log
2. attempts to save `latest-error.png`
3. attempts to send a Discord failure message
4. exits with a non-zero status code

The Discord failure message does not include credentials.

## Troubleshooting

Run with a visible browser:

```bash
MAILBOX_MONITOR_HEADLESS=false ./run-mailbox-monitor.sh --env-file .env
```

Common problems:

### Login field not found

Set explicit login selectors:

```bash
MAILBOX_MONITOR_USERNAME_SELECTOR='input[name="username"]'
MAILBOX_MONITOR_PASSWORD_SELECTOR='input[type="password"]'
MAILBOX_MONITOR_LOGIN_SELECTOR='button[type="submit"]'
```

### Navigation item not found

Check whether the target is a text link, icon button, tooltip title, or aria label.

For icon-only links, inspect attributes such as:

```html
data-bs-title="Manage Mailboxes"
```

Then keep the navigation path as:

```bash
MAILBOX_MONITOR_NAV_PATH="Email|Manage Mailboxes"
```

### Cron works manually but not on reboot

Increase the reboot delay:

```cron
@reboot sleep 180; ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor/run-mailbox-monitor.sh --env-file ${HOME}/.dotfiles/bashrc/helpers/mailbox-monitor/.env >> ${HOME}/.logs/mailbox-monitor/reboot.log 2>&1
```

### Discord message not sent

Check:

* `DISCORD_WEBHOOK` is present in `.env`
* the webhook URL is still valid
* outbound HTTPS works from the machine
* the script found at least one mailbox at or above the yellow threshold

No alert is sent when all mailboxes are below the warning threshold.

## Operational notes

This monitor is intentionally simple.

It does not attempt to call a hidden hosting API. It follows the same web interface a human would use, which makes it resilient against unpredictable session IDs.

The most likely future breakage points are:

* the hosting provider changes the login form
* the hosting provider changes the mailbox table markup
* the hosting provider changes the icon tooltip/title text
* the hosting provider adds multi-factor authentication

When that happens, run once with:

```bash
MAILBOX_MONITOR_HEADLESS=false ./run-mailbox-monitor.sh --env-file .env
```

Then adjust the selectors or navigation path.
