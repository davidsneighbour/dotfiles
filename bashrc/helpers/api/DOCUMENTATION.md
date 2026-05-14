# `api/` documentation

This file documents every file currently present in `bashrc/helpers/api`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Files

### `api/porkbun-api.ts`

Porkbun API inspector. Lists domains or gathers metadata, nameservers, DNS, forwards, glue, and SSL information for one domain.

CLI option notes:

* --domain DOMAIN — inspect one domain.
* --list-domains — list domains visible to the API key pair.
* --verbose — additional logging.
* --help — show help.

Functions/methods defined:

* `timestampNow`
* `ensureLogDir`
* `usage`
* `parseArgs`
* `gatherDomainInfo`
* `printSummary`
* `printDomainList`
* `writeRunArtifacts`
* `main`

Requirements:

* Node.js with ts-node for the current shebang, or an equivalent TypeScript runner.
* Environment: PORKBUN_APIKEY and PORKBUN_SECKEY.
* Network access to `https://api.porkbun.com`.
