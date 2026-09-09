<!-- markdownlint-disable-next-line title-case-style -->
# Canonical file-manager workspace

Session-scoped subsystem that owns one canonical, singleton Thunar
"Files" workspace for the i3 session. i3-only — XFCE is legacy and does
not receive this functionality (see the repo-root `AGENTS.md` and
`SESSION.md`).

This file is the canonical operational documentation for this subsystem.
`SESSION.md` only points here; it does not duplicate this content.

## Purpose

Plain XDG/`xdg-open`/`gio open` file-manager behaviour has no concept of
"my own browsing window" vs. "wherever this external request happens to
land." Every directory-open request just asks Thunar to show a path, and
Thunar (or XDG) decides which window, if any, to reuse — so a deliberately
arranged browsing session gets clobbered by the next `explore` call, a
build script's "open output folder," or a browser's "show in file
manager."

This controller fixes that by giving the two roles separate, stable
identities:

* a window you arrange and browse in yourself, never touched by anything
  else;
* a window that is always the target of external requests, so you always
  know where the next `explore`/`xdg-open` result will show up.

## User-facing model

```text
┌───────────────────────────────┬───────────────────────────────┐
│ LEFT                          │ RIGHT                         │
│ file-manager-left             │ file-manager-right            │
│ user-controlled                │ external navigation target    │
└───────────────────────────────┴───────────────────────────────┘
```

* **LEFT** — browse, change directories, open tabs, whatever you want.
  Never retargeted by `explore`, `xdg-open`, `gio open`, or any other
  external "open this directory" request.
* **RIGHT** — always the destination for those requests. Every external
  open ends with the Files workspace shown, LEFT unchanged, RIGHT showing
  the requested directory, RIGHT focused.

## Workspace lifecycle

* Reserved i3 workspace number **90** (name `90:<icon>`, where `<icon>` is
  U+E33C — a Nerd Font private-use glyph, invisible without that font
  installed, same as it is throughout this document), a fixed identity so
  the controller can always find "the" Files workspace without ambiguity.
  This number is picked well clear of the dynamic Code workspace range
  (`configs/session/i3/workspaces/workspaces.yaml`'s `launch` command
  starts at 10 and grows upward) — see "Relationship to Code dynamic
  workspaces" below.
* Does not need to exist at session start. Created on first `--show` or
  `--open`.
* i3 removes it on its own once both managed windows are closed and you
  switch away from it (ordinary i3 behaviour for any empty workspace —
  this controller does nothing special here).
* The next invocation recreates it from scratch.
* There is never more than one Files workspace: every command first checks
  for an existing workspace with number 90 before creating anything.

## Commands

```bash
configs/session/filemanager/file-manager --show
configs/session/filemanager/file-manager --open --path "${HOME}/Downloads"
configs/session/filemanager/file-manager --status
configs/session/filemanager/file-manager --help

explore
explore --path "${HOME}/Downloads"

thunar-standalone
thunar-standalone --path "${HOME}/Downloads"
```

* `file-manager --show` — "show my canonical file manager": creates the
  Files workspace/managed windows if absent, otherwise just switches to
  the existing workspace. Never creates a second workspace or duplicate
  managed windows, even when pressed repeatedly.
* `file-manager --open --path <dir>` — ensures the workspace and LEFT
  exist (creating them if needed), then makes RIGHT show `<dir>` (see
  "RIGHT replacement semantics" below). LEFT is never touched. Switches to
  the Files workspace and focuses RIGHT.
* `file-manager --status` — read-only report of the current managed state
  (workspace, LEFT, RIGHT, any unmanaged Thunar windows). Makes no
  changes; useful for diagnostics and for verifying the invariants below.
* [`bashrc/helpers/explore`](../../../bashrc/helpers/explore) — the
  general-purpose "open a directory" helper command. Resolves its target
  path (current directory by default) exactly as before, then delegates to
  `file-manager --open --path`. It never duplicates the controller's
  workspace/window logic itself.
* [`bashrc/helpers/thunar-standalone`](../../../bashrc/helpers/thunar-standalone)
  — opens an ordinary, unmanaged Thunar window on the current workspace.
  See "Standalone Thunar" below.

## Keyboard shortcut

`Ctrl+Shift+Alt+F` (i3 `Control+Shift+Mod1+f`, bound in
`configs/session/i3/configs/applications.conf`) runs `file-manager --show`.
The i3 config only invokes the controller; it contains no workspace/window
logic of its own.

## XDG integration

* [`dnb-file-manager.desktop`](./dnb-file-manager.desktop) is the canonical
  source of the desktop entry that routes directory-opening requests into
  this controller (`Exec=… file-manager --open --path %f`). `Type=Application`,
  `MimeType=inode/directory;`, `NoDisplay=true` (it is a routing target, not
  something to show in an app grid).
