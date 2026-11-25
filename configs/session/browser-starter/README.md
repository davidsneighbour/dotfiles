# Browser starter

`Ctrl+Shift+Alt+B` shows a temporary side bar on the left edge of the screen. Each button starts Google Chrome with one Chrome profile. A close button is at the bottom. The bar closes after a click on a button, after `bar.timeout_seconds` (default: 30 seconds), or when you press `Ctrl+Shift+Alt+B` again.

## Files

| Path | Purpose |
| --- | --- |
| `browser-starter.toml` | Configuration: bar size, timeout, close button, and the profile buttons. |
| `browser-starter.ts` | Controller. Reads the configuration, starts and stops the bars, and starts Chrome. Run `browser-starter.ts --help` for the commands. |
| `tests/browser-starter.test.ts` | Tests for configuration checks, layout, and the generated Polybar configuration (`npm run test:browser-starter`). |

## Chrome profiles

The buttons use the existing Chrome profiles in `~/.config/google-chrome`. A button runs `google-chrome-stable --profile-directory=<directory>`, so logins, sync, extensions, and history stay in the profile, and all profiles share one Chrome process. When Chrome already runs, it opens a new window of that profile.

`directory` is the profile folder name, for example `Default` or `Profile 3`, not the name that Chrome shows. Chrome never renames these folders. To see the folders and their names:

```bash
configs/session/browser-starter/browser-starter.ts --list-profiles
```

If a configured folder does not exist, Chrome creates a new, empty profile with that folder name on the first start. `--check` and the session log show a warning for each such folder.

## Configuration

Edit `browser-starter.toml`, then check it:

```bash
configs/session/browser-starter/browser-starter.ts --check
```

`--check` validates the file and prints the generated Polybar configuration. Unknown keys are errors.

Each `[[profiles]]` entry has these keys:

| Key | Required | Value |
| --- | --- | --- |
| `label` | yes | Text right of the icon, 1 to 6 characters. |
| `directory` | yes | Chrome profile folder name. |
| `icon` | yes | One icon character, written as an escape such as `"\uE19F"`. |
| `font` | no | `lucide` (default), `nerd`, or `brands`. |
| `colour` | no | Icon colour: `#RRGGBB`, or a name from `configs/session/polybar/configs/01-colours.ini` such as `cyan`. Default: `foreground`. |

Lucide codepoints are in `~/.fonts/System/lucide/codepoints.json`. For example, `"user": 57759` is `\uE19F` (57759 in hexadecimal is E19F).

The `[bar]` section sets `timeout_seconds`, `icon_pixels`, `icon_offset_pixels`, `label_pixels`, `item_height_pixels`, `width_pixels`, `top_offset_pixels`, and `show_labels`. The comments in `browser-starter.toml` explain each one. With `show_labels = false`, the icons are centred; set `width_pixels` to about `item_height_pixels`.

## How it works

Polybar 3.7 draws only horizontal bars. The side bar is therefore a stack of small Polybar bars on the left edge: one bar for each profile, one filler bar, and one close bar. Each time the side bar opens, the controller:

1. Reads the configuration, the colours from `configs/session/polybar/configs/01-colours.ini`, and the font families from `01-fonts.ini`. The side bar thus uses the same design as the top bar, with larger font sizes.
2. Gets the primary monitor from `polybar --list-monitors` and writes the bar configuration to `${XDG_RUNTIME_DIR}/dnb-browser-starter/bars-<token>.ini`.
3. Starts one Polybar process for each bar. The bars use `override-redirect = true`, so i3 does not manage them or reserve space for them; they cover the windows below them. They start below the top bar (`top_offset_pixels`).
4. Starts a timer (`sh -c 'sleep N; exec browser-starter.ts --close --session <token>'`). The token makes sure that an old timer never closes a newer bar.
5. Writes the process IDs to `${XDG_RUNTIME_DIR}/dnb-browser-starter/state.json`.

`--close` stops only the Polybar processes whose command line contains that session's bar configuration, so the top bar is never affected. Polybar runs the click commands; a profile click runs `--launch <directory>`, which starts Chrome as a separate process and then closes the bar.

`configs/session/polybar/launch.sh` stops all Polybar processes of the user, so an i3 restart also removes an open side bar. The timer then only removes the old state.

## Logs and errors

Each opened bar writes `~/.logs/browser-starter/YYYYMMDD-HHMMSS.log`, with the Polybar warnings and the controller steps. Configuration errors and bars that fail to start also show a desktop notification, because the key binding has no terminal.

## Validation

```bash
configs/session/browser-starter/browser-starter.ts --check
npm run test:browser-starter
i3 -C -c configs/session/i3/config
```

To test the bar without a real Chrome window, put a fake `google-chrome-stable` first on `PATH` before you run `--open`.
