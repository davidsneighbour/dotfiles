# Node and npm maintenance

`cron-node-update.sh` updates Node Current and the default global packages through the existing scheduled update workflow. Pass `--lts` for a separate explicit LTS installation followed by refresh of `~/.local/bin/node-cron`; this leaves the Current default unchanged. Use `--dry-run` to inspect either operation and `--verbose` for diagnostics.

The `--lts` operation delegates to `scripts/node-cron.sh --update`, which resolves the latest published LTS online before installation. The `host-locutus` cron profile runs this helper every Sunday at 04:45.

The shared refresh helper is `scripts/node-cron.sh`. Service startup runs refresh only, never installation. See [Node runtime maintenance](../../../docs/node-runtime.md) for commands, failure behaviour, and cron integration.
