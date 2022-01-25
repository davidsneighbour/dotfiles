# shellcheck shell=bash
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

FILE=${HOME}/.env
if [ -f "$FILE" ]; then
  set -a
  # this routine ranges through a folder of files that we don't explicitly know (@davidsneighbour)
  # see https://github.com/koalaman/shellcheck/wiki/SC1090
  # shellcheck source=/dev/null
  source "${FILE}"
  set +a
fi
unset FILE

for FILE in "$DOTFILES_PATH"/homedir/bash/{options,bash,functions,exports,aliases,completion,prompt}; do
  # this routine ranges through a folder of files that we don't explicitly know (@davidsneighbour)
  # see https://github.com/koalaman/shellcheck/wiki/SC1090
  # shellcheck source=/dev/null
  [ -r "$FILE" ] && source "$FILE";
done;
unset FILE;
