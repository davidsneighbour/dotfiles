#!/bin/bash

# exit if any command fails
set -e

# synch books
rsync -rztv media:/home/patrick/Downloads/Books/ /home/patrick/Downloads/Books

# remove remote book files
ssh media "rm -rf /home/patrick/Downloads/Books/*"
