#!/bin/bash
#
# The links that the i3 session reads its configuration through point into
# this repository: ~/.dotfiles, the Dotbot links for i3, Rofi, dunst, and the
# desktop fonts, and the xss-lock systemd user unit (enabled).

# Checks run through system-checkup, which exports SYSTEM_CHECKUP_DIR.
: "${SYSTEM_CHECKUP_DIR:?run this check with: system-checkup --check <name>}"

REPO_ROOT="$(cd -- "${SYSTEM_CHECKUP_DIR}/../.." && pwd -P)"

# Link, then the repository path it must resolve to. The Dotbot links come
# from configs/dotbot/config.yaml; ~/.fonts/dotfiles resolves through the
# ~/.fonts link and the configs/fonts/dotfiles compatibility link.
EXPECTED_LINKS=(
  "${HOME}/.dotfiles:."
  "${HOME}/.config/i3/config:configs/session/i3/config"
  "${HOME}/.config/rofi:configs/session/rofi"
  "${HOME}/.config/dunst:configs/session/dunst"
  "${HOME}/.fonts/dotfiles:configs/session/fonts"
  "${HOME}/.config/systemd/user/xss-lock.service:configs/session/systemd/xss-lock.service"
)

failed=0
for entry in "${EXPECTED_LINKS[@]}"; do
  link="${entry%%:*}"
  target="${REPO_ROOT}/${entry#*:}"
  target="${target%/.}"
  actual="$(readlink -f -- "${link}" 2>/dev/null)"
  if [[ ! -e "${link}" ]]; then
    printf '%s does not exist\n' "${link/#"${HOME}"/\~}"
    failed=1
  elif [[ "${actual}" != "${target}" ]]; then
    printf '%s points to %s, expected %s\n' "${link/#"${HOME}"/\~}" "${actual}" "${target}"
    failed=1
  fi
done

# systemctl --user needs the user runtime folder, which cron does not set.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${UID}}"
state="$(systemctl --user is-enabled xss-lock.service 2>/dev/null)"
if [[ "${state}" != "enabled" ]]; then
  printf 'xss-lock.service is %s, expected enabled\n' "${state:-unknown}"
  failed=1
fi

if [[ "${failed}" -ne 0 ]]; then
  printf 'Fix: run "dotfiles" to restore the Dotbot links; for xss-lock run: systemctl --user link %s/configs/session/systemd/xss-lock.service && systemctl --user enable xss-lock.service\n' "${REPO_ROOT}"
  exit 1
fi
printf 'All %s session links point into %s and xss-lock.service is enabled\n' "${#EXPECTED_LINKS[@]}" "${REPO_ROOT/#"${HOME}"/\~}"
exit 0
