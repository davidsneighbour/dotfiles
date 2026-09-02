# `configs` documentation

This is an inventory of the top-level areas under `configs/`. Scripts and
config files remain the source of truth — this file only maps ownership,
host scope, and installation role where the directory name alone isn't
enough. Most files are installed onto the workstation as symlinks by
`dotfiles` (`bashrc/helpers/dotfiles`, a Dotbot wrapper); see
[`dotbot/README.md`](./dotbot/README.md).

## Top-level areas

| Area | Purpose | Installed via |
| --- | --- | --- |
| `content/` | `.remarkrc.js` / `.remarkignore` — Markdown/remark linting config for content repos. | Dotbot (`~/.remarkrc.js`, `~/.remarkignore`). |
| `dotbot/` | Dotbot profiles (`config.yaml`, `config.<name>.yaml`, `includes.yaml`) that `dotfiles` runs. See [`dotbot/README.md`](./dotbot/README.md). | N/A — this is the installer itself. |
| `fonts/` | Font families (JetBrains Mono, Monaspace, system/symbol fonts) installed to `~/.fonts`. See [`fonts/READ_ABOUT_LICENSES.md`](./fonts/READ_ABOUT_LICENSES.md) for per-family licensing. | Dotbot (`~/.fonts`). |
| `hosts/` | One TOML file per workstation (`dionysus.toml`, `locutus.toml`, `hal2025.toml`, `hal2026.toml`) holding host-specific settings, including `[packages.<name>]` archive definitions consumed by `bashrc/helpers/packages/create.sh`. | Not symlinked; read directly by helper scripts using `$(hostname)`. |
| `installs/` | Numbered workstation setup scripts (`10-system.sh`, `20-brew.sh`, `50-*.sh`, `90-*-packages.sh`). See [`installs/DOCUMENTATION.md`](./installs/DOCUMENTATION.md). | Run directly (`bash configs/installs/NN-name.sh`), not symlinked. |
| `packages/` | `system/default.jsonc` and `legacy/starter.jsonc` — not referenced anywhere in this repo's scripts or Dotbot configs. Appear to be a stale/orphaned `package.json`-shaped snapshot (`system/default.jsonc` hasn't changed since a `default.jsonc` last touched in an unrelated May commit) and a `package.json` template that only gets touched incidentally by dependency-update automation scanning all `*.jsonc` files. Not confirmed obsolete — flagging for a decision rather than deleting. | Not symlinked; no known consumer. |
| `savefiles/` | `devdocs.json` — a [DevDocs](https://devdocs.io) settings export for manual import; not consumed by any script. | Not symlinked; manual import into DevDocs. |
| `session/` | `i3/` (i3 window manager starter config) and `polybar/` (i3-only Polybar bar). See [`session/i3/README.md`](./session/i3/README.md), [`session/polybar/README.md`](./session/polybar/README.md), and the repo-root [`SESSION.md`](../SESSION.md) for the full session architecture. | `i3/` via Dotbot (`~/.config/i3`); `polybar/` referenced by repo path directly from i3's config, not symlinked. |
| `system/` | Per-application config for desktop/workstation tools (polybar, rofi, xfce, git, etc. — **not** i3, see `session/` above). See the subdirectory table below. | Mostly Dotbot; a few (`monitor/`, `systemd/nfs-storage/`) are referenced directly by path or run manually instead. |
| `theme/` | Icon/cursor themes. `DNB` and `DNB-Bibata` are repo-authored and Dotbot-linked to `~/.icons`. `Dracula` is a gitignored downloaded icon pack (~1.6G, includes `Archive.zip`/`__MACOSX` extraction remnants), not linked from Dotbot — see the `theme-dracula` entry in `bashrc/helpers/logs/config.toml`, which flags it as a cleanup candidate pending confirmation. | `DNB`/`DNB-Bibata` via Dotbot; `Dracula` unmanaged. |

## `system/` subdirectories

| Directory | Purpose | Dotbot-linked |
| --- | --- | --- |
| `atuin` | Atuin shell-history sync config. | Yes — `~/.config/atuin` |
| `barrier` | Barrier (KVM software) server config. | Yes — `~/.barrier-server.config` |
| `bittorrent` | qBittorrent watched-folder/category/main config. | Yes — three separate `~/.config/qBittorrent/*` files |
| `conky` | Conky system-monitor widget config. | Yes — `~/.config/conky` |
| `espanso` | Espanso text-expander matches/config. | Yes — `~/.config/espanso` |
| `fastfetch` | Fastfetch system-info banner config. | Yes — `~/.config/fastfetch` |
| `filezilla` | FileZilla client config. | Yes — `~/.config/filezilla` |
| `fontconfig` | Extra `fontconfig` snippets (e.g. emoji fallback). | Yes — `~/.config/fontconfig/conf.d/01-emoji.conf` |
| `git` | Global gitignore, git message template, git templates, GitHub label-manager config. | Yes — four separate files/dirs |
| `launchers` | Desktop launcher (`.desktop`) files. | Yes — `~/.local/share/applications` |
| `monitor` | Standalone XFCE monitor-layout debug/fix scripts, run manually. | No — ad hoc scripts, not linked. |
| `npm` | `npm-check-updates` config, default global npm packages list, `install-default-packages.ts`, and `cron-node-update.sh` for daily Node.js updates. | Yes — `~/.ncurc.js`, `~/.nvm/default-packages` |
| `polybar` | Polybar bar modules/scripts/start script. | Yes — `~/.config/polybar` |
| `rofi` | Rofi launcher config and scripts (window switcher, workspace/project picker). | Yes — `~/.config/rofi` |
| `starship` | Starship prompt config. | Yes — `~/.config/starship.toml` |
| `sublime-merge` | Sublime Merge config. | Yes — `~/.config/sublime-merge` |
| `sublime-text` | Sublime Text config. | Yes — `~/.config/sublime-text` |
| `systemd` | `nfs-storage/` — a manually-run NFS mount setup script with its own README; not a systemd unit installed via Dotbot. | No — run manually. |
| `typos` | A scratch note (`scratch.md`) about the `typos` CLI; the actual `typos.toml` config lives at the repo root. | No — not a real config target. |
| `vale` | Vale prose-linter styles/config. | Yes — `~/.config/vale` and `~/.local/share/vale` |
| `xfce` | XFCE keyboard shortcuts and window-manager (`xfwm4`) settings. | Yes — two `xfconf` XML files |

Root-level dotfiles under `configs/system/` (`.hidden`, `.pam_environment`, `.czrc`, `face.icon`, `user-dirs.dirs`, `repository_updates.toml`) are Dotbot-linked or cron-config individually; see `configs/dotbot/config.yaml` for the authoritative list.