* The **installed copy** lives at
  `configs/system/launchers/dnb-file-manager.desktop`, because
  `~/.local/share/applications` is already a whole-directory Dotbot link to
  `configs/system/launchers/` (see `configs/dotbot/config.yaml`). Adding a
  second, one-off Dotbot link *inside* an already directory-linked path
  would fight that existing link rather than reuse it, so the installed
  file is a plain copy of the canonical source kept in sync by hand — this
  is the "least invasive reproducible" option that existing repo
  conventions actually support. If this repo ever gains per-file linking
  into an already-linked directory, revisit this.
* `configs/system/launchers/mimeapps.list` (Dotbot-linked to
  `~/.local/share/applications/mimeapps.list`) sets
  `inode/directory=dnb-file-manager.desktop` under `[Default Applications]`.
* `~/.config/mimeapps.list` (higher XDG precedence, per the
  `xdg-desktop-specification`) is live, host-local desktop state — not
  Dotbot-managed by this or any other part of the repo — and today still
  points `inode/directory` at XFCE's own file manager. `configs/dotbot/config.yaml`'s
  `shell:` section runs `xdg-mime default dnb-file-manager.desktop
  inode/directory`, which writes into that same file; the command is
  idempotent (safe to run on every `dotfiles` run) and is how this
  association actually takes effect on this host, not just in the
  lower-priority `~/.local/share/applications/mimeapps.list`.
* `xdg-open`/`gio open`/"open in file manager" from any XDG-aware
  application resolve through this association into the controller exactly
  like `explore` does.
* Does not touch `/usr/share/applications` (system-wide) and does not
  replace `/usr/bin/thunar` or shadow it with another `thunar` on `PATH`.

## Direct-Thunar limitation

An application that runs `/usr/bin/thunar /some/path` literally bypasses
XDG entirely — there is no interception point between that call and the
real Thunar binary, and this repo deliberately does not attempt one (no
`PATH` shadowing, no wrapping the real executable). Only requests that go
through XDG/GIO (the desktop entry above) or explicitly call `explore`/the
controller are managed. This is an accepted limitation, not a bug.

<!-- markdownlint-disable-next-line title-case-style -->
## i3 marks

* `file-manager-left`, `file-manager-right` — the only source of truth for
  which container is which pane. i3 mark identifiers are unique: setting a
  mark on a new container automatically removes it from whichever
  container held it before, which is exactly what "RIGHT replacement"
  below relies on.
* Deliberately **not** used as identity: window title (changes as you
  navigate), "currently focused Thunar" (ambiguous with 2+ Thunar
  windows), position alone, or child ordering alone. `WM_CLASS` (`Thunar`)
  is used only transiently, to tell a genuinely new Thunar container apart
  from pre-existing ones while polling right after launch — every
  subsequent operation targets the mark/container id.

## Recovery semantics

The controller derives all state from the live i3 tree
(`i3-msg -t get_tree` / `get_workspaces`) — no PID/state/cache files. Every
invocation converges the environment back towards:

```text
Files workspace (90:<icon>)
├── file-manager-left
└── file-manager-right
```

| Situation | Result of the next invocation |
| --- | --- |
| LEFT closed manually | Recreated at `${HOME}` (see "LEFT's default directory" below) the next time the controller runs — not recreated eagerly in the background. |
| RIGHT closed manually | Recreated the next time the controller runs (at `${HOME}` for `--show`, or immediately populated with the requested directory for the next `--open`). |
| Both closed | Workspace is naturally removed by i3 once you switch away from it; the next invocation recreates the full environment exactly once — no duplicates. |
| Workspace exists, one mark missing | The controller creates only the missing pane; the existing one is left untouched. |
| Workspace exists, neither mark present | Both panes are (re)created. |
| A managed window was manually moved to another workspace | The next invocation detects the mark is on the wrong workspace and moves it back to the Files workspace. |
| Unmanaged Thunar windows exist elsewhere | Ignored — matching is always by mark, never by `WM_CLASS` alone, so they are never adopted. |
| i3 reloaded/restarted in place | Marks and workspace state are unaffected (i3 preserves them across reload/restart-in-place); the controller's next invocation sees the same state as before. |

## RIGHT replacement semantics

Rather than trusting Thunar's own "reuse an existing window" logic (which
cannot be reliably pointed at one specific, identified window), `--open`
always launches a brand-new Thunar window for the requested path and then:

1. Marks the new window `file-manager-right` (this automatically strips
   the mark from whichever container held it before — see "i3 marks").
2. Moves it into the RIGHT slot and re-applies the canonical 50/50 layout.
3. Closes the previous `file-manager-right` window.
4. Focuses the new window.

"The RIGHT pane" is therefore a logical role, not a promise that the same
underlying X11 window persists forever. What the user sees (one right-hand
Thunar pane, always showing the most recently requested directory) is the
contract; the underlying container id changing on every `--open` is an
implementation detail.

## LEFT's default directory

A recreated LEFT starts at `${HOME}` — the same default `explore` already
used before this feature existed, and the only directory guaranteed to
exist for every user on this workstation.

## Layout convergence

* Initial creation always starts at an even 50/50 split, LEFT physically
  left of RIGHT.
* `--show` on an already-intact environment does not touch layout at all —
  harmless manual resizing between the two panes is left alone.
