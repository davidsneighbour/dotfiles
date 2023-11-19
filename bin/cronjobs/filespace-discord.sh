#!/bin/bash

FILE=~/.env
if [ -f "${FILE}" ]; then
  #echo "exporting .env"
  set -a # export all variables created next
  # this routine ranges through a folder of files that we don't explicitly know (@davidsneighbour)
  # see https://github.com/koalaman/shellcheck/wiki/SC1090
  # shellcheck source=/dev/null
  source "${FILE}"
  set +a # stop exporting
fi

# This variable holds the usage disk space in percents
CURRENT=$(df / | grep / | awk '{ print $5}' | sed 's/%//g')

# The threshold where the alert will be sent.
THRESHOLD=50

if [ "${CURRENT}" -gt "${THRESHOLD}" ]; then

  PROJECT_NAME="Behemoth"

  # shellcheck disable=SC2154
  curl --location --request POST "${DISCORD_WEBHOOK}" \
    --form "content=\":floppy_disk: The disk space for ${PROJECT_NAME} is critical.
    Used: ${CURRENT}%.
    Please clean up some space.\" " \
    --form 'username="Disk Space Alert"'

fi
