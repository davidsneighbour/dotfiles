# Chrome apps

Run Chrome-hosted web apps with separate profiles and X11 window classes. The controller lives in `bin/chrome-app` and is exposed as the `bashrc/helpers/chrome-app` helper command. App definitions live in `apps/`.

## Installation

Run the default `dotfiles` profile to install the controller at `~/.local/bin/chrome-app` and link `apps/` at `~/.config/chrome-apps/apps/`. The existing `~/.local/share/applications` link exposes `configs/session/launchers/whatsapp.desktop`. Ensure `~/.local/bin` is on the session's `PATH`. With custom XDG configuration paths, link the definitions under `${XDG_CONFIG_HOME}/chrome-apps/apps/` instead.

## Usage

```bash
chrome-app --list
chrome-app --inspect whatsapp
chrome-app --app whatsapp
```

Use the space form `--app NAME`. On first launch, link WhatsApp Web using your phone. Authentication stays in the dedicated profile; do not copy it into an automation-specific profile.

WhatsApp starts automatically once per i3 login through `configs/session/i3/configs/session-starts.conf`. Reloading or restarting i3 does not start it again.

## Single instance

WhatsApp sets `APP_SINGLE_INSTANCE="true"`. The launcher uses `wmctrl` to find an existing window with the app class and activate it on its current workspace. If no matching window exists, it starts Chrome normally. Other apps retain their existing behaviour unless they enable this option. Existing duplicate windows are not closed automatically. This is a window-reuse check, not a lock against simultaneous launches before the first window appears.

## Runtime state

Each app has a separate profile under `${XDG_DATA_HOME:-${HOME}/.local/share}/chrome-apps/`, selected by `APP_PROFILE`. With the standard environment, WhatsApp uses `~/.local/share/chrome-apps/whatsapp/`. Normal Chrome uses its own profile. Keep profile state outside the repository.

## X11 verification

Run `chrome-app --app whatsapp`, then run `xprop WM_CLASS` and click the window. Its class should contain `dnb-whatsapp`, matching `StartupWMClass` in the desktop entry. The existing i3 window inspector can also inspect this identity. No workspace assignment is required.

## Adding another app

Add an app definition to `apps/example.conf`:

```bash
APP_NAME="Example"
APP_URL="https://example.com/"
APP_CLASS="dnb-example"
APP_PROFILE="example"
```

Add a matching entry under `configs/session/launchers/` with `Exec=chrome-app --app example` and `StartupWMClass=dnb-example`. Keep the class values identical. Prefer an app-specific icon name; the icon must be available in the installed icon theme. The older prototype desktop entries in `launchers/` are reference examples and are not installed automatically.

## Validation

Use `chrome-app --inspect whatsapp` without opening a browser. Run `npm run check` for repository checks. `npm run test:shell` includes an isolated launch test with a fake Chrome executable, which checks profile selection and arguments without accessing customer messages.
