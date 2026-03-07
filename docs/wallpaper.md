## Wallpaper management script

A portable CLI tool to set desktop wallpapers across multiple Linux desktop environments with consistent logging and behaviour.

### Core features

* **Environment detection**

  * Automatically detects the active desktop or window manager.
  * Supports XFCE, GNOME-family desktops, KDE Plasma, Sway, Hyprland, and generic X11 sessions.

* **Correct backend per environment**

  * XFCE: uses `xfconf-query` and `xfdesktop --reload`
  * GNOME/Cinnamon/MATE: uses `gsettings`
  * KDE Plasma: uses `qdbus` / `qdbus6`
  * Sway: uses `swaymsg`
  * Hyprland: uses `hyprctl` / `hyprpaper`
  * Generic X11 fallback: uses `feh`

* **Unified CLI interface**

```bash
wallpaper-set.sh --wallpaper PATH
```

The same command works across different systems and desktop environments.

* **Logging**

Logs wallpaper changes to `~/.logs/desktop/wallpaper.log`.`

Log entries include timestamps, selected backend, and execution results.

* **Wallpaper styles**

Supports common wallpaper placement modes:

* `fill`
* `fit`
* `stretch`
* `center`
* `tile`

Style settings are translated automatically to the appropriate backend.

* **Manual backend override**

The backend can be explicitly selected:

```bash
wallpaper-set.sh --wallpaper image.jpg --mode xfce
```

Available modes: `auto | xfce | gnome | kde | sway | hyprland | feh`.

* **Verbose mode**

Optional runtime diagnostics: `--verbose`.

Prints log messages to stdout in addition to writing the log file.

### Design goals

* One consistent wallpaper command across systems
* Avoid conflicts with desktop wallpaper managers (e.g. XFCE `xfdesktop`)
* Safe for dotfiles deployment
* Works across both X11 and Wayland environments
* Fully scriptable and automation-friendly

### Example

```bash
wallpaper-set.sh --wallpaper ~/Pictures/wallpapers/forest.jpg
```

Sets the wallpaper using the appropriate backend for the current desktop session and records the action in the wallpaper log.
