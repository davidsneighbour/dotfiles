#!/bin/bash
# shellcheck shell=bash
# dnb-dotfiles 3003.2.0

# a collection of inxi aliases for quick system information
alias sysinfo='inxi -Sxxx'
alias sysinfo-full='inxi -Fxxxz'
alias sysinfo-cpu='inxi -Cxxx'
alias sysinfo-gpu='inxi -Gxxx'
alias sysinfo-mem='inxi -mxxx'

# more verbosity
alias mv="mv -iv"
alias cp="cp -iv"
