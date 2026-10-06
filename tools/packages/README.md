# Packages

A read-only command to inspect the APT/dpkg package state of this system. It shows which packages are installed, which are marked manual or automatic, and why an automatic package is installed. It never installs, removes, or marks packages.

`bin/packages` calls [`packages`](packages), so the command is on `PATH` as `packages`. Run `packages --help` for all options.

## Commands

| Command | Shows |
| --- | --- |
| `packages list` | All installed packages with their mark and version. |
| `packages manual` | Installed packages that APT marks manual. |
| `packages automatic` | Installed packages that APT marks automatic. |
| `packages orphaned` | Automatic packages that APT would autoremove. |
| `packages find <query>` | Available package names that match, and if each one is installed. |
| `packages why <name>` | The manual or essential packages that need an installed package, one shortest path each. |
| `packages tree [name]` | The dependency tree of the given installed packages, or of all manual packages. |

`find`, `why`, and `tree` take package names after the command or with `--package <name>` (repeatable). `why` and `tree` also accept globs, matched against the installed packages. For `find`, a plain query matches any part of a name, and a glob (`*`, `?`, `[...]`) must match the whole name. Quote globs, so that the shell does not expand them against files in the current folder.

```bash
packages why libnghttp2-14
packages why 'libcurl*' --all
packages tree --package curl --depth 2
packages find curl
packages find 'python3-*'
packages automatic | wc -l
```

Example output of `why` (shortened):

```text
libnghttp2-14 [automatic]

Required through:

curl [manual]
└── libcurl4t64 [automatic]
    └── libnghttp2-14 [automatic]

git [manual]
└── libcurl3t64-gnutls [automatic]
    └── libnghttp2-14 [automatic]
```

`why` shows the first 10 paths. Use `--all` to show all of them. In `tree`, each package is expanded only once. Later occurrences show `(see above)`, which also stops dependency cycles. When `tree` shows all manual packages, a manual package below another one is not expanded, because it has its own entry.

`list`, `manual`, `automatic`, and `orphaned` print one package per line, so their output works in pipes. Colours are used only when the output is a terminal. `--no-color` or `NO_COLOR` turns them off.

## Terms

* **manual**: APT's current manual flag. It does not prove that somebody ran `apt install` for the package. Installers and upgrades can set or clear it.
* **automatic**: installed as a dependency. APT can autoremove it when no package needs it any more.
* **essential**: dpkg's `Essential: yes` field. dpkg does not let you remove these packages.
* **needs**: `Pre-Depends`, `Depends`, `Recommends`, or `Suggests`. With the default settings, APT keeps an automatic package for all four. So `why` and `tree` follow all four and mark soft dependencies with `(recommends)` or `(suggests)`.
* **orphaned**: what APT's own autoremove calculation (`apt-get --simulate autoremove`) would remove. The tool does not use its own definition.

## How it works

| File | Purpose |
| --- | --- |
| `packages` | CLI, argument parsing, data layer, and the simple commands. |
| `graph.awk` | Builds the dependency graph and prints `why` and `tree`. |
| `tests/packages-test.sh` | Tests against the fixture data in `tests/fixtures/`. |

The data comes from:

* `dpkg-query --show`: the installed packages, with their `Essential`, `Version`, `Pre-Depends`, `Depends`, `Recommends`, `Suggests`, and `Provides` fields.
* `apt-mark showmanual`: the manual flag. All other installed packages are automatic.
* `apt-cache pkgnames`: all available package names (for `find`).
* `apt-get --simulate autoremove`: the orphaned packages. This does not need root.

`graph.awk` reads the dpkg data once. Only installed packages are nodes. A dependency on a virtual package links to each installed package that provides it. An alternative (`a | b`) links to each installed alternative. `why` searches upwards from the package, breadth first, and stops at each manual or essential package. It prefers `Depends` paths over soft ones. It shows one shortest path per root, because the dependency graph is not a tree: a package often has many roots.

When no manual or essential package needs an automatic package, `why` says so. It also says if APT would autoremove it, or if APT keeps it for another reason. On this machine, the only such packages are older kernel packages: APT protects some kernels by its own rules, not by a dependency.

The model was checked on this machine (Ubuntu 26.04): with all four dependency types, every automatic package is reachable from a manual or essential package, except for older kernel packages that APT protects. Without `Suggests`, one package would wrongly look orphaned.

## Exit status

| Code | Meaning |
| --- | --- |
| 0 | Success. An empty result from `orphaned` is a success. |
| 1 | A name or query matched no package. The other names are still shown. |
| 2 | Usage error, for example an unknown command or option. |
| 3 | `dpkg-query`, `apt-mark`, `apt-cache`, or `apt-get` is not available. |

## Verbose mode

`--verbose` (or `DNB_VERBOSE=1`) prints what the command does to stderr and logs it to `~/.logs/packages/YYYYMMDD-HHMMSS.log`. `--quiet` turns it off. Without verbose mode, the command writes no logs.

## Tests

```bash
bash tools/packages/tests/packages-test.sh
```

The tests set `PACKAGES_DATA_DIR` to `tests/fixtures/`. With this variable set, the command reads `installed.tsv`, `manual.txt`, `available.txt`, and `orphans.txt` from that folder instead of from APT. The fixture graph has shared dependencies, several manual roots, a cycle, a virtual package, an alternative, soft dependencies, an orphan, and a removed package. `npm run test:shell` runs these tests.

## Limitations

* Version constraints are not checked. A dependency links to the installed package, whatever its version.
* Packages are identified by name only. On a multiarch system, the same package for two architectures counts as one node. This machine has no foreign architecture.
* Only packages in the "installed" state count. Packages that are only unpacked, half-configured, or removed with their config files kept (`rc`) are not nodes.
* `manual` is the current flag only. An install history (`/var/log/apt/history.log*`) would be a separate future command, for example `packages history`.

Possible later additions: `--json` output, `--version`, `packages history`, and a Graphviz export of `tree`.
