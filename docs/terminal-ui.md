# Terminal UI

The DNB terminal UI facade gives Bash helpers one way to print messages, ask questions, show progress, and render documents. Helpers describe *intent* (`dnb_ui_warning`, `dnb_ui_confirm`); the facade picks the backend, applies the theme, and falls back to plain text when a tool, a terminal, or colour is missing.

Source files:

* [`bashrc/lib/00-core/dnb-core-ui.bash`](../bashrc/lib/00-core/dnb-core-ui.bash) — public functions, capability checks, and backend adapters.
* [`bashrc/lib/00-core/dnb-core-ui-theme.bash`](../bashrc/lib/00-core/dnb-core-ui-theme.bash) — canonical Dracula Pro palette, semantic roles, and symbols.
* [`bashrc/lib/00-core/dnb-core-colors.bash`](../bashrc/lib/00-core/dnb-core-colors.bash) and [`dnb-core-log.bash`](../bashrc/lib/00-core/dnb-core-log.bash) — the existing colour and logging foundation. The facade reuses them.

## Rules for helpers

* Do not write raw ANSI escapes, palette literals, or Gum/fzf styling flags in business logic. Call `dnb_ui_*` functions.
* stdout carries results only. Headings, messages, prompts, progress, and diagnostics go to stderr.
* Never treat a default, an empty answer, a missing terminal, or a missing tool as consent.
* Run commands as argument arrays (`dnb_ui_spin --title T -- cmd arg`). Never use `eval`.
* Normal helpers do not use full-screen frameworks (Bubble Tea, Textual, dialog, whiptail). Native Node.js or Python tools keep their own libraries but must follow the same stream and `NO_COLOR` rules.

## Loading

Interactive shells load all of `bashrc/lib/*/*.bash`. Standalone helpers source what they need, in this order:

```bash
for file in dnb-core-colors dnb-core-log dnb-core-ui-theme dnb-core-ui; do
  # shellcheck source=/dev/null
  source "${BASHRC_PATH}/lib/00-core/${file}.bash"
done
```

Sourcing only defines functions and data. It prints nothing, starts no tools, and does not change shell options.

## Functions

| Function | Output | Behaviour |
| --- | --- | --- |
| `dnb_ui_heading TEXT...` | stderr | Bordered heading through Gum on a colour UTF-8 terminal, else `== TEXT ==`. |
| `dnb_ui_subheading TEXT` | stderr | `→ TEXT` (or `-> TEXT`). |
| `dnb_ui_rule` | stderr | Horizontal rule, width clamped to 20–100 columns. |
| `dnb_ui_info`, `dnb_ui_success`, `dnb_ui_warning`, `dnb_ui_error` | stderr | Wrap `dnb_log` (which writes its console lines to stderr) (levels `info`, `success`, `warn`, `error`), including its logfile. Colourless when stderr is redirected. |
| `dnb_ui_input --prompt T [--default D]` | answer on stdout | Gum input or `read`. Empty answer uses the default. |
| `dnb_ui_confirm --prompt T [--default no]` | nothing | 0 only after an explicit "yes". Empty answer or Enter on the preselected "No" returns 1. |
| `dnb_ui_select --prompt T --option V ...` | value on stdout | Small fixed lists. Gum choose, or a numbered menu. |
| `dnb_ui_filter --prompt T --option V ...` | value on stdout | Small type-ahead lists. Gum filter, or a numbered menu. |
| `dnb_ui_search --prompt T --items-file P [--null]` | record on stdout | Large or dynamic lists through fzf. Records come from the file, never stdin. `--null` reads and prints NUL-delimited records for arbitrary filenames. |
| `dnb_ui_spin --title T -- CMD ARG...` | child streams | Runs the command once and returns its exit status. Gum spinner on a terminal, else a static `→ T` line. Gum buffers child output until the end and gives the child no stdin. |
| `dnb_ui_table --input P [--stream stdout\|stderr]` | chosen stream | Tab-separated input; first line is the header. Gum table on a colour terminal, else a space-aligned plain table. |
| `dnb_ui_markdown --file P` | stdout | Glow with the derived style on a colour terminal, else the file unchanged. |
| `dnb_ui_code --file P` | stdout | bat with the derived theme on a colour terminal, else the file unchanged. |
| `dnb_ui_diff --file P` | stdout | delta with theme tokens (ignores `~/.gitconfig` delta settings), else the diff unchanged. |
| `dnb_ui_style_code VAR ROLE [--fd N]` | variable | Sets VAR to the escape for a role, `bold`, `dim`, or `reset` when fd N (default 1) takes colour, else empty. For helpers that colour parts of their own layout, such as table cells. Sets a variable because `$(...)` would hide the real stdout. |
| `dnb_ui_mode` | stdout | `json`, `plain`, or `auto`. |
| `dnb_ui_is_interactive` | — | 0 when stdin and stderr are terminals, the format is not JSON, and `TERM` is not `dumb`. |
| `dnb_ui_supports_color [--fd N]` | — | 0 when fd N (default 2) may receive colour. |
| `dnb_ui_symbol NAME` | stdout | `success`, `error`, `warning`, `action`, `item`, `prompt`, `rule`, `created`, `changed`, `removed`. |
| `dnb_ui_export_tokens` | environment | Exports `DNB_UI_*` hex tokens (called at shell startup). |

