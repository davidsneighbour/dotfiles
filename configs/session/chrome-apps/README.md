# Chrome apps prototype

Prototype for running Chrome-hosted web apps as distinct X11 applications.

Each app gets:

* its own Chrome `--user-data-dir`;
* its own `--class` / X11 `WM_CLASS`;
* its own `.desktop` launcher and `StartupWMClass`;
* its own icon name.

The prototype contains ChatGPT, Codex, and Claude.

## Suggested dotfiles layout

```text
configs/session/chrome-apps/
├── README.md
├── apps/
│   ├── chatgpt.conf
│   ├── claude.conf
│   └── codex.conf
└── bin/
    └── chrome-app

configs/system/launchers/
├── chatgpt.desktop
├── claude.desktop
└── codex.desktop
```

The controller should be linked into a directory on the graphical session's
`PATH`, preferably `~/.local/bin/chrome-app`. The app definitions should be
linked to `~/.config/chrome-apps/apps/`.

## Runtime state

Chrome creates one independent browser state tree per application:

```text
~/.local/share/chrome-apps/
├── chatgpt/
├── claude/
└── codex/
```

Normal Chrome continues using its normal user-data directory and therefore
cannot restore the sessions stored in these app-specific directories.

## Usage

```bash
chrome-app --list
chrome-app --inspect codex
chrome-app --app=codex
```

The controller accepts `--app NAME`, not positional application names.

## X11 verification

Launch one app and inspect it:

```bash
chrome-app --app=codex
xprop WM_CLASS
```

Click the Codex window. The class should contain `dnb-codex`.

For i3, the same identity can be inspected with the existing window inspector.
The resulting rule target should be equivalent to:

```text
[class="dnb-codex"]
```

The `.desktop` file deliberately uses the same value:

```ini
StartupWMClass=dnb-codex
```

This is what lets launchers, switchers, i3 rules, and compatible desktop
components distinguish the app from ordinary Google Chrome.

## Icons

The prototype uses icon names `chatgpt`, `codex`, and `claude`. They must exist
in the configured icon theme or be installed separately. Prefer application-
specific icon names so switchers do not fall back to the Google Chrome icon.

## Adding another app

Create `~/.config/chrome-apps/apps/example.conf`:

```bash
APP_NAME="Example"
APP_URL="https://example.com/"
APP_CLASS="dnb-example"
APP_PROFILE="example"
```

Then create a matching desktop entry:

```ini
[Desktop Entry]
Version=1.0
Type=Application
Name=Example
Exec=chrome-app --app=example
Icon=example
Terminal=false
StartupNotify=true
StartupWMClass=dnb-example
Categories=Network;
```

Keep `APP_CLASS` and `StartupWMClass` identical.
