## `dnb_config_get` – TOML configuration retrieval for shell scripts

`dnb_config_get` is a single-file Bash CLI designed to **safely and predictably read values from TOML configuration files**. It is intended for use in dotfiles, launchers, automation scripts, and other shell-based tooling where:

* configuration is optional,
* missing values must not crash scripts,
* empty values need to be distinguishable from unset ones,
* and output must be usable in pipelines.

The tool deliberately avoids JSON output and complex formats.
Instead, it focuses on **exit codes as the source of truth**, which is the only collision-free approach in shell environments.

## Design principles

* **Exit codes signal state, stdout signals data**
* **No magic defaults**
* **Empty strings are valid data unless explicitly forbidden**
* **Shell-friendly output**
* **Python 3.11+ only (explicit dependency)**

This makes the tool robust for both human use and automation.

## Core behaviour (contract)

### Success

* The key exists
* The value is valid for its type
* Exit code: `0`
* Stdout: the value only

### Failure

* Missing file
* Missing key
* Empty value (when `--fail-on-empty` is enabled)
* Exit code: `1`
* Stdout: **nothing by default**

### Parse / environment error

* Invalid TOML
* Python < 3.11
* Exit code: `2`
* Stdout: nothing
* Stderr: error message

## Why stdout is empty on failure

Using a sentinel string like `"false"` is **fundamentally unsafe**, because `"false"` can be a perfectly valid TOML string value.

Example of the collision problem:

```toml
feature.enabled = "false"
```

You cannot distinguish this from "key not found" if both print `false`.

### Correct solution

* Stdout is **only for real values**
* Exit codes indicate state
* Optional fallback output is **explicit and lossy**

This tool therefore:

* Prints **nothing** on failure by default
* Allows opt-in legacy behaviour via `--print-fallback`

## Features

### 1. Retrieve values via dotted paths

```bash
dnb_config_get --file config.toml launcher.icon
```

* Paths are split on `.`
* Nested tables are supported
* Quoted TOML keys containing dots are intentionally not supported

### 2. Sorted key listing

```bash
dnb_config_get --file config.toml --list-keys
```

Outputs **all scalar and array leaf keys**, sorted alphabetically:

```text
launcher.group
launcher.icon
launcher.name
repo.notes
repo.role
repo.visibility
```

Tables themselves are not returned as values.

### 3. Empty value handling

By default:

* Empty strings are valid
* Empty arrays are valid

Enable strictness with:

```bash
--fail-on-empty
```

This causes:

* `""` (length 0)
* `[]`

to be treated as *not found* (exit `1`).

### 4. Trimming string values

```bash
--trim-values
```

* Trims left and right whitespace
* Applies to:

  * string values
  * string items inside arrays
* Trimming happens **before** empty checks

Example:

```toml
launcher.name = "   "
```

```bash
dnb_config_get --file config.toml launcher.name
# prints "   "

dnb_config_get --file config.toml launcher.name --trim-values
# prints ""

dnb_config_get --file config.toml launcher.name --trim-values --fail-on-empty
# exit 1
```

Only **0-length strings** are considered empty.
Whitespace-only values count as content unless trimmed.

### 5. Optional fallback output (legacy / UX)

```bash
--print-fallback false
```

This restores the old `"false"`-on-failure behaviour:

```bash
dnb_config_get --file config.toml missing.key --print-fallback false
# prints: false
# exit: 1
```

This is **explicitly lossy** and should be avoided in new scripts.

## Exit codes

| Code | Meaning                                            |
| ---: | -------------------------------------------------- |
|    0 | Key found                                          |
|    1 | Missing file/key or empty (when `--fail-on-empty`) |
|    2 | TOML parse error or Python < 3.11                  |

## Dependency

* **Python 3.11 or newer**
* Uses standard library `tomllib`
* Earlier Python versions are intentionally unsupported

## How to use it safely in scripts (recommended)

Always rely on **exit codes**, not stdout content.

### Example: optional value

```bash
if value="$(dnb_config_get --file ".github/dnb.toml" "launcher.icon")"; then
  printf 'icon=%s\n' "${value}"
else
  printf 'no icon configured\n' >&2
fi
```

### Example: required value

```bash
value="$(dnb_config_get --file config.toml repo.role)" || {
  printf 'repo.role is required\n' >&2
  exit 1
}
```

### Example: trimmed and non-empty

```bash
value="$(
  dnb_config_get \
    --file config.toml \
    launcher.name \
    --trim-values \
    --fail-on-empty
)" || {
  printf 'launcher.name must be set and non-empty\n' >&2
  exit 1
}
```