Labels, prompts, and options that contain control characters are rejected with code 2.

### Return codes for questions

| Code | Meaning |
| --- | --- |
| 0 | Accepted result |
| 1 | Declined confirmation, or no fzf match |
| 2 | Invalid arguments or backend error |
| 3 | Input required but not possible (no terminal, or fzf unavailable for search) |
| 130 | Cancelled (Esc, Ctrl+C, EOF, or an empty numbered-menu answer) |

`dnb_ui_spin` always returns the child's status instead.

### Example

```bash
config="$(dnb_ui_select --prompt 'Select config' --option default --option host-locutus)" || exit 1
if dnb_ui_confirm --prompt "Apply ${config}?"; then
  dnb_ui_spin --title "Applying ${config}" -- dotfiles "${config}"
fi
```

Command substitution only captures stdout, so prompts stay visible and only the value is captured.

## Modes and environment

| Variable | Values | Effect |
| --- | --- | --- |
| `DNB_UI_FORMAT` | `auto`, `plain`, `json` | Helpers map `--plain` and `--json` to this. Priority: json over plain over auto. `TERM=dumb` behaves as plain. |
| `DNB_UI_QUIET` | `1` | Suppresses headings, info, success, and spinner titles. Errors, warnings, results, and confirmations remain. |
| `DNB_UI_THEME` | `dracula-pro`, `dracula-pro-dark` | Selects the main or darker palette. |
| `DNB_UI_SYMBOLS` | `auto`, `unicode`, `ascii` | `auto` uses Unicode only in `auto` mode with a UTF-8 locale. |
| `DNB_COLOR_MODE` | `auto`, `truecolor`, `256`, `basic`, `none` | Existing colour depth switch. A forced value never adds escapes to redirected, plain, or JSON output. |
| `NO_COLOR` | non-empty | No colour or reset escapes anywhere. |
| `DNB_UI_DISABLE` | space-separated tool names | Treat these backends as missing (for tests or opting out), for example `gum fzf`. |

## Fallbacks

| Situation | Behaviour |
| --- | --- |
| No terminal on stdin or stderr | Questions return 3 with a short message. Defaults are not used silently. |
| Gum missing | Plain `read` prompts and numbered menus on stderr; static progress text. |
| fzf missing | `dnb_ui_search` returns 3; the helper must ask for an explicit value. No large numbered menus. |
| Glow, bat, or delta missing, or stdout redirected | The original document is printed unchanged. |
| Renderer fails | A warning on stderr, then the original document. |

Nothing pages automatically. No tool is installed or downloaded at runtime.

## Theme

The palette in `dnb-core-ui-theme.bash` is the single source. It keeps the supplied Dracula Pro hex, RGB, HSL, and 256-colour values for all 30 main rows and the six darker override rows. The darker variant overrides only Background, Comment, Selection, Cursor, BrightBlack, and DimBlack.

