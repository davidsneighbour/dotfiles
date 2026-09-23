<!-- markdownlint-disable-next-line title-case-style -->
# i3 keybindings

Authoritative table of every i3 keybinding defined in
[`configs/session/i3/configs/`](../configs/session/i3/configs/). Update this
table in the same change as any binding you add, change, or remove — see
[`.agents/instructions/session/i3-keybindings.instructions.md`](../.agents/instructions/session/i3-keybindings.instructions.md),
which also defines the mandatory rule that any binding launching, focusing,
or toggling an individual application must use `Ctrl+Shift+Alt+<key>`
(`Control+Shift+Mod1+<key>`), never a bare `Ctrl+Shift+<key>`.

`$mod` is `Mod4` (Super/Windows key).

| Binding | Action |
| --- | --- |
| `Super` (bare, release) | Open Rofi (`drun`) — see "Bare Super key limitation" below |
| `Super+D` | Open Rofi (`drun`) — explicit, always-reliable fallback for the above |
| `Ctrl+Shift+W` | Open Rofi VS Code workspace picker and launch the selection in a temporary dynamic Code workspace (`configs/session/rofi/workspaces.sh --newwindow --dynamic-workspace code`) |
| `Ctrl+Shift+Alt+O` | Launch/focus Obsidian (`/opt/Obsidian/obsidian vault=notes`), assigned to its own workspace via `rules.conf`'s `assign [class="obsidian"] $ws5` |
| `Ctrl+Shift+Alt+S` | Launch/focus Sublime Text (`/usr/bin/subl`) |
| `Ctrl+Shift+Alt+I` | Click a window, then show its WM_CLASS/role/title/PID/geometry in a floating terminal (`configs/session/i3/window-inspector.sh`) — see "Window rules" in `SESSION.md` |
| `Ctrl+Shift+Alt+N` | Move the focused managed window to a freshly created temporary icon workspace (`configs/session/i3/workspaces/workspaces.py promote-focused`) |
| `Ctrl+Shift+Alt+E` | Toggle Enpass in/out of the scratchpad on the current workspace (`[con_mark="scratch-enpass"] scratchpad show`) — see "Window rules" in `SESSION.md` |
| `Ctrl+Shift+Alt+T` | Toggle the persistent scratch terminal in/out of the scratchpad on the current workspace, right half of the focused output (`configs/session/terminal/scratch-terminal --toggle`) — see "Scratch terminal" in `SESSION.md` |
| `Ctrl+Shift+Alt+F` | Show the canonical, singleton Files workspace — a two-pane Thunar environment (LEFT user-controlled, RIGHT the external-open target) invoked via `configs/session/filemanager/file-manager --show` — see "Canonical Files workspace" in `SESSION.md` |
| `Alt+Tab` (`Mod1+Tab`) | Open YAML-aware Rofi window switcher, all workspaces (`configs/session/rofi/window-switcher.sh`) — see "Rofi" in `SESSION.md` |
| `Super+Enter` | Open terminal (`$terminal`, currently `xfce4-terminal`) |
| `Super+Shift+Q` | Close focused window |
| `Super+Shift+C` | Reload i3 config |
| `Super+Shift+R` | Restart i3 in place |
| `Super+Shift+E` | Exit i3, with an `i3-nagbar` confirmation prompt |
| `Super+L` | Lock the screen (`loginctl lock-session`, caught by `xss-lock`) |
| `Super+1`..`Super+9` | Switch to generated numbered icon workspace 1-9 |
| `Super+Shift+1`..`Super+Shift+9` | Move focused window to generated numbered icon workspace 1-9 |
| `Super+Arrow` | Move focus |
| `Super+Shift+Arrow` | Move focused window |
| `Super+F` | Toggle fullscreen |
| `Super+Space` | Toggle floating |
| `Super+R` | Enter resize mode (`Arrow` keys resize, `Enter`/`Escape` to leave) |

## Known exception: `Ctrl+Shift+W`

`Ctrl+Shift+W` launches a Rofi picker that ends in starting a VS Code
workspace, which arguably falls under the "program-launch" rule above but
predates it and has not yet been migrated to `Ctrl+Shift+Alt+W`. `Ctrl+Shift+W`
is also a common "close tab/window" shortcut in browsers, so it carries the
same collision risk the rule exists to prevent. Flagged here rather than
changed silently — migrate it (and update this table) the next time it's
touched, or on explicit request.
