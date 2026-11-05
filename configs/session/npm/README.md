# Node and npm maintenance

`cron-node-update.sh` updates Node Current and the default global packages through the existing scheduled update workflow.

Global default packages are opt-in per host. The `host-locutus` Dotbot profile links `~/.nvm/default-packages` to [`default-packages`](default-packages); nvm then installs that list after every `nvm install`, and `cron-node-update.sh` installs it when the default Node version changes. Hosts without that link (for example `hal2025` and `hal2026`) skip both steps. Their host profiles remove a link left over from older setups. Pass `--lts` for a separate explicit LTS installation followed by refresh of `~/.local/bin/node-cron`; this leaves the Current default unchanged. Use `--dry-run` to inspect either operation and `--verbose` for diagnostics.

The `--lts` operation delegates to `scripts/node-cron.sh --update`, which resolves the latest published LTS online before installation. The `host-locutus` cron profile runs this helper every Sunday at 04:45.

The shared refresh helper is `scripts/node-cron.sh`. Service startup runs refresh only, never installation. See [Node runtime maintenance](../../../docs/node-runtime.md) for commands, failure behaviour, and cron integration.
