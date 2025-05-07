* The project is a customized **Dotfiles setup**, focused on scripting, logging, and system configuration.
* Scripts are written in **Node.js (ESM)** or **Bash** (always with `#!/bin/bash`, not `#!/usr/bin/env bash`).
* Uses environment variables:
  * `DOTFILES_PATH`: main location for scripts and configuration.
  * `LOGFILES_PATH`: log storage location (also typically `~/.logs/`).
* All Bash scripts:
  * Must comply with **ShellCheck** standards.
  * Include `--help` and `--verbose` flags (`-v`, `-vv`, `-vvv` style).
  * Should **gracefully fail** when files or folders are missing.
  * Use log filenames like `setup-log-YYYYMMDD-HHMMSS.log`, not error-specific names.
  * Log format:  

    ```plaintext
    [2025-02-02 13:45:02][scriptname] This is a log entry.
    ```

  * Include Markdown-style documentation for each function.
  * Help messages dynamically include the function name using `${FUNCNAME[0]}`.
  * Scripts that are intended for `.bashrc` **must not** use `set -euo pipefail`.

* All scripts handle security sensitively — **no logging of credentials**, and masked if needed.

[comment]: # (the comment text)
