# Rofi window switcher

This project uses `rofi` as a replacement for the standard Alt+Tab window switcher. The script lives at `configs/system/rofi/window-switcher.sh` and provides a keyboard-driven window menu that can show either:

* all open windows across all workspaces
* only the windows on the current workspace

The implementation is based on `rofi`'s built-in window modes. `window` shows all windows, while `windowcd` shows only windows on the current desktop. `rofi` also supports custom window formatting, icons, thumbnails, and theme overrides, which makes it a good fit for a more controlled and scriptable window switcher setup. :contentReference[oaicite:0]{index=0}

## Scope

This document currently describes the setup for **Xubuntu/Xfce on X11**.

That is the primary target because `rofi` is an X11 window switcher and Xfce exposes keyboard shortcut configuration in a straightforward way through both the GUI and `xfconf`. This document should stay open for future additions for other environments such as other Xfce-based distributions, plain XFCE, or other Linux desktop environments where the shortcut binding path differs. :contentReference[oaicite:1]{index=1}

## Script location

The switcher script lives at:

`configs/system/rofi/window-switcher.sh`

Make it executable once after creating or updating it:

```bash
chmod +x configs/system/rofi/window-switcher.sh
````

## What the script does

The script wraps `rofi` and exposes two scopes:

* `all`
  Shows windows from all workspaces using `rofi -show window`

* `workspace`
  Shows only windows from the current workspace using `rofi -show windowcd`

The current default is:

* `--scope all`

So running the script without arguments is equivalent to:

```bash
./configs/system/rofi/window-switcher.sh --scope all
```

This behaviour maps directly to `rofi`'s documented window modes. `windowcd` is specifically intended for the current desktop only. ([Davatorium][1])

## Usage

### Show all windows

```bash
./configs/system/rofi/window-switcher.sh --scope all
```

### Show windows on the current workspace only

```bash
./configs/system/rofi/window-switcher.sh --scope workspace
```

### Show help

```bash
./configs/system/rofi/window-switcher.sh --help
```

### Default behaviour

```bash
./configs/system/rofi/window-switcher.sh
```

This currently defaults to:

```bash
./configs/system/rofi/window-switcher.sh --scope all
```

## Current rofi behaviour

The switcher is configured around these ideas:

* `Alt+Tab` and `Down` move down in the list
* `Alt+Shift+Tab` and `Up` move up in the list
* `Alt+Escape` and `Escape` cancel
* icons are shown
* the list is formatted for readability
* the layout is controlled via `-theme-str`

`rofi` supports keyboard customisation through command-line options such as `-kb-row-down`, `-kb-row-up`, and `-kb-cancel`. It also supports window entry formatting through `-window-format`, and visual/layout tuning through the theme system and `-theme-str`. ([Davatorium][1])

## Window scopes

### All windows

Use this when you want a global Alt+Tab replacement across all workspaces.

Command logic:

```bash
rofi -show window
```

Suggested entry formatting for this mode:

```text
{w:10} {c:18} {t}
```

This is useful because it shows:

* workspace / desktop label
* window class
* window title

That makes the cross-workspace list easier to scan.

### Current workspace only

Use this when you want stricter workspace separation.

Command logic:

```bash
rofi -show windowcd
```

Suggested entry formatting for this mode:

```text
{c:20} {t}
```

This avoids wasting space on workspace labels when the list is already limited to the current workspace. `rofi` documents window formatting placeholders such as workspace name, class, title, name, and role. ([Davatorium][1])

## Formatting options

The current switcher design is built around `-window-format`.

Useful variants:

### Minimal

```text
{t}
```

Use this if your window titles are already distinct.

### Balanced

```text
{c:20} {t}
```

Usually the best default for everyday use.

### Workspace-aware

```text
{w:10} {c:18} {t}
```

Best for the global switcher where windows from multiple workspaces appear together.

If alignment matters, a monospace font often works better for formatted columns in `rofi`. The rofi documentation explicitly notes that monospaced fonts help when alignment matters. ([Davatorium][1])

## Design and theme options

The switcher uses `rofi`'s theme system for layout tuning. This can be done inline with `-theme-str` or later moved into a dedicated `rasi` theme file.

A practical starter layout is:

```text
listview { lines: 12; dynamic: false; scrollbar: true; }
element { padding: 6px; }
element-text { vertical-align: 0.5; }
```

Useful design directions:

### Compact list

```text
listview { lines: 10; dynamic: false; scrollbar: true; }
```

### Spacious list

```text
listview { lines: 14; spacing: 4px; }
element { padding: 8px; }
```

### Grid layout

```text
listview { lines: 3; columns: 2; fixed-columns: true; }
```

### Thumbnail experiment

`rofi` also supports window thumbnails in the window switcher:

```bash
-window-thumbnail
```

This may look good for a more visual switcher, but it should be tested in the actual desktop setup before making it the default. Theme customisation, layout widgets, and inline theme overrides are all supported by the current `rofi` theme system. ([Davatorium][1])

## Recommended default profile

For a practical first setup, the following is a good baseline:

* show icons
* 12 visible rows
* readable spacing
* balanced format for workspace-local switching
* workspace-aware format for global switching

That leads to the following general preference:

### All windows

```text
-window-format "{w:10} {c:18} {t}"
```

### Current workspace

```text
-window-format "{c:20} {t}"
```

## Manual tests

Before binding the switcher to a shortcut, test `rofi` itself directly.

### Test all windows

```bash
rofi -show window
```

### Test current workspace only

```bash
rofi -show windowcd
```

If these commands work, but the wrapper script does not, the problem is in the script.

If these commands do not work either, the problem is likely one of:

* `rofi` is not installed
* the session environment is wrong
* the current environment does not support the relevant X11 window interaction
* the script is launched from a context that does not inherit the right desktop session variables

Because `rofi` is documented as an X11 window switcher, testing within the active Xfce/X11 session is important. ([Davatorium][1])

## Configuring Alt+Tab in Xubuntu

### Important note for Xubuntu/Xfce

In Xfce, keyboard shortcuts are split between two places:

* **Window Manager Settings > Keyboard**
  for window-manager actions
* **Keyboard Preferences > Shortcuts**
  for application shortcuts and custom commands

This matters because replacing Alt+Tab with a script usually involves:

1. disabling or reassigning the default window-manager Alt+Tab action
2. binding Alt+Tab to the custom script as an application shortcut

The Xfce documentation and FAQ describe this split explicitly. ([Xfce Docs][2])

### Suggested GUI setup in Xubuntu

#### 1. Remove or change the default Alt+Tab action

Open:

**Settings Manager > Window Manager > Keyboard**

Look for the existing window cycling actions and either:

* disable the default Alt+Tab binding
* or move it to a different key combination

This prevents the built-in Xfce switcher from competing with your custom `rofi` switcher. Xfce documents that window-manager shortcuts are configured in the Window Manager keyboard settings. ([Xfce Docs][2])

#### 2. Add the custom rofi switcher command

Open:

**Settings Manager > Keyboard > Application Shortcuts**

Add a new shortcut for:

```bash
/path/to/your/dotfiles/configs/system/rofi/window-switcher.sh --scope all
```

Then press:

```text
Alt+Tab
```

Xfce's keyboard settings documentation shows that custom application shortcuts can be assigned directly by pressing the desired key combination in the shortcut dialog. ([Xfce Docs][3])

#### 3. Optional: add a workspace-only switcher

You may also want a second shortcut for current-workspace-only switching, for example:

```bash
/path/to/your/dotfiles/configs/system/rofi/window-switcher.sh --scope workspace
```

Bind that to a separate shortcut such as:

```text
Alt+grave
```

or any other combination that fits your workspace workflow.

### Notes

* Use an **absolute path** in the Xfce shortcut entry.
* Do not rely on the terminal's current working directory.
* Test the command manually first.
* If Alt+Tab is already grabbed by the window manager, the custom application shortcut will not win until the original binding is removed or changed.

## Example Xubuntu setup

Example bindings:

* `Alt+Tab`
  `configs/system/rofi/window-switcher.sh --scope all`

* `Super+Tab`
  `configs/system/rofi/window-switcher.sh --scope workspace`

In practice, the actual command entered into Xfce should be the full path, for example:

```bash
/home/patrick/path/to/dotfiles/configs/system/rofi/window-switcher.sh --scope all
```

## Extension points

The current script is intentionally simple and should stay easy to extend.

### 1. Add a single wrapper option

A future wrapper could expose a single public function or command like:

```bash
window-switcher.sh --scope all
window-switcher.sh --scope workspace
```

This is already the current interface and should remain stable.

### 2. Move theme settings into a `.rasi` file

Inline `-theme-str` is convenient for development, but if the design grows more complex, move the styling into a dedicated rofi config or theme file such as:

`~/.config/rofi/config.rasi`

The rofi documentation describes this as a standard path for config/theming. ([Davatorium][4])

### 3. Support thumbnails

Experiment with:

```bash
-window-thumbnail
```

This may improve scanning for visually distinct windows.

### 4. Expose formatting presets

Potential future options:

* `--format minimal`
* `--format balanced`
* `--format workspace-aware`

That would make the switcher easier to integrate into different workflows without editing the script.

### 5. Add environment-specific sections

This document should later gain dedicated sections for:

* other Xfce-based systems
* other Linux desktop environments
* any setup differences between X11 and other session types

For now, **Xubuntu/Xfce on X11** is the only documented target.

## Troubleshooting

### Running the script does nothing

If you run:

```bash
./configs/system/rofi/window-switcher.sh
```

and nothing happens, check these points:

* the file is executable
* the script contains a real main entry point
* `rofi` is installed and available in `PATH`
* `rofi -show window` works on its own
* the script is being run inside the active desktop session

### Alt+Tab still opens the old switcher

That usually means Xfce's built-in window-manager shortcut is still active.

Check:

**Settings Manager > Window Manager > Keyboard**

and remove or reassign the original Alt+Tab binding. Xfce's documentation states that window-manager shortcuts are configured separately from general application shortcuts. ([Xfce Docs][2])

### The shortcut works in a terminal but not from Xfce

That usually points to one of these:

* wrong path in the shortcut command
* missing executable bit
* environment mismatch between terminal and shortcut launcher

Use a full absolute path and test the exact same command manually.

## Maintenance notes

The current goal is not to create a fully generic Linux switcher abstraction. The goal is to have a clean, scriptable `rofi` window switcher that fits into the workspace tooling and can be called consistently from shell functions, keybindings, and future automation.

Because the implementation relies on `rofi`'s native modes instead of external filtering, it stays small and easier to maintain. `window` and `windowcd` already cover the main use cases directly.

## Why the popup appears on key release

The rofi switcher is triggered on **key release**, not on key press. This is expected behaviour in Xubuntu/Xfce and is not controlled by the script itself.

Two technical reasons explain this:

* **Xfce shortcut handling**  
  Application shortcuts in Xfce are executed after the key combination is completed (on release). There is no built-in option in Xfce to change this behaviour to "trigger on key-down".

* **Keyboard grab requirements in rofi**  
  `rofi` needs to take control of keyboard input when it opens. While modifier keys (like Alt) are still held down and owned by the window manager, this keyboard grab can fail or behave inconsistently. Launching on key release ensures that the keybinding system has fully released control before `rofi` starts.

Because of this, launching the switcher on key-down is generally **not possible** within Xfce's shortcut system and is often **not desirable** from a technical standpoint.

### Can this be changed?

Only by replacing the shortcut handling layer. Possible alternatives include:

* using a different window manager with explicit support for key press/release bindings
* using a dedicated hotkey daemon (e.g. `sxhkd`, `xbindkeys`) that allows triggering on key press

Even in those setups, launching `rofi` on key-down may still lead to input conflicts, so key-release triggering remains the most stable and compatible approach.

### Practical takeaway

Treat the key-release behaviour as part of the design:

* optimise the `rofi` theme and layout for fast rendering
* keep the list concise and readable
* rely on fast keyboard navigation instead of instant key-down activation

In practice, a well-tuned `rofi` switcher feels just as responsive as a traditional Alt+Tab implementation, even with key-release triggering.