* Any repair/replace path (a missing pane gets (re)created, or `--open`
  replaces RIGHT) re-applies the canonical LEFT|RIGHT 50/50 layout, since
  at that point the layout is not "harmless manual state" — it is either
  freshly created or was just structurally changed by the controller
  itself.

<!-- markdownlint-disable-next-line title-case-style -->
## Standalone Thunar

`thunar-standalone` (`bashrc/helpers/thunar-standalone`) opens a plain,
unmanaged Thunar window:

* on the current i3 workspace (default Thunar/i3 behaviour — new windows
  appear on the focused workspace; the helper does not call `i3-msg` at
  all);
* never marked `file-manager-left`/`file-manager-right`;
* never switches to the Files workspace;
* never becomes the target of a future `explore`/XDG open — those always
  go through `file-manager --open`, which only ever looks at the two
  marks above.

There is deliberately no `assign [class="Thunar"] …` rule anywhere in this
repository — that would capture `thunar-standalone` windows (and any other
ad hoc Thunar window) into the managed set. Only windows explicitly
launched and marked by `file-manager` are managed.

## Thunar-specific behaviour

`FILE_MANAGER=/usr/bin/thunar` is a deliberate, fixed implementation
dependency (see `configs/session/filemanager/file-manager`) — not a
provider/plugin abstraction. Changing file manager later means changing
that one constant, plus whatever Thunar-specific launch flag replaces the
one below.

Every launch (`file-manager` and `thunar-standalone` alike) uses
`thunar --window <path>`, which forces Thunar to open a genuinely new
top-level window rather than reusing/tabbing into an existing one (even
when a Thunar background/daemon instance is already running). This is
what makes "poll the i3 tree for a new Thunar container id right after
launch" deterministic. No Thunar preference/configuration change was
required or made — `--window` already gives deterministic new-window
behaviour on the Thunar version installed on this workstation
(confirmed: `thunar --version` → 4.20.7).

<!-- markdownlint-disable-next-line title-case-style -->
## Relationship to Code dynamic workspaces

`configs/session/i3/workspaces/workspaces.py`'s `launch` command (used by
`Ctrl+Shift+W`, the VS Code workspace picker) supports zero-to-many
dynamic Code workspaces, auto-numbered upward from 10. The Files workspace
is deliberately **not** implemented on top of that machinery:

* Code workspaces are zero-to-many by design; Files is zero-or-one.
  Forcing the existing `launch`/auto-numbering logic to also enforce
  "at most one" would either complicate that command for every Code caller
  or require bolting on singleton semantics it was never designed for.
* Files needs window-level identity (marks, LEFT/RIGHT roles, replacement
  semantics) that Code dynamic workspaces have no equivalent of — they are
  "launch one command into one fresh workspace" only.

So Files workspace ownership lives entirely in this controller, and reuses
only the *visual convention* (an icon character embedded directly in the
workspace name, e.g. `90:<icon>`, the same pattern `workspaces.py` uses for
`10:`) — which is also why nothing needed to change in `workspaces.yaml`
or `workspaces.py`: Polybar renders the embedded icon character directly
(`strip-wsnumbers = true`), and the Rofi window switcher's icon lookup
already falls back to the workspace name's own indicator segment when no
YAML entry matches it.

## Troubleshooting

Read-only commands, safe to run at any time:

```bash
# Full managed-state report (workspace, LEFT, RIGHT, unmanaged windows)
configs/session/filemanager/file-manager --status

# Raw i3 tree view of everything currently marked
i3-msg -t get_tree | jq '[.. | objects | select(.marks? and (.marks|length)>0)] | map({id, marks, name, rect})'

# All Thunar windows currently known to i3, managed or not
i3-msg -t get_tree | jq '[.. | objects | select(.window_properties.class? == "Thunar")] | map({id, marks, name})'

# Which .desktop currently owns inode/directory
xdg-mime query default inode/directory

# WM_CLASS/role/PID for a window you click on (repo-wide diagnostic, not
# specific to this subsystem)
configs/session/i3/window-inspector.sh
```

## Scope

i3-only. XFCE is legacy (see `AGENTS.md`/`SESSION.md`) and does not receive
this functionality. `file-manager` detects whether i3 is the running
window manager (`i3-msg -t get_version`); when it is not, `--show` and
`--open` both fall back to the same plain, unmanaged window behaviour as
`thunar-standalone` — no workspace/mark logic runs — so `explore` keeps
working under XFCE (or any other session) exactly as it always has,
instead of failing outright.

## Known limitation: overlapping invocations

Each invocation derives all state from a fresh read of the live i3 tree —
there is no lock file (see "Recovery semantics" above: state is i3 itself,
not a cache). Two invocations that are actually in flight at the same
time (not sequential — one started before the previous one finished) can
both read the same "current RIGHT" snapshot and each try to replace it,
which can leave an extra unmanaged Thunar window behind. This does not
happen under normal usage (one keypress, or one `explore` call after the
last one has returned) — it was only reproduced by deliberately firing
several `--open` calls a few hundred milliseconds apart, without waiting
for each to finish. Let one invocation complete before starting the next.
