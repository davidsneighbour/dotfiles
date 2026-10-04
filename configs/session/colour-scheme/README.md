# Session colour scheme

The i3 session maintains `prefer-dark` through `org.gnome.desktop.interface color-scheme`. The existing portal provider exposes this as `org.freedesktop.appearance color-scheme=1`. This layer does not replace the portal backend, change the session desktop identity, or replace existing GTK, Qt, Rofi, and Polybar palettes. It selects dark mode; Enpass still uses its own dark palette, rather than Dracula colours.

## Usage

The helper command lives in `bashrc/helpers/`, as required by the repository Bash rules. i3 runs `session-colour-scheme --apply` at startup and restart. It checks the setting first, writes only when needed, and reports failures on stderr without preventing i3 from starting. `preference` is the global policy; it currently supports only `prefer-dark`.

```bash
bashrc/helpers/session-colour-scheme --apply
bashrc/helpers/session-colour-scheme --tool enpass -- --minimize
bashrc/helpers/session-colour-scheme --tool enpass -- showassistant
```

Enpass startup, `Ctrl+Shift+Alt+E`, and the `enpass.desktop` launcher all use the same `tools/enpass.conf`. That profile sets `XDG_CURRENT_DESKTOP=GNOME` only for Enpass and its children. Arguments, including URLs and arguments containing spaces, pass through unchanged. No Enpass controller exists in the current tree; window placement remains in i3 rules.

Dotbot already links `configs/session/launchers` to `~/.local/share/applications`. The matching `enpass.desktop` filename overrides the installed system entry and retains its URL handlers. Run `update-desktop-database ~/.local/share/applications` after adding it. Reload i3 with `i3-msg reload`, and run `--apply` once for the current session. Quit Enpass normally, then relaunch through this helper to change an already-running instance's environment; a second invocation cannot alter the first instance. Future logins use the updated startup path.

## Add a tool

1. Add `tools/<name>.conf`, where the name contains lowercase letters, digits, or hyphens, and starts with a letter or digit.
2. Set exactly one `executable=/absolute/path/to/program`, then add process-local environment assignments, for example `XDG_CURRENT_DESKTOP=GNOME` only when that app requires it.
3. Route all relevant i3 bindings, startup commands, controllers, and desktop entry `Exec` lines through `session-colour-scheme --tool <name> --`. Keep placement and lifecycle logic in their existing owners.
4. Check the real app after restarting its existing instance, and document why its override is needed.

Configs are data, not shell scripts: one literal `NAME=value` per line, with empty lines and full-line `#` comments allowed. Do not add quotes, `export`, variable substitutions, shell commands, or inline comments. The parser splits at the first `=`, does not evaluate values, and rejects malformed assignments, invalid names, and missing executables. Profiles inherit the parent environment and override only their listed variables. They are trusted repository configuration; do not place secrets in them.

The helper supports `--help`, `--verbose`, `--quiet`, and `DNB_VERBOSE=1`. Verbose diagnostics use the core logging API and `~/.logs/colour-scheme/YYYYMMDD-HHMMSS.log`. `--quiet` takes precedence. Diagnostic errors always remain visible.

## Verification

```bash
shellcheck bashrc/helpers/session-colour-scheme
bash -n bashrc/helpers/session-colour-scheme
i3 -C -c configs/session/i3/config
gsettings get org.gnome.desktop.interface color-scheme
dbus-send --session --print-reply=literal --reply-timeout=1000 --dest=org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.Settings.Read string:org.freedesktop.appearance string:color-scheme
```

Expected preference: `'prefer-dark'`; expected portal value: `uint32 1`. If they disagree, inspect the existing portal service rather than changing the whole session identity. A direct `/opt/enpass/Enpass` invocation bypasses compatibility settings.