Semantic roles: `bg` Background, `fg` Foreground, `muted` Comment, `accent`/`info` Cyan, `accent_alt` Magenta, `success` Green, `warning` Orange, `error` Red, `dry` Yellow, `skip` Magenta, `trace` DimWhite, `border` BrightBlack, `selected` Selection, `cursor` Cursor. `dnb_log` level colours use the same roles.

Truecolour uses exact hex values. 256-colour mode uses the supplied indices, which are approximations. Basic mode maps roles to standard ANSI slots, so exact colours are not available there.

### Exported tokens

Shell startup exports `DNB_UI_BG`, `DNB_UI_FG`, `DNB_UI_MUTED`, `DNB_UI_ACCENT`, `DNB_UI_INFO`, `DNB_UI_ACCENT_ALT`, `DNB_UI_SUCCESS`, `DNB_UI_WARNING`, `DNB_UI_ERROR`, `DNB_UI_DRY`, `DNB_UI_SKIP`, `DNB_UI_TRACE`, `DNB_UI_BORDER`, `DNB_UI_SELECTED`, and `DNB_UI_CURSOR` as hex values for tools that take a colour argument. They replace the removed `COLOR_*` (`bashrc/partials/exports`) and `GREY`, `RED`, `GREEN`, `YELLOW`, `BLUE`, `MAGENTA`, `CYAN`, `WHITE`, `NONE` (`bashrc/bashrc`) escape variables. To print coloured text, use the `dnb_ui_*` functions instead of escape variables.

### Renderer assets

[`scripts/build-terminal-theme.ts`](../scripts/build-terminal-theme.ts) generates these files from the palette. Do not edit them by hand:

* `configs/theme/dnb-terminal/glow/dracula-pro.json` and `dracula-pro-dark.json` — Glow styles, used directly by path.
* `configs/theme/dnb-terminal/bat/DNB Dracula Pro.tmTheme` and `DNB Dracula Pro Dark.tmTheme` — linked to `~/.config/bat/themes/` by Dotbot (`configs/dotbot/config.yaml`), which then runs `bat cache --build`. delta reads the same cache. If the themes are not in the cache, bat and delta use the `ansi` theme, which follows the terminal palette.

Gum and fzf receive colours as per-call flags; nothing is exported to unrelated commands.

```bash
npm run build:terminal-theme   # regenerate after palette changes
npm run lint:terminal-theme    # fail on drift (part of npm run check)
```

## Tools

Gum, fzf, Glow, bat, and delta (`git-delta`) are optional and installed by [`configs/installs/90-brew-packages.sh`](../configs/installs/90-brew-packages.sh). Each one improves presentation only; content is always available without them.

## Enforcement

`npm run lint:terminal-ui` (part of `npm run check`) scans shell and awk files below `bashrc/`, `bin/`, `configs/`, `scripts/`, and `tools/` and fails on raw ANSI escapes, direct Gum styling or widget calls, and `tput` colour calls outside the facade files. `LESS_TERMCAP_*` lines in `bashrc/bashrc` are allowed because they configure `less` itself. TypeScript, JavaScript, and Python tools are not scanned; they follow the same rules by review.

## Tests

```bash
npm run test:ui   # bashrc/helpers/tests/dnb-ui-test.sh
```

The test covers stream separation, JSON escaping, palette rows, both theme variants, modes, symbols, non-interactive failures, control-character rejection, spinner status and streams, plain tables, renderer fallbacks, and plain interactive paths in a pseudo-terminal (`script` from util-linux).

## Migrated callers

* `dnb_log_header` delegates to `dnb_ui_heading`.
* `dotfiles --list` uses `dnb_ui_select`; Gum is no longer required.
* `cdg` uses `dnb_ui_search` (fzf). Only listed repositories can be selected.

* `tools/packages/packages` passes theme codes from `dnb_ui_style_code` to its awk programs (`list`, `find`, `why`, `tree`).
* `git-repos-status` colours table cells through `dnb_ui_style_code`; its verbose messages now go to stderr.

`bashrc/helpers/llms` is a native Node.js exception. `tools/clockify` uses Gum directly and is out of scope.
