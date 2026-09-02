# Hard-coded home paths

Most functional scripts should resolve the home directory through `${HOME}`
or the `~/.dotfiles` symlink Dotbot creates for the repository root, not a
literal absolute home directory path.

## Fixed

* `bashrc/helpers/update-npm.sh` — now iterates `"${NVM_DIR}"/versions/node/*/`
  instead of a literal path, respecting an `XDG_CONFIG_HOME` override.
* `configs/installs/10-system.sh` — now copies into
  `"${HOME}/.dotfiles/bashrc/partials/_completions/"` instead of an absolute
  path, since `dotfiles` (the dotbot wrapper at `bashrc/helpers/dotfiles`)
  creates the `~/.dotfiles` symlink before install scripts run.

## Intentionally left literal

* `containers/hal2025/*/docker-compose.yaml` and
  `containers/locutus/*/docker-compose.yaml` volume paths — these are already
  host-specific by directory name. Docker Compose only substitutes `${HOME}`
  from the environment of whatever invoked `docker compose up` (interactive
  shell, cron, or systemd), which isn't guaranteed to have `HOME` set the
  same way in every context. Per the Docker rules in `AGENTS.md`
  ("Paths must be explicit", "No hidden bind mounts"), these stay literal.
* Comment/usage-example paths in `bashrc/helpers/synch-devspace.sh`,
  `bashrc/lib/30-filesystem/dnb-synchhome.bash`, and
  old workspace configuration examples — these are illustrative text in comments,
  not paths a script resolves at runtime.
