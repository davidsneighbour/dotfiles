# Clockify session integration

This folder connects the isolated `tools/clockify` CLI to the i3 desktop session.

`polybar-clockify` is a small Bash wrapper used by the i3 Polybar copy. It calls the TypeScript tool, converts status JSON into a coloured Lucide indicator, and opens the local form on left click. Right-clicking the module opens the full Clockify tracker overview (`https://app.clockify.me/tracker`) in the default browser via `xdg-open`, wired directly in `07-module-clockify.ini` since it doesn't touch any Clockify state.

Polybar starts from i3 through a non-interactive shell, so it may not inherit the interactive NVM `PATH`. The wrapper resolves `node` from `PATH` first and then falls back to `~/.nvm/versions/node/*/bin/node`; if no usable Node binary is found, it prints the purple error indicator instead of leaving the module blank.

## Polybar states

| Indicator | State | Meaning |
| --- | --- | --- |
| Green Lucide `clock-plus` (`U+E667`) | `healthy` | No timer is running, by the local tracking state. |
| Red Lucide `clock-arrow-down` (`U+E600`) | `running` | A timer is running, by the local tracking state. A timer started outside this workstation shows after the next online check. |
| Yellow Lucide `clipboard-clock` (`U+E688`) | `nudge` | No timer is running, and active non-idle desktop usage exceeded the configured nudge threshold. |
| Purple Lucide `U+E4B1` | `error` | Missing token or another local problem. |

The status reads only local state and sends no Clockify API requests. Clockify's Free plan allows 30 API requests per hour, so the bar must not poll Clockify. Polybar's hidden fallback refresher polls the wrapper every 60 seconds. The online check for a running timer happens when you open the form and when the form window gets focus again. See [the Clockify tool README](../../../tools/clockify/README.md#api-rate-limits) for the request budget.

The visible Polybar module is `custom/ipc`. After a successful entry change through the form or the CLI, the tool updates the local tracking state, resets the local nudge counter, and sends `polybar-msg action clockify hook 0`, so the indicator refreshes immediately when the bar has IPC enabled. A hidden `clockify-refresh` module still triggers the same hook every minute as a fallback.

## Token handling

The wrapper does not store secrets. The TypeScript tool reads `CLOCKIFY_TOKEN` from the environment or from `~/.env`.

## Commands

```bash
configs/session/clockify/polybar-clockify --status
configs/session/clockify/polybar-clockify --open-form
```

The form binds to `127.0.0.1` only. If the configured form port is already in use, `--open-form` reopens the existing local form URL instead of starting another server. The browser window opens through Chrome app mode with the dedicated profile at `~/.config/dnb-clockify/chrome-profile`; i3 floats and centres that window via the `dnb-clockify-form` class. After a successful submit, the page closes its own app window; it does not terminate Chrome or any other browser windows.

If a previous form server is stuck (holding the port without responding), run `dnb-clockify form --restart` directly from `tools/clockify` to kill it and start a fresh one — see `tools/clockify/README.md`.

Clockify’s Polybar status poll runs every 60 seconds and enables `status --remind`. During the full-hour minute, it sends one Dunst notification asking you to add tracking if no timer is running, the latest Clockify entry ended at least one hour ago (or no entry exists), and no entry was changed through the local tool in the past hour. It repeats at subsequent full hours while these conditions hold, including during desktop idle time. The reminder uses only the local tracking state and sends no API requests. Notification failures are reported on stderr. A local cache prevents repeat notifications within the same hour. Missed hours are not replayed. Entries added or timers started through other Clockify clients are known only after the next online check, for example when you open the form.
