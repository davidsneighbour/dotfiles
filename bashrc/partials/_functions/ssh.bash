#!/bin/bash
# shellcheck shell=bash

ssh() {
  local normal_bg="#000000"
  local remote_bg="#0B0D0F"

  printf '\e]11;%s\a' "${remote_bg}"
  printf '\e]0;SSH: %s\a' "$*"

  command ssh "$@"
  local exit_code=$?

  printf '\e]11;%s\a' "${normal_bg}"
  printf '\e]0;Terminal\a'

  return "${exit_code}"
}
