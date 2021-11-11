# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

for file in "$(dirname "$BASH_SOURCE")"/.dotfiles/homedir/bash/{options,bash,functions,exports,aliases,completion,prompt}.sh; do
  [ -r "$file" ] && source "$file";
done;
unset file;
