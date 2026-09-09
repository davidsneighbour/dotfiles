---
name: I3 Keybindings And Workspace Commands
description: What to check before trusting a new or changed i3 bindsym/exec/workspace command, and the specific error shapes each mistake produces.
applyTo: configs/session/i3/**
---

<!-- markdownlint-disable-next-line title-case-style -->
# I3 keybindings and workspace commands

## Scope

Read this before adding or changing anything in `configs/session/i3/configs/*.conf`
that binds a key to `exec`, or that drives i3 workspaces/marks/containers
(`workspace`, `move`, `mark`, `[con_id=...]`, etc.), whether that logic lives
directly in the i3 config or in a script the config invokes. Read `SESSION.md`
first, as it already requires for any i3 change.

This file exists because custom i3 keybindings/workspace commands in this
repository have repeatedly failed in ways `i3 -C -c` does not catch, and the
failure only surfaces the first time the binding actually fires.

## The core gotcha: `i3 -C -c` does not validate `exec` payloads

`i3 -C -c configs/session/i3/config` checks the config's own grammar (known
directives, balanced quotes/braces, valid modifier/keysym names). It does
**not** parse the string passed to `exec`/`exec_always` the way i3's runtime
command parser does when the binding actually fires. A syntactically broken
`exec` payload will validate cleanly and still fail every single time the key
is pressed.

Confirmed directly in this repository: a bindsym line with an `exec` target
that fails at runtime with an "Expected one of these tokens" error passed
`i3 -C -c` with no error or warning at all.

**Consequence: treat `i3 -C -c` as a syntax gate, not proof the binding
works.** After it passes, you still must runtime-verify the exact command
string (see "How to actually verify a binding" below).

## Mistake 1: arguments placed outside the quoted `exec` command

i3's `exec` command takes the entire program invocation — binary path plus
all of its arguments — as a single token. Anything placed *after* the
closing quote is re-parsed as a **second, separate i3 command**, not as
more arguments to the first one.

Broken:

```text
bindsym Control+Shift+Mod1+f exec --no-startup-id "$HOME/.dotfiles/configs/session/filemanager/file-manager" --show
```

Runtime error when the key is pressed (not at `i3 -C -c` time):

```text
ERROR: Expected one of these tokens: <end>, '[', 'move', 'exec', 'exit', 'restart', ...
ERROR: Your command: exec --no-startup-id "$HOME/.dotfiles/configs/session/filemanager/file-manager" --show
ERROR:                                                                                               ^^^^^^
```

The caret lands on the first token after the closing quote — that is the
signature of this exact mistake. i3 successfully parsed
`exec --no-startup-id "<path>"` as one complete command, then tried to parse
`--show` as the start of a new one.

Fix: put every argument *inside* the same quoted string as the path, so the
whole invocation is one token:

```text
bindsym Control+Shift+Mod1+f exec --no-startup-id "$HOME/.dotfiles/configs/session/filemanager/file-manager --show"
```

For anything more complex than "one path plus flags" (pipelines, env vars,
multiple commands), wrap the whole thing in `sh -c '...'` instead — this is
the pattern already used elsewhere in `applications.conf`:

```text
bindsym Control+Shift+w exec --no-startup-id sh -c 'BASHRC_PATH="$HOME/.dotfiles/bashrc" "$HOME/.dotfiles/configs/session/rofi/workspaces.sh" --newwindow --dynamic-workspace code'
```

Before adding a new `exec` binding, grep this file for the pattern you're
about to write and copy the shape of an existing, working line rather than
inventing new quoting.

## Mistake 2: `con_id`/mark identifiers built from tainted variables

If a script invoked by a binding builds `i3-msg` command strings from a
value captured via bash command substitution (`id="$(some_function)"`), and
`some_function` (or anything it calls) ever writes a diagnostic/log line to
**stdout** instead of stderr, that log text gets spliced into `id` — and the
next `i3-msg "[con_id=${id}] ..."` call fails with:

```text
ERROR: Could not parse con id "<garbage>"
ERROR: Expected one of these tokens: 'class', 'instance', 'window_role', 'con_id', ...
```

This is not an i3 config problem — it is a script-writing problem — but it
produces an i3 runtime error that looks similar to Mistake 1 at a glance, so
distinguish them by what the `ERROR: Your command:` line actually contains:
a corrupted `con_id=`/mark value (Mistake 2) vs. a clean command with extra
trailing tokens (Mistake 1).

When writing or reviewing a helper script that i3 invokes and that captures
its own or another function's output via `$(...)`:

* Every logging/diagnostic helper called from inside a captured code path
  MUST write to stderr (`>&2`), never stdout. Stdout in that code path is
  reserved for the one value being returned.
* Audit *every* call site of a shared logger (e.g. `dnb_log`), not just the
  ones you touched — a single unredirected call anywhere in the captured
  call chain is enough to corrupt the captured value intermittently (it only
  triggers when that particular log call's condition is hit, e.g. a warning
  path), which makes it easy to miss in a quick test and to reintroduce
  later.

## Mistake 3: modifier and keysym syntax

* i3 has no bare `Alt` modifier alias — use `Mod1`. There is no bare `Ctrl`
  either — use `Control` (or `Ctrl`, both work, but be consistent with the
  rest of this file's style, which uses `Control`/`Shift`/`Mod1`/`Mod4`).
* Combine modifiers with `+`, no spaces: `Control+Shift+Mod1+f`.
* `bindsym` keysym names are case-sensitive X11 keysym names, not the
  shifted character you want. Lowercase letters bind the unshifted key
  (`f`, not `F`); punctuation produced by Shift needs its own keysym name
  (e.g. `exclam` for `!`), not the literal character.
* i3 does not error on two `bindsym` lines for the same combination — the
  later one silently wins. Grep `configs/session/i3/configs/*.conf` for the
  exact modifier+key combination before adding a new binding, to catch an
  accidental duplicate/shadow rather than discovering it by "my binding
  doesn't do what I expect."

## Mistake 4: workspace name quoting

Workspace names in this repo that carry an icon (`90:<icon>`,
`{number}:{icon}`, see `configs/session/filemanager/README.md` and
`configs/session/i3/workspaces/workspaces.yaml`) must be quoted in every
`i3-msg`/config command that references them — `workspace "90:<icon>"`, not
`workspace 90:<icon>` — because the icon character and the `:` are not safe
to leave unquoted in i3's command grammar. Prefer `workspace number <N>`
(no name needed) when you only need to select-or-create by number and don't
need to guarantee a specific icon on first creation.

## How to actually verify a binding

`i3 -C -c` only proves the config parses. To prove the binding itself works:

1. Validate first (catches gross syntax errors, cheap and safe):

   ```bash
   i3 -C -c configs/session/i3/config
   ```

2. Reload the live session so the new binding is loaded:

   ```bash
   i3-msg reload
   ```

3. Fire the *exact* `exec` target directly through `i3-msg`, copying the
   string after `exec --no-startup-id` verbatim from the config line. This
   reproduces exactly what pressing the key does, without needing a
   physical keypress or `xdotool`:

   ```bash
   i3-msg 'exec --no-startup-id "$HOME/.dotfiles/configs/session/filemanager/file-manager --show"'
   ```

   Check the JSON result's `success` field. `i3-msg`'s own exit code can be
   0 even when the *inner* exec content fails to parse — the failure shows
   up as `"success": false` plus an `"error"` string in the result, not as a
   nonzero shell exit code. Read the actual JSON, don't just check `$?`.

4. Inspect the resulting i3 state rather than trusting a clean result alone
   — a command can report success while still not doing what was intended
   (e.g. focusing the wrong container):

   ```bash
   i3-msg -t get_tree | jq '[.. | objects | select(.marks? and (.marks|length)>0)] | map({id, marks, name, rect})'
   i3-msg -t get_workspaces | jq -r '.[].name'
   ```

5. Only after 3 and 4 both look correct, treat the binding as verified.
   `xdotool key` simulation of the physical combo is not a reliable
   substitute for step 3 in every environment — it has been observed to
   silently do nothing (no error, no effect) in at least one sandboxed test
   environment even for a long-working, unrelated binding, which is a false
   negative, not proof the binding is broken. Don't use "the key doesn't
   seem to do anything under `xdotool key`" as your only evidence either
   way; use the `i3-msg` reproduction above as the authoritative check.

## Before opening a PR / committing

* Run `i3 -C -c configs/session/i3/config` (necessary, not sufficient).
* Run the exact `exec` payload through `i3-msg` as shown above and confirm
  `"success": true` with no `"error"` field.
* Confirm the resulting `get_tree`/`get_workspaces` state matches intent.
* If the binding is a repeat/idempotent action (like a workspace
  show/create toggle), fire it twice in a row and confirm the second run
  doesn't duplicate anything.
* Update `SESSION.md`'s keybinding table in the same change — it is the
  authoritative source for what every binding does.
