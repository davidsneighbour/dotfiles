#!/bin/bash
#
# The commands that the i3 session starts or calls from its bindings, Polybar
# modules, and Rofi scripts are installed, and Polybar has i3 support.

# Command, then the session part that needs it. Keep this list in sync with
# configs/session/ (SESSION.md lists where each one is used).
REQUIRED_COMMANDS=(
  "i3:window manager"
  "i3-msg:workspace and Rofi scripts"
  "polybar:status bar"
  "rofi:launcher, window switcher, power menu"
  "feh:wallpaper"
  "xsetroot:root background colour"
  "xss-lock:screen lock on idle and suspend"
  "i3lock:configs/session/i3/lock.sh"
  "dunst:notifications"
  "xfce4-terminal:terminal binding"
  "python3:configs/session/i3/workspaces/workspaces.py"
  "wmctrl:window-inspector.sh"
  "xdotool:window-inspector.sh"
  "xprop:window-inspector.sh"
  "lsof:Polybar camera and microphone indicator"
  "zenity:system checkup report window"
)

missing=()
for entry in "${REQUIRED_COMMANDS[@]}"; do
  if ! command -v "${entry%%:*}" >/dev/null 2>&1; then
    missing+=("${entry%%:*} (${entry#*:})")
  fi
done

failed=0
if [[ "${#missing[@]}" -gt 0 ]]; then
  for entry in "${missing[@]}"; do
    printf 'Not installed: %s\n' "${entry}"
  done
  failed=1
else
  printf 'All %s session commands are installed\n' "${#REQUIRED_COMMANDS[@]}"
fi

# The i3 workspace module needs a Polybar build with i3 IPC support.
if command -v polybar >/dev/null 2>&1; then
  if polybar --version 2>/dev/null | grep -q -- '+i3'; then
    printf 'Polybar has i3 support\n'
  else
    printf 'Polybar has no i3 support (no "+i3" in polybar --version)\n'
    failed=1
  fi
fi

if [[ "${failed}" -ne 0 ]]; then
  printf 'Fix: install the missing packages with apt (Polybar must be a build with i3 support)\n'
fi
exit "${failed}"
