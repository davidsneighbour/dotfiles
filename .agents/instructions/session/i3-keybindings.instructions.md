---
applyTo: "configs/session/i3/config,configs/session/i3/configs/**,configs/session/i3/workspaces/**"
---

<!-- markdownlint-disable-next-line dnb-title-case-style -->
# i3 keybindings and workspace commands

Read `SESSION.md` before desktop changes. These rules also apply to scripts invoked by bindings; use this file when the task concerns binding execution outside its automatic scope.

* Application start/focus/toggle bindings MUST use `Control+Shift+Mod1+<key>` (Ctrl+Shift+Alt). Do not add bare `Control+Shift+<key>` application bindings. Window management and session controls follow their own conventions.
* Use `Control`, `Shift`, `Mod1`, and `Mod4`; combine modifiers with `+`, without spaces. Use case-sensitive X11 keysyms and check for duplicate combinations before adding a binding.
* Keep the entire executable and arguments inside the appropriate i3 command quoting. Quote icon-bearing workspace names, or use `workspace number <N>` when only the number matters.
* Diagnostics in command-substitution call chains must go to stderr. Inspect every shared logger call site on that chain so stdout contains only the returned value.
* `i3 -C -c` proves syntax only. For binding or workspace-command changes, read [the troubleshooting and runtime verification procedure](../../references/i3-keybindings.md), verify the exact command through i3 IPC, inspect resulting state, and repeat idempotent actions to check for duplicates. Report any unavailable runtime verification explicitly.
* Keep `docs/i3-keybindings.md`, the authoritative binding table, in sync with binding changes. Update `SESSION.md` when its documented behaviour changes.
