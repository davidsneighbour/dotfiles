#!/bin/bash
# executed by the command interpreter for non-interactive login shells

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
umask 022

# the logical path THIS file is in
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# load the library functions
for FILE in "${SCRIPT_DIR}"/bash/_lib/*; do
  [ -f "${FILE}" ] && source "${FILE}"
done


# @TODO add npm
