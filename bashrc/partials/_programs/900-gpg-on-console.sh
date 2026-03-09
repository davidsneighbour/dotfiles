# shellcheck shell=bash
if dnb_is_interactive; then
  GPG_TTY="$(tty)"
  export GPG_TTY
  gpg-connect-agent updatestartuptty /bye >/dev/null
fi
