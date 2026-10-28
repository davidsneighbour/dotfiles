---
applyTo: "bashrc/**,bin/**,scripts/**/*.sh,configs/installs/**"
---

# Terminal output and input

Use the DNB terminal UI facade for all human-facing terminal output and input in Bash. Read [the terminal UI reference](../../references/terminal-ui.md) before you add or change messages, prompts, selections, progress, tables, or document rendering.

* Call `dnb_ui_*` functions. Do not add raw ANSI escapes, palette literals, `tput` colours, exported colour variables, or direct `gum`/`fzf`/`glow`/`bat`/`delta` calls in business logic.
* stdout carries results only. Send headings, messages, prompts, progress, and diagnostics to stderr.
* Never infer consent from a default, an empty answer, a missing terminal, or a missing tool. Keep `dnb_ui_confirm` default "no".
* Run commands as argument arrays after `--`. Never use `eval`.
* Palette values live only in `bashrc/lib/00-core/dnb-core-ui-theme.bash`. After a palette change, run `npm run build:terminal-theme`. Never edit files under `configs/theme/dnb-terminal/` by hand.
* Do not add full-screen frameworks or other widget libraries for normal helpers.
