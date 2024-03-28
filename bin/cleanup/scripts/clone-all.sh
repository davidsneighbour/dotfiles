#!/bin/bash

if [ -z "$1" ]; then
    echo "Arguments: username [max-page-number [(users|orgs)]]"
    exit 1
else
    name=$1
fi

if [ -z "$2" ]; then
    max=2
else
    max=$2
fi

if [ -z "$3" ]; then
    cntx=users
else
    cntx=orgs
fi

page=1

echo "${name}"
echo "${max}"
echo "${cntx}"
echo "${page}"

until (( $page -lt $max ))
do
    curl "https://api.github.com/$cntx/$name/repos?page=$page&per_page=100" | grep -e 'clone_url*' | cut -d \" -f 4 | xargs -L1 git clone
    page=${page}+1
done

exit 0