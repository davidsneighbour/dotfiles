# Tailscale network reference

## Purpose and authority

Use this reference for all Tailscale-related networking, remote access, service exposure, scripts, and automation. Assume this topology unless explicitly stated otherwise. The network uses Tailscale mesh networking between workstations, Raspberry Pi systems, and mobile devices.

The architecture and device details below were supplied by the user, with a source update date of 26 October 2026. They are the expected configuration, not a live verification of device availability or network settings. Verify current state when a task depends on it; do not silently replace these defaults with assumptions.

## Tailnet and addressing

Tailnet domain: `trout-tortoise.ts.net`. MagicDNS is enabled. Device hostnames follow `<device>.trout-tortoise.ts.net`.

Agents MUST prefer DNS hostnames over raw IP addresses. Use this priority order:

1. Tailscale hostname, such as `hal2025.trout-tortoise.ts.net`.
2. Tailscale IP.
3. Local LAN IP, as a fallback only.

## Known devices

| Device | Hostname | Role |
| --- | --- | --- |
| Locutus | `locutus.trout-tortoise.ts.net` | Primary Linux workstation: development, infrastructure management, SSH administration, and container orchestration. |
| Hal2025 | `hal2025.trout-tortoise.ts.net` | Raspberry Pi infrastructure node: Docker services, infrastructure services, and persistent compute. |
| Nothing-phone-2 | `nothing-phone-2.trout-tortoise.ts.net` | Mobile device: remote access, service testing, and monitoring. |
| patricks-s20-ultra | `patricks-s20-ultra.trout-tortoise.ts.net` | Mobile device: remote access, administration, and service interaction. |

## Network behaviour

The expected access model is a private, encrypted mesh network. Devices connect directly when possible, with automatic NAT traversal and no required router configuration.

Agents MUST assume devices may be outside the LAN or move between networks. Connectivity must work through Tailscale; do not depend on LAN-only access.

## Mobile access

Mobile devices use the Tailscale application. The setup MUST preserve normal phone functionality while allowing infrastructure service access and remote administration.

Use standard SSH over Tailscale unless Tailscale SSH is explicitly confirmed for the task. For workstation-to-Pi or mobile-to-Pi access:

```bash
ssh hal2025.trout-tortoise.ts.net
```

For web services, use `http://hal2025.trout-tortoise.ts.net` or `http://hal2025.trout-tortoise.ts.net:PORT`, replacing `PORT` with the actual service port.

## Service exposure

Services SHOULD remain private. The preferred model is:

```text
Service -> Docker container -> LAN -> Tailscale access
```

Unless explicitly requested, agents MUST NOT recommend public port exposure, router port forwarding, or insecure service publication.

## Expected feature state

| Feature | Supplied state | Agent requirement |
| --- | --- | --- |
| Subnet routing | Disabled | Do not assume the entire LAN is accessible through Tailscale. Only nodes running the Tailscale agent are reachable under this topology. |
| Exit nodes | None configured | Mobile internet traffic is not routed through the Tailnet under this configuration. |
| Tailscale Serve / Funnel | Not used | No services are intentionally published to the public internet through Tailscale. |
| Tailscale SSH | Unknown | Assume standard SSH over Tailscale; do not assume Tailscale SSH is enabled. |

## Design principles

Preserve encrypted mesh networking, minimal public exposure, DNS-based access, and mobile-first accessibility. Future infrastructure additions SHOULD integrate into the Tailnet.
