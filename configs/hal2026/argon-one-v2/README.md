# Argon ONE V2 configuration for `hal2026`

This directory contains the host-specific Argon ONE V2 configuration and runtime scripts for the Raspberry Pi 4 `hal2026`.

The purpose is to keep a known-working Argon ONE V2 setup inside the dotfiles repository instead of depending on the upstream installer and `download.argon40.com` during future rebuilds.

## Hardware

* Host: `hal2026`
* Raspberry Pi 4
* Case: Argon ONE V2
* Power mode jumper: **Always ON / pins 2-3**

The Always ON jumper ensures that the Raspberry Pi starts automatically when mains power returns after a power outage.

```text
Default / Mode 1

[1][2] [3]
 └───┘

Pins 1-2:
requires the physical power button after power is restored


Always ON / Mode 2

[1] [2][3]
     └───┘

Pins 2-3:
automatically powers the Raspberry Pi when power is restored
```

For `hal2026`, use **Mode 2 / pins 2-3**.

## Power button behaviour

The Argon daemon handles the physical case button.

Expected behaviour while the Raspberry Pi is running:

```text
short press       -> no action
double press      -> graceful reboot
hold 3-5 seconds  -> graceful shutdown
hold >= 5 seconds -> forced power cut
```

The forced power cut should only be used when the operating system is no longer responding.

## Directory layout

The `rootfs/` directory mirrors the relevant paths on the Raspberry Pi:

```text
argon-one-v2/
├── README.md
├── install.sh
├── .gitignore
└── rootfs/
    ├── etc/
    │   ├── argon/
    │   │   ├── argon-blstrdac.sh
    │   │   ├── argon-config
    │   │   ├── argon-status.sh
    │   │   ├── argon-uninstall.sh
    │   │   ├── argon-unitconfig.sh
    │   │   ├── argon-versioninfo.sh
    │   │   ├── argondashboard.py
    │   │   ├── argonone-eepromconfig.py
    │   │   ├── argonone-fanconfig.sh
    │   │   ├── argonone-ir
    │   │   ├── argononed.py
    │   │   ├── argonpowerbutton.py
    │   │   ├── argonregister.py
    │   │   ├── argonstatus.py
    │   │   └── argonsysinfo.py
    │   ├── argononed.conf
    │   └── argonunits.conf
    └── lib/
        └── systemd/
            ├── system/
            │   └── argononed.service
            └── system-shutdown/
                └── argon-shutdown.sh
```

The `/usr/bin/argon*` commands installed by Argon are only symlinks into `/etc/argon`:

```text
/usr/bin/argon-config
    -> /etc/argon/argon-config

/usr/bin/argonone-config
    -> /etc/argon/argon-config

/usr/bin/argonone-ir
    -> /etc/argon/argonone-ir

/usr/bin/argonone-uninstall
    -> /etc/argon/argon-uninstall.sh
```

The `/usr/bin/argon*` commands are symbolic links into `/etc/argon`. They are stored as symbolic links inside `rootfs/usr/bin/` and restored using `cp -a`, preserving the original link targets.

## Why this is vendored

The official installation command is:

```bash
curl https://download.argon40.com/argon1.sh | bash
```

The downloaded `argon1.sh` installer is not self-contained. It downloads additional scripts and service files from Argon's server during installation.

Keeping only `argon1.sh` would therefore not provide a reproducible or offline-capable rebuild.

This directory instead stores the known-working installed files used by `hal2026`.

Benefits:

* no dependency on the Argon download server during recovery
* reproducible host rebuilds
* changes to upstream Argon scripts cannot silently alter this machine
* all relevant configuration is version-controlled
* differences can be reviewed through Git

## Installation

From this directory:

```bash
./install.sh --install
```

The installer should:

1. restore `/etc/argon`
2. restore `/etc/argononed.conf`
3. restore `/etc/argonunits.conf`
4. install the `argononed.service`
5. install the system shutdown hook
6. recreate the `/usr/bin/argon*` symlinks
7. reload systemd
8. enable and start `argononed.service`

After installation, reboot the Raspberry Pi:

```bash
sudo reboot
```

## Dependencies

The vendored files do not include operating-system packages required by the Argon scripts.

A fresh installation may require packages including:

```bash
sudo apt-get update

sudo apt-get install \
  --yes \
  python3-libgpiod \
  python3-smbus \
  i2c-tools
```

The exact package requirements should be verified against the Raspberry Pi OS version in use before rebuilding the host.

I2C must also be enabled if required by the installed Argon functionality.

Check with:

```bash
sudo raspi-config
```

and ensure I2C is enabled under the interface options.

## Verify the service

After installation or reboot:

```bash
systemctl status argononed.service
```

The service should report:

```text
active (running)
```

Check recent logs with:

```bash
journalctl \
  --unit argononed.service \
  --boot \
  --no-pager
```

## Verify the commands

The following commands should resolve successfully:

```bash
command -v argon-config
command -v argonone-config
command -v argonone-ir
command -v argonone-uninstall
```

Expected paths:

```text
/usr/bin/argon-config
/usr/bin/argonone-config
/usr/bin/argonone-ir
/usr/bin/argonone-uninstall
```

The symlink targets can be checked with:

```bash
ls -l /usr/bin/argon*
```

## Functional test

After restoring the configuration, test the complete setup.

### Reboot button

With the Pi running:

1. double-press the Argon ONE V2 power button
2. confirm that Linux performs a clean reboot
3. confirm that `hal2026` becomes reachable again

### Graceful shutdown

Hold the power button for approximately 3-5 seconds.

Confirm that the operating system performs a clean shutdown.

### Power-loss recovery

1. boot `hal2026`
2. disconnect mains power completely
3. wait at least 10 seconds
4. restore mains power
5. do not touch the case button
6. confirm that the Raspberry Pi boots automatically
7. confirm that `hal2026` becomes reachable over the network

This verifies the Argon ONE V2 jumper is still configured for **Always ON**.

## Updating the snapshot

Do not automatically replace these files when Argon publishes a new installer.

If an update is deliberately installed:

1. run the official Argon installation/update procedure
2. test fan control
3. test double-press reboot
4. test graceful shutdown
5. test power-loss recovery
6. compare the installed files against this snapshot
7. review all changes
8. update this directory only after confirming the new version works

Useful comparison:

```bash
git diff -- configs/hal2026/argon-one-v2/
```

The version in this repository should represent a **tested, known-working configuration**, not necessarily the latest upstream version.

## Git ignore policy

Dynamic Python cache files should not be committed:

```gitignore
__pycache__/
*.pyc
*.pyo
```

Do not broadly ignore files inside `rootfs/etc/argon/`.

Configuration, scripts, service definitions, and Argon state/version marker files should remain version-controlled unless they are confirmed to contain machine-generated volatile data.
