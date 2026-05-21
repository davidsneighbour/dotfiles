# Eww companion widgets

This folder contains Eww widgets used as Polybar companion popups.

The first widget is `dnb-session-menu`, a small session menu opened from the Polybar `powermenu` module.

## Files

* `eww.yuck` defines the Eww windows and widgets.
* `eww.scss` defines the widget styling.
* `scripts/toggle-session-menu.sh` toggles the popup from Polybar.
* `scripts/session-menu-action.sh` runs the selected session action.

## Polybar integration

The Polybar top bar keeps the `powermenu` module. Clicking it runs:

```bash
bash -lc '${HOME}/.dotfiles/configs/system/eww/scripts/toggle-session-menu.sh'
```

The Polybar start script also starts the Eww daemon with this config:

```bash
eww --config "${HOME}/.dotfiles/configs/system/eww" daemon
```

## Install Eww on XUbuntu / XFCE / X11

The official Eww documentation recommends installing Rust through `rustup`, then building Eww from source. For this XUbuntu setup, build the X11 variant.

Install build dependencies:

```bash
sudo apt update
sudo apt install --yes \
  build-essential \
  git \
  libgtk-3-dev \
  libpango1.0-dev \
  libgdk-pixbuf-2.0-dev \
  libdbusmenu-gtk3-dev \
  libcairo2-dev
```

Install Rust through rustup if needed:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Build Eww for X11:

```bash
git clone https://github.com/elkowar/eww.git "${HOME}/github.com/elkowar/eww"
cd "${HOME}/github.com/elkowar/eww"
cargo build --release --no-default-features --features x11
mkdir -p "${HOME}/.local/bin"
cp ./target/release/eww "${HOME}/.local/bin/eww"
```

Verify:

```bash
eww --version
eww --config "${HOME}/.dotfiles/configs/system/eww" daemon
eww --config "${HOME}/.dotfiles/configs/system/eww" open dnb-session-menu
```

## Package manager notes

There is no official apt, npm, or Homebrew install path documented for Eww at the time this configuration was added. Prefer the Rust source build above for XUbuntu/XFCE/X11.

If a distribution package becomes available later, keep the runtime path compatible by ensuring `eww` is available on `PATH`.
