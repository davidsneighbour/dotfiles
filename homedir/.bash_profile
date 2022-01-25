#!/bin/bash
# executed by the command interpreter for login shells

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
umask 022

# if running bash
if [ -n "${BASH_VERSION}" ]; then
  # include .bashrc if it exists
  if [ -f "${HOME}/.bashrc" ]; then
    # shellcheck source=homedir/.bashrc
    source "${HOME}/.bashrc"
  fi
fi
