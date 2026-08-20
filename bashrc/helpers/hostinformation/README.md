# Pi-info-dump

`pi-info-dump.sh` collects a detailed system profile from a Raspberry Pi over SSH and saves the result locally as a timestamped text file.

It is intended to generate a self-contained diagnostic dump that can later be turned into an AI memory/reference profile for the machine.

## What it collects

The dump includes information about:

* hostname and system identity
* Raspberry Pi model and board revision
* CPU and architecture
* RAM and swap
* operating system and kernel
* storage devices and mounted filesystems
* network interfaces, addresses, and MAC addresses
* NetworkManager connections
* routing and DNS
* timezone and clock synchronization
* SSH status
* user and group memberships
* Docker, when installed
* Tailscale, when installed
* Raspberry Pi firmware
* throttling and undervoltage status
* temperature
* failed systemd services
* uptime and system load

Each section includes the command that generated its output, making the resulting dump useful both as documentation and for later diagnostics.

Individual unavailable commands do not abort the collection process.

## Usage

```bash
pi-info-dump --host hal2026
```

Specify a different SSH user:

```bash
pi-info-dump --host hal2026 --user patrick
```

Save dumps to a dedicated directory:

```bash
pi-info-dump --host hal2026 --output-dir ~/pi-info
```

See all options:

```bash
pi-info-dump --help
```

## Output

A single SSH connection is used to collect the information.

The resulting file is stored locally using the host and timestamp:

```text
hal2026-20260820-083512.txt
```

Sections are self-documenting:

```text
###############################################################################
# Memory usage
# Command: free -h
###############################################################################
               total        used        free ...
```

The dump can then be pasted into an AI assistant to create or refresh a persistent Markdown machine profile such as `hal2026.md`.
