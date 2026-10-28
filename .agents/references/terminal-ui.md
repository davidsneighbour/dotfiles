# Terminal UI facade

Read this when a Bash helper prints messages, asks questions, shows progress, prints tables, or renders Markdown, source, or diffs. The full user documentation is [docs/terminal-ui.md](../../docs/terminal-ui.md); this reference lists what agents must apply.

## Loading

Standalone helpers source, in this order: `dnb-core-colors`, `dnb-core-log`, `dnb-core-ui-theme`, `dnb-core-ui` from `bashrc/lib/00-core/`. Helpers that already loop over all of `lib/00-core/*.bash` get them automatically.

## Choosing a function

| Intent | Function |
| --- | --- |
| Status message | `dnb_ui_info`, `dnb_ui_success`, `dnb_ui_warning`, `dnb_ui_error` (stderr, through `dnb_log`) |
| Structure | `dnb_ui_heading`, `dnb_ui_subheading`, `dnb_ui_rule` |
| Free text answer | `dnb_ui_input --prompt T [--default D]` |
| Yes/no | `dnb_ui_confirm --prompt T` (0 only on explicit yes) |
| Small fixed choice | `dnb_ui_select --prompt T --option V ...` |
| Small type-ahead choice | `dnb_ui_filter --prompt T --option V ...` |
| Large or dynamic list | `dnb_ui_search --prompt T --items-file P [--null]` (fzf) |
| Long-running command | `dnb_ui_spin --title T -- CMD ARG...` |
| Result table | `dnb_ui_table --input FILE.tsv [--stream stderr]` |
| Colour parts of an own layout (cells) | `dnb_ui_style_code VAR ROLE` once, then pad before adding codes |
| Markdown, source, diff | `dnb_ui_markdown`, `dnb_ui_code`, `dnb_ui_diff` with `--file P` |

Route by intent, not by item count.

## Contracts to keep

* Question return codes: 0 accepted, 1 declined or no match, 2 invalid arguments, 3 input not possible, 130 cancelled. Handle 3 with an explicit flag alternative (for example `--config NAME`). Map these to the helper's existing exit codes; do not change a helper's documented exit codes silently.
* Map `--plain` to `DNB_UI_FORMAT=plain`, `--json` to `DNB_UI_FORMAT=json`, and `--quiet` to `DNB_UI_QUIET=1` (in addition to the [verbosity rules](bash-verbosity.md)). JSON results go to stdout and must not contain log lines; do not use `dnb_log --json` as a result serializer.
* `dnb_log` writes console lines to stderr (only `dnb_log --json` uses stdout). Do not add `>&2` to `dnb_log` calls, and do not hide logs with `>/dev/null`.
* For colour values in tool arguments, use the exported `DNB_UI_*` hex tokens. The old `COLOR_*`, `RED`, `GREEN`, … escape variables were removed.

## Validation

* `npm run lint:terminal-ui` — fails on direct styling outside the facade. Allowed exceptions live in `scripts/lint-terminal-ui.ts`; add one only with a stated reason.
* `npm run test:ui` — facade contract tests, including pseudo-terminal checks.
* `npm run lint:terminal-theme` — fails when generated renderer assets drift from the palette.
* Interactive Gum and fzf behaviour needs a manual check in a real terminal; automated pseudo-terminals do not answer Gum's terminal colour queries.
