# Repository scripts

Repository maintenance scripts live here. The standalone utilities are listed in [tools](../tools/README.md).

## Scheduled runtime

`node-cron.sh --refresh` atomically maintains the machine-local installed LTS runtime. `--update` installs the latest published LTS and refreshes the link; the host profile schedules it weekly. `--exec --` launches Node after either operation. Run `bash scripts/node-cron-test.sh` for isolated runtime tests; these also run through `npm run test:shell`.

See [Node runtime maintenance](../docs/node-runtime.md) for manual inspection, explicit LTS upgrades, logs, and startup integration.

## Central configuration

`dotfiles-config.ts` and its Bash entry point read, validate, and update the canonical configuration. See [configuration usage and extension rules](../schema/README.md). Run `npm run test:dotfiles-config` for CLI tests.
