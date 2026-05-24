#!/bin/bash

sudo apt install --yes \
  build-essential \
  git \
  pkg-config \
  libgtk-3-dev \
  libglib2.0-dev \
  libpango1.0-dev \
  libgdk-pixbuf-2.0-dev \
  libcairo2-dev \
  libdbusmenu-gtk3-dev \
  libx11-dev \
  libxrandr-dev \
  libxi-dev \
  libxext-dev \
  libxcb1-dev \
  libdbus-1-dev \
  libgtk-layer-shell-dev

clone https://github.com/elkowar/eww ~/github.com/elkowar/eww
cd ~/github.com/elkowar/eww

cargo clean
cargo build --release --no-default-features --features x11

mv target/release/eww ~/.local/bin/

eww --help
