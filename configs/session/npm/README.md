# Node and npm maintenance

`cron-node-update.sh` updates Node Current and the default global packages through the existing scheduled update workflow. It resolves the newest stable `vX.Y.Z` release from `nvm ls-remote`, installs that exact version, and points the NVM `default` alias at it. It does not use the moving `node` alias, because the Node.js release index also lists pre-releases (for example `v27.0.0-alpha.0.0.0`), and the script skips them.

Global default packages are opt-in per host. The `host-locutus` Dotbot profile links `~/.nvm/default-packages` to [`default-packages`](default-packages); nvm then installs that list after every `nvm install`, and `cron-node-update.sh` installs it when the default Node version changes. Hosts without that link (for example `hal2025` and `hal2026`) skip both steps. Their host profiles remove a link left over from older setups. Pass `--lts` for a separate explicit LTS installation followed by refresh of `~/.local/bin/node-cron`; this leaves the Current default unchanged. Use `--dry-run` to inspect either operation and `--verbose` for diagnostics.

The `--lts` operation delegates to `scripts/node-cron.sh --update`, which resolves the latest published LTS online before installation. The `host-locutus` cron profile runs this helper every Sunday at 04:45.

The shared refresh helper is `scripts/node-cron.sh`. Service startup runs refresh only, never installation. See [Node runtime maintenance](../../../docs/node-runtime.md) for commands, failure behaviour, and cron integration.

Local repository CLIs use explicit `npm link` tasks in the `host-locutus` Dotbot profile, once per repository. Reapply that profile with the desired Node version active. See [local npm CLI links](../../dotbot/README.md#local-npm-cli-links) for the entry pattern, runtime selection, and build requirements.
