#!/bin/bash

git stash -m "dotbot update" --include-untracked
cd dotbot/lib/pyyaml
git checkout main
git pull --no-recurse-submodules
cd ../..
git checkout master
git pull --no-recurse-submodules
cd ../dotbot-plugins/crontab-dotbot
git checkout master
git pull --no-recurse-submodules
cd ../dotbot-aptget
git checkout master
git pull --no-recurse-submodules
cd ../../
git add dotbot*
git commit -m "chore(git): update dotbot submodules"
git stash pop
