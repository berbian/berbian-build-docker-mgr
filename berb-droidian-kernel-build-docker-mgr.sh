#!/bin/bash

## berb-droidian-kernel-build-docker-mgr
## Script that creates a Custom Docker Container with Droidian Build Environment
## Berbasc 2022

# Version 0.0.0

## REQUERIMENTS
   # Set cons Wwith your own values:
     # PACKAGER_DIR KERNEL_DIR CONTAINER_NAME

# Path cons
PACKAGES_DIR="./Droidian/kernel/lavender/sources/droidian-lavender-4.4.192-2022-sources/compilat/"
KERNEL_DIR="./Droidian/kernel/lavender/sources/droidian-lavender-4.4.192-2022-sources/kernel-xiaomi-lavender/"
# Scan const PACKAGES_DIR
[ -z "$PACKAGES_DIR" ] || echo "" && read -p \
	"Enter the absolute path that you want to the output dir for deb packages: " PACKAGES_DIR
# Scan const KERNEL_DIR
[ -z "$KERNEL_DIR" ] || echo "" && read -p \
	"Enter the absolute path to your kernel source root dir: " KERNEL_DIR



# Docker cons
CONTAINER_NAME="droidian-kkrtts-build-env"


# Creating the container
docker create --name $CONTAINER_NAME -v $PACKAGES_DIR:/buildd -v $KERNEL_DIR:/buildd/sources -p 2222:2222 -i -t quay.io/droidian/build-essential:bookworm-amd64


