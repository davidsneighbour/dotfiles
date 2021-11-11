#!/usr/bin/env bash

REQUIRED_TOOLS=(
    export
)

for tool in ${REQUIRED_TOOLS[@]}; do
  if ! command -v ${tool} >/dev/null; then
    echo "${tool} is required... "
    exit 1
  fi
done

while getopts v:h: flag
do
    case "${flag}" in
        v) debug=true;;
        h) vars=${OPTARG};;
    esac
done

FILE=~/.env
if [ -f "$FILE" ]; then
  export $(grep -v '^#' $FILE | xargs)
fi

if [ "$debug" = true ] ; then
  echo "Completed in ${SECONDS}s"
fi