## Design rationale

This section explains *why* `dnb_config_get` is designed the way it is, not just *how* it works. The goal is to make the decisions explicit so future readers (including future you) understand which trade-offs were chosen intentionally.

### Exit codes over stdout

Shell scripting has no reliable way to distinguish *data* from *state* if both are encoded as strings. Any sentinel printed to stdout is inherently ambiguous.

Example of the unsolvable problem:

```toml
feature.flag = "false"
```

If a missing key also prints `false`, there is no way to tell whether:

* the key exists and its value is `"false"`, or
* the key does not exist at all

This is not a tooling problem, it is a **fundamental limitation of string-based interfaces**.

**Design decision**

* Stdout is reserved exclusively for real values.
* Exit codes signal success or failure.
* Scripts MUST check exit codes, not stdout content.

This mirrors long-standing Unix conventions (`grep`, `test`, `command -v`, etc.) and enables collision-free automation.

### Why empty stdout on failure

Printing nothing on failure may feel inconvenient at first, but it is the only correct default.

* Printing `"false"` is lossy.
* Printing `"null"` or `"unset"` has the same collision problem.
* Printing error messages to stdout breaks pipelines.

Therefore:

* Failure produces no stdout.
* Humans can opt in to a fallback string with `--print-fallback`.
* Machines rely on exit codes.

This keeps the default behaviour safe while still allowing explicit UX compromises when desired.

### Empty vs unset is explicit

In many configurations, these cases are semantically different:

* The key does not exist.
* The key exists but is intentionally empty.

TOML allows empty strings and empty arrays, and they are valid data.

**Design decision**

* Empty values are treated as valid by default.
* Strictness must be explicitly requested via `--fail-on-empty`.
* Trimming is opt-in (`--trim-values`) and applied before emptiness checks.

This avoids accidental breakage when a configuration evolves.

### Trimming is not implicit

Whitespace can be meaningful in configuration values. Automatically trimming values would silently change semantics.

**Design decision**

* Values are returned exactly as stored.
* `--trim-values` must be explicitly enabled.
* Trimming applies only to strings and string array items.
* A value that becomes 0-length after trimming is considered empty.

This makes whitespace handling deliberate and auditable.

### No implicit defaults

`dnb_config_get` does not invent values.

* No default fallbacks.
* No implicit type coercion.
* No silent conversions.

If a script needs defaults, it should implement them explicitly:

```bash
value="$(dnb_config_get --file cfg.toml key)" || value="default"
```

This keeps configuration semantics close to the consuming logic and avoids hidden behaviour.

### Sorted key listing

`--list-keys` exists primarily for:

* discoverability
* documentation
* debugging

Output is sorted alphabetically to ensure:

* stable diffs
* predictable output
* consistent tooling behaviour

Traversal order is intentionally not exposed.

### Dotted paths are intentionally limited

Supporting quoted TOML keys containing dots would require:

* a custom escaping grammar
* additional parsing logic
* more documentation and edge cases

**Design decision**

* Dot-separated paths are simple and predictable.
* Quoted keys containing dots are not supported.
* This limitation is documented, not hidden.

If this becomes necessary in the future, it can be added in a backwards-compatible way.

### Arrays are line-based by design

Arrays are printed one item per line:

```toml
tags = ["a", "b", "c"]
```

```text
a
b
c
```

This is optimised for shell pipelines (`while read`, `xargs`, etc.).

More robust serialisation (JSON) was intentionally excluded to keep the tool small, composable, and Unix-like.

### Python 3.11+ is a hard dependency

TOML parsing in Bash is impractical without external tools.

**Design decision**

* Require Python 3.11+.
* Use `tomllib` from the standard library.
* No third-party Python dependencies.
* No fallback parsers.

This makes the environment requirement explicit and future-proof while keeping the script small and maintainable.

### Single-purpose, single responsibility

`dnb_config_get` does exactly one thing:

> Retrieve configuration values from a TOML file safely.

It does **not**:

* manage configuration files
* validate schemas
* enforce typing beyond basic safety
* apply defaults
* perform repository detection

This keeps the tool easy to reason about and easy to replace.

### Summary

The design prioritises:

* correctness over convenience
* explicitness over magic
* shell safety over aesthetics
* future maintainability over feature creep

Every limitation is intentional.
Every escape hatch is explicit.
Every failure mode is detectable.

That is what makes `dnb_config_get` reliable enough to live in dotfiles.
