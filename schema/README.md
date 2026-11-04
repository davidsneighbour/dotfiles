# Dotfiles configuration

[configs/dotfiles.json](../configs/dotfiles.json) is the canonical, non-secret configuration for repository-owned orchestration. [dotfiles.schema.json](dotfiles.schema.json) defines its format. This foundation does not migrate settings or change workstation behaviour. The empty `dotfiles` object is deliberate: add settings together with their first consumer.

VS Code reads the local `$schema` reference and the workspace association for hover descriptions, completion, and validation. No published schema URL or network access is required. Schema defaults are editor hints; the CLI does not insert defaults, coerce values, or remove unknown properties.

## Ownership decision

| Question | Destination |
| --- | --- |
| Is this a credential, token, or private machine detail? | The existing protected configuration or ignored secret file; never this file |
| Does a tool define and consume this setting directly? | Its native configuration, such as VS Code settings or i3 config |
| Does dotfiles coordinate several tools, choose a workflow, or define shared workspace metadata? | A named domain under `dotfiles`, with a documented consumer |
| Is this generated, cached, or runtime state? | The existing state or cache location |
| Is ownership unclear, or is there no consumer yet? | Investigate before adding a setting |

Do not copy tool settings into the central file merely to collect them. When central data generates tool configuration later, document the generator and generated destination, and make the central value the only editable source.

## Adding a setting

1. Apply the ownership decision above, and inspect existing consumers and configuration.
2. Use `dotfiles.<domain>.<setting>` with lower camel case, for example `dotfiles.workspaces.defaultProfile`. Use functional domains, explicit units such as `timeoutSeconds`, and positive booleans such as `enabled`. Avoid ambiguous names such as `misc`, `options`, or top-level tool names.
3. Add an explicitly named schema property, a type, a description explaining ownership and behaviour, constraints, and useful examples. Close each object with `additionalProperties: false`. Use bounded maps with `propertyNames` and typed `additionalProperties` only when user-defined identifiers are required. Prefer `$defs` and `$ref` for repeated structures.
4. Add the canonical value and its consumer together. Document path resolution and missing-value behaviour. Never silently merge a second configuration source.
5. Add valid and invalid test cases, run `npm run test:dotfiles-config`, and run `npm run check`. Breaking format changes require a new `schemaVersion` and an explicit migration; adding optional properties does not.

The repository agent instructions link to this decision matrix. New domain names must describe their purpose independently of their current tool implementation.

## CLI

Requires Node.js 24 or newer and the repository npm dependencies. Both entry points use the same validation and update implementation:

```bash
npm run config:validate
bash scripts/dotfiles-config.sh --action get --pointer /schemaVersion
node scripts/dotfiles-config.ts --action get --pointer /dotfiles
node scripts/dotfiles-config.ts --action set --pointer /dotfiles --value '{}'
node scripts/dotfiles-config.ts --action validate --config /path/to/dotfiles.json --schema /path/to/schema.json
```

Flags override `DOTFILES_CONFIG` and `DOTFILES_SCHEMA`, which override repository-relative defaults. Explicit relative paths resolve from the current directory; defaults resolve from the script location. No environment-variable or tilde expansion occurs inside JSON values. `--schema` selects a trusted local JSON Schema; external references are not downloaded. The document's `$schema` is only an editor hint.

`get` returns JSON, including quotes for strings, and defaults to the complete document. JSON Pointer uses `/` to separate keys, `~1` for a literal slash, and `~0` for a tilde. `set` requires a JSON value and an explicit pointer; an empty pointer replaces the whole document. Parents must already exist and be objects. Array values can be replaced as a whole; array element traversal and unsafe prototype segments are rejected. There is no implicit file creation, deletion, merge, or repair of invalid input.

Every action validates the input. Updates also validate the result before replacing the file atomically in the same directory, retain permission bits, and detect changes observed before replacement. Concurrent writers are not supported: serialise writes externally. JSON formatting becomes two-space indentation on write. Updates reject symbolic links and other non-regular files. Configuration directories must be writable. Results and help go to stdout; errors and `--verbose` path diagnostics go to stderr. Validation and successful writes produce no stdout. Exit status is 0 for success and 1 for invalid arguments, invalid JSON, schema failures, or file errors. `--help` lists options.
