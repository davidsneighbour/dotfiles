#!/bin/bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERBOSE=false
DRY_RUN=false

APT_PACKAGES=(
  build-essential
  conky-all apcupsd audacious moc mpd
  coreutils
  curl
  libimage-exiftool-perl
  feh
  ffmpeg
  filezilla filezilla-theme-papirus filezilla-common
  git git-delta git-extras
  htop
  jsonnet
  golang-go
  librsvg2-bin
  meld
  nmap arp-scan net-tools
  openshot-qt python3-openshot
  papirus-icon-theme papirus-folders papirus-colors
  pulseaudio-utils
  qbittorrent
  shfmt
  software-properties-common
  unzip
  vlc
  wget
  wtmpdb
  wmctrl
  yad
  yamllint
)

print_help() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--verbose] [--dry-run] [--help]

Add the libreoffice/papirus/openshot PPAs, update/upgrade/clean apt, install
the base workstation package set, install the vale snap, and copy the
git-extras Bash completion into this repo's completions directory.

Options:
  --verbose   Trace each command as it runs.
  --dry-run   Print what would run without changing anything.
  --help      Show this help.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
  --verbose)
    VERBOSE=true
    shift
    ;;
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  --help)
    print_help
    exit 0
    ;;
  *)
    echo "Unknown argument: ${1}" >&2
    print_help >&2
    exit 1
    ;;
  esac
done

if [[ "${DRY_RUN}" == true ]]; then
  cat <<EOF
Would run:
  1. Add PPAs: libreoffice/ppa, papirus/papirus, openshot.developers/ppa
  2. sudo apt update / upgrade / dist-upgrade / autoremove / clean
  3. sudo apt install -y ${APT_PACKAGES[*]}
  4. sudo snap install vale
  5. Copy /usr/etc/bash-completion/completions/git-extras into bashrc/partials/_completions/
EOF
  exit 0
fi

if [[ "${VERBOSE}" == true ]]; then
  set -x
fi

sudo add-apt-repository ppa:libreoffice/ppa --yes --no-update
sudo add-apt-repository ppa:papirus/papirus --yes --no-update
sudo add-apt-repository ppa:openshot.developers/ppa --yes --no-update

sudo apt update
sudo apt upgrade --yes
sudo apt dist-upgrade --yes
sudo apt autoremove --yes
sudo apt clean --yes

sudo apt install -y "${APT_PACKAGES[@]}"

sudo snap install vale

cp --remove-destination "/usr/etc/bash-completion/completions/git-extras" "${HOME}/.dotfiles/bashrc/partials/_completions/"
