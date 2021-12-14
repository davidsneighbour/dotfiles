# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# history setup
export HISTCONTROL=ignoreboth:erasedups # don't put duplicate lines or lines starting with space in the history and remove doubles
export HISTFILESIZE=                    # unlimited history size
export HISTSIZE=
shopt -s histappend                     # append to the history file, don't overwrite it
shopt -s histverify                     # don't execute history searched lines, put them in the shell
shopt -s extglob                        # extended pattern matching features
shopt -s dotglob                        # for considering dot files (turn on dot files)
shopt -s cdspell                        # correct dir spelling errors on cd
shopt -s lithist                        # save multi-line commands with newlines
shopt -s autocd                         # if a command is a dir name, cd to it
shopt -s checkjobs                      # print warning if jobs are running on shell exit
shopt -s dirspell                       # correct dir spelling errors on completion
shopt -s globstar                       # ** matches all files, dirs and subdirs
shopt -s cmdhist                        # save multi-line commands in a single hist entry
shopt -s cdable_vars                    # if cd arg is not a dir, assume it is a var
shopt -s checkwinsize                   # check the window size after each command
shopt -s no_empty_cmd_completion        # don't try to complete empty cmds

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt
color_prompt=yes

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# add local scripts directory to the path
if [ -d "$HOME/Scripts" ] ; then
  PATH="$PATH:$HOME/Scripts"
fi

if [ -d "$HOME/.npm/packages/bin" ] ; then
  PATH="$PATH:$HOME/.npm/packages/bin"
fi

if [ -d "$HOME/.bin" ] ; then
  PATH="$HOME/.bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ] ; then
  PATH="$HOME/.local/bin:$PATH"
fi

if [ -d "$HOME/.local/npm/bin" ] ; then
  PATH="$HOME/.local/npm/bin:$PATH"
fi

if [ -d "$HOME/.local/share/umake/bin" ] ; then
  PATH="$HOME/.local/share/umake/bin:$PATH"
fi

if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/.bin/local/bin" ] ; then
    PATH="$HOME/.bin/local/bin:$PATH"
fi

if [ -d "$HOME/.npm-global/bin" ] ; then
    PATH="$HOME/.npm-global/bin:$PATH"
fi

if [ -d "$HOME/.config/composer/vendor/bin" ] ; then
    PATH="$HOME/.config/composer/vendor/bin:$PATH"
fi

if [ -d "$HOME/.dotfiles/scripts" ] ; then
    PATH="$HOME/.dotfiles/scripts:$PATH"
fi

if [ -d "$HOME/.bin/android-sdk" ] ; then
    PATH="$HOME/.bin/android-sdk/tools:$HOME/.bin/android-sdk/platform-tools:$PATH"
    export ANDROID_HOME=$HOME/.bin/android/sdk
fi

if [ -d "$HOME/.npm" ] ; then
    PATH="$PATH:$HOME/.npm/bin"
    export NODE_PATH="$NODE_PATH:$HOME/.npm/lib/node_modules"
fi

if [ -d "$HOME/.rbenv/bin" ] ; then
    PATH="$HOME/.rbenv/bin:$PATH"
fi

if [ -d "/usr/local/heroku/bin" ] ; then
    PATH="/usr/local/heroku/bin:$PATH"
fi

if [ -d "$HOME/.config/composer/vendor/bin" ] ; then
    PATH="$HOME/.config/composer/vendor/bin:$PATH"
fi

if [ -d "/usr/lib/dart/bin" ] ; then
    PATH="/usr/lib/dart/bin:$PATH"
fi

# don't add jrnl entries to bash history
HISTIGNORE="$HISTIGNORE:jrnl *"

export GOPATH=$HOME/go
export EDITOR=/usr/bin/vim

PAGER='less -i'

set -o notify   # Report status of terminated bg jobs immediately
set -o emacs    # emacs-style editing

# enable coloured man pages
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

# define some colours
GREY=$'\033[1;30m'
RED=$'\033[1;31m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[1;34m'
MAGENTA=$'\033[1;35m'
CYAN=$'\033[1;36m'
WHITE=$'\033[1;37m'
NONE=$'\033[m'

# random grep colour
export GREP_COLOR="1;3$((RANDOM%6+1))"

# path for directories
export CDPATH=".:..:../..:~/:~/dev/"

# file containing hosts
export HOSTFILE=~/.bash_hosts

#export VISUAL=subl
export EDITOR=vim

# see https://wiki.archlinux.org/index.php/GTK+#Suppress_warning_about_accessibility_bus
export NO_AT_BRIDGE=1

export PATH

source ~/.dotfiles/bin/load-env.sh
