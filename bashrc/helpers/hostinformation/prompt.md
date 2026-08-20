# Raspberry pi profile prompt

Create or recreate an AI memory/reference profile for a Raspberry Pi from the diagnostic dump pasted below.

The result must be a single Markdown document suitable for storing as a long-term machine profile for AI assistants.

Use the existing `hal2025` / `hal2026` profile style and follow these rules:

* Derive all machine-specific facts from the supplied dump.
* Do not invent missing values.
* Clearly separate:

  * observed facts from this specific machine
  * stable hardware capabilities implied by the exact Raspberry Pi model
  * current-state values that may change over time
* If the exact Raspberry Pi model is identifiable, add the stable hardware capabilities for that model, including:

  * CPU / SoC
  * RAM class
  * networking capabilities
  * USB ports
  * display outputs
  * GPIO
  * camera/display connectors
  * storage/PCIe capabilities where applicable
  * Bluetooth/Wi-Fi capabilities
  * power/PoE capabilities where applicable
* Do not include the board serial number in the final profile unless it is specifically relevant.
* Include the board revision code.
* Record architecture, OS, Debian/Raspberry Pi OS version, kernel, firmware, and boot/storage layout.
* Record primary storage and any mounted network storage separately.
* Record Ethernet and Wi-Fi interfaces, MAC addresses, IPv4 addresses, routing, and whether addressing appears static or DHCP-based.
* Record Tailscale if present.
* Record Docker/container networking if present, but mark transient bridge names, veth devices, and container-specific state as non-stable.
* Record SSH state.
* Record the administrative user, UID/GID, sudo access, and relevant supplementary groups.
* Record timezone, NTP state, and RTC information.
* Record firmware, temperature, throttling, and undervoltage state if available.
* If a command failed, do not treat that as absence of the underlying feature. Mention the failed query only when it materially affects what can be concluded.
* Treat temperatures, disk usage, free memory, uptime, IP state, kernel version, firmware version, container state, and similar values as snapshots that may change.
* Prefer durable facts and operational guidance over transient details.
* Add an `AI assistant guidance` section containing machine-specific instructions for future assistants.
* Add a `Useful identification commands` section.
* Add a `Profile provenance` section explaining that the profile combines observed facts from the dump with stable hardware capabilities of the detected Raspberry Pi model.
* Do not add citations unless the chat explicitly used external sources.
* Return only the completed Markdown profile, ready to save as `<hostname>.md`.

Use this structure where applicable:

```markdown
# <hostname> — Raspberry Pi profile

> AI memory/reference file for the machine `<hostname>`.

## Identity

## Hardware

### Board

### Built-in connectivity

### Physical I/O and expansion

## Operating system

## Storage

### Network storage

## Memory and swap

## Networking

### Ethernet

### Wi-Fi

### Tailscale

## Containers

## SSH and remote administration

## Time and RTC

## Firmware / thermal status

## Installation history and caveats

## AI assistant guidance

## Useful identification commands

## Profile provenance
```

Omit sections that are genuinely irrelevant, but do not omit a section merely because one query failed.

Diagnostic dump follows:

```text
PASTE PI-INFO-DUMP OUTPUT HERE
```
