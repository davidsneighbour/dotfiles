#!/bin/sh

if [ "$DESKTOP_SESSION" = "xubuntu" ]; then
  sleep 20s
  killall conky
  cd "$HOME/.config/conky/desktop/"
  conky -c "$HOME/.config/conky/desktop/datetime.lua" &
  exit 0
fi
