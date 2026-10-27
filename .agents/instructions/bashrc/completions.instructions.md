---
applyTo: "bashrc/partials/_functions/**,bashrc/partials/_completions/**"
---

# Bash completions

Every function added to or changed in `bashrc/partials/_functions/` MUST have a matching completion file in `bashrc/partials/_completions/` (same base name, no extension) that offers its flags via `complete -F`. The completion directory is auto-sourced. Update the matching completion whenever flags change. See `bashrc/partials/_completions/searchfor` for a minimal example.
