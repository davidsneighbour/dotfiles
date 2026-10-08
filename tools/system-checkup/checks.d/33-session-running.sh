#!/bin/bash
#
# When an i3 session runs, its parts run too: i3 answers on its IPC socket,
# Polybar runs, and the xss-lock screen locker service is active. Without a
# running i3 (XFCE login, or no login at all) the check passes and says so,
# because cron runs the checkup in every case.

uid="$(id -u)"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/${uid}}"

# The "i3 (with debug log)" LightDM session runs i3 as i3-with-shmlog.
if ! pgrep -u "${uid}" -x 'i3|i3-with-shmlog' >/dev/null 2>&1; then
  printf 'i3 is not running; session process checks skipped\n'
  exit 0
fi

failed=0
fixes=()

# Cron has no DISPLAY, so `i3 --get-socketpath` cannot find the socket; use
# the default socket folder instead.
socket_ok=0
shopt -s nullglob
for socket in "${runtime_dir}/i3/ipc-socket."*; do
  if [[ -S "${socket}" ]] && i3-msg -s "${socket}" -t get_version >/dev/null 2>&1; then
    socket_ok=1
    break
  fi
done
shopt -u nullglob
if [[ "${socket_ok}" -eq 1 ]]; then
  printf 'i3 runs and answers on its IPC socket\n'
else
  printf 'i3 runs, but no IPC socket in %s/i3/ answers\n' "${runtime_dir}"
  fixes+=('restart i3 with Super+Shift+R')
  failed=1
fi

if pgrep -u "${uid}" -x polybar >/dev/null 2>&1; then
  printf 'Polybar runs\n'
else
  printf 'Polybar does not run\n'
  fixes+=("${HOME}/.dotfiles/configs/session/polybar/launch.sh (log: ${HOME}/.logs/polybar-i3/)")
  failed=1
fi

export XDG_RUNTIME_DIR="${runtime_dir}"
state="$(systemctl --user is-active xss-lock.service 2>/dev/null)"
if [[ "${state}" == "active" ]]; then
  printf 'xss-lock.service is active\n'
else
  printf 'xss-lock.service is %s; the screen does not lock on idle or suspend\n' "${state:-unknown}"
  fixes+=('systemctl --user start xss-lock.service (details: journalctl --user -u xss-lock.service)')
  failed=1
fi

for fix in "${fixes[@]}"; do
  printf 'Fix: %s\n' "${fix}"
done
exit "${failed}"
