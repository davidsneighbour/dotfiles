# Parse APT's history log (/var/log/apt/history.log*) into one row per
# package and action.
#
# Input: the log entries in chronological order (the caller decompresses the
# rotated .gz files and puts the oldest first).
#
# Variables:
#   ALL_ACTIONS  1 to print all actions. Otherwise only explicit installs
#                (Install entries without the "automatic" flag) are printed.
#
# Output: tab-separated rows with these fields:
#   date (YYYY-MM-DD HH:MM), action, package, version, command line
#
# Actions: install, install-auto (installed as a dependency), upgrade,
# downgrade, reinstall, remove, purge. For upgrade and downgrade, the version
# is the new version.

BEGIN {
  ACTION["Install"] = "install"
  ACTION["Upgrade"] = "upgrade"
  ACTION["Downgrade"] = "downgrade"
  ACTION["Reinstall"] = "reinstall"
  ACTION["Remove"] = "remove"
  ACTION["Purge"] = "purge"
}

/^Start-Date: / {
  date = substr($0, 13)
  gsub(/  +/, " ", date)
  date = substr(date, 1, 16)
  commandline = ""
  next
}

/^Commandline: / {
  commandline = substr($0, 14)
  gsub(/\t/, " ", commandline)
  next
}

{
  key = $0
  sub(/:.*/, "", key)
  if (!(key in ACTION)) {
    next
  }
  value = substr($0, length(key) + 3)
  n = split(value, items, /\), /)
  for (i = 1; i <= n; i++) {
    print_item(ACTION[key], items[i])
  }
}

# One item looks like "name:arch (version)", "name:arch (version, automatic)",
# or, for upgrades, "name:arch (old, new)".
function print_item(action, item,    name, details, np, parts, version) {
  name = item
  sub(/ .*/, "", name)
  sub(/:.*/, "", name)
  details = item
  sub(/^[^(]*\(/, "", details)
  sub(/\)$/, "", details)
  np = split(details, parts, /, /)
  version = parts[1]
  if (action == "install" && parts[np] == "automatic") {
    action = "install-auto"
  } else if ((action == "upgrade" || action == "downgrade") && np >= 2) {
    version = parts[2]
  }
  if (ALL_ACTIONS != 1 && action != "install") {
    return
  }
  printf "%s\t%s\t%s\t%s\t%s\n", date, action, name, version, commandline
}
