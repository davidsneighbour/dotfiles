#!/bin/bash
set -euo pipefail

print_help() {
  cat <<'EOF'
polybar-app-indicator

Shows a coloured icon for an application depending on state.

States:
  hidden  -> foreground colour
  visible -> selection colour
  unread  -> alert colour (blinking)

Usage:
  polybar-app-indicator --wmclass "signal.Signal" --icon ""
EOF
}

WMCLASS=""
ICON="●"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --wmclass)
    WMCLASS="$2"
    shift 2
    ;;
  --icon)
    ICON="$2"
    shift 2
    ;;
  --help)
    print_help
    exit 0
    ;;
  *)
    echo "Unknown option: $1"
    exit 2
    ;;
  esac
done

if [[ -z "$WMCLASS" ]]; then
  echo "WMCLASS required"
  exit 2
fi

# find window
win=$(wmctrl -lx | awk -v cls="$WMCLASS" '$3==cls {print $1; exit}')

# window not running
if [[ -z "$win" ]]; then
  echo "%{F#708CA9}$ICON%{F-}"
  exit 0
fi

title=$(wmctrl -l | awk -v id="$win" '$1==id {for(i=4;i<=NF;i++)printf $i " ";}')

# detect unread count in title
if echo "$title" | grep -qE '\([0-9]+\)'; then
  echo "%{F#FF9580}%{A1:~/.config/polybar/scripts/polybar-toggle-window --wmclass \"$WMCLASS\":}$ICON%{A}%{F-}"
  exit 0
fi

# detect hidden state
if xprop -id "$win" WM_STATE | grep -q Iconic; then
  echo "%{F#F8F8F2}%{A1:~/.config/polybar/scripts/polybar-toggle-window --wmclass \"$WMCLASS\":}$ICON%{A}%{F-}"
else
  echo "%{F#414D58}%{A1:~/.config/polybar/scripts/polybar-toggle-window --wmclass \"$WMCLASS\":}$ICON%{A}%{F-}"
fi
