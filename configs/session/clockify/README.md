# Clockify session integration

This folder connects the isolated `tools/clockify` CLI to the i3 desktop session.

`polybar-clockify` is a small Bash wrapper used by the i3 Polybar copy. It calls the TypeScript tool, converts status JSON into a coloured Lucide indicator, and opens the local form on left click.

Polybar starts from i3 through a non-interactive shell, so it may not inherit the interactive NVM `PATH`. The wrapper resolves `node` from `PATH` first and then falls back to `~/.nvm/versions/node/*/bin/node`; if no usable Node binary is found, it prints the purple error indicator instead of leaving the module blank.

## Polybar states

| Indicator | State | Meaning |
| --- | --- | --- |
| Green Lucide `U+E080` | `healthy` | Clockify is reachable, and no timer is running. |
| Red Lucide `U+E083` | `running` | A timer is running, including one started outside this workstation. |
| Yellow Lucide `U+E082` | `nudge` | No timer is running, and active non-idle desktop usage exceeded the configured nudge threshold. |
| Purple Lucide `U+E4B1` | `error` | Token, network, or API problem. |

The CLI keeps a short status cache, defaulting to 30 seconds. Polybar's hidden fallback refresher polls the wrapper every 300 seconds, which keeps the bar gentle on the Clockify API while still refreshing without manual action.

The visible Polybar module is `custom/ipc`. After a successful form submit, the CLI clears the status cache, resets the local nudge counter, and sends `polybar-msg action clockify hook 0`, so the indicator refreshes immediately when the bar has IPC enabled. A hidden `clockify-refresh` module still triggers the same hook every few minutes as a fallback.

## Token handling

The wrapper does not store secrets. The TypeScript tool reads `CLOCKIFY_TOKEN` from the environment or from `~/.env`.

## Commands

```bash
configs/session/clockify/polybar-clockify --status
configs/session/clockify/polybar-clockify --open-form
```

The form binds to `127.0.0.1` only. If the configured form port is already in use, `--open-form` reopens the existing local form URL instead of starting another server. The browser window opens through Chrome app mode with the dedicated profile at `~/.config/dnb-clockify/chrome-profile`; i3 floats and centres that window via the `dnb-clockify-form` class. After a successful submit, the page closes its own app window; it does not terminate Chrome or any other browser windows.

If a previous form server is stuck (holding the port without responding), run `dnb-clockify form --restart` directly from `tools/clockify` to kill it and start a fresh one — see `tools/clockify/README.md`.
