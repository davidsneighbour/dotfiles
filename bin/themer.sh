#!/usr/bin/env bash

REQUIRED_TOOLS=(
    npm
)

for tool in ${REQUIRED_TOOLS[@]}; do
  if ! command -v ${tool} >/dev/null; then
    echo "${tool} is required... "
    exit 1
  fi
done

echo "Installing Rust and Cargo"
node ./node_modules/themer/bin/themer.js -c @themer/colors-nova \
   -t @themer/vim \
   -t @themer/sublime-text \
   -t @themer/atom-syntax \
   -t @themer/atom-ui \
   -t @themer/chrome \
   -t @themer/css \
   -t @themer/firefox-addon \
   -t @themer/firefox-color \
   -t themer-gnome-terminal \
   -t themer-i3 \
   -t @themer/slack \
   -t @themer/xresources \
   -t @themer/wallpaper-block-wave \
   -t @themer/wallpaper-burst \
   -t @themer/wallpaper-circuits \
   -t @themer/wallpaper-diamonds \
   -t @themer/wallpaper-dot-grid \
   -t @themer/wallpaper-octagon \
   -t @themer/wallpaper-shirts \
   -t @themer/wallpaper-triangles \
   -t @themer/wallpaper-trianglify \
   -o themes

echo "Completed in ${SECONDS}s"
