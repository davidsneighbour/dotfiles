#!/bin/bash

# Check if the current user is not root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Exiting."
  exit 1
fi

su patrick -c 'notify-send -u critical \
  "Backup" \
  "starting at $(date)"'

# Paths to backup
backup_files="/home /etc /root /boot /opt"
# backup_files="/etc"

# Backup destination
dest="/media/patrick/Glacier/System"

# Date variables
day=$(date +%A)
day_num=$(date +%-d)
month_num=$(date +%m)
hostname=$(hostname -s)

# Week of the month calculation
week_num=$(((day_num - 1) / 7 + 1))
week_file="${hostname}-week${week_num}.tgz"

# Month calculation
month_file="${hostname}-month$((month_num % 2 + 1)).tgz"

# Archive filename decision
archive_file="${hostname}-${day}.tgz"
[[ "${day_num}" == 1 ]] && archive_file=${month_file}
[[ "${day}" == "Saturday" ]] && archive_file=${week_file}

# Backup process
echo "Backing up ${backup_files} to ${dest}/${archive_file}"
date
# shellcheck disable=SC2086
tar czf "${dest}/${archive_file}" ${backup_files} || {
  echo "Backup failed"
  exit 1
}
echo -e "\nBackup finished"
date

# File sizes
ls -lh "${dest}/"

su patrick -c 'notify-send -u critical \
  "Backup" \
  "starting at $(date)"'
