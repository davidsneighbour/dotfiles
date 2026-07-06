#!/bin/bash
# shellcheck shell=bash

alias synch-dio2loc="rsync -aHAXv --numeric-ids --delete \
  ~/github.com/davidsneighbour/ \
  locutus:~/github.com/davidsneighbour/"

alias dus='du --summarize'
